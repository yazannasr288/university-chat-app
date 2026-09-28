import { onCall, HttpsError } from "firebase-functions/v2/https";
import { assertAdminRoleOrThrow } from "../services/dashboard-user.service";

export const restoreRemovedUser = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "يجب تسجيل الدخول");
  }

  await assertAdminRoleOrThrow(request.auth.uid, ["admin0"]);
  throw new HttpsError(
    "failed-precondition",
    "الحسابات المحذوفة نهائيًا لا يمكن استعادتها",
  );
});
