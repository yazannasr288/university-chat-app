import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import {
  allowedStorageRootsForMessage,
  deleteStorageObjectIfAllowed,
  VIDEO_THUMBNAIL_STORAGE_ROOTS,
} from "../../utils/storage-path";
import {
  assertSignedIn,
  deleteVotesSubcollection,
  getCallerData,
  refreshGroupRecentMessage,
} from "../../services/group-chat.service";
import { updateGroupSummaryFieldsForMembers } from "../../services/group-summary.service";
import { canUserAccessGroup } from "../../services/group-access.service";
import {
  isIndexedGroupMember,
  listIndexedGroupMemberUids,
} from "../../services/group-member-index.service";

export const deleteMessageCascade = onCall(async (request) => {
  const callerUid = assertSignedIn(request);
  const callerData = await getCallerData(callerUid);
  const callerRole = String(callerData.role ?? "user");
  const groupId = String(request.data.groupId ?? "").trim();
  const messageId = String(request.data.messageId ?? "").trim();

  if (!groupId || !messageId) throw new HttpsError("invalid-argument", "البيانات غير مكتملة");

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
    throw new HttpsError("permission-denied", "ليست لديك صلاحية");
  }

  const messageRef = groupRef.collection("messages").doc(messageId);
  const messageDoc = await messageRef.get();
  if (!messageDoc.exists) return { success: true };

  const messageData = messageDoc.data() || {};
  const senderId = String(messageData.senderId ?? "");

  const callerDepartment = String(callerData.department ?? "").trim();
  const groupDepartment = String(groupData.department ?? "").trim();
  const groupAdminId = String(groupData.adminId ?? "").trim();
  const groupAdminIds = Array.isArray(groupData.adminIds)
    ? groupData.adminIds.map((id: any) => String(id).trim()).filter(Boolean)
    : [];

  const isSender = senderId === callerUid;
  const isAdmin0 = callerRole === "admin0";
  const isAdmin1SameDepartment =
    callerRole === "admin1" && callerDepartment.length > 0 && callerDepartment === groupDepartment;
  const isGroupCreator = groupAdminId === callerUid || groupAdminIds.includes(callerUid);

  if (!isSender && !isAdmin0 && !isAdmin1SameDepartment && !isGroupCreator) {
    throw new HttpsError("permission-denied", "ليست لديك صلاحية حذف هذه الرسالة");
  }

  await deleteVotesSubcollection(groupId, messageId);
  await deleteStorageObjectIfAllowed(messageData.storagePath, {
    groupId,
    allowedRoots: allowedStorageRootsForMessage(messageData),
    reason: "delete message attachment",
  });
  await deleteStorageObjectIfAllowed(messageData.videoThumbnailPath, {
    groupId,
    allowedRoots: VIDEO_THUMBNAIL_STORAGE_ROOTS,
    reason: "delete message video thumbnail",
  });
  await messageRef.delete();
  await refreshGroupRecentMessage(groupRef);

  const updatedGroupDoc = await groupRef.get();
  const updatedGroupData = updatedGroupDoc.data() || {};
  await updateGroupSummaryFieldsForMembers({
    groupId,
    memberIds: await listIndexedGroupMemberUids({
      groupRef,
      groupData: updatedGroupData,
    }),
    data: {
      recentMessage: String(updatedGroupData.recentMessage ?? ""),
      recentMessageEn: String(updatedGroupData.recentMessageEn ?? ""),
      recentMessageSender: String(updatedGroupData.recentMessageSender ?? ""),
      recentMessageSenderId: String(updatedGroupData.recentMessageSenderId ?? ""),
      recentMessageTime: Number(updatedGroupData.recentMessageTime ?? 0) || 0,
      messageCount: Number(updatedGroupData.messageCount ?? 0) || 0,
    },
  });

  return { success: true };
});
