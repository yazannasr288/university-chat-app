import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import { assertMaxLength, INPUT_FIELD_LIMITS } from "../../utils/user-field-validation";
import { fastCallableOptions } from "../../runtime-options";
import { assertActiveUserData } from "../../services/account-status.service";
import { normalizeLanguageCode } from "../../utils/localized-notifications";

export const saveCurrentFcmToken = onCall(fastCallableOptions, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "يجب تسجيل الدخول");
  }

  const uid = request.auth.uid;
  const fcmToken = String(request.data.fcmToken ?? "").trim();
  const sessionId = String(request.data.sessionId ?? "").trim();
  const languageCode = normalizeLanguageCode(request.data.languageCode);
  assertMaxLength(fcmToken, INPUT_FIELD_LIMITS.fcmToken, "رمز الإشعارات طويل جدًا");
  assertMaxLength(sessionId, INPUT_FIELD_LIMITS.sessionId, "معرف الجلسة طويل جدًا");
  assertMaxLength(languageCode, 8, "البيانات غير صالحة");

  if (!fcmToken || !sessionId) return { success: true, skipped: true };

  const userRef = admin.firestore().collection("users").doc(uid);
  const userDoc = await userRef.get();
  if (!userDoc.exists) {
    throw new HttpsError("not-found", "المستخدم غير موجود");
  }

  const userData = userDoc.data() || {};
  assertActiveUserData(userData);

  const activeSessionId = String(userData.activeSessionId ?? "").trim();
  if (activeSessionId !== sessionId) {
    return { success: true, skipped: true, reason: "stale_session" };
  }

  await userRef.set(
    {
      fcmToken,
      languageCode,
      fcmTokenSessionId: sessionId,
      fcmTokenUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );

  return { success: true };
});

export const clearCurrentFcmToken = onCall(fastCallableOptions, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "يجب تسجيل الدخول");
  }

  const uid = request.auth.uid;
  const sessionId = String(request.data.sessionId ?? "").trim();

  if (!sessionId) {
    return { success: true, skipped: true };
  }
assertMaxLength(sessionId, INPUT_FIELD_LIMITS.sessionId, "معرف الجلسة طويل جدًا");
  const userRef = admin.firestore().collection("users").doc(uid);

  await admin.firestore().runTransaction(async (tx) => {
    const userDoc = await tx.get(userRef);
    if (!userDoc.exists) return;

    const data = userDoc.data() || {};
    const activeSessionId = String(data.activeSessionId ?? "");
    const pendingSessionId = String(data.pendingSessionId ?? "");

    const update: Record<string, unknown> = {};

    if (activeSessionId === sessionId) {
      update.fcmToken = "";
      update.fcmTokenSessionId = "";
    }

    if (pendingSessionId === sessionId) {
      update.pendingFcmToken = "";
    }

    if (Object.keys(update).length > 0) {
      tx.set(userRef, update, { merge: true });
    }
  });

  return { success: true };
});
