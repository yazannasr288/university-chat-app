import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import { syncUserGroupMembershipAfterProfileUpdate } from "../services/group-membership.service";
import {
	assertAdminRoleOrThrow,
	assertCanViewOrManageTargetUserOrThrow,
	buildManagedUserResponse,
	getUserOrThrow,
} from "../services/dashboard-user.service";
import { writeDashboardAuditLog } from "../services/dashboard-audit.service";
import { mapAccountTypeToRole } from "../utils/group-mapping";
import { normalizeSyrianPhone } from "../utils/phone";
import {
	applyManagedUserStatusTransition,
	normalizeManagedAccountStatus,
} from "../services/managed-user-status.service";
import { assertUserProfileFieldLimits } from "../utils/user-field-validation";
import { assertWorkerAccountCompatibility } from "../services/group-access.service";
import { updateUserProfileWithUniquePhone } from "../services/unique-user.service";

const ALLOWED_ACCOUNT_TYPES = new Set([
	"user",
	"doctor",
	"employee",
	"dean",
	"presidency_employee",
	"worker",
]);

export const updateManagedUserProfile = onCall(async (request) => {
	if (!request.auth) {
		throw new HttpsError("unauthenticated", "يجب تسجيل الدخول");
	}

	const callerData = await assertAdminRoleOrThrow(request.auth.uid, [
		"admin0",
		"admin1",
	]);

	const targetUid = String(request.data.uid ?? "").trim();
	if (!targetUid) {
		throw new HttpsError("invalid-argument", "uid مطلوب");
	}

	const fullName = String(request.data.fullName ?? "").trim();
	const userId = String(request.data.userId ?? "").trim();
	const phone = String(request.data.phone ?? "").trim();
	const department = String(request.data.department ?? "").trim();
	const accountType = String(request.data.accountType ?? "user").trim();
	const nextStatus = normalizeManagedAccountStatus(request.data.accountStatus);
	const accountStatusReason = String(
		request.data.accountStatusReason ?? "",
	).trim();

	if (!fullName || !userId || !phone || !department) {
		throw new HttpsError("invalid-argument", "البيانات غير مكتملة");
	}

	if (!ALLOWED_ACCOUNT_TYPES.has(accountType)) {
		throw new HttpsError("invalid-argument", "نوع الحساب غير صالح");
	}

	assertWorkerAccountCompatibility({ department, accountType });

	assertUserProfileFieldLimits({
		fullName,
		userId,
		phone,
		department,
		accountType,
		accountStatusReason,
	});

	const phoneE164 = normalizeSyrianPhone(phone);
	if (!phoneE164) {
		throw new HttpsError("invalid-argument", "رقم الهاتف غير صالح");
	}

	const { userRef, userData } = await getUserOrThrow(targetUid);
	const previousStatus = normalizeManagedAccountStatus(userData.accountStatus);
	if (nextStatus === "removed") {
		throw new HttpsError(
			"failed-precondition",
			"استخدم الحذف النهائي من قائمة الطلاب لحذف الحساب",
		);
	}
	if (previousStatus === "removed") {
		throw new HttpsError(
			"failed-precondition",
			"الحساب المحذوف نهائيًا لا يمكن تعديله أو استعادته",
		);
	}

	const callerRole = String(callerData.role ?? "user");
	const callerDepartment = String(callerData.department ?? "").trim();
	const targetRole = String(userData.role ?? "user");
	const currentAccountType = String(userData.accountType ?? "user").trim();
	const currentDepartment = String(userData.department ?? "").trim();
	const currentUserId = String(userData.userId ?? "").trim();
	const role = mapAccountTypeToRole(accountType);

	if (userId !== currentUserId) {
		throw new HttpsError(
			"failed-precondition",
			"الرقم الجامعي معرف ثابت ولا يمكن تعديله بعد إنشاء الحساب",
		);
	}
	assertCanViewOrManageTargetUserOrThrow(callerData, userData);

	const samePhone = await admin
		.firestore()
		.collection("users")
		.where("phoneE164", "==", phoneE164)
		.limit(1)
		.get();

	if (samePhone.docs.some((doc) => doc.id !== targetUid)) {
		throw new HttpsError("already-exists", "رقم الهاتف مستخدم بالفعل");
	}

	const email = String(userData.email ?? `${currentUserId}@wpu.edu`);

	if (callerRole === "admin1") {
		if (
			targetRole === "admin0" ||
			(targetRole === "admin1" && targetUid !== request.auth?.uid)
		) {
			throw new HttpsError(
				"permission-denied",
				"ليس لديك صلاحية لتعديل هذا الحساب",
			);
		}

		if (!callerDepartment || currentDepartment !== callerDepartment) {
			throw new HttpsError("permission-denied", "يمكنك تعديل مستخدمي قسمك فقط");
		}

		if (department !== currentDepartment) {
			throw new HttpsError(
				"permission-denied",
				"لا يمكنك نقل المستخدم إلى قسم آخر",
			);
		}

		if (accountType !== currentAccountType || role !== targetRole) {
			throw new HttpsError(
				"permission-denied",
				"تغيير نوع الحساب أو مستوى الصلاحية متاح لإدارة النظام فقط",
			);
		}

	} else if (callerRole !== "admin0") {
		throw new HttpsError("permission-denied", "ليس لديك صلاحية");
	}

	const statusChanged = previousStatus !== nextStatus;

	await updateUserProfileWithUniquePhone({
		targetUid,
		userRef,
		nextPhoneE164: phoneE164,
		profilePatch: {
			uid: targetUid,
			fullName,
			userId,
			phone,
			phoneE164,
			department,
			email,
			role,
			accountType,
			updatedAt: admin.firestore.FieldValue.serverTimestamp(),
			updatedBy: request.auth.uid,
			...(statusChanged
				? {}
				: {
						accountStatus: nextStatus,
						accountStatusReason,
					}),
		},
	});

	let updatedUser = (await userRef.get()).data() || {};

	if (statusChanged) {
		updatedUser = await applyManagedUserStatusTransition({
			userRef,
			targetUid,
			userData: {
				...userData,
				uid: targetUid,
				fullName,
				userId,
				phone,
				phoneE164,
				department,
				email,
				role,
				accountType,
			},
			callerUid: request.auth.uid,
			callerData,
			nextStatus,
			reason: accountStatusReason,
			auditDetails: { source: "updateManagedUserProfile" },
		});
	}
	const membershipProfileChanged =
		String(userData.fullName ?? "").trim() !== fullName ||
		String(userData.department ?? "").trim() !== department ||
		String(userData.accountType ?? "user").trim() !== accountType;

	if (membershipProfileChanged && nextStatus === "active") {
		await syncUserGroupMembershipAfterProfileUpdate({
			uid: targetUid,
			fullName,
			department,
			accountType,
		});

		updatedUser = (await userRef.get()).data() || {};
	}

	await writeDashboardAuditLog({
		actorUid: request.auth.uid,
		actorRole: String(callerData.role ?? ""),
		action: "user.profile.updated",
		level: statusChanged ? "warning" : "info",
		targetType: "user",
		targetId: targetUid,
		targetLabel: fullName,
		summary: `updated managed user ${fullName}`,
		details: {
			department,
			accountType,
			previousStatus,
			nextStatus,
			statusChanged,
		},
	});

	return {
		success: true,
		user: buildManagedUserResponse(targetUid, updatedUser),
	};
});
