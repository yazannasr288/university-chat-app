import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import {
  assertSignedIn,
  getCallerData,
} from "../../services/group-chat.service";
import { userGroupSummaryRef } from "../../services/group-summary.service";
import { canUserAccessGroup } from "../../services/group-access.service";
import { isIndexedGroupMember } from "../../services/group-member-index.service";

export const updateGroupNotificationSettings = onCall(async (request) => {
  const callerUid = assertSignedIn(request);
  const callerData = await getCallerData(callerUid);

  const groupId = String(request.data.groupId ?? "").trim();
  if (!groupId) throw new HttpsError("invalid-argument", "groupId مطلوب");

  const hasMuted = Object.prototype.hasOwnProperty.call(request.data, "muted");
  const hasPinned = Object.prototype.hasOwnProperty.call(request.data, "pinned");
  if (!hasMuted && !hasPinned) {
    throw new HttpsError("invalid-argument", "لا توجد إعدادات لتحديثها");
  }

  const muted = request.data.muted === true;
  const pinned = request.data.pinned === true;
  const rawMutedUntil = Number(request.data.mutedUntil ?? 0);
  const mutedUntil = hasMuted && muted && Number.isFinite(rawMutedUntil) && rawMutedUntil > Date.now()
    ? rawMutedUntil
    : null;

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

  const userRef = admin.firestore().collection("users").doc(callerUid);
  const groupSettingsPatch: Record<string, any> = {
    groupId,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };
  const summaryPatch: Record<string, any> = {
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  if (hasMuted) {
    groupSettingsPatch.muted = muted;
    groupSettingsPatch.mutedUntil = mutedUntil;
    summaryPatch.isMuted = muted;
    summaryPatch.mutedUntil = mutedUntil;
  }

  if (hasPinned) {
    groupSettingsPatch.pinned = pinned;
    summaryPatch.isPinned = pinned;
  }

  const writes: Promise<unknown>[] = [
    userRef.collection("groupSettings").doc(groupId).set(groupSettingsPatch, { merge: true }),
    userGroupSummaryRef(callerUid, groupId).set(summaryPatch, { merge: true }),
  ];



  await Promise.all(writes);

  return { success: true, muted, mutedUntil, pinned };
});
