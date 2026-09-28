import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import { writeDashboardAuditLog } from "../../services/dashboard-audit.service";
import {
  assertSignedIn,
  canManageGroup,
  getCallerData,
} from "../../services/group-chat.service";
import { userGroupSummaryRef } from "../../services/group-summary.service";
import {
  groupMemberCountPatch,
  isIndexedGroupMember,
} from "../../services/group-member-index.service";

export const kickGroupMember = onCall(async (request) => {
  const callerUid = assertSignedIn(request);
  const callerData = await getCallerData(callerUid);
  const callerRole = String(callerData.role ?? "user");
  const callerDepartment = String(callerData.department ?? "").trim();
  const groupId = String(request.data.groupId ?? "").trim();
  const memberUid = String(request.data.memberUid ?? "").trim();

  if (!groupId || !memberUid) throw new HttpsError("invalid-argument", "البيانات غير مكتملة");

  const groupRef = admin.firestore().collection("groups").doc(groupId);
  const groupDoc = await groupRef.get();
  if (!groupDoc.exists) throw new HttpsError("not-found", "المجموعة غير موجودة");

  const groupData = groupDoc.data() || {};
  if (!canManageGroup(groupData, callerUid, callerRole, callerDepartment)) {
    throw new HttpsError("permission-denied", "ليس لديك صلاحية");
  }

  const adminIds = Array.isArray(groupData.adminIds)
    ? groupData.adminIds.map((id: any) => String(id).trim()).filter(Boolean)
    : [];

  if (memberUid === String(groupData.adminId ?? "") || adminIds.includes(memberUid)) {
    throw new HttpsError("failed-precondition", "لا يمكن طرد مدير المجموعة");
  }

  const wasMember = await isIndexedGroupMember({
    groupRef,
    uid: memberUid,
    groupData,
  });
  const batch = admin.firestore().batch();
  batch.set(
    groupRef,
    {

      ...(wasMember
        ? { memberCount: groupMemberCountPatch(groupData, -1) }
        : {}),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );

  const memberRef = admin.firestore().collection("users").doc(memberUid);

  batch.set(
    memberRef,
    {
      groupIds: admin.firestore.FieldValue.arrayRemove(groupId),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );

  batch.delete(memberRef.collection("unreadGroups").doc(groupId));
  batch.delete(memberRef.collection("groupSettings").doc(groupId));
  batch.delete(userGroupSummaryRef(memberUid, groupId));
  batch.delete(groupRef.collection("memberStates").doc(memberUid));

  await batch.commit();

  await writeDashboardAuditLog({
    actorUid: callerUid,
    actorRole: callerRole,
    action: "group.member.kicked",
    category: "groups",
    level: "warning",
    targetType: "group",
    targetId: groupId,
    targetLabel: String(groupData.groupName ?? ""),
    summary: `removed member from ${String(groupData.groupName ?? "")}`,
    details: {
      memberUid,
      source: "kickGroupMember",
    },
  });

  return { success: true };
});
