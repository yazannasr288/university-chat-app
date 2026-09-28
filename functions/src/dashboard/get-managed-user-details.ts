import { onCall, HttpsError } from "firebase-functions/v2/https";
import {
  assertAdminRoleOrThrow,
  assertCanViewOrManageTargetUserOrThrow,
  buildManagedUserResponse,
  getUserOrThrow,
} from "../services/dashboard-user.service";

export const getManagedUserDetails = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "يجب تسجيل الدخول");
  }

  const callerData = await assertAdminRoleOrThrow(request.auth.uid, ["admin0", "admin1", "admin2"]);

  const targetUid = String(request.data.uid ?? "").trim();
  if (!targetUid) {
    throw new HttpsError("invalid-argument", "uid مطلوب");
  }

  const { userData } = await getUserOrThrow(targetUid);
  assertCanViewOrManageTargetUserOrThrow(callerData, userData);

  return {
    success: true,
    user: buildManagedUserResponse(targetUid, userData),
  };
});
