import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import {
  assertAdminRoleOrThrow,
  assertCanViewOrManageTargetUserOrThrow,
  clearUserSessions,
  getUserOrThrow,
} from "../services/dashboard-user.service";
import { writeDashboardAuditLog } from "../services/dashboard-audit.service";

export const adminResetManagedUserPin = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "يجب تسجيل الدخول");
  }

  const callerData = await assertAdminRoleOrThrow(request.auth.uid, ["admin0", "admin1"]);

  const uid = String(request.data.uid ?? "").trim();
  if (!uid) {
    throw new HttpsError("invalid-argument", "uid مطلوب");
  }

  const { userRef, userData } = await getUserOrThrow(uid);
  assertCanViewOrManageTargetUserOrThrow(callerData, userData);

  await admin
    .firestore()
    .collection("userPins")
    .doc(uid)
    .delete()
    .catch(() => {});

  await userRef.set(
    {
      hasPin: false,
      pinResetRequired: true,
      pinResetByAdminAt: admin.firestore.FieldValue.serverTimestamp(),
      pinResetByAdminId: request.auth.uid,
    },
    { merge: true }
  );

  await clearUserSessions(userRef);

  await writeDashboardAuditLog({
    actorUid: request.auth.uid,
    actorRole: String(callerData.role ?? ""),
    action: "user.pin.reset",
    level: "warning",
    targetType: "user",
    targetId: uid,
    targetLabel: String(userData.fullName ?? ""),
    summary: `reset pin for ${String(userData.fullName ?? "")}`,
  });

  return { success: true };
});
