import { HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";

function safeDocId(value: string): string {
	return encodeURIComponent(value.trim().toLowerCase()).replace(/\./g, "%2E");
}

export function uniqueUserIdRef(userId: string) {
	return admin.firestore().collection("uniqueUserIds").doc(safeDocId(userId));
}

export function uniquePhoneRef(phoneE164: string) {
	return admin.firestore().collection("uniquePhones").doc(safeDocId(phoneE164));
}

export async function reserveUniqueUserFields({
	userId,
	phoneE164,
	reservationId = "",
}: {
	userId: string;
	phoneE164: string;
	reservationId?: string;
}) {
	const cleanUserId = userId.trim();
	const cleanPhone = phoneE164.trim();
	const cleanReservationId = reservationId.trim();
	if (!cleanUserId || !cleanPhone) {
		throw new HttpsError("invalid-argument", "بيانات التعريف غير مكتملة");
	}

	const userIdRef = uniqueUserIdRef(cleanUserId);
	const phoneRef = uniquePhoneRef(cleanPhone);

	await admin.firestore().runTransaction(async (tx) => {
		const [userIdDoc, phoneDoc] = await Promise.all([
			tx.get(userIdRef),
			tx.get(phoneRef),
		]);

		const ownsUserIdReservation =
			cleanReservationId.length > 0 &&
			String(userIdDoc.data()?.reservationId ?? "") === cleanReservationId;
		const ownsPhoneReservation =
			cleanReservationId.length > 0 &&
			String(phoneDoc.data()?.reservationId ?? "") === cleanReservationId;

		if (userIdDoc.exists && !ownsUserIdReservation) {
			throw new HttpsError("already-exists", "الرقم الجامعي مسجل بالفعل");
		}

		if (phoneDoc.exists && !ownsPhoneReservation) {
			throw new HttpsError("already-exists", "رقم الهاتف مستخدم بالفعل");
		}

		const reservation = {
			uid: "",
			reservationId: cleanReservationId,
			createdAt: admin.firestore.FieldValue.serverTimestamp(),
			finalizedAt: null,
		};

		if (!userIdDoc.exists) {
			tx.create(userIdRef, { ...reservation, userId: cleanUserId });
		}
		if (!phoneDoc.exists) {
			tx.create(phoneRef, { ...reservation, phoneE164: cleanPhone });
		}
	});
}

export async function finalizeUniqueUserFields({
	userId,
	phoneE164,
	uid,
}: {
	userId: string;
	phoneE164: string;
	uid: string;
}) {
	const payload = {
		uid,
		finalizedAt: admin.firestore.FieldValue.serverTimestamp(),
	};

	await Promise.all([
		uniqueUserIdRef(userId).set(payload, { merge: true }),
		uniquePhoneRef(phoneE164).set(payload, { merge: true }),
	]);
}

export async function updateUserProfileWithUniquePhone({
	targetUid,
	userRef,
	nextPhoneE164,
	profilePatch,
}: {
	targetUid: string;
	userRef: FirebaseFirestore.DocumentReference;
	nextPhoneE164: string;
	profilePatch: Record<string, unknown>;
}) {
	const cleanTargetUid = targetUid.trim();
	const cleanNextPhone = nextPhoneE164.trim();

	if (!cleanTargetUid || !cleanNextPhone) {
		throw new HttpsError("invalid-argument", "بيانات رقم الهاتف غير مكتملة");
	}

	await admin.firestore().runTransaction(async (tx) => {
		const userDoc = await tx.get(userRef);
		if (!userDoc.exists) {
			throw new HttpsError("not-found", "المستخدم غير موجود");
		}

		const currentPhone = String(userDoc.data()?.phoneE164 ?? "").trim();
		const nextPhoneRef = uniquePhoneRef(cleanNextPhone);
		const currentPhoneRef =
			currentPhone && currentPhone !== cleanNextPhone
				? uniquePhoneRef(currentPhone)
				: null;
		const [nextPhoneDoc, currentPhoneDoc] = await Promise.all([
			tx.get(nextPhoneRef),
			currentPhoneRef ? tx.get(currentPhoneRef) : Promise.resolve(null),
		]);

		if (nextPhoneDoc.exists) {
			const nextOwnerUid = String(nextPhoneDoc.data()?.uid ?? "").trim();
			const isCurrentPhoneLock =
				currentPhone === cleanNextPhone && nextOwnerUid.length === 0;

			if (nextOwnerUid !== cleanTargetUid && !isCurrentPhoneLock) {
				throw new HttpsError(
					"already-exists",
					"رقم الهاتف مستخدم بالفعل",
				);
			}
		}

		if (currentPhoneDoc?.exists) {
			const currentOwnerUid = String(
				currentPhoneDoc.data()?.uid ?? "",
			).trim();
			if (currentOwnerUid && currentOwnerUid !== cleanTargetUid) {
				throw new HttpsError(
					"failed-precondition",
					"تعذر تحديث رقم الهاتف لأن سجل الرقم الحالي مرتبط بحساب آخر",
				);
			}
		}

		const finalizedPhoneLock = {
			uid: cleanTargetUid,
			phoneE164: cleanNextPhone,
			reservationId: "",
			finalizedAt: admin.firestore.FieldValue.serverTimestamp(),
			updatedAt: admin.firestore.FieldValue.serverTimestamp(),
		};

		if (nextPhoneDoc.exists) {
			tx.set(nextPhoneRef, finalizedPhoneLock, { merge: true });
		} else {
			tx.create(nextPhoneRef, {
				...finalizedPhoneLock,
				createdAt: admin.firestore.FieldValue.serverTimestamp(),
			});
		}

		if (currentPhoneRef && currentPhoneDoc?.exists) {
			tx.delete(currentPhoneRef);
		}

		tx.set(userRef, profilePatch, { merge: true });
	});
}

export async function releaseUniqueUserFields({
	userId,
	phoneE164,
	reservationId = "",
}: {
	userId: string;
	phoneE164: string;
	reservationId?: string;
}) {
	const cleanReservationId = reservationId.trim();
	if (cleanReservationId) {
		const userIdRef = uniqueUserIdRef(userId);
		const phoneRef = uniquePhoneRef(phoneE164);
		await admin.firestore().runTransaction(async (tx) => {
			const [userIdDoc, phoneDoc] = await Promise.all([
				tx.get(userIdRef),
				tx.get(phoneRef),
			]);

			if (
				userIdDoc.exists &&
				String(userIdDoc.data()?.reservationId ?? "") === cleanReservationId
			) {
				tx.delete(userIdRef);
			}
			if (
				phoneDoc.exists &&
				String(phoneDoc.data()?.reservationId ?? "") === cleanReservationId
			) {
				tx.delete(phoneRef);
			}
		});
		return;
	}

	await Promise.all([
		uniqueUserIdRef(userId)
			.delete()
			.catch(() => {}),
		uniquePhoneRef(phoneE164)
			.delete()
			.catch(() => {}),
	]);
}
