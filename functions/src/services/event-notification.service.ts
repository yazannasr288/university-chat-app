import * as admin from "firebase-admin";
import { listIndexedGroupMemberUids } from "./group-member-index.service";
import { USER_DOC_FETCH_CHUNK_SIZE } from "../constants";
import type {
	EventScopeType,
	NotifyEventAudienceArgs,
} from "../types/event-types";
import { sendMulticastAndClean } from "./fcm.service";
import { chunkArray } from "../utils/array";
import type {
	LocalizedText,
	SupportedLanguageCode,
} from "../utils/localized-notifications";
import {
	localizedText,
	normalizeLanguageCode,
} from "../utils/localized-notifications";

type LocalizedNotificationInput = string | LocalizedText;
type TokensByLanguage = Record<SupportedLanguageCode, string[]>;

function isMutedSettingsActive(
	settingsData: Record<string, any> | undefined,
): boolean {
	if (!settingsData || settingsData.muted !== true) return false;

	const mutedUntil = settingsData.mutedUntil;
	if (!mutedUntil) return true;

	if (mutedUntil instanceof admin.firestore.Timestamp) {
		return mutedUntil.toMillis() > Date.now();
	}

	const fallback = Number(mutedUntil ?? 0);
	return Number.isFinite(fallback) ? fallback > Date.now() : true;
}

function isActiveAccount(data: Record<string, any>): boolean {
	const status = String(data.accountStatus ?? "active").trim();
	return status === "" || status === "active";
}

function toLocalizedText(value: LocalizedNotificationInput): LocalizedText {
	if (typeof value === "string") return { ar: value, en: value };
	return value;
}

export async function collectTokensByLanguageForUserIds(
	userIds: string[],
	mutedGroupId = "",
): Promise<TokensByLanguage> {
	const uniqueUserIds = [
		...new Set(userIds.map((e) => e.trim()).filter((e) => e.length > 0)),
	];
	const tokensByLanguage: TokensByLanguage = { ar: [], en: [] };

	if (uniqueUserIds.length === 0) return tokensByLanguage;

	for (const uidChunk of chunkArray(uniqueUserIds, USER_DOC_FETCH_CHUNK_SIZE)) {
		const userRefs = uidChunk.map((uid) =>
			admin.firestore().collection("users").doc(uid),
		);
		const userDocs = await admin.firestore().getAll(...userRefs);

		const settingsRefs = mutedGroupId
			? uidChunk.map((uid) =>
					admin
						.firestore()
						.collection("users")
						.doc(uid)
						.collection("groupSettings")
						.doc(mutedGroupId),
				)
			: [];
		const settingsDocs =
			settingsRefs.length > 0
				? await admin.firestore().getAll(...settingsRefs)
				: [];

		for (const [index, doc] of userDocs.entries()) {
			if (!doc.exists) continue;
			if (mutedGroupId && isMutedSettingsActive(settingsDocs[index]?.data()))
				continue;

			const data = doc.data() || {};
			if (!isActiveAccount(data)) continue;

			const token = String(data.fcmToken ?? "").trim();
			if (token.length === 0) continue;

			tokensByLanguage[normalizeLanguageCode(data.languageCode)].push(token);
		}
	}

	return {
		ar: [...new Set(tokensByLanguage.ar)],
		en: [...new Set(tokensByLanguage.en)],
	};
}



export async function sendLocalizedNotificationToTokensByLanguage({
	tokensByLanguage,
	title,
	body,
	data,
}: {
	tokensByLanguage: TokensByLanguage;
	title: LocalizedNotificationInput;
	body: LocalizedNotificationInput;
	data: Record<string, string>;
}) {
	const localizedTitle = toLocalizedText(title);
	const localizedBody = toLocalizedText(body);

	await Promise.all(
		(["ar", "en"] as const).map(async (languageCode) => {
			const tokens = [...new Set(tokensByLanguage[languageCode])];
			if (tokens.length === 0) return;

			await sendMulticastAndClean({
				tokens,
				title: localizedText(localizedTitle, languageCode),
				body: localizedText(localizedBody, languageCode),
				data,
			});
		}),
	);
}


export async function notifyEventAudience(args: NotifyEventAudienceArgs) {
	const mutedGroupId = args.scopeType === "group" ? args.targetGroupId : "";
	let tokensByLanguage: TokensByLanguage;

	if (args.scopeType === "group") {
		const audienceUserIds = await collectAudienceUserIds(args);
		tokensByLanguage = await collectTokensByLanguageForUserIds(
			audienceUserIds,
			mutedGroupId,
		);
	} else {
		let query: FirebaseFirestore.Query = admin.firestore().collection("users");
		if (args.scopeType === "department") {
			query = query.where("department", "==", args.department);
		}
		tokensByLanguage = await collectTokensByLanguageForQuery(query);
	}

	await sendLocalizedNotificationToTokensByLanguage({
		tokensByLanguage,
		title: args.title,
		body: args.body,
		data: {
			type: args.dataType,
			eventId: args.eventId,
			scopeType: args.scopeType,
			...(mutedGroupId ? { groupId: mutedGroupId } : {}),
		},
	});
}

function collectTokensByLanguageForUserQueryPage(
	documents: FirebaseFirestore.QueryDocumentSnapshot[],
): TokensByLanguage {
	const tokensByLanguage: TokensByLanguage = { ar: [], en: [] };

	for (const doc of documents) {
		const data = doc.data() || {};
		if (!isActiveAccount(data)) continue;

		const token = String(data.fcmToken ?? "").trim();
		if (!token) continue;
		tokensByLanguage[normalizeLanguageCode(data.languageCode)].push(token);
	}

	return tokensByLanguage;
}

async function collectTokensByLanguageForQuery(
	baseQuery: FirebaseFirestore.Query,
): Promise<TokensByLanguage> {
	const tokensByLanguage: TokensByLanguage = { ar: [], en: [] };
	const orderedQuery = baseQuery.orderBy(
		admin.firestore.FieldPath.documentId(),
	);
	let query = orderedQuery.limit(500);

	while (true) {
		const snapshot = await query.get();
		if (snapshot.empty) break;

		const pageTokens = collectTokensByLanguageForUserQueryPage(snapshot.docs);
		tokensByLanguage.ar.push(...pageTokens.ar);
		tokensByLanguage.en.push(...pageTokens.en);

		const lastDocument = snapshot.docs.at(-1);
		if (!lastDocument || snapshot.size < 500) break;
		query = orderedQuery.startAfter(lastDocument).limit(500);
	}

	return {
		ar: [...new Set(tokensByLanguage.ar)],
		en: [...new Set(tokensByLanguage.en)],
	};
}

export async function collectAudienceUserIds({
	scopeType,
	department,
	targetGroupId,
}: {
	scopeType: EventScopeType;
	department: string;
	targetGroupId: string;
}) {
	if (scopeType === "university") {
		const ids: string[] = [];
		let query = admin
			.firestore()
			.collection("users")
			.orderBy("__name__")
			.limit(500);

		let snapshot = await query.get();

		while (!snapshot.empty) {
			ids.push(...snapshot.docs.map((doc) => doc.id));

			if (snapshot.size < 500) break;
			const lastDoc = snapshot.docs.at(-1);
			if (!lastDoc) break;
			snapshot = await query.startAfter(lastDoc).get();
		}

		return ids;
	}

	if (scopeType === "department") {
		const ids: string[] = [];
		let query = admin
			.firestore()
			.collection("users")
			.where("department", "==", department)
			.orderBy("__name__")
			.limit(500);

		let snapshot = await query.get();

		while (!snapshot.empty) {
			ids.push(...snapshot.docs.map((doc) => doc.id));

			if (snapshot.size < 500) break;
			const lastDoc = snapshot.docs.at(-1);
			if (!lastDoc) break;
			snapshot = await query.startAfter(lastDoc).get();
		}

		return ids;
	}

	const groupDoc = await admin
		.firestore()
		.collection("groups")
		.doc(targetGroupId)
		.get();

	if (!groupDoc.exists) return [];

	const data = groupDoc.data() || {};
	return listIndexedGroupMemberUids({
		groupRef: groupDoc.ref,
		groupData: data,
	});
}
