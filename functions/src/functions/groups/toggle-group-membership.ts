import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import {
  assertSignedIn,
  getCallerData,
} from "../../services/group-chat.service";
import { setUserGroupSummary, userGroupSummaryRef } from "../../services/group-summary.service";
import { canUserAccessGroup } from "../../services/group-access.service";
import {
  groupMemberCountPatch,
  isIndexedGroupMember,
} from "../../services/group-member-index.service";

export const toggleGroupMembership = onCall(async (request) => {
  const callerUid = assertSignedIn(request);
  const callerData = await getCallerData(callerUid);
  const groupId = String(request.data.groupId ?? "").trim();

  if (!groupId) throw new HttpsError("invalid-argument", "groupId مطلوب");

  const groupRef = admin.firestore().collection("groups").doc(groupId);
  const groupDoc = await groupRef.get();
  if (!groupDoc.exists) throw new HttpsError("not-found", "المجموعة غير موجودة");

  const groupData = groupDoc.data() || {};
  const isActive = groupData.isActive === true;
  const alreadyJoined = await isIndexedGroupMember({
    groupRef,
    uid: callerUid,
    groupData,
  });
  const batch = admin.firestore().batch();
  const userRef = admin.firestore().collection("users").doc(callerUid);

  if (alreadyJoined) {
    if (String(groupData.adminId ?? "") === callerUid) {
      throw new HttpsError(
        "failed-precondition",
        "لا يمكن لمدير المجموعة مغادرتها قبل تعيين مدير آخر"
      );
    }

    batch.set(
      groupRef,
      {

        memberCount: groupMemberCountPatch(groupData, -1),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    batch.set(
      userRef,
      {
        groupIds: admin.firestore.FieldValue.arrayRemove(groupId),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    batch.delete(userRef.collection("unreadGroups").doc(groupId));
    batch.delete(userRef.collection("groupSettings").doc(groupId));
    batch.delete(userGroupSummaryRef(callerUid, groupId));
    batch.delete(groupRef.collection("memberStates").doc(callerUid));

    await batch.commit();
    return { success: true, joined: false };
  }

  if (!isActive) throw new HttpsError("failed-precondition", "لا يمكن الانضمام إلى مجموعة مؤرشفة");
  if (!canUserAccessGroup({ groupData, userData: callerData })) {
    throw new HttpsError(
      "permission-denied",
      "هذه المجموعة غير متاحة لنوع حسابك أو قسمك"
    );
  }

  batch.set(
    groupRef,
    {
      memberCount: groupMemberCountPatch(groupData, 1),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );

  batch.set(
    userRef,
    {
      groupIds: admin.firestore.FieldValue.arrayUnion(groupId),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );

  batch.set(
    groupRef.collection("memberStates").doc(callerUid),
    {
      uid: callerUid,
      groupId,
      lastDeliveredMessageTime: 0,
      lastReadMessageTime: 0,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );

  batch.set(
    userRef.collection("unreadGroups").doc(groupId),
    {
      groupId,
      count: 0,
      lastReadMessageTime: Number(groupData.recentMessageTime ?? 0) || 0,
      lastReadMessageCount: Number(groupData.messageCount ?? 0) || 0,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );

  await batch.commit();

  await setUserGroupSummary({
    uid: callerUid,
    groupId,
    groupData,
    unreadCount: 0,
    lastReadMessageTime: Number(groupData.recentMessageTime ?? 0) || 0,
    lastDeliveredMessageTime: 0,
  });

  return { success: true, joined: true };
});
