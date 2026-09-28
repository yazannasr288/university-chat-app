import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import {
  addGroupMembershipValueForUsers,
  assertAdminRoleOrThrow,
  assertCanManageGroupOrThrow,
  buildManagedGroupSummary,
  getGroupOrThrow,
  loadUsersByIds,
} from "../services/dashboard-user.service";
import { writeDashboardAuditLog } from "../services/dashboard-audit.service";
import { createSummariesForMembers } from "../services/group-summary.service";
import { canUserAccessGroup } from "../services/group-access.service";
import {
  groupMemberCountPatch,
  listIndexedGroupMemberUids,
} from "../services/group-member-index.service";

export const addManagedGroupMembers = onCall(async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "يجب تسجيل الدخول");

  const callerData = await assertAdminRoleOrThrow(request.auth.uid, ["admin0", "admin1", "admin2"]);
  const groupId = String(request.data.groupId ?? "").trim();
  const memberUidsRaw: unknown[] = Array.isArray(request.data.memberUids)
    ? request.data.memberUids
    : [];

  const memberUids = Array.from(
    new Set(memberUidsRaw.map((e) => String(e ?? "").trim()).filter(Boolean))
  ).slice(0, 300);

  if (!groupId || memberUids.length === 0) {
    throw new HttpsError("invalid-argument", "البيانات غير مكتملة");
  }

  const { groupRef, groupData } = await getGroupOrThrow(groupId);
  assertCanManageGroupOrThrow(
    groupData,
    request.auth.uid,
    String(callerData.role ?? "user"),
    String(callerData.department ?? "")
  );

  const currentMemberUids = await listIndexedGroupMemberUids({
    groupRef,
    groupData,
  });
  const candidateUsers = await loadUsersByIds(memberUids);
  const nextUsers = candidateUsers.filter(
    ({ uid, data }) =>
      !currentMemberUids.includes(uid) &&
      String(data.accountStatus ?? "active") === "active" &&
      canUserAccessGroup({ groupData, userData: data })
  );

  if (nextUsers.length === 0) {
    throw new HttpsError("failed-precondition", "لا يوجد أعضاء صالحون للإضافة");
  }

  await groupRef.set(
    {
      memberCount: groupMemberCountPatch(groupData, nextUsers.length),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedBy: request.auth.uid,
    },
    { merge: true }
  );

  await addGroupMembershipValueForUsers({
    memberUids: nextUsers.map((user) => user.uid),
    groupId,
  });

  const memberStateBatch = admin.firestore().batch();
  for (const user of nextUsers) {
    memberStateBatch.set(
      groupRef.collection("memberStates").doc(user.uid),
      {
        uid: user.uid,
        groupId,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
  }
  await memberStateBatch.commit();

  const updatedGroup = (await groupRef.get()).data() || {};

  await createSummariesForMembers({
    memberIds: nextUsers.map((user) => user.uid),
    groupId,
    groupData: updatedGroup,
  });

  await writeDashboardAuditLog({
    actorUid: request.auth.uid,
    actorRole: String(callerData.role ?? ""),
    action: "group.members.added",
    level: "info",
    targetType: "group",
    targetId: groupId,
    targetLabel: String(updatedGroup.groupName ?? ""),
    summary: `added ${nextUsers.length} members to ${String(updatedGroup.groupName ?? "")}`,
    details: { addedMemberUids: nextUsers.map((user) => user.uid) },
  });

  return {
    success: true,
    addedCount: nextUsers.length,
    group: buildManagedGroupSummary(groupId, updatedGroup),
  };
});
