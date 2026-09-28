import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import { writeDashboardAuditLog } from "../../services/dashboard-audit.service";
import {
  deleteStorageObjectIfAllowed,
  GROUP_ICON_STORAGE_ROOTS,
} from "../../utils/storage-path";
import {
  assertSignedIn,
  canManageGroup,
  getCallerData,
} from "../../services/group-chat.service";
import { updateGroupSummaryFieldsForMembers } from "../../services/group-summary.service";
import { listIndexedGroupMemberUids } from "../../services/group-member-index.service";

export const updateGroupIconMeta = onCall(async (request) => {
  const callerUid = assertSignedIn(request);
  const callerData = await getCallerData(callerUid);
  const callerRole = String(callerData.role ?? "user");
  const callerDepartment = String(callerData.department ?? "").trim();
  const groupId = String(request.data.groupId ?? "").trim();
  const groupIcon = String(request.data.groupIcon ?? "").trim();
  const groupIconPath = String(request.data.groupIconPath ?? "").trim();

  if (!groupId || !groupIcon || !groupIconPath) {
    throw new HttpsError("invalid-argument", "البيانات غير مكتملة");
  }

  if (!groupIcon.startsWith("https://") || !groupIconPath.startsWith(`group_icons/${groupId}/`)) {
    throw new HttpsError("invalid-argument", "مسار صورة المجموعة غير صالح");
  }

  const groupRef = admin.firestore().collection("groups").doc(groupId);
  const groupDoc = await groupRef.get();
  if (!groupDoc.exists) throw new HttpsError("not-found", "المجموعة غير موجودة");

  const groupData = groupDoc.data() || {};
  if (!canManageGroup(groupData, callerUid, callerRole, callerDepartment)) {
    throw new HttpsError("permission-denied", "ليس لديك صلاحية");
  }

  const previousPath = String(groupData.groupIconPath ?? "").trim();

  await groupRef.set(
    {
      groupIcon,
      groupIconPath,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedBy: callerUid,
    },
    { merge: true }
  );

  await updateGroupSummaryFieldsForMembers({
    memberIds: await listIndexedGroupMemberUids({ groupRef, groupData }),
    groupId,
    data: { groupIcon },
  });

  if (previousPath && previousPath !== groupIconPath) {
    await deleteStorageObjectIfAllowed(previousPath, {
      groupId,
      allowedRoots: GROUP_ICON_STORAGE_ROOTS,
      reason: "replace group icon",
    });
  }

  await writeDashboardAuditLog({
    actorUid: callerUid,
    actorRole: callerRole,
    action: "group.icon.updated",
    category: "groups",
    level: "info",
    targetType: "group",
    targetId: groupId,
    targetLabel: String(groupData.groupName ?? ""),
    summary: `updated group icon ${String(groupData.groupName ?? "")}`,
    details: {
      previousPath,
      groupIconPath,
    },
  });

  return { success: true };
});
