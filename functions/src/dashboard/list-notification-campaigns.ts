import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import { assertAdminRoleOrThrow } from "../services/dashboard-user.service";

export const listNotificationCampaigns = onCall(async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "يجب تسجيل الدخول");

  const callerData = await assertAdminRoleOrThrow(request.auth.uid, ["admin0", "admin1", "admin2"]);
  const callerRole = String(callerData.role ?? "user");
  const callerDepartment = String(callerData.department ?? "").trim();

  const snap = await admin
    .firestore()
    .collection("notificationCampaigns")
    .orderBy("createdAt", "desc")
    .limit(callerRole === "admin0" ? 120 : 250)
    .get();

  const docs = snap.docs.filter((doc) => {
    if (callerRole === "admin0") return true;
    if (!callerDepartment) return false;

    const data = doc.data() || {};
    const targetDepartment = String(data.targetDepartment ?? "").trim();
    const targetDepartments = Array.isArray(data.targetDepartments)
      ? data.targetDepartments.map((department: unknown) => String(department ?? "").trim())
      : [];

    // Keep old campaign documents visible to their creator until all campaigns
    // carry department metadata.
    if (!targetDepartment && targetDepartments.length === 0) {
      return String(data.createdBy ?? "") === request.auth?.uid;
    }

    return (
      targetDepartment === "all" ||
      targetDepartment === callerDepartment ||
      targetDepartments.includes(callerDepartment)
    );
  });

  const campaigns = docs.slice(0, 80).map((doc) => {
    const data = doc.data() || {};
    const targetDepartments = Array.isArray(data.targetDepartments)
      ? data.targetDepartments.map((department: unknown) => String(department ?? "").trim())
      : [];

    return {
      id: doc.id,
      title: String(data.title ?? ""),
      body: String(data.body ?? ""),
      deliveredTokenCount: Number(data.deliveredTokenCount ?? 0) || 0,
      recipientsCount: Array.isArray(data.recipientUids) ? data.recipientUids.length : 0,
      createdBy: String(data.createdBy ?? ""),
      createdByRole: String(data.createdByRole ?? ""),
      targetDepartment: String(data.targetDepartment ?? ""),
      targetDepartments,
      createdAtMs:
        data.createdAt instanceof admin.firestore.Timestamp ? data.createdAt.toMillis() : 0,
    };
  });

  return { success: true, campaigns };
});
