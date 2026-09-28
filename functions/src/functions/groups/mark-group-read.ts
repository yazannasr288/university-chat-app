import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import {
  assertSignedIn,
  getCallerData,
} from "../../services/group-chat.service";
import { userGroupSummaryRef } from "../../services/group-summary.service";
import { canUserAccessGroup } from "../../services/group-access.service";
import { isIndexedGroupMember } from "../../services/group-member-index.service";

export const markGroupRead = onCall(async (request) => {
  const callerUid = assertSignedIn(request);
  const callerData = await getCallerData(callerUid);
  const groupId = String(request.data.groupId ?? "").trim();

  if (!groupId) throw new HttpsError("invalid-argument", "groupId مطلوب");

  const groupRef = admin.firestore().collection("groups").doc(groupId);
  const groupDoc = await groupRef.get();
  if (!groupDoc.exists) throw new HttpsError("not-found", "المجموعة غير موجودة");

  const groupData = groupDoc.data() || {};
  const isMember = await isIndexedGroupMember({
    groupRef,
    uid: callerUid,
    groupData,
  });
  if (
    !isMember ||
    !canUserAccessGroup({
      groupData,
      userData: { ...callerData, isGroupMember: true },
    })
  ) {
    throw new HttpsError("permission-denied", "لست عضوًا في هذه المجموعة");
  }

 const requestedTime = Number(request.data.lastReadMessageTime ?? 0);
 const recentMessageTime = Number(groupData.recentMessageTime ?? 0);
 const messageCount = Number(groupData.messageCount ?? 0);
 const safeMessageCount = Number.isFinite(messageCount) && messageCount > 0 ? messageCount : 0;
 const safeRequestedTime = Number.isFinite(requestedTime) && requestedTime > 0 ? requestedTime : 0;
 const safeRecentMessageTime =
   Number.isFinite(recentMessageTime) && recentMessageTime > 0 ? recentMessageTime : 0;
 const maxReadTime = safeRecentMessageTime > 0 ? safeRecentMessageTime : Date.now();
 const incomingReadTime =
   safeRequestedTime > 0 ? Math.min(safeRequestedTime, maxReadTime) : safeRecentMessageTime;
  const unreadRef = admin
    .firestore()
    .collection("users")
    .doc(callerUid)
    .collection("unreadGroups")
    .doc(groupId);

  const memberStateRef = groupRef.collection("memberStates").doc(callerUid);

  await admin.firestore().runTransaction(async (transaction) => {
    const previousState = await transaction.get(memberStateRef);
    const previousReadTime = Number(previousState.data()?.lastReadMessageTime ?? 0);
    const previousDeliveredTime = Number(previousState.data()?.lastDeliveredMessageTime ?? 0);
    const lastReadMessageTime = Math.max(previousReadTime || 0, incomingReadTime || 0);
    const lastDeliveredMessageTime = Math.max(previousDeliveredTime || 0, lastReadMessageTime);

    transaction.set(
      unreadRef,
      {
        groupId,
        count: 0,
        lastReadAt: Date.now(),
        lastReadMessageTime,
        lastReadMessageCount: safeMessageCount,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        userRole: String(callerData.role ?? "user"),
      },
      { merge: true }
    );

    transaction.set(
      memberStateRef,
      {
        uid: callerUid,
        groupId,
        lastDeliveredMessageTime,
        lastReadMessageTime,
        lastReadAt: Date.now(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    transaction.set(
      userGroupSummaryRef(callerUid, groupId),
      {
        unreadCount: 0,
        lastReadMessageTime,
        lastDeliveredMessageTime,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
  });

  return { success: true };
});
