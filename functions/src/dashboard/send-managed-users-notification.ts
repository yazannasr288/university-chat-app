import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import {
	assertMaxLength,
	INPUT_FIELD_LIMITS,
} from "../utils/user-field-validation";
import {
	assertAdminRoleOrThrow,
	canViewOrManageTargetUser,
	getUserOrThrow,
	isStudentLikeRole,
	normalizeAppRole,
} from "../services/dashboard-user.service";
import { writeDashboardAuditLog } from "../services/dashboard-audit.service";
import { chunkArray } from "../utils/array";

const INVALID_TOKEN_CODES = new Set([
	"messaging/invalid-registration-token",
	"messaging/registration-token-not-registered",
]);

export const sendManagedUsersNotification = onCall(async (request) => {
	if (!request.auth) {
		throw new HttpsError("unauthenticated", "يجب تسجيل الدخول");
	}

	const callerData = await assertAdminRoleOrThrow(request.auth.uid, [
		"admin0",
		"admin1",
		"admin2",
	]);

	const title = String(request.data.title ?? "").trim();
	const body = String(request.data.body ?? "").trim();
	const recipientUidsRaw: unknown[] = Array.isArray(request.data.recipientUids)
		? (request.data.recipientUids as unknown[])
		: [];

	const recipientUids = Array.from(
		new Set<string>(
			recipientUidsRaw
				.map((e: unknown) => String(e ?? "").trim())
				.filter((e: string) => e.length > 0),
		),
	).slice(0, 500);

	if (!title || !body || recipientUids.length === 0) {
		throw new HttpsError("invalid-argument", "البيانات غير مكتملة");
	}
	assertMaxLength(
		title,
		INPUT_FIELD_LIMITS.notificationTitle,
		"عنوان الإشعار طويل جدًا",
	);
	assertMaxLength(
		body,
		INPUT_FIELD_LIMITS.notificationBody,
		"نص الإشعار طويل جدًا",
	);
	const users = await Promise.all(
		recipientUids.map((uid) => getUserOrThrow(uid).catch(() => null)),
	);

	const callerRole = normalizeAppRole(callerData.role);
	const callerDepartment = String(callerData.department ?? "").trim();
	const loadedRecipients = users.filter(
		(e): e is Awaited<ReturnType<typeof getUserOrThrow>> => !!e,
	);

	const hasOutOfScopeRecipient =
		loadedRecipients.length !== recipientUids.length ||
		loadedRecipients.some((e) => {
			if (!canViewOrManageTargetUser(callerData, e.userData)) return true;
			if (callerRole !== "admin0" && !isStudentLikeRole(e.userData.role)) {
				return true;
			}
			return false;
		});

	if (hasOutOfScopeRecipient) {
		throw new HttpsError(
			"permission-denied",
			"يمكنك إرسال الإشعارات فقط ضمن نطاق صلاحياتك",
		);
	}

	const recipientDocs = loadedRecipients.map((e) => ({
		uid: e.userRef.id,
		data: e.userData,
	}));

	if (recipientDocs.length === 0) {
		throw new HttpsError(
			"invalid-argument",
			"لا يوجد مستلمون صالحون ضمن نطاق صلاحياتك",
		);
	}

	const recipientDepartments = Array.from(
		new Set(
			recipientDocs
				.map((e) => String(e.data.department ?? "").trim())
				.filter((department) => department.length > 0),
		),
	);

	const targetDepartment =
		callerRole === "admin0"
			? recipientDepartments.length === 1
				? recipientDepartments[0]
				: "all"
			: callerDepartment;
	const targetDepartments =
		callerRole === "admin0"
			? recipientDepartments
			: callerDepartment
				? [callerDepartment]
				: [];

	const tokenOwners = new Map<string, string>();
	for (const { uid, data } of recipientDocs) {
		if (String(data.accountStatus ?? "active") !== "active") continue;
		const token = String(data.fcmToken ?? "").trim();
		if (token) tokenOwners.set(token, uid);
	}

	const uniqueTokens = Array.from(tokenOwners.keys());
	let successCount = 0;
	let failureCount = 0;
	const invalidTokens: string[] = [];

	for (const tokenChunk of chunkArray(uniqueTokens, 500)) {
		const result = await admin.messaging().sendEachForMulticast({
			tokens: tokenChunk,
			notification: { title, body },
			data: { type: "admin_targeted_notification" },
			android: {
				priority: "high",
				notification: { channelId: "chat_messages" },
			},
		});

		successCount += result.successCount;
		failureCount += result.failureCount;

		result.responses.forEach((response, index) => {
			if (response.success) return;
			const code = response.error?.code ?? "";
			if (INVALID_TOKEN_CODES.has(code)) {
				const invalidToken = tokenChunk[index];
				if (invalidToken) invalidTokens.push(invalidToken);
			}
		});
	}

	for (const invalidChunk of chunkArray(invalidTokens, 400)) {
		const batch = admin.firestore().batch();
		for (const token of invalidChunk) {
			const uid = tokenOwners.get(token);
			if (!uid) continue;
			batch.set(
				admin.firestore().collection("users").doc(uid),
				{ fcmToken: "" },
				{ merge: true },
			);
		}
		await batch.commit();
	}

	const campaignRef = await admin
		.firestore()
		.collection("notificationCampaigns")
		.add({
			title,
			body,
			recipientUids: recipientDocs.map((e) => e.uid),
			deliveredTokenCount: successCount,
			failureTokenCount: failureCount,
			attemptedTokenCount: uniqueTokens.length,
			invalidTokenCount: invalidTokens.length,
			createdAt: admin.firestore.FieldValue.serverTimestamp(),
			createdBy: request.auth.uid,
			createdByRole: callerRole,
			targetDepartment,
			targetDepartments,
			scopeType: targetDepartment === "all" ? "all" : "department",
		});

	await writeDashboardAuditLog({
		actorUid: request.auth.uid,
		actorRole: callerRole,
		action: "notification.campaign.created",
		level: "info",
		targetType: "notification",
		targetId: campaignRef.id,
		targetLabel: title,
		summary: `sent targeted notification to ${recipientDocs.length} users`,
		details: {
			recipientsCount: recipientDocs.length,
			attemptedTokenCount: uniqueTokens.length,
			deliveredTokenCount: successCount,
			failureTokenCount: failureCount,
			invalidTokenCount: invalidTokens.length,
			targetDepartment,
			targetDepartments,
		},
	});

	return {
		success: true,
		recipientsCount: recipientDocs.length,
		deliveredTokenCount: successCount,
		failureTokenCount: failureCount,
		attemptedTokenCount: uniqueTokens.length,
	};
});
