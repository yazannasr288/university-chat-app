import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import {
  assertAdminRoleOrThrow,
  assertCanManageGroupOrThrow,
  buildManagedGroupSummary,
  getGroupOrThrow,
  removeGroupMembershipValueForUsers,
} from "../services/dashboard-user.service";
import { writeDashboardAuditLog } from "../services/dashboard-audit.service";
import { userGroupSummaryRef } from "../services/group-summary.service";
import {
  groupMemberCountPatch,
  isIndexedGroupMember,
} from "../services/group-member-index.service";
export const removeManagedGroupMember = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "يجب تسجيل الدخول");
  }

  const callerData = await assertAdminRoleOrThrow(request.auth.uid, [
    "admin0",
    "admin1",
    "admin2",
  ]);

  const groupId = String(request.data.groupId ?? "").trim();
  const memberUid = String(request.data.memberUid ?? "").trim();

  if (!groupId || !memberUid) {
    throw new HttpsError("invalid-argument", "البيانات غير مكتملة");
  }

  const { groupRef, groupData } = await getGroupOrThrow(groupId);

  assertCanManageGroupOrThrow(
    groupData,
    request.auth.uid,
    String(callerData.role ?? "user"),
    String(callerData.department ?? "")
  );

  const adminId = String(groupData.adminId ?? "").trim();
  const adminIds = Array.isArray(groupData.adminIds)
    ? groupData.adminIds.map((id: unknown) => String(id).trim()).filter(Boolean)
    : [];

  if (memberUid === adminId || adminIds.includes(memberUid)) {
    throw new HttpsError(
      "failed-precondition",
      "انقل إدارة المجموعة أولًا قبل حذف المدير"
    );
  }

  const wasMember = await isIndexedGroupMember({
    groupRef,
    uid: memberUid,
    groupData,
  });
  if (!wasMember) {
    return {
      success: true,
      group: buildManagedGroupSummary(groupId, groupData),
    };
  }

  await groupRef.set(
    {

      memberCount: groupMemberCountPatch(groupData, -1),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedBy: request.auth.uid,
    },
    { merge: true }
  );

  await removeGroupMembershipValueForUsers({
    memberUids: [memberUid],
    groupId,
  });

  const cleanupBatch = admin.firestore().batch();
  const memberRef = admin.firestore().collection("users").doc(memberUid);
  cleanupBatch.delete(memberRef.collection("unreadGroups").doc(groupId));
  cleanupBatch.delete(memberRef.collection("groupSettings").doc(groupId));
  cleanupBatch.delete(userGroupSummaryRef(memberUid, groupId));
  cleanupBatch.delete(groupRef.collection("memberStates").doc(memberUid));
  await cleanupBatch.commit();

  const updatedGroup = (await groupRef.get()).data() || {};

  await writeDashboardAuditLog({
    actorUid: request.auth.uid,
    actorRole: String(callerData.role ?? ""),
    action: "group.member.removed",
    level: "warning",
    targetType: "group",
    targetId: groupId,
    targetLabel: String(updatedGroup.groupName ?? ""),
    summary: `removed member from ${String(updatedGroup.groupName ?? "")}`,
    details: {
      removedMemberUid: memberUid,
    },
  });

  return {
    success: true,
    group: buildManagedGroupSummary(groupId, updatedGroup),
  };
});
