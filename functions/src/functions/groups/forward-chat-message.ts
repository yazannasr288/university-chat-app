import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import {
  CHAT_VIDEO_THUMBNAIL_STORAGE_ROOT,
  deleteStorageObjectIfAllowed,
  MESSAGE_ATTACHMENT_STORAGE_ROOTS,
  VIDEO_THUMBNAIL_STORAGE_ROOTS,
  normalizeStoragePath,
} from "../../utils/storage-path";
import {
  assertSignedIn,
  buildForwardedMessagePayload,
  canSendMessageToGroup,
  copyMessageStorageObject,
  getCallerData,
  messageStorageRootForType,
} from "../../services/group-chat.service";
import { canUserAccessGroup } from "../../services/group-access.service";
import { isIndexedGroupMember } from "../../services/group-member-index.service";

export const forwardChatMessage = onCall(async (request) => {
  const callerUid = assertSignedIn(request);
  const callerData = await getCallerData(callerUid);
  const callerRole = String(callerData.role ?? "user").trim();
  const callerDepartment = String(callerData.department ?? "").trim();
  const callerAccountType = String(callerData.accountType ?? "user").trim();
  const callerName = String(callerData.fullName ?? "").trim();

  const sourceGroupId = String(request.data.sourceGroupId ?? "").trim();
  const targetGroupId = String(request.data.targetGroupId ?? "").trim();
  const messageId = String(request.data.messageId ?? "").trim();

  if (!sourceGroupId || !targetGroupId || !messageId) {
    throw new HttpsError("invalid-argument", "البيانات غير مكتملة");
  }
  if (sourceGroupId === targetGroupId) {
    throw new HttpsError("invalid-argument", "اختر مجموعة أخرى لإعادة التوجيه");
  }

  const db = admin.firestore();
  const sourceGroupRef = db.collection("groups").doc(sourceGroupId);
  const targetGroupRef = db.collection("groups").doc(targetGroupId);
  const [sourceGroupDoc, targetGroupDoc, sourceMessageDoc] = await Promise.all([
    sourceGroupRef.get(),
    targetGroupRef.get(),
    sourceGroupRef.collection("messages").doc(messageId).get(),
  ]);

  if (!sourceGroupDoc.exists || !targetGroupDoc.exists || !sourceMessageDoc.exists) {
    throw new HttpsError("not-found", "المجموعة أو الرسالة غير موجودة");
  }

  const sourceGroupData = sourceGroupDoc.data() || {};
  const targetGroupData = targetGroupDoc.data() || {};
  const sourceData = sourceMessageDoc.data() || {};
  const [isSourceMember, isTargetMember] = await Promise.all([
    isIndexedGroupMember({
      groupRef: sourceGroupRef,
      uid: callerUid,
      groupData: sourceGroupData,
    }),
    isIndexedGroupMember({
      groupRef: targetGroupRef,
      uid: callerUid,
      groupData: targetGroupData,
    }),
  ]);

  if (
    !isSourceMember ||
    !canUserAccessGroup({
      groupData: sourceGroupData,
      userData: { ...callerData, isGroupMember: true },
    })
  ) {
    throw new HttpsError("permission-denied", "لست عضوًا في المجموعة الأصلية");
  }
  if (
    !canSendMessageToGroup(
      targetGroupData,
      callerUid,
      callerRole,
      callerDepartment,
      isTargetMember,
      callerAccountType
    )
  ) {
    throw new HttpsError("permission-denied", "لا يمكنك الإرسال إلى هذه المجموعة");
  }

  const type = String(sourceData.type ?? "text").trim();
  const mainRoot = messageStorageRootForType(type);
  let copiedStoragePath = "";
  let copiedThumbnailPath = "";

  if (mainRoot) {
    copiedStoragePath = await copyMessageStorageObject({
      sourcePath: sourceData.storagePath,
      sourceGroupId,
      targetGroupId,
      sourceRoot: mainRoot,
      targetRoot: mainRoot,
    });

    const sourceThumbnailPath = normalizeStoragePath(sourceData.videoThumbnailPath);
    if (type === "video" && sourceThumbnailPath) {
      copiedThumbnailPath = await copyMessageStorageObject({
        sourcePath: sourceThumbnailPath,
        sourceGroupId,
        targetGroupId,
        sourceRoot: CHAT_VIDEO_THUMBNAIL_STORAGE_ROOT,
        targetRoot: CHAT_VIDEO_THUMBNAIL_STORAGE_ROOT,
      });
    }
  }

  const forwardedPayload = buildForwardedMessagePayload({
    callerUid,
    callerName: callerName || "مستخدم",
    sourceData,
    storagePath: copiedStoragePath,
    videoThumbnailPath: copiedThumbnailPath,
  });

  const newMessageRef = targetGroupRef.collection("messages").doc();
  const copiedPaths = [copiedStoragePath, copiedThumbnailPath].filter((path) => path.trim().length > 0);

  try {
    await newMessageRef.set({
      ...forwardedPayload,
      forwardedFrom: {
        groupId: sourceGroupId,
        messageId,
        senderId: String(sourceData.senderId ?? ""),
      },
    });
  } catch (error) {
    await Promise.all(
      copiedPaths.map((path) =>
        deleteStorageObjectIfAllowed(path, {
          groupId: targetGroupId,
          allowedRoots: [
            ...MESSAGE_ATTACHMENT_STORAGE_ROOTS,
            ...VIDEO_THUMBNAIL_STORAGE_ROOTS,
          ],
          reason: "rollback failed forwardChatMessage",
        })
      )
    );
    throw error;
  }

  return { success: true, messageId: newMessageRef.id };
});
