import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import { fastCallableOptions } from "../../runtime-options";
import { assertActiveUserData } from "../../services/account-status.service";

export const completePasswordChange = onCall(fastCallableOptions, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "يجب تسجيل الدخول");
  }

  const uid = request.auth.uid;
  const newPassword = String(request.data?.newPassword ?? "").trim();

  if (newPassword.length < 6) {
    throw new HttpsError("invalid-argument", "كلمة السر الجديدة يجب أن تكون 6 أحرف على الأقل");
  }

  if (newPassword.length > 128) {
    throw new HttpsError("invalid-argument", "كلمة السر طويلة جدًا");
  }

  const authTimeSeconds = Number((request.auth.token as Record<string, unknown>).auth_time ?? 0);
  const nowSeconds = Math.floor(Date.now() / 1000);

  if (!Number.isFinite(authTimeSeconds) || nowSeconds - authTimeSeconds > 10 * 60) {
    throw new HttpsError("failed-precondition", "أعد تسجيل الدخول ثم حاول مرة أخرى");
  }

  const userRef = admin.firestore().collection("users").doc(uid);
  const userDoc = await userRef.get();

  if (!userDoc.exists) {
    throw new HttpsError("not-found", "المستخدم غير موجود");
  }

  const userData = userDoc.data() || {};
  assertActiveUserData(userData);

  await admin.auth().updateUser(uid, { password: newPassword });

  await userRef.set(
    {
      mustChangePassword: false,
      passwordChangedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );

  return { success: true };
});
