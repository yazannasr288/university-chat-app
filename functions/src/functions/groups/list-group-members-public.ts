import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import { chunkArray } from "../../utils/array";
import {
  assertSignedIn,
  canManageGroup,
  getCallerData,
} from "../../services/group-chat.service";
import { canUserAccessGroup } from "../../services/group-access.service";
import {
  isIndexedGroupMember,
  listIndexedGroupMemberUids,
} from "../../services/group-member-index.service";

export const listGroupMembersPublic = onCall(async (request) => {
  const callerUid = assertSignedIn(request);
  const callerData = await getCallerData(callerUid);

  const groupId = String(request.data.groupId ?? "").trim();
  if (!groupId) {
    throw new HttpsError("invalid-argument", "groupId مطلوب");
  }

  const groupDoc = await admin.firestore().collection("groups").doc(groupId).get();
  if (!groupDoc.exists) {
    throw new HttpsError("not-found", "المجموعة غير موجودة");
  }

  const groupData = groupDoc.data() || {};
  const callerIsMember = await isIndexedGroupMember({
    groupRef: groupDoc.ref,
    uid: callerUid,
    groupData,
  });
  if (!canUserAccessGroup({
    groupData,
    userData: { ...callerData, isGroupMember: callerIsMember },
  })) {
    throw new HttpsError("permission-denied", "ليس لديك صلاحية");
  }
  const callerRole = String(callerData.role ?? "user");
  const callerDepartment = String(callerData.department ?? "").trim();
  const groupDepartment = String(groupData.department ?? "").trim();
  const canSeeStudentIds =
    callerRole === "admin0" ||
    (callerRole === "admin1" && callerDepartment && callerDepartment === groupDepartment) ||
    (callerRole === "admin2" && canManageGroup(groupData, callerUid, callerRole, callerDepartment));

  const canViewMembers =
    callerIsMember ||
    callerRole === "admin0" ||
    ((callerRole === "admin1" || callerRole === "admin2") &&
      callerDepartment.length > 0 &&
      callerDepartment === groupDepartment);

  if (!canViewMembers) {
    throw new HttpsError("permission-denied", "ليس لديك صلاحية");
  }

  const memberIds = await listIndexedGroupMemberUids({
    groupRef: groupDoc.ref,
    groupData,
  });
  const members: Array<Record<string, unknown>> = [];

  for (const uidChunk of chunkArray(memberIds, 300)) {
    const refs = uidChunk.map((uid) =>
      admin.firestore().collection("users").doc(uid)
    );

    const docs = await admin.firestore().getAll(...refs);

    for (const doc of docs) {
      if (!doc.exists) continue;

      const data = doc.data() || {};
      members.push({
        uid: doc.id,
        fullName: String(data.fullName ?? ""),
        userId: canSeeStudentIds ? String(data.userId ?? "") : "",
        role: String(data.role ?? "user"),
        accountType: String(data.accountType ?? "user"),
        profilepic: String(data.profilepic ?? ""),
      });
    }
  }

  members.sort((a, b) =>
    String(a.fullName ?? "").localeCompare(String(b.fullName ?? ""), "ar")
  );

  return {
    success: true,
    members,
  };
});
