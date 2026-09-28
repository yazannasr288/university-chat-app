import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import {
  assertAdminRoleOrThrow,
  assertCanViewOrManageTargetUserOrThrow,
  clearUserSessions,
  getUserOrThrow,
} from "../services/dashboard-user.service";
import { writeDashboardAuditLog } from "../services/dashboard-audit.service";
import { USER_FIELD_LIMITS } from "../utils/user-field-validation";

export const adminResetManagedUserPassword = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "يجب تسجيل الدخول");
  }

  const callerData = await assertAdminRoleOrThrow(request.auth.uid, ["admin0", "admin1"]);

  const uid = String(request.data.uid ?? "").trim();
  const password = String(request.data.password ?? "").trim();

  if (!uid || !password) {
    throw new HttpsError("invalid-argument", "البيانات غير مكتملة");
  }

  if (password.length < 6) {
    throw new HttpsError("invalid-argument", "كلمة السر يجب أن تكون 6 أحرف على الأقل");
  }

  if (password.length > USER_FIELD_LIMITS.password) {
    throw new HttpsError("invalid-argument", "كلمة المرور طويلة جدًا");
  }

  const { userRef, userData } = await getUserOrThrow(uid);
  assertCanViewOrManageTargetUserOrThrow(callerData, userData);

  await admin.auth().updateUser(uid, { password });

  const pinRef = admin.firestore().collection("userPins").doc(uid);
  const pinDoc = await pinRef.get();
  if (pinDoc.exists) {
    await pinRef.delete();
  }

  await userRef.set(
    {
      mustChangePassword: true,
      resetByAdminAt: admin.firestore.FieldValue.serverTimestamp(),
      resetByAdminId: request.auth.uid,
      hasPin: false,
      pinResetRequired: true,
    },
    { merge: true }
  );

  await clearUserSessions(userRef);

  await writeDashboardAuditLog({
    actorUid: request.auth.uid,
    actorRole: String(callerData.role ?? ""),
    action: "user.password.reset",
    level: "critical",
    targetType: "user",
    targetId: uid,
    targetLabel: String(userData.fullName ?? ""),
    summary: `reset password for ${String(userData.fullName ?? "")}`,
    details: { alsoResetPin: true },
  });

  return { success: true };
});
