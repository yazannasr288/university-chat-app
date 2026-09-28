import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import {
  MESSAGE_ATTACHMENT_STORAGE_ROOTS,
  VIDEO_THUMBNAIL_STORAGE_ROOTS,
  isStoragePathAllowedForGroup,
  normalizeStoragePath,
} from "../../utils/storage-path";
import {
  assertSignedIn,
  getCallerData,
} from "../../services/group-chat.service";
import { canUserAccessGroup } from "../../services/group-access.service";
import { isIndexedGroupMember } from "../../services/group-member-index.service";

export const getChatAttachmentUrl = onCall(async (request) => {
  const callerUid = assertSignedIn(request);
  const callerData = await getCallerData(callerUid);

  const groupId = String(request.data.groupId ?? "").trim();
  const storagePath = normalizeStoragePath(request.data.storagePath);

  if (!groupId || !storagePath) {
    throw new HttpsError("invalid-argument", "البيانات غير مكتملة");
  }

  const groupDoc = await admin.firestore().collection("groups").doc(groupId).get();
  if (!groupDoc.exists) {
    throw new HttpsError("not-found", "المجموعة غير موجودة");
  }

  const groupData = groupDoc.data() || {};
  const isMember = await isIndexedGroupMember({
    groupRef: groupDoc.ref,
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

  const allowedRoots = [
    ...MESSAGE_ATTACHMENT_STORAGE_ROOTS,
    ...VIDEO_THUMBNAIL_STORAGE_ROOTS,
  ];

  if (
    !isStoragePathAllowedForGroup(storagePath, {
      groupId,
      allowedRoots,
      reason: "get chat attachment url",
    })
  ) {
    throw new HttpsError("invalid-argument", "مسار المرفق غير صالح");
  }

  const expiresAt = Date.now() + 10 * 60 * 1000;
  const [url] = await admin
    .storage()
    .bucket()
    .file(storagePath)
    .getSignedUrl({
      version: "v4",
      action: "read",
      expires: expiresAt,
    });

  return {
    success: true,
    url,
    expiresAt,
  };
});
