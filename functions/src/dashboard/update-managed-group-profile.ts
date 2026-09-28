import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import {
  assertAdminRoleOrThrow,
  assertCanManageGroupOrThrow,
  buildManagedGroupSummary,
  getGroupOrThrow,
  loadUsersByIds,
} from "../services/dashboard-user.service";
import { writeDashboardAuditLog } from "../services/dashboard-audit.service";
import { updateGroupSummaryFieldsForMembers } from "../services/group-summary.service";
import {
  groupNameLockRef,
  normalizeGroupName,
} from "../utils/group-name";
import {
  canUserAccessGroup,
  GROUP_AUDIENCES,
  resolveGroupAudience,
} from "../services/group-access.service";
import { listIndexedGroupMemberUids } from "../services/group-member-index.service";

export const updateManagedGroupProfile = onCall(async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "يجب تسجيل الدخول");

  const authUid = request.auth.uid;
  const callerData = await assertAdminRoleOrThrow(authUid, ["admin0", "admin1", "admin2"]);
  const groupId = String(request.data.groupId ?? "").trim();
  const groupName = String(request.data.groupName ?? "").trim();
  const groupNameNormalized = normalizeGroupName(groupName);
  const department = String(request.data.department ?? "").trim();
  const writePermission = String(request.data.writePermission ?? "all").trim();
  const adminUid = String(request.data.adminUid ?? "").trim();
  const adminIds = Array.isArray(request.data.adminIds)
    ? request.data.adminIds.map((id: any) => String(id).trim()).filter((id: string) => id.length > 0)
    : [];

  if (!groupId || !groupName || !department) {
    throw new HttpsError("invalid-argument", "البيانات غير مكتملة");
  }

  if (groupName.length > 50) {
    throw new HttpsError("invalid-argument", "اسم المجموعة طويل جدًا");
  }

  if (!groupNameNormalized) {
    throw new HttpsError("invalid-argument", "اسم المجموعة فارغ");
  }

  if (!["all", "admins"].includes(writePermission)) {
    throw new HttpsError("invalid-argument", "إعداد الكتابة غير صالح");
  }

  const { groupRef, groupData } = await getGroupOrThrow(groupId);
  assertCanManageGroupOrThrow(
    groupData,
    authUid,
    String(callerData.role ?? "user"),
    String(callerData.department ?? "")
  );
  const callerRole = String(callerData.role ?? "user");
  const callerDepartment = String(callerData.department ?? "").trim();

  if (callerRole !== "admin0") {
    if (!callerDepartment || department !== callerDepartment) {
      throw new HttpsError(
        "permission-denied",
        "لا يمكنك إدارة مجموعات خارج قسمك"
      );
    }
  }

  const currentMemberUids = await listIndexedGroupMemberUids({
    groupRef,
    groupData,
  });
  if (currentMemberUids.length === 0) {
    throw new HttpsError("failed-precondition", "المجموعة لا تحتوي أعضاء صالحين");
  }

  const effectiveAdminUid = adminUid || String(groupData.adminId ?? "").trim();
  if (!effectiveAdminUid || !currentMemberUids.includes(effectiveAdminUid)) {
    throw new HttpsError("failed-precondition", "يجب اختيار مدير من أعضاء المجموعة الحاليين");
  }

  const memberUsers = await loadUsersByIds(currentMemberUids);
  const audience = resolveGroupAudience(groupData);

  const adminUser = memberUsers.find((user) => user.uid === effectiveAdminUid);
  if (!adminUser) throw new HttpsError("failed-precondition", "مدير المجموعة المحدد غير موجود");
  if (String(adminUser.data.accountStatus ?? "active") !== "active") {
    throw new HttpsError("failed-precondition", "مدير المجموعة المحدد غير نشط");
  }

  const invalidAudienceMembers = memberUsers.filter(
    ({ data }) =>
      !canUserAccessGroup({
        groupData: { ...groupData, department, audience },
        userData: data,
      })
  );

  if (invalidAudienceMembers.length > 0) {
    if (callerData.role === "admin0" && audience === GROUP_AUDIENCES.department) {
      const batch = admin.firestore().batch();
      for (const member of invalidAudienceMembers) {
        batch.set(
          admin.firestore().collection("users").doc(member.uid),
          { department, updatedAt: admin.firestore.FieldValue.serverTimestamp() },
          { merge: true }
        );
      }
      await batch.commit();
    } else {
      throw new HttpsError(
        "failed-precondition",
        "لا يمكن حفظ المجموعة مع وجود أعضاء لا يطابقون نطاق جمهورها"
      );
    }
  }


  const finalAdminIds = Array.from(new Set([effectiveAdminUid, ...adminIds])).filter((uid) =>
    currentMemberUids.includes(uid)
  );

  await admin.firestore().runTransaction(async (transaction) => {
    const freshGroupSnap = await transaction.get(groupRef);
    if (!freshGroupSnap.exists) {
      throw new HttpsError("not-found", "المجموعة غير موجودة");
    }

    const freshGroupData = freshGroupSnap.data() || {};
    const previousGroupNameNormalized = normalizeGroupName(
      freshGroupData.groupNameNormalized ?? freshGroupData.groupName ?? ""
    );
    const newLockRef = groupNameLockRef(groupNameNormalized);
    const oldLockRef = previousGroupNameNormalized
      ? groupNameLockRef(previousGroupNameNormalized)
      : null;
    const shouldMoveLock =
      !!oldLockRef && oldLockRef.path !== newLockRef.path;

    const newLockSnap = await transaction.get(newLockRef);
    const oldLockSnap = shouldMoveLock && oldLockRef
      ? await transaction.get(oldLockRef)
      : null;

    if (newLockSnap.exists && String(newLockSnap.data()?.groupId ?? "") !== groupId) {
      throw new HttpsError("already-exists", "توجد مجموعة بنفس الاسم بالفعل");
    }

    transaction.set(
      newLockRef,
      {
        groupId,
        groupName,
        groupNameNormalized,
        ...(newLockSnap.exists
          ? {}
          : {
              createdAt: admin.firestore.FieldValue.serverTimestamp(),
              createdBy: authUid,
            }),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedBy: authUid,
      },
      { merge: true }
    );

    transaction.set(
      groupRef,
      {
        groupName,
        groupNameNormalized,
        department,
        writePermission,
        adminId: adminUser.uid,
        adminName: String(adminUser.data.fullName ?? ""),
        adminIds: finalAdminIds,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedBy: authUid,
      },
      { merge: true }
    );

    if (
      oldLockRef &&
      oldLockSnap?.exists &&
      String(oldLockSnap.data()?.groupId ?? "") === groupId
    ) {
      transaction.delete(oldLockRef);
    }
  });

  const updatedGroup = (await groupRef.get()).data() || {};

  await updateGroupSummaryFieldsForMembers({
    memberIds: currentMemberUids,
    groupId,
    data: {
      groupName: String(updatedGroup.groupName ?? ""),
      department: String(updatedGroup.department ?? ""),
      writePermission: String(updatedGroup.writePermission ?? "all"),
      adminId: String(updatedGroup.adminId ?? ""),
      adminName: String(updatedGroup.adminName ?? ""),
      adminIds: Array.isArray(updatedGroup.adminIds) ? updatedGroup.adminIds : [],
      audience: resolveGroupAudience(updatedGroup),
    },
  });

  await writeDashboardAuditLog({
    actorUid: authUid,
    actorRole: String(callerData.role ?? ""),
    action: "group.profile.updated",
    level: "info",
    targetType: "group",
    targetId: groupId,
    targetLabel: String(updatedGroup.groupName ?? ""),
    summary: `updated group ${String(updatedGroup.groupName ?? "")}`,
    details: {
      department,
      audience: resolveGroupAudience(updatedGroup),
      writePermission,
      adminUid: effectiveAdminUid,
      groupNameNormalized,
    },
  });

  return {
    success: true,
    group: {
      ...buildManagedGroupSummary(groupId, updatedGroup),
      archivedBy: String(updatedGroup.archivedBy ?? ""),
    },
  };
});
