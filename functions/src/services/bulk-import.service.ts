type BulkGroupMeta = {
	id: string;
	groupName: string;
	data: Record<string, any>;
};

let cachedGroupsMap: Map<string, BulkGroupMeta> | null = null;
let cachedGroupsMapAt = 0;
const GROUPS_MAP_CACHE_TTL_MS = 60_000;

import { HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import { createHash } from "node:crypto";

import type { BulkStudentInput } from "../types/bulk-student";
import { normalizeSyrianPhone } from "../utils/phone";
import {
	buildDefaultGroupNames,
	mapAccountTypeToRole,
} from "../utils/group-mapping";
import { assertUserProfileFieldLimits } from "../utils/user-field-validation";
import {
	releaseUniqueUserFields,
	reserveUniqueUserFields,
	uniquePhoneRef,
	uniqueUserIdRef,
} from "./unique-user.service";
import {
	buildUserGroupSummary,
	userGroupSummaryRef,
} from "./group-summary.service";
import {
	assertWorkerAccountCompatibility,
	canUserAccessGroup,
} from "./group-access.service";
import { groupMemberCountPatch } from "./group-member-index.service";

export function sanitizeStudent(student: any): BulkStudentInput {
	return {
		fullName: String(student?.fullName ?? "").trim(),
		userId: String(student?.userId ?? "").trim(),
		phone: String(student?.phone ?? "").trim(),
		department: String(student?.department ?? "").trim(),
		password: String(student?.password ?? "").trim(),
		accountType: String(student?.accountType ?? "user").trim() || "user",
	};
}

export function ensureRequiredStudentFields(student: BulkStudentInput) {
	if (
		!student.fullName ||
		!student.userId ||
		!student.phone ||
		!student.department ||
		!student.password
	) {
		throw new Error("بيانات ناقصة");
	}
}

export function validateDuplicatesInsideFile(students: BulkStudentInput[]) {
	const userIds = new Set<string>();
	const phones = new Set<string>();

	for (const student of students) {
		if (userIds.has(student.userId)) {
			throw new HttpsError(
				"invalid-argument",
				`يوجد تكرار داخل الملف للرقم الجامعي: ${student.userId}`,
			);
		}

		userIds.add(student.userId);

		const phoneE164 = normalizeSyrianPhone(student.phone);
		const phoneKey = phoneE164 ?? student.phone;

		if (phones.has(phoneKey)) {
			throw new HttpsError(
				"invalid-argument",
				`يوجد تكرار داخل الملف لرقم الهاتف: ${student.phone}`,
			);
		}

		phones.add(phoneKey);
	}
}

export async function loadGroupsMap(
	forceRefresh = false,
): Promise<Map<string, BulkGroupMeta>> {
	const now = Date.now();

	if (
		!forceRefresh &&
		cachedGroupsMap != null &&
		now - cachedGroupsMapAt < GROUPS_MAP_CACHE_TTL_MS
	) {
		return cachedGroupsMap;
	}

	const snapshot = await admin
		.firestore()
		.collection("groups")
		.select(
			"groupName",
			"groupIcon",
			"adminId",
			"adminName",
			"adminIds",

			"memberCount",
			"department",
			"audience",
			"createdAt",
			"recentMessage",
			"recentMessageEn",
			"recentMessageSender",
			"recentMessageSenderId",
			"recentMessageTime",
			"messageCount",
			"writePermission",
			"isActive",
		)
		.get();
	const groupsMap = new Map<string, BulkGroupMeta>();

	for (const doc of snapshot.docs) {
		const groupName = String(doc.data().groupName ?? "").trim();
		if (!groupName) continue;

		groupsMap.set(groupName, {
			id: doc.id,
			groupName,
			data: doc.data(),
		});
	}

	cachedGroupsMap = groupsMap;
	cachedGroupsMapAt = now;

	return groupsMap;
}

function bulkReservationId(jobId: string, userId: string): string {
	return createHash("sha256").update(`${jobId}/${userId}`).digest("hex");
}

function bulkAuthUid(jobId: string, userId: string): string {
	return `bulk_${bulkReservationId(jobId, userId)}`;
}

async function createOrRecoverBulkAuthUser({
	uid,
	email,
	password,
	displayName,
}: {
	uid: string;
	email: string;
	password: string;
	displayName: string;
}) {
	try {
		return await admin.auth().createUser({
			uid,
			email,
			password,
			displayName,
		});
	} catch (error: any) {
		const code = String(error?.code ?? "");
		let existingUser: admin.auth.UserRecord | null = null;

		if (code === "auth/uid-already-exists") {
			existingUser = await admin
				.auth()
				.getUser(uid)
				.catch(() => null);
		} else if (code === "auth/email-already-exists") {
			existingUser = await admin
				.auth()
				.getUserByEmail(email)
				.catch(() => null);
		}

		if (
			existingUser?.uid === uid &&
			String(existingUser.email ?? "").toLowerCase() === email.toLowerCase()
		) {
			return existingUser;
		}
		throw error;
	}
}

export async function createStudentFromBulkJob({
	student,
	callerUid,
	jobId,
	groupsMap,
}: {
	student: BulkStudentInput;
	callerUid: string;
	jobId: string;
	groupsMap: Map<string, BulkGroupMeta>;
}) {
	ensureRequiredStudentFields(student);

	const { fullName, userId, phone, department, password, accountType } =
		student;

	assertWorkerAccountCompatibility({ department, accountType });

	assertUserProfileFieldLimits({
		fullName,
		userId,
		phone,
		department,
		accountType,
		password,
	});

	const phoneE164 = normalizeSyrianPhone(phone);
	if (!phoneE164) {
		throw new Error("رقم الهاتف غير صالح");
	}

	const users = admin.firestore().collection("users");
	const [sameUserId, samePhone] = await Promise.all([
		users.where("userId", "==", userId).limit(1).get(),
		users.where("phoneE164", "==", phoneE164).limit(1).get(),
	]);

	if (!sameUserId.empty) {
		const existing = sameUserId.docs.at(0);
		if (existing?.data().createdByBulkJobId === jobId) {
			return { uid: existing.id, userId, alreadyCreated: true };
		}
		throw new Error("الرقم الجامعي مسجل بالفعل");
	}

	if (!samePhone.empty) {
		throw new Error("رقم الهاتف مستخدم بالفعل");
	}

	const email = `${userId}@wpu.edu`;
	const role = mapAccountTypeToRole(accountType);
	const reservationId = bulkReservationId(jobId, userId);
	const expectedUid = bulkAuthUid(jobId, userId);

	let createdUid = "";
	let reservedUniqueFields = false;

	try {
		await reserveUniqueUserFields({ userId, phoneE164, reservationId });
		reservedUniqueFields = true;
		const userRecord = await createOrRecoverBulkAuthUser({
			uid: expectedUid,
			email,
			password,
			displayName: fullName,
		});

		const uid = userRecord.uid;
		createdUid = uid;

		const defaultGroupNames = buildDefaultGroupNames(department, accountType);

		const userGroupIds: string[] = [];
		const batch = admin.firestore().batch();

		for (const groupName of defaultGroupNames) {
			const groupMeta = groupsMap.get(groupName);
			if (!groupMeta) continue;
			if (
				!canUserAccessGroup({
					groupData: groupMeta.data,
					userData: { uid, department, accountType, role },
				})
			)
				continue;

			userGroupIds.push(groupMeta.id);

			const groupRef = admin.firestore().collection("groups").doc(groupMeta.id);
			const memberCountPatch = groupMemberCountPatch(groupMeta.data, 1);

			batch.update(groupRef, {
				memberCount: memberCountPatch,
				updatedAt: admin.firestore.FieldValue.serverTimestamp(),
			});


			batch.set(
				groupRef.collection("memberStates").doc(uid),
				{
					uid,
					groupId: groupMeta.id,
					updatedAt: admin.firestore.FieldValue.serverTimestamp(),
				},
				{ merge: true },
			);

			batch.set(
				userGroupSummaryRef(uid, groupMeta.id),
				buildUserGroupSummary({
					uid,
					groupId: groupMeta.id,
					groupData: groupMeta.data,
					unreadCount: 0,
					lastReadMessageTime:
						Number(groupMeta.data.recentMessageTime ?? 0) || 0,
					lastDeliveredMessageTime: 0,
				}),
				{ merge: true },
			);
		}

		batch.set(admin.firestore().collection("users").doc(uid), {
			uid,
			fullName,
			userId,
			phone,
			phoneE164,
			department,
			email,
			role,
			accountType,
			accountStatus: "active",
			accountStatusReason: "",
			groupIds: Array.from(new Set(userGroupIds)),
			profilepic: "",
			activeSessionId: "",
			activeDeviceId: "",
			activeDeviceName: "",
			pendingSessionId: "",
			pendingDeviceId: "",
			pendingDeviceName: "",
			pendingFcmToken: "",
			pendingLoginAt: null,
			lastLoginAt: null,
			hasPin: false,
			pinResetRequired: false,
			mustChangePassword: true,
			passwordChangedAt: null,
			resetByAdminAt: admin.firestore.FieldValue.serverTimestamp(),
			resetByAdminId: callerUid,
			fcmToken: "",
			createdByBulkJobId: jobId,
			createdAt: admin.firestore.FieldValue.serverTimestamp(),
		});

		const finalizedUniqueFields = {
			uid,
			finalizedAt: admin.firestore.FieldValue.serverTimestamp(),
		};
		batch.set(uniqueUserIdRef(userId), finalizedUniqueFields, { merge: true });
		batch.set(uniquePhoneRef(phoneE164), finalizedUniqueFields, {
			merge: true,
		});

		await batch.commit();

		return {
			uid,
			userId,
		};
	} catch (e) {
		if (createdUid) {
			const committedUser = await admin
				.firestore()
				.collection("users")
				.doc(createdUid)
				.get()
				.catch(() => null);
			if (
				committedUser?.exists &&
				committedUser.data()?.createdByBulkJobId === jobId
			) {
				return { uid: createdUid, userId, alreadyCreated: true };
			}

			await admin
				.auth()
				.deleteUser(createdUid)
				.catch(() => {});
			await admin
				.firestore()
				.collection("users")
				.doc(createdUid)
				.delete()
				.catch(() => {});
			await admin
				.firestore()
				.collection("userPins")
				.doc(createdUid)
				.delete()
				.catch(() => {});
		}

		if (reservedUniqueFields) {
			await releaseUniqueUserFields({ userId, phoneE164, reservationId });
		}

		throw e;
	}
}
