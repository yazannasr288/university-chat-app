import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import * as admin from "firebase-admin";
import { assertMaxLength, INPUT_FIELD_LIMITS } from "../../utils/user-field-validation";
import { fastCallableOptions } from "../../runtime-options";
import { assertActiveUserData } from "../../services/account-status.service";
import { loginAttemptNotification, normalizeLanguageCode } from "../../utils/localized-notifications";

export const startPendingSessionAfterPassword = onCall(fastCallableOptions, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "يجب تسجيل الدخول");
  }

  const uid = request.auth.uid;
  const sessionId = String(request.data.sessionId ?? "").trim();
  const deviceId = String(request.data.deviceId ?? "").trim();
  const deviceName = String(request.data.deviceName ?? "").trim();
  const fcmToken = String(request.data.fcmToken ?? "").trim();
  const languageCode = normalizeLanguageCode(request.data.languageCode);
  assertMaxLength(sessionId, INPUT_FIELD_LIMITS.sessionId, "معرف الجلسة طويل جدًا");
  assertMaxLength(deviceId, INPUT_FIELD_LIMITS.deviceId, "معرف الجهاز طويل جدًا");
  assertMaxLength(deviceName, INPUT_FIELD_LIMITS.deviceName, "اسم الجهاز طويل جدًا");
  assertMaxLength(fcmToken, INPUT_FIELD_LIMITS.fcmToken, "رمز الإشعارات طويل جدًا");
  assertMaxLength(languageCode, 8, "البيانات غير صالحة");

  if (!sessionId || !deviceId) {
    throw new HttpsError("invalid-argument", "بيانات الجلسة غير مكتملة");
  }

  const userRef = admin.firestore().collection("users").doc(uid);
  const userDoc = await userRef.get();

  if (!userDoc.exists) {
    throw new HttpsError("not-found", "المستخدم غير موجود");
  }

  const userData = userDoc.data() || {};
  assertActiveUserData(userData);

  const previousToken = String(userData.fcmToken ?? "");

  const pinDoc = await admin.firestore().collection("userPins").doc(uid).get();

  const hasPin = userData.hasPin === true || pinDoc.exists;

  await userRef.update({
    pendingSessionId: sessionId,
    pendingDeviceId: deviceId,
    pendingDeviceName: deviceName,
    pendingFcmToken: fcmToken,
    pendingLanguageCode: languageCode,
    pendingLoginAt: admin.firestore.FieldValue.serverTimestamp(),

    pinVerifiedPendingSessionId: "",
    pinVerifiedAt: null,
  });

  if (previousToken && previousToken !== fcmToken) {
    try {
      const notification = loginAttemptNotification(userData.languageCode);
      await admin.messaging().send({
        token: previousToken,
        notification,
        data: {
          type: "login_attempt",
        },
        android: {
          priority: "high",
          notification: {
            channelId: "chat_messages",
          },
        },
      });
    } catch (e) {
      logger.error("Failed to notify previous device", e);
    }
  }

  return {
    pinResetRequired: userData.pinResetRequired === true,
    mustChangePassword: userData.mustChangePassword === true,
    hasPin,
    user: {
      uid,
      fullName: userData.fullName ?? "",
      email: userData.email ?? "",
      role: userData.role ?? "user",
      accountType: userData.accountType ?? "user",
      department: userData.department ?? "",
      profilepic: userData.profilepic ?? "",
    },
  };
});

export const activatePendingSessionAfterPin = onCall(fastCallableOptions, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "يجب تسجيل الدخول");
  }

  const uid = request.auth.uid;
  const sessionId = String(request.data.sessionId ?? "").trim();

  if (!sessionId) {
    throw new HttpsError("invalid-argument", "sessionId مطلوب");
  }

assertMaxLength(sessionId, INPUT_FIELD_LIMITS.sessionId, "معرف الجلسة طويل جدًا");
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

    const pendingSessionId = String(userData.pendingSessionId ?? "");
    const verifiedPendingSessionId = String(userData.pinVerifiedPendingSessionId ?? "");
    const requiresPin = userData.hasPin === true || pinDoc.exists;

    if (pendingSessionId !== sessionId) {
      throw new HttpsError("failed-precondition", "الجلسة المعلقة غير صالحة");
    }

    if (requiresPin && verifiedPendingSessionId !== pendingSessionId) {
      throw new HttpsError("failed-precondition", "يجب التحقق من رمز PIN قبل تفعيل هذا الجهاز");
    }

    tx.update(userRef, {
      activeSessionId: pendingSessionId,
      activeDeviceId: String(userData.pendingDeviceId ?? ""),
      activeDeviceName: String(userData.pendingDeviceName ?? ""),
      fcmToken: String(userData.pendingFcmToken ?? ""),
      languageCode: normalizeLanguageCode(userData.pendingLanguageCode ?? userData.languageCode),
      lastLoginAt: admin.firestore.FieldValue.serverTimestamp(),

      pendingSessionId: "",
      pendingDeviceId: "",
      pendingDeviceName: "",
      pendingFcmToken: "",
      pendingLanguageCode: "",
      pendingLoginAt: null,

      pinVerifiedPendingSessionId: "",
    });
  });

  return { success: true };
});

export const closeCurrentSession = onCall(fastCallableOptions, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "يجب تسجيل الدخول");
  }

  const uid = request.auth.uid;
  const sessionId = String(request.data.sessionId ?? "").trim();
assertMaxLength(sessionId, INPUT_FIELD_LIMITS.sessionId, "معرف الجلسة طويل جدًا");
  const userRef = admin.firestore().collection("users").doc(uid);
  const userDoc = await userRef.get();

  if (!userDoc.exists) {
    throw new HttpsError("not-found", "المستخدم غير موجود");
  }

  const currentSessionId = String(userDoc.data()?.activeSessionId ?? "");

  if (currentSessionId === sessionId) {
    await userRef.update({
      activeSessionId: "",
      activeDeviceId: "",
      activeDeviceName: "",
      fcmToken: "",
    });
  }

  return { success: true };
});
