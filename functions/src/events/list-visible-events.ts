import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import {
	assertSignedIn,
	getCallerData,
	isEventVisibleToUser,
} from "../services/event-access.service";
import { fastCallableOptions } from "../runtime-options";

function eventResponse(id: string, data: Record<string, any>) {
	return {
		eventId: id,
		scopeType: String(data.scopeType ?? ""),
		title: String(data.title ?? ""),
		details: String(data.details ?? ""),
		location: String(data.location ?? ""),
		notes: String(data.notes ?? ""),
		eventAt: Number(data.eventAt ?? 0) || 0,
		department: String(data.department ?? ""),
		targetGroupId: String(data.targetGroupId ?? ""),
		targetGroupName: String(data.targetGroupName ?? ""),
		interestedCount: Number(data.interestedCount ?? 0) || 0,
		isCancelled: data.isCancelled === true,
		createdBy: String(data.createdBy ?? ""),
		createdByName: String(data.createdByName ?? ""),
	};
}

function normalizedPageLimit(value: unknown) {
	const raw = Number(value ?? 200);
	if (!Number.isFinite(raw)) return 200;
	return Math.max(20, Math.min(Math.floor(raw), 300));
}

function isAfterCursor(
	event: ReturnType<typeof eventResponse>,
	cursorEventAt: number,
	cursorEventId: string,
) {
	if (!cursorEventAt || !cursorEventId) return true;
	if (event.eventAt > cursorEventAt) return true;
	if (event.eventAt < cursorEventAt) return false;
	return event.eventId > cursorEventId;
}

export const listVisibleEvents = onCall(
	fastCallableOptions,
	async (request) => {
		const uid = assertSignedIn(request);
		const callerData = await getCallerData(uid);
		const mode = String(request.data.mode ?? "upcoming");
		const now = Date.now();
		const limit = normalizedPageLimit(request.data.limit);
		const cursorEventAt = Number(request.data.cursorEventAt ?? 0);
		const cursorEventId = String(request.data.cursorEventId ?? "").trim();

		const department = String(callerData.department ?? "").trim();
		const groupIds = Array.isArray(callerData.groupIds)
			? callerData.groupIds.map((e: any) => String(e)).filter(Boolean)
			: [];

		const visibilityKeys = Array.from(
			new Set([
				"all",
				...(department ? [`dept:${department}`] : []),
				...groupIds.map((id: string) => `group:${id}`),
			]),
		);

		const keyChunks: string[][] = [];
		for (let i = 0; i < visibilityKeys.length; i += 30) {
			keyChunks.push(visibilityKeys.slice(i, i + 30));
		}

		const byId = new Map<string, ReturnType<typeof eventResponse>>();
		const lowerBound = mode === "all" ? 0 : now;
		const hasCursor =
			Number.isFinite(cursorEventAt) &&
			cursorEventAt > 0 &&
			cursorEventId.length > 0;

		const snapshots = await Promise.all(
			keyChunks.map(async (keys) => {
				let ref: FirebaseFirestore.Query = admin
					.firestore()
					.collection("events")
					.where("isCancelled", "==", false)
					.where("visibilityKeys", "array-contains-any", keys)
					.where("eventAt", ">=", lowerBound)
					.orderBy("eventAt", "asc")
					.orderBy(admin.firestore.FieldPath.documentId(), "asc")
					.limit(limit + 1);

				if (hasCursor) {
					ref = ref.startAfter(cursorEventAt, cursorEventId);
				}

				return ref.get().catch((e) => {
					throw new HttpsError(
						"failed-precondition",
						"قد تحتاج إلى إنشاء فهرس Firestore للأحداث",
						e?.message,
					);
				});
			}),
		);

		for (const snap of snapshots) {
			for (const doc of snap.docs) {
				const data = doc.data() || {};
				if (!isEventVisibleToUser(data, callerData)) continue;

				const event = eventResponse(doc.id, data);
				if (!isAfterCursor(event, cursorEventAt, cursorEventId)) continue;

				byId.set(doc.id, event);
			}
		}

		const sortedEvents = Array.from(byId.values()).sort((a, b) => {
			const byTime = a.eventAt - b.eventAt;
			if (byTime !== 0) return byTime;
			return a.eventId.localeCompare(b.eventId);
		});

		const pageEvents = sortedEvents.slice(0, limit);
		const lastEvent = pageEvents[pageEvents.length - 1];
		const hasMore = sortedEvents.length > limit;

		return {
			success: true,
			events: pageEvents,
			hasMore,
			nextCursor:
				hasMore && lastEvent
					? { eventAt: lastEvent.eventAt, eventId: lastEvent.eventId }
					: null,
		};
	},
);
