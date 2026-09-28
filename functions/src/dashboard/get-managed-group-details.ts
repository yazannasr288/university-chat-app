import { onCall, HttpsError } from "firebase-functions/v2/https";
import {
  assertAdminRoleOrThrow,
  assertCanManageGroupOrThrow,
  buildManagedGroupSummary,
  getGroupOrThrow,
  loadUsersByIds,
} from "../services/dashboard-user.service";
import { listIndexedGroupMemberUids } from "../services/group-member-index.service";

export const getManagedGroupDetails = onCall(async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "يجب تسجيل الدخول");

  const callerData = await assertAdminRoleOrThrow(request.auth.uid, ["admin0", "admin1", "admin2"]);
  const groupId = String(request.data.groupId ?? "").trim();

  if (!groupId) throw new HttpsError("invalid-argument", "groupId مطلوب");

  const { groupRef, groupData } = await getGroupOrThrow(groupId);
  assertCanManageGroupOrThrow(
    groupData,
    request.auth.uid,
    String(callerData.role ?? "user"),
    String(callerData.department ?? "")
  );

  const memberUids = await listIndexedGroupMemberUids({ groupRef, groupData });
  const memberUsers = await loadUsersByIds(memberUids);
  const adminUid = String(groupData.adminId ?? "").trim();
  const adminIds = Array.isArray(groupData.adminIds)
    ? groupData.adminIds.map((id: any) => String(id).trim())
    : [adminUid];

  const detailedMembers = memberUsers
    .map(({ uid, data }) => ({
      uid,
      fullName: String(data.fullName ?? ""),
      userId: String(data.userId ?? ""),
      department: String(data.department ?? ""),
      role: String(data.role ?? "user"),
      accountType: String(data.accountType ?? "user"),
      accountStatus: String(data.accountStatus ?? "active"),
      phone: String(data.phone ?? ""),
      email: String(data.email ?? ""),
      isAdmin: adminIds.includes(uid),
    }))
    .sort((a, b) => a.fullName.localeCompare(b.fullName, "ar"));

  return {
    success: true,
    group: {
      ...buildManagedGroupSummary(groupId, groupData),
      archivedBy: String(groupData.archivedBy ?? ""),
      members: detailedMembers,
    },
  };
});
