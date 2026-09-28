import { HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";

import { eventFeedRef } from "./event-feed.service";
import { removeUserFromAllGroupsAndCleanup } from "./group-membership.service";
import { uniquePhoneRef, uniqueUserIdRef } from "./unique-user.service";
import { PROFILE_IMAGE_STORAGE_ROOTS } from "../utils/storage-path";

function cleanString(value: unknown): string {
	return String(value ?? "").trim();
}

function authErrorCode(error: unknown): string {
	return cleanString((error as { code?: unknown } | null)?.code);
}

async function disableAndDeleteAuthUser(uid: string) {
	try {
		await admin.auth().updateUser(uid, { disabled: true });
	} catch (error) {
		if (authErrorCode(error) !== "auth/user-not-found") {
			console.error("Failed to disable user before permanent deletion", {
				uid,
				error,
			});
			throw new HttpsError("internal", "تعذر تعطيل حساب المصادقة");
		}
	}

	try {
		await admin.auth().deleteUser(uid);
	} catch (error) {
		if (authErrorCode(error) !== "auth/user-not-found") {
			console.error("Failed to permanently delete Auth user", { uid, error });
			throw new HttpsError("internal", "تعذر حذف حساب المصادقة نهائيًا");
		}
	}
}

async function deleteProfileImageFolders(uid: string) {
	const bucket = admin.storage().bucket();

	try {
		for (const root of PROFILE_IMAGE_STORAGE_ROOTS) {
			await bucket.deleteFiles({ prefix: `${root}/${uid}/` });
		}
	} catch (error) {
		console.error("Failed to delete user profile images", { uid, error });
		throw new HttpsError("internal", "تعذر حذف صور الحساب نهائيًا");
	}
}

function safeEventFeedRef(
	eventData: Record<string, any>,
	eventId: string,
): FirebaseFirestore.DocumentReference | null {
	const scopeType = cleanString(eventData.scopeType);
	if (scopeType === "university" || scopeType === "all") {
		return eventFeedRef(eventData, eventId);
	}
	if (scopeType === "department" && cleanString(eventData.department)) {
		return eventFeedRef(eventData, eventId);
	}
	if (cleanString(eventData.targetGroupId)) {
		return eventFeedRef(eventData, eventId);
	}
	return null;
}

async function deleteEventInterest({
	uid,
	eventId,
}: {
	uid: string;
	eventId: string;
}) {
	const db = admin.firestore();
	const eventRef = db.collection("events").doc(eventId);
	const interestRef = eventRef.collection("interestedUsers").doc(uid);
	const userInterestRef = db
		.collection("users")
		.doc(uid)
		.collection("eventInterests")
		.doc(eventId);

	await db.runTransaction(async (tx) => {
		const [eventDoc, interestDoc] = await Promise.all([
			tx.get(eventRef),
			tx.get(interestRef),
		]);

		let feedRef: FirebaseFirestore.DocumentReference | null = null;
		let feedDoc: FirebaseFirestore.DocumentSnapshot | null = null;

		if (eventDoc.exists && interestDoc.exists) {
			feedRef = safeEventFeedRef(eventDoc.data() || {}, eventId);
			if (feedRef) feedDoc = await tx.get(feedRef);
		}

		tx.delete(userInterestRef);
		if (!interestDoc.exists) return;

		tx.delete(interestRef);
		if (!eventDoc.exists) return;

		const eventData = eventDoc.data() || {};
		const nextInterestedCount = Math.max(
			0,
			Number(eventData.interestedCount ?? 0) - 1,
		);
		tx.update(eventRef, { interestedCount: nextInterestedCount });

		if (feedRef && feedDoc?.exists) {
			const feedData = feedDoc.data() || {};
			tx.set(
				feedRef,
				{
					interestedCount: Math.max(
						0,
						Number(feedData.interestedCount ?? 0) - 1,
					),
					updatedAt: admin.firestore.FieldValue.serverTimestamp(),
				},
				{ merge: true },
			);
		}
	});
}

async function deleteUserEventInterests(uid: string) {
	const interestsRef = admin
		.firestore()
		.collection("users")
		.doc(uid)
		.collection("eventInterests");

	while (true) {
		const snapshot = await interestsRef.limit(100).get();
		if (snapshot.empty) return;

		for (const doc of snapshot.docs) {
			await deleteEventInterest({ uid, eventId: doc.id });
		}
	}
}

async function deleteAllUserSubcollections(
	userRef: FirebaseFirestore.DocumentReference,
) {
	const collections = await userRef.listCollections();

	for (const collectionRef of collections) {
		await admin.firestore().recursiveDelete(collectionRef);
	}
}

function assertLockBelongsToUser({
	lockDoc,
	targetUid,
	fieldLabel,
}: {
	lockDoc: FirebaseFirestore.DocumentSnapshot;
	targetUid: string;
	fieldLabel: string;
}) {
	if (!lockDoc.exists) return;

	const lockUid = cleanString(lockDoc.data()?.uid);
	if (lockUid && lockUid !== targetUid) {
		throw new HttpsError(
			"failed-precondition",
			`تعذر تحرير ${fieldLabel} لأن سجل القفل مرتبط بحساب آخر`,
		);
	}
}

async function loadUniqueLockRefs({
	targetUid,
	userData,
}: {
	targetUid: string;
	userData: Record<string, any>;
}) {
	const db = admin.firestore();
	const userId = cleanString(userData.userId);
	const phoneE164 = cleanString(userData.phoneE164);
	const [ownedUserIdLocks, ownedPhoneLocks] = await Promise.all([
		db.collection("uniqueUserIds").where("uid", "==", targetUid).get(),
		db.collection("uniquePhones").where("uid", "==", targetUid).get(),
	]);
	const lockRefsByPath = new Map<string, FirebaseFirestore.DocumentReference>();

	for (const lockDoc of [...ownedUserIdLocks.docs, ...ownedPhoneLocks.docs]) {
		lockRefsByPath.set(lockDoc.ref.path, lockDoc.ref);
	}
	if (userId) {
		const ref = uniqueUserIdRef(userId);
		lockRefsByPath.set(ref.path, ref);
	}
	if (phoneE164) {
		const ref = uniquePhoneRef(phoneE164);
		lockRefsByPath.set(ref.path, ref);
	}

	return Array.from(lockRefsByPath.values());
}

async function assertUniqueLocksCanBeReleased({
	targetUid,
	userData,
}: {
	targetUid: string;
	userData: Record<string, any>;
}) {
	const lockRefs = await loadUniqueLockRefs({ targetUid, userData });
	const lockDocs = await Promise.all(lockRefs.map((ref) => ref.get()));

	for (const lockDoc of lockDocs) {
		assertLockBelongsToUser({
			lockDoc,
			targetUid,
			fieldLabel: lockDoc.ref.parent.id === "uniqueUserIds"
				? "الرقم الجامعي"
				: "رقم الهاتف",
		});
	}
}

async function finalizeFirestoreDeletion({
	targetUid,
	userData,
	callerUid,
	callerData,
}: {
	targetUid: string;
	userData: Record<string, any>;
	callerUid: string;
	callerData: Record<string, any>;
}) {
	const db = admin.firestore();
	const userRef = db.collection("users").doc(targetUid);
	const pinRef = db.collection("userPins").doc(targetUid);
	const auditRef = db.collection("dashboardAuditLogs").doc();
	const userId = cleanString(userData.userId);
	const phoneE164 = cleanString(userData.phoneE164);
	const lockRefs = await loadUniqueLockRefs({ targetUid, userData });

	await db.runTransaction(async (tx) => {
		const freshUserDoc = await tx.get(userRef);
		const lockDocs: FirebaseFirestore.DocumentSnapshot[] = [];
		for (const lockRef of lockRefs) {
			lockDocs.push(await tx.get(lockRef));
		}

		for (const lockDoc of lockDocs) {
			assertLockBelongsToUser({
				lockDoc,
				targetUid,
				fieldLabel: lockDoc.ref.parent.id === "uniqueUserIds"
					? "الرقم الجامعي"
					: "رقم الهاتف",
			});
		}

		for (const lockDoc of lockDocs) {
			if (lockDoc.exists) tx.delete(lockDoc.ref);
		}
		tx.delete(pinRef);
		if (!freshUserDoc.exists) return;

		tx.delete(userRef);

		const targetName = cleanString(userData.fullName);
		const targetDepartment = cleanString(userData.department);
		const targetAccountType = cleanString(userData.accountType);
		const actorName = cleanString(callerData.fullName);
		tx.set(auditRef, {
			actorUid: callerUid,
			actorRole: cleanString(callerData.role),
			actorName,
			actorDisplayName: actorName,
			actorUserId: cleanString(callerData.userId),
			actorDepartment: cleanString(callerData.department),
			actorAccountType: cleanString(callerData.accountType),
			action: "user.deleted",
			category: "students",
			level: "critical",
			targetType: "user",
			targetId: targetUid,
			targetLabel: targetName,
			targetDisplayName: targetName,
			targetName,
			targetUserId: userId,
			targetDepartment,
			targetAccountType,
			summary: `permanently deleted student ${targetName || userId || targetUid}`,
			details: {
				permanent: true,
				releasedUserId: Boolean(userId),
				releasedPhone: Boolean(phoneE164),
				source: "removeStudentAccount",
			},
			schemaVersion: 4,
			createdAt: admin.firestore.FieldValue.serverTimestamp(),
		});
	});
}

export async function permanentlyDeleteStudent({
	targetUid,
	userData,
	callerUid,
	callerData,
}: {
	targetUid: string;
	userData: Record<string, any>;
	callerUid: string;
	callerData: Record<string, any>;
}) {
	const userRef = admin.firestore().collection("users").doc(targetUid);
	const now = admin.firestore.FieldValue.serverTimestamp();

	// Validate lock ownership before any irreversible Auth or Storage deletion.
	await assertUniqueLocksCanBeReleased({ targetUid, userData });

	// Mark the account first so Firestore and Storage rules block it even if a
	// later cleanup step has to be retried.
	await userRef.set(
		{
			accountStatus: "removed",
			accountStatusReason: "الحذف النهائي قيد التنفيذ",
			deletionInProgress: true,
			deletionStartedAt: now,
			deletionStartedBy: callerUid,
			removedAt: now,
			statusUpdatedAt: now,
			statusUpdatedBy: callerUid,
			activeSessionId: "",
			activeDeviceId: "",
			activeDeviceName: "",
			pendingSessionId: "",
			pendingDeviceId: "",
			pendingDeviceName: "",
			fcmToken: "",
			pendingFcmToken: "",
			pendingLoginAt: null,
		},
		{ merge: true },
	);

	await disableAndDeleteAuthUser(targetUid);
	await deleteUserEventInterests(targetUid);
	await removeUserFromAllGroupsAndCleanup({
		uid: targetUid,
		updatedBy: callerUid,
		updateUserDocument: false,
	});
	await deleteProfileImageFolders(targetUid);
	await deleteAllUserSubcollections(userRef);
	await finalizeFirestoreDeletion({
		targetUid,
		userData,
		callerUid,
		callerData,
	});
}
