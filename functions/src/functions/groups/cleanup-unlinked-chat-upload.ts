import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import {
  deleteStorageObjectIfAllowed,
  GROUP_ICON_STORAGE_ROOTS,
  MESSAGE_ATTACHMENT_STORAGE_ROOTS,
  VIDEO_THUMBNAIL_STORAGE_ROOTS,
  isStoragePathAllowedForGroup,
  normalizeStoragePath,
} from "../../utils/storage-path";
import {
  assertSignedIn,
  canManageGroup,
  getCallerData,
} from "../../services/group-chat.service";
import { canUserAccessGroup } from "../../services/group-access.service";
import { isIndexedGroupMember } from "../../services/group-member-index.service";

export const cleanupUnlinkedChatUpload = onCall(async (request) => {
  const callerUid = assertSignedIn(request);
  const callerData = await getCallerData(callerUid);
  const callerRole = String(callerData.role ?? "user").trim();
  const callerDepartment = String(callerData.department ?? "").trim();

  const groupId = String(request.data.groupId ?? "").trim();
  const storagePath = normalizeStoragePath(request.data.storagePath);

  if (!groupId || !storagePath) {
    throw new HttpsError("invalid-argument", "البيانات غير مكتملة");
  }

  const groupRef = admin.firestore().collection("groups").doc(groupId);
  const groupDoc = await groupRef.get();
  if (!groupDoc.exists) return { success: true, skipped: true };

  const groupData = groupDoc.data() || {};

  const isGroupIconPath = isStoragePathAllowedForGroup(storagePath, {
    groupId,
    allowedRoots: GROUP_ICON_STORAGE_ROOTS,
    reason: "cleanup unlinked group icon upload",
  });

  if (isGroupIconPath) {
    if (!canManageGroup(groupData, callerUid, callerRole, callerDepartment)) {
      throw new HttpsError("permission-denied", "ليس لديك صلاحية");
    }

    if (String(groupData.groupIconPath ?? "").trim() === storagePath) {
      return { success: true, skipped: true, reason: "linked" };
    }

    await deleteStorageObjectIfAllowed(storagePath, {
      groupId,
      allowedRoots: GROUP_ICON_STORAGE_ROOTS,
      reason: "cleanup unlinked group icon upload",
    });

    return { success: true };
  }

  const isMember = await isIndexedGroupMember({
    groupRef,
    uid: callerUid,
    groupData,
  });
  if (!isMember || !canUserAccessGroup({
    groupData,
    userData: { ...callerData, isGroupMember: true },
  })) {
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
      reason: "cleanup unlinked chat upload",
    })
  ) {
    throw new HttpsError("invalid-argument", "مسار المرفق غير صالح");
  }

  const [mainRefs, thumbnailRefs] = await Promise.all([
    groupRef.collection("messages").where("storagePath", "==", storagePath).limit(1).get(),
    groupRef.collection("messages").where("videoThumbnailPath", "==", storagePath).limit(1).get(),
  ]);

  if (!mainRefs.empty || !thumbnailRefs.empty) {
    return { success: true, skipped: true, reason: "linked" };
  }

  await deleteStorageObjectIfAllowed(storagePath, {
    groupId,
    allowedRoots,
    reason: "cleanup unlinked chat upload",
  });

  return { success: true };
});
