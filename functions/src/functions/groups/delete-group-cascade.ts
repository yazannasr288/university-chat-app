import {
  groupNameLockRef,
  normalizeGroupName,
} from "../../utils/group-name";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import { chunkArray } from "../../utils/array";
import { writeDashboardAuditLog } from "../../services/dashboard-audit.service";
import {
  allowedStorageRootsForMessage,
  deleteStorageObjectIfAllowed,
  GROUP_ICON_STORAGE_ROOTS,
  VIDEO_THUMBNAIL_STORAGE_ROOTS,
} from "../../utils/storage-path";
import {
  assertSignedIn,
  canManageGroup,
  deleteVotesSubcollection,
  getCallerData,
} from "../../services/group-chat.service";
import { userGroupSummaryRef } from "../../services/group-summary.service";
import { listIndexedGroupMemberUids } from "../../services/group-member-index.service";

export const deleteGroupCascade = onCall(async (request) => {
  const callerUid = assertSignedIn(request);
  const callerData = await getCallerData(callerUid);
  const callerRole = String(callerData.role ?? "user");
  const callerDepartment = String(callerData.department ?? "").trim();
  const groupId = String(request.data.groupId ?? "").trim();

  if (!groupId) throw new HttpsError("invalid-argument", "groupId مطلوب");

  const groupRef = admin.firestore().collection("groups").doc(groupId);
  const groupDoc = await groupRef.get();
  if (!groupDoc.exists) return { success: true };

  const groupData = groupDoc.data() || {};
  if (!canManageGroup(groupData, callerUid, callerRole, callerDepartment)) {
    throw new HttpsError("permission-denied", "ليس لديك صلاحية");
  }

  const memberUids = await listIndexedGroupMemberUids({ groupRef, groupData });
  for (const uidChunk of chunkArray(memberUids, 350)) {
    const batch = admin.firestore().batch();

    for (const uid of uidChunk) {
      const userRef = admin.firestore().collection("users").doc(uid);

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
      batch.delete(userGroupSummaryRef(uid, groupId));
      batch.delete(groupRef.collection("memberStates").doc(uid));
    }

    await batch.commit();
  }

  while (true) {
    const messagesSnap = await groupRef.collection("messages").limit(100).get();
    if (messagesSnap.empty) break;

    for (const messageDoc of messagesSnap.docs) {
      const messageData = messageDoc.data() || {};
      await deleteVotesSubcollection(groupId, messageDoc.id);
      await deleteStorageObjectIfAllowed(messageData.storagePath, {
        groupId,
        allowedRoots: allowedStorageRootsForMessage(messageData),
        reason: "delete group cascade message attachment",
      });
      await deleteStorageObjectIfAllowed(messageData.videoThumbnailPath, {
        groupId,
        allowedRoots: VIDEO_THUMBNAIL_STORAGE_ROOTS,
        reason: "delete group cascade video thumbnail",
      });
      await messageDoc.ref.delete();
    }

    if (messagesSnap.size < 100) break;
  }

  const groupName = String(groupData.groupName ?? "").trim();

  await deleteStorageObjectIfAllowed(groupData.groupIconPath, {
    groupId,
    allowedRoots: GROUP_ICON_STORAGE_ROOTS,
    reason: "delete group icon",
  });
  const normalizedGroupName = normalizeGroupName(groupName);
  if (normalizedGroupName) {
    const lockRef = groupNameLockRef(normalizedGroupName);
    const lockDoc = await lockRef.get();

    if (lockDoc.exists && String(lockDoc.data()?.groupId ?? "") === groupId) {
      await lockRef.delete();
    }
  }
  await groupRef.delete();

  await writeDashboardAuditLog({
    actorUid: callerUid,
    actorRole: callerRole,
    action: "group.deleted",
    category: "groups",
    level: "critical",
    targetType: "group",
    targetId: groupId,
    targetLabel: groupName,
    summary: `deleted group ${groupName}`,
    details: {
      removedMemberships: memberUids.length,
      source: "deleteGroupCascade",
    },
  });

  return { success: true };
});
