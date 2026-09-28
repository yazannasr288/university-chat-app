import { onCall, HttpsError } from "firebase-functions/v2/https";
import {
  assertAdminRoleOrThrow,
  assertCanViewOrManageTargetUserOrThrow,
  getUserOrThrow,
} from "../services/dashboard-user.service";
import { applyManagedUserStatusTransition } from "../services/managed-user-status.service";

export const unfreezeStudentAccount = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "يجب تسجيل الدخول");
  }

  const callerData = await assertAdminRoleOrThrow(request.auth.uid, ["admin0", "admin1", "admin2"]);

  const targetUid = String(request.data.uid ?? "").trim();
  if (!targetUid) {
    throw new HttpsError("invalid-argument", "uid مطلوب");
  }

  const { userRef, userData } = await getUserOrThrow(targetUid);
  assertCanViewOrManageTargetUserOrThrow(callerData, userData);

  await applyManagedUserStatusTransition({
    userRef,
    targetUid,
    userData,
    callerUid: request.auth.uid,
    callerData,
    nextStatus: "active",
    auditDetails: { source: "unfreezeStudentAccount" },
  });

  return { success: true };
});
