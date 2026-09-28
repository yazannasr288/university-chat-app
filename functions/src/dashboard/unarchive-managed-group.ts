import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import {
  assertAdminRoleOrThrow,
  assertCanManageGroupOrThrow,
  buildManagedGroupSummary,
  getGroupOrThrow,
} from "../services/dashboard-user.service";
import { writeDashboardAuditLog } from "../services/dashboard-audit.service";
import { updateGroupSummaryFieldsForMembers } from "../services/group-summary.service";
import { listIndexedGroupMemberUids } from "../services/group-member-index.service";

export const unarchiveManagedGroup = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "يجب تسجيل الدخول");
  }

  const callerData = await assertAdminRoleOrThrow(request.auth.uid, ["admin0", "admin1", "admin2"]);
  const groupId = String(request.data.groupId ?? "").trim();
  if (!groupId) {
    throw new HttpsError("invalid-argument", "groupId مطلوب");
  }

  const { groupRef, groupData } = await getGroupOrThrow(groupId);
  assertCanManageGroupOrThrow(
    groupData,
    request.auth.uid,
    String(callerData.role ?? "user"),
    String(callerData.department ?? "")
  );

  await groupRef.set(
    {
      isActive: true,
      archivedAt: null,
      archivedBy: "",
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedBy: request.auth.uid,
    },
    { merge: true }
  );

  const updatedGroup = (await groupRef.get()).data() || {};

  await updateGroupSummaryFieldsForMembers({
    memberIds: await listIndexedGroupMemberUids({
      groupRef,
      groupData: updatedGroup,
    }),
    groupId,
    data: { isActive: true },
  });

  await writeDashboardAuditLog({
    actorUid: request.auth.uid,
    actorRole: String(callerData.role ?? ""),
    action: "group.unarchived",
    level: "warning",
    targetType: "group",
    targetId: groupId,
    targetLabel: String(updatedGroup.groupName ?? ""),
    summary: `unarchived group ${String(updatedGroup.groupName ?? "")}`,
  });

  return {
    success: true,
    group: buildManagedGroupSummary(groupId, updatedGroup),
  };
});
