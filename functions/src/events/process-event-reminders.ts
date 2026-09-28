import { randomUUID } from "node:crypto";
import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";
import { onSchedule } from "firebase-functions/v2/scheduler";

import { scheduledJobOptions } from "../runtime-options";
import {
	collectTokensByLanguageForUserIds,
	sendLocalizedNotificationToTokensByLanguage,
} from "../services/event-notification.service";
import {
	type EventReminderKey,
	formatRemainingDurationArabic,
	formatRemainingDurationEnglish,
	listEventReminderCheckpoints,
} from "../utils/event-helpers";

const EVENT_PROCESSING_LIMIT = 100;
const EVENT_CONCURRENCY = 5;
const INTEREST_PAGE_SIZE = 400;
const REMINDER_LEASE_MS = 15 * 60 * 1000;

type ReminderJob = {
	key: EventReminderKey;
	token: string;
	body: { ar: string; en: string };
};

type ReminderOutcome = ReminderJob & {
	success: boolean;
	error?: unknown;
};

type ClaimedEvent = {
	title: string;
	jobs: ReminderJob[];
};

function sentField(key: EventReminderKey) {
	return `${key}ReminderSentAt`;
}

function processingAtField(key: EventReminderKey) {
	return `${key}ReminderProcessingAt`;
}

function processingTokenField(key: EventReminderKey) {
	return `${key}ReminderProcessingToken`;
}

function toMillis(value: unknown): number | null {
	if (value instanceof admin.firestore.Timestamp) return value.toMillis();
	const parsed = Number(value ?? Number.NaN);
	return Number.isFinite(parsed) ? parsed : null;
}

function reminderBaseMillis(data: Record<string, any>): number | null {
	return toMillis(data.reminderBaseAt ?? data.createdAt);
}

function nextReminderAtForData(
	data: Record<string, any>,
	now: number,
): number | null {
	const baseAt = reminderBaseMillis(data);
	const eventAt = Number(data.eventAt ?? 0);
	if (
		baseAt === null ||
		!Number.isFinite(eventAt) ||
		eventAt <= now ||
		data.isCancelled === true
	) {
		return null;
	}

	const candidates = listEventReminderCheckpoints(baseAt, eventAt)
		.filter(({ key }) => !data[sentField(key)])
		.map(({ key, at }) => {
			const processingAt = toMillis(data[processingAtField(key)]);
			const processingToken = String(
				data[processingTokenField(key)] ?? "",
			).trim();
			const leaseUntil =
				processingAt !== null && processingToken
					? processingAt + REMINDER_LEASE_MS
					: 0;
			return Math.max(now, at, leaseUntil);
		});

	return candidates.length > 0 ? Math.min(...candidates) : null;
}

function buildReminderBody({
	key,
	eventAt,
	checkpointAt,
	title,
}: {
	key: EventReminderKey;
	eventAt: number;
	checkpointAt: number;
	title: string;
}) {
	if (key === "hour") {
		return {
			ar: `يتبقى ساعة أو أقل على الحدث: ${title}`,
			en: `One hour or less remaining for the event: ${title}`,
		};
	}

	return {
		ar: `باقي ${formatRemainingDurationArabic(eventAt - checkpointAt)} على الحدث: ${title}`,
		en: `${formatRemainingDurationEnglish(eventAt - checkpointAt)} remaining for the event: ${title}`,
	};
}

async function claimDueReminders(
	eventRef: FirebaseFirestore.DocumentReference,
	now: number,
): Promise<ClaimedEvent | null> {
	return admin.firestore().runTransaction(async (transaction) => {
		const eventSnapshot = await transaction.get(eventRef);
		if (!eventSnapshot.exists) return null;

		const data = eventSnapshot.data() || {};
		const baseAt = reminderBaseMillis(data);
		const eventAt = Number(data.eventAt ?? 0);
		if (
			baseAt === null ||
			!Number.isFinite(eventAt) ||
			eventAt <= now ||
			data.isCancelled === true
		) {
			transaction.update(eventRef, { nextReminderAt: null });
			return null;
		}

		const title = String(data.title ?? "").trim() || "تذكير بالحدث";
		const jobs: ReminderJob[] = [];
		const processingTimestamp = admin.firestore.Timestamp.fromMillis(now);
		const virtualData = { ...data };
		const updates: Record<string, unknown> = {};

		for (const checkpoint of listEventReminderCheckpoints(baseAt, eventAt)) {
			if (checkpoint.at > now || data[sentField(checkpoint.key)]) continue;

			const processingAt = toMillis(data[processingAtField(checkpoint.key)]);
			const existingToken = String(
				data[processingTokenField(checkpoint.key)] ?? "",
			).trim();
			if (
				processingAt !== null &&
				existingToken &&
				processingAt + REMINDER_LEASE_MS > now
			) {
				continue;
			}

			const token = randomUUID();
			jobs.push({
				key: checkpoint.key,
				token,
				body: buildReminderBody({
					key: checkpoint.key,
					eventAt,
					checkpointAt: checkpoint.at,
					title,
				}),
			});

			updates[processingAtField(checkpoint.key)] = processingTimestamp;
			updates[processingTokenField(checkpoint.key)] = token;
			virtualData[processingAtField(checkpoint.key)] = processingTimestamp;
			virtualData[processingTokenField(checkpoint.key)] = token;
		}

		updates.nextReminderAt = nextReminderAtForData(virtualData, now);
		transaction.update(eventRef, updates);

		return jobs.length > 0 ? { title, jobs } : null;
	});
}

async function deliverClaimedReminders(
	eventRef: FirebaseFirestore.DocumentReference,
	claimed: ClaimedEvent,
): Promise<ReminderOutcome[]> {
	const outcomes = new Map<EventReminderKey, ReminderOutcome>(
		claimed.jobs.map((job) => [job.key, { ...job, success: true }]),
	);
	const orderedInterests = eventRef
		.collection("interestedUsers")
		.orderBy(admin.firestore.FieldPath.documentId());
	let query = orderedInterests.limit(INTEREST_PAGE_SIZE);

	while (true) {
		const snapshot = await query.get();
		if (snapshot.empty) break;

		const activeOutcomes = [...outcomes.values()].filter(
			(outcome) => outcome.success,
		);
		if (activeOutcomes.length === 0) break;

		try {
			const interestedUserIds = snapshot.docs.map((document) => document.id);
			const tokensByLanguage =
				await collectTokensByLanguageForUserIds(interestedUserIds);
			const results = await Promise.allSettled(
				activeOutcomes.map((outcome) =>
					sendLocalizedNotificationToTokensByLanguage({
						tokensByLanguage,
						title: {
							ar: `⏰ ${claimed.title}`,
							en: `⏰ ${claimed.title}`,
						},
						body: outcome.body,
						data: {
							type: "event_reminder",
							eventId: eventRef.id,
							reminderType: outcome.key,
						},
					}),
				),
			);

			for (const [index, result] of results.entries()) {
				if (result.status === "fulfilled") continue;
				const outcome = activeOutcomes[index];
				if (!outcome) continue;
				outcome.success = false;
				outcome.error = result.reason;
			}
		} catch (error) {
			for (const outcome of activeOutcomes) {
				outcome.success = false;
				outcome.error = error;
			}
			break;
		}

		const lastDocument = snapshot.docs.at(-1);
		if (!lastDocument || snapshot.size < INTEREST_PAGE_SIZE) break;
		query = orderedInterests.startAfter(lastDocument).limit(INTEREST_PAGE_SIZE);
	}

	return [...outcomes.values()];
}

async function finishReminderClaims(
	eventRef: FirebaseFirestore.DocumentReference,
	outcomes: ReminderOutcome[],
	now: number,
) {
	await admin.firestore().runTransaction(async (transaction) => {
		const eventSnapshot = await transaction.get(eventRef);
		if (!eventSnapshot.exists) return;

		const data = eventSnapshot.data() || {};
		const virtualData = { ...data };
		const updates: Record<string, unknown> = {};
		let hasOwnedClaim = false;

		for (const outcome of outcomes) {
			const tokenField = processingTokenField(outcome.key);
			if (String(data[tokenField] ?? "") !== outcome.token) continue;

			hasOwnedClaim = true;
			updates[processingAtField(outcome.key)] =
				admin.firestore.FieldValue.delete();
			updates[tokenField] = admin.firestore.FieldValue.delete();
			delete virtualData[processingAtField(outcome.key)];
			delete virtualData[tokenField];

			if (outcome.success) {
				updates[sentField(outcome.key)] =
					admin.firestore.FieldValue.serverTimestamp();
				virtualData[sentField(outcome.key)] =
					admin.firestore.Timestamp.fromMillis(now);
			}
		}

		if (!hasOwnedClaim) return;
		updates.nextReminderAt = nextReminderAtForData(virtualData, now);
		transaction.update(eventRef, updates);
	});
}

async function processEventDocument(
	eventRef: FirebaseFirestore.DocumentReference,
	now: number,
) {
	try {
		const claimed = await claimDueReminders(eventRef, now);
		if (!claimed) return;

		const outcomes = await deliverClaimedReminders(eventRef, claimed);
		for (const outcome of outcomes) {
			if (outcome.success) continue;
			logger.error("Failed to deliver event reminder", {
				eventId: eventRef.id,
				reminderType: outcome.key,
				error: outcome.error,
			});
		}
		await finishReminderClaims(eventRef, outcomes, Date.now());
	} catch (error) {
		logger.error("Failed to process event reminder", {
			eventId: eventRef.id,
			error,
		});
	}
}


async function processWithConcurrency(
	documents: FirebaseFirestore.QueryDocumentSnapshot[],
	now: number,
) {
	for (let index = 0; index < documents.length; index += EVENT_CONCURRENCY) {
		await Promise.all(
			documents
				.slice(index, index + EVENT_CONCURRENCY)
				.map((document) => processEventDocument(document.ref, now)),
		);
	}
}

export const processEventReminders = onSchedule(
	{
		...scheduledJobOptions,
		schedule: "every 10 minutes",
	},
	async () => {
		const now = Date.now();

		const snapshot = await admin
			.firestore()
			.collection("events")
			.where("isCancelled", "==", false)
			.where("nextReminderAt", "<=", now)
			.orderBy("nextReminderAt")
			.limit(EVENT_PROCESSING_LIMIT)
			.get();

		await processWithConcurrency(snapshot.docs, now);
	},
);
