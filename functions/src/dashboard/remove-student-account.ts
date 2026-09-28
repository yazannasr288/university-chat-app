import { onCall, HttpsError } from "firebase-functions/v2/https";
import {
  assertAdminRoleOrThrow,
  assertCanViewOrManageTargetUserOrThrow,
  ensureStudentOnly,
  getUserOrThrow,
} from "../services/dashboard-user.service";
import { permanentlyDeleteStudent } from "../services/permanent-user-deletion.service";

export const removeStudentAccount = onCall(
  { timeoutSeconds: 540, memory: "512MiB" },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "يجب تسجيل الدخول");
    }

    const callerData = await assertAdminRoleOrThrow(request.auth.uid, ["admin0"]);

    const targetUid = String(request.data.uid ?? "").trim();
    if (!targetUid) {
      throw new HttpsError("invalid-argument", "uid مطلوب");
    }

    const { userData } = await getUserOrThrow(targetUid);
    ensureStudentOnly(userData);
    assertCanViewOrManageTargetUserOrThrow(callerData, userData);

    await permanentlyDeleteStudent({
      targetUid,
      userData,
      callerUid: request.auth.uid,
      callerData,
    });

    return {
      success: true,
      permanent: true,
      releasedUserId: Boolean(String(userData.userId ?? "").trim()),
      releasedPhone: Boolean(String(userData.phoneE164 ?? "").trim()),
    };
  },
);
