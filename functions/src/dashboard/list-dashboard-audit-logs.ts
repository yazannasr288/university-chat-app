import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import { assertAdmin0OrThrow } from "../services/dashboard-user.service";

const ALLOWED_CATEGORIES = new Set([
	"all",
	"events",
	"students",
	"groups",
	"notifications",
	"system",
]);

const ALLOWED_LEVELS = new Set(["all", "info", "warning", "critical"]);
const MAX_LIMIT = 100;
const DEFAULT_LIMIT = 50;
const DAY_MS = 24 * 60 * 60 * 1000;


function readPositiveInt(value: unknown, fallback: number) {
	const parsed = Number(value ?? fallback);
	if (!Number.isFinite(parsed) || parsed <= 0) return fallback;
	return Math.min(Math.floor(parsed), MAX_LIMIT);
}

function readRequiredDateMs(value: unknown, fieldName: string) {
	const parsed = Number(value ?? 0);
	if (!Number.isFinite(parsed) || parsed <= 0) {
		throw new HttpsError("invalid-argument", `${fieldName} مطلوب`);
	}
	return parsed;
}



export const listDashboardAuditLogs = onCall(async (request) => {
	if (!request.auth) {
		throw new HttpsError("unauthenticated", "يجب تسجيل الدخول");
	}

	await assertAdmin0OrThrow(request.auth.uid);

	const category = String(request.data.category ?? "").trim();
	const level = String(request.data.level ?? "all").trim() || "all";
	const startAtMs = readRequiredDateMs(request.data.startAtMs, "startAtMs");
	const endAtMs = readRequiredDateMs(request.data.endAtMs, "endAtMs");
	const limit = readPositiveInt(request.data.limit, DEFAULT_LIMIT);
	const cursorCreatedAtMs = Number(request.data.cursorCreatedAtMs ?? 0);

	if (!ALLOWED_CATEGORIES.has(category)) {
		throw new HttpsError("invalid-argument", "نوع السجل مطلوب");
	}

	if (!ALLOWED_LEVELS.has(level)) {
		throw new HttpsError("invalid-argument", "مستوى السجل غير صالح");
	}

	if (endAtMs < startAtMs) {
		throw new HttpsError(
			"invalid-argument",
			"تاريخ النهاية يجب أن يكون بعد تاريخ البداية",
		);
	}

	if (endAtMs - startAtMs > 370 * DAY_MS) {
		throw new HttpsError("invalid-argument", "أقصى نطاق مسموح هو سنة واحدة");
	}

	const startTimestamp = admin.firestore.Timestamp.fromMillis(startAtMs);
	const endTimestamp = admin.firestore.Timestamp.fromMillis(endAtMs);

	let ref: FirebaseFirestore.Query = admin
		.firestore()
		.collection("dashboardAuditLogs");

	if (category !== "all") {
		ref = ref.where("category", "==", category);
	}

	if (level !== "all") {
		ref = ref.where("level", "==", level);
	}

	ref = ref
		.where("createdAt", ">=", startTimestamp)
		.where("createdAt", "<=", endTimestamp)
		.orderBy("createdAt", "desc");

	if (Number.isFinite(cursorCreatedAtMs) && cursorCreatedAtMs > 0) {
		ref = ref.startAfter(
			admin.firestore.Timestamp.fromMillis(cursorCreatedAtMs),
		);
	}

	ref = ref.limit(limit + 1);


	const snap = await ref.get();
	const docs = snap.docs.slice(0, limit);
	const hasMore = snap.docs.length > limit;

	const logs = docs.map((doc) => {
		const data = doc.data() || {};
		const actorUid = String(data.actorUid ?? "").trim();
		const actorName = String(data.actorName ?? "").trim();
		const targetTypeValue = String(data.targetType ?? "system").trim();
		const targetId = String(data.targetId ?? "").trim();
		const targetLabel = String(data.targetLabel ?? "").trim();
		const targetName = String(data.targetName ?? "").trim();
		const createdAtMs =
			data.createdAt instanceof admin.firestore.Timestamp
				? data.createdAt.toMillis()
				: 0;

		return {
			id: doc.id,
			action: String(data.action ?? ""),
			category: String(data.category ?? "system").trim() || "system",
			level: String(data.level ?? "info"),
			targetType: targetTypeValue,
			targetId,
			targetLabel,
			targetName,
			targetDisplayName: String(
				(data.targetDisplayName ?? targetName) || targetLabel,
			),
			targetUserId: String(data.targetUserId ?? ""),
			targetDepartment: String(data.targetDepartment ?? ""),
			targetAccountType: String(data.targetAccountType ?? ""),
			actorUid,
			actorRole: String(data.actorRole ?? ""),
			actorName,
			actorDisplayName: String(data.actorDisplayName ?? actorName),
			actorUserId: String(data.actorUserId ?? ""),
			actorDepartment: String(data.actorDepartment ?? ""),
			actorAccountType: String(data.actorAccountType ?? ""),
			summary: String(data.summary ?? ""),
			details: data.details ?? {},
			schemaVersion: Number(data.schemaVersion ?? 4) || 4,
			createdAtMs,
		};
	});

	return {
		success: true,
		logs,
		hasMore,
		nextCursorCreatedAtMs: hasMore ? (logs.at(-1)?.createdAtMs ?? 0) : 0,
	};
});
