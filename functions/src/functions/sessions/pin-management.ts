import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import { assertActiveUserData } from "../../services/account-status.service";
import {
  MAX_PIN_ATTEMPTS,
  PIN_LOCK_MS,
  assertValidPin,
  hashPinOnServer,
  pinCallableOptions,
} from "./pin-security";

export const saveUserPin = onCall(pinCallableOptions, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "يجب تسجيل الدخول");
  }

  const uid = request.auth.uid;
  const pin = String(request.data.pin ?? "").trim();

  assertValidPin(pin);

  const pinHash = hashPinOnServer(uid, pin);
  const userRef = admin.firestore().collection("users").doc(uid);
  const pinRef = admin.firestore().collection("userPins").doc(uid);

  await admin.firestore().runTransaction(async (tx) => {
    const userDoc = await tx.get(userRef);
    const pinDoc = await tx.get(pinRef);

    if (!userDoc.exists) {
      throw new HttpsError("not-found", "المستخدم غير موجود");
    }

    const userData = userDoc.data() || {};
    assertActiveUserData(userData);

    const alreadyHasPin = userData.hasPin === true || pinDoc.exists;
    const pinResetRequired = userData.pinResetRequired === true;

    if (alreadyHasPin && !pinResetRequired) {
      throw new HttpsError(
        "failed-precondition",
        "لا يمكن تعيين رمز جديد هنا، استخدم تغيير الرمز بإدخال الرمز القديم"
      );
    }

    const pendingSessionId = String(userData.pendingSessionId ?? "");

    tx.set(pinRef, {
      pinHash,
      failedAttempts: 0,
      lockUntilMs: 0,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    tx.set(
      userRef,
      {
        hasPin: true,
        pinResetRequired: false,
        pinVerifiedPendingSessionId: pendingSessionId,
        pinVerifiedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
  });

  return { success: true };
});

export const changeUserPin = onCall(pinCallableOptions, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "يجب تسجيل الدخول");
  }

  const uid = request.auth.uid;
  const oldPin = String(request.data.oldPin ?? "").trim();
  const newPin = String(request.data.newPin ?? "").trim();

  assertValidPin(oldPin);
  assertValidPin(newPin);

  const oldPinHash = hashPinOnServer(uid, oldPin);
  const newPinHash = hashPinOnServer(uid, newPin);

  const userRef = admin.firestore().collection("users").doc(uid);
  const pinRef = admin.firestore().collection("userPins").doc(uid);

  await admin.firestore().runTransaction(async (tx) => {
    const userDoc = await tx.get(userRef);
    const pinDoc = await tx.get(pinRef);

    if (!userDoc.exists) {
      throw new HttpsError("not-found", "المستخدم غير موجود");
    }

    const userData = userDoc.data() || {};
    assertActiveUserData(userData);

    if (!pinDoc.exists) {
      throw new HttpsError("failed-precondition", "لم يتم تعيين رمز PIN بعد");
    }

    const pinData = pinDoc.data() || {};
    const savedPinHash = String(pinData.pinHash ?? "");
    const failedAttemptsBefore = Number(pinData.failedAttempts ?? 0);
    const lockUntilMs = Number(pinData.lockUntilMs ?? 0);
    const now = Date.now();

    if (lockUntilMs > now) {
      throw new HttpsError("resource-exhausted", "تم قفل المحاولات مؤقتاً، حاول لاحقاً");
    }

    if (!savedPinHash || savedPinHash !== oldPinHash) {
      const failedAttempts = failedAttemptsBefore + 1;
      const nextLockUntilMs =
        failedAttempts >= MAX_PIN_ATTEMPTS ? now + PIN_LOCK_MS : 0;

      tx.set(
        pinRef,
        {
          failedAttempts,
          lockUntilMs: nextLockUntilMs,
          lastFailedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );

      throw new HttpsError("permission-denied", "الرمز القديم غير صحيح");
    }

    tx.set(
      pinRef,
      {
        pinHash: newPinHash,
        failedAttempts: 0,
        lockUntilMs: 0,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    tx.set(
      userRef,
      {
        hasPin: true,
        pinResetRequired: false,
      },
      { merge: true }
    );
  });

  return { success: true };
});

export const verifyUserPin = onCall(pinCallableOptions, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "يجب تسجيل الدخول");
  }

  const uid = request.auth.uid;
  const pin = String(request.data.pin ?? "").trim();

  assertValidPin(pin);

  const pinHash = hashPinOnServer(uid, pin);
  const userRef = admin.firestore().collection("users").doc(uid);
  const pinRef = admin.firestore().collection("userPins").doc(uid);

  return admin.firestore().runTransaction(async (tx) => {
    const userDoc = await tx.get(userRef);
    const pinDoc = await tx.get(pinRef);

    if (!userDoc.exists) {
      throw new HttpsError("not-found", "المستخدم غير موجود");
    }

    const userData = userDoc.data() || {};
    assertActiveUserData(userData);

    const pinData = pinDoc.data() || {};
    const savedPinHash = String(pinData.pinHash ?? "");
    const failedAttemptsBefore = Number(pinData.failedAttempts ?? 0);
    const lockUntilMs = Number(pinData.lockUntilMs ?? 0);
    const now = Date.now();

    if (lockUntilMs > now) {
      return {
        success: false,
        forceLogout: true,
        remainingAttempts: 0,
        lockedUntilMs: lockUntilMs,
      };
    }

    if (savedPinHash.length > 0 && savedPinHash === pinHash) {
      const pendingSessionId = String(userData.pendingSessionId ?? "");

      tx.set(
        pinRef,
        {
          failedAttempts: 0,
          lockUntilMs: 0,
          lastVerifiedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );

      tx.set(
        userRef,
        {
          pinVerifiedPendingSessionId: pendingSessionId,
          pinVerifiedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );

      return {
        success: true,
        forceLogout: false,
        remainingAttempts: MAX_PIN_ATTEMPTS,
        lockedUntilMs: 0,
      };
    }

    const failedAttempts = failedAttemptsBefore + 1;
    const remainingAttempts = Math.max(0, MAX_PIN_ATTEMPTS - failedAttempts);
    const nextLockUntilMs =
      failedAttempts >= MAX_PIN_ATTEMPTS ? now + PIN_LOCK_MS : 0;

    tx.set(
      pinRef,
      {
        failedAttempts,
        lockUntilMs: nextLockUntilMs,
        lastFailedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    return {
      success: false,
      forceLogout: failedAttempts >= MAX_PIN_ATTEMPTS,
      remainingAttempts,
      lockedUntilMs: nextLockUntilMs,
    };
  });
});
