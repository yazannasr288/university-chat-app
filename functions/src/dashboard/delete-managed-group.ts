import {
  groupNameLockRef,
  normalizeGroupName,
} from "../utils/group-name";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import {
  assertAdminRoleOrThrow,
  assertCanManageGroupOrThrow,
  deleteStorageObjectIfExists,
  deleteVotesSubcollection,
  getGroupOrThrow,
  removeGroupMembershipValueForUsers,
} from "../services/dashboard-user.service";
import * as admin from "firebase-admin";
import { writeDashboardAuditLog } from "../services/dashboard-audit.service";
import {
  allowedStorageRootsForMessage,
  GROUP_ICON_STORAGE_ROOTS,
  VIDEO_THUMBNAIL_STORAGE_ROOTS,
} from "../utils/storage-path";
import { userGroupSummaryRef } from "../services/group-summary.service";
import { listIndexedGroupMemberUids } from "../services/group-member-index.service";

export const deleteManagedGroup = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "يجب تسجيل الدخول");
  }

  const callerData = await assertAdminRoleOrThrow(request.auth.uid, ["admin0", "admin1", "admin2"]);
  const groupId = String(request.data.groupId ?? "").trim();
  if (!groupId) {
    throw new HttpsError("invalid-argument", "groupId مطلوب");
  }

  const { groupRef, groupData } = await getGroupOrThrow(groupId);
  assertCanManageGroupOrThrow(
    groupData,
    request.auth.uid,
    String(callerData.role ?? "user"),
    String(callerData.department ?? "")
  );

  const groupName = String(groupData.groupName ?? "").trim();
  const memberUids = await listIndexedGroupMemberUids({ groupRef, groupData });

  await removeGroupMembershipValueForUsers({
    memberUids,
    groupId,
  });

  for (let index = 0; index < memberUids.length; index += 400) {
    const batch = admin.firestore().batch();
    for (const uid of memberUids.slice(index, index + 400)) {
      const userRef = admin.firestore().collection("users").doc(uid);
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

    const batch = admin.firestore().batch();
    const storageDeletes: Array<{
      path: unknown;
      allowedRoots: readonly string[];
      reason: string;
    }> = [];

    for (const messageDoc of messagesSnap.docs) {
      const messageData = messageDoc.data() || {};
      await deleteVotesSubcollection(groupId, messageDoc.id);
      storageDeletes.push({
        path: messageData.storagePath,
        allowedRoots: allowedStorageRootsForMessage(messageData),
        reason: "delete managed group message attachment",
      });
      storageDeletes.push({
        path: messageData.videoThumbnailPath,
        allowedRoots: VIDEO_THUMBNAIL_STORAGE_ROOTS,
        reason: "delete managed group video thumbnail",
      });
      batch.delete(messageDoc.ref);
    }

    await batch.commit();
    await Promise.all(
      storageDeletes.map((item) =>
        deleteStorageObjectIfExists(item.path, {
          groupId,
          allowedRoots: item.allowedRoots,
          reason: item.reason,
        })
      )
    );

    if (messagesSnap.size < 100) break;
  }

  await deleteStorageObjectIfExists(groupData.groupIconPath, {
    groupId,
    allowedRoots: GROUP_ICON_STORAGE_ROOTS,
    reason: "delete managed group icon",
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
    actorUid: request.auth.uid,
    actorRole: String(callerData.role ?? ""),
    action: "group.deleted",
    level: "critical",
    targetType: "group",
    targetId: groupId,
    targetLabel: groupName,
    summary: `deleted group ${groupName}`,
    details: { removedMemberships: memberUids.length },
  });

  return { success: true };
});
