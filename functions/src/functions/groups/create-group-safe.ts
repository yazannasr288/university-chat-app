import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import { writeDashboardAuditLog } from "../../services/dashboard-audit.service";
import {
  assertSignedIn,
  getCallerData,
} from "../../services/group-chat.service";
import { setUserGroupSummary } from "../../services/group-summary.service";
import {
  groupNameLockRef,
  normalizeGroupName,
} from "../../utils/group-name";
import {
  GROUP_AUDIENCES,
  isDoctorCollaborator,
  normalizeCreatableGroupAudience,
  WORKER_DEPARTMENT,
} from "../../services/group-access.service";

const ALLOWED_DEPARTMENTS = new Set([
  "طب الاسنان",
  "الصيدلة",
  "هندسة العمارة",
  "هندسة الحاسوب",
  "إدارة الأعمال",
  "الهندسة المدنية",
  "هندسة الإتصالات",
  "موظف",
  WORKER_DEPARTMENT,
]);

export const createGroupSafe = onCall(async (request) => {
  const callerUid = assertSignedIn(request);
  const callerData = await getCallerData(callerUid);
  const callerRole = String(callerData.role ?? "user");
  const callerName = String(callerData.fullName ?? "").trim();
  const callerDepartment = String(callerData.department ?? "").trim();
  const groupName = String(request.data.groupName ?? "").trim();
  const groupNameNormalized = normalizeGroupName(groupName);
  const requestedAudience = String(
    request.data.audience ?? GROUP_AUDIENCES.department
  ).trim();
  const audience = normalizeCreatableGroupAudience(requestedAudience);
  const requestedDepartment = String(request.data.department ?? "").trim();

  if (!["admin0", "admin1", "admin2"].includes(callerRole)) {
    throw new HttpsError("permission-denied", "ليس لديك صلاحية إنشاء مجموعات");
  }

  if (!groupName) {
    throw new HttpsError("invalid-argument", "اسم المجموعة فارغ");
  }

  if (groupName.length > 50) {
    throw new HttpsError("invalid-argument", "اسم المجموعة طويل جدًا");
  }

  if (!groupNameNormalized) {
    throw new HttpsError("invalid-argument", "اسم المجموعة فارغ");
  }

  if (requestedAudience !== audience) {
    throw new HttpsError("invalid-argument", "نطاق المجموعة غير صالح");
  }

  if (
    (audience === GROUP_AUDIENCES.doctorsDepartment ||
      audience === GROUP_AUDIENCES.doctorsAll) &&
    callerRole !== "admin0" &&
    !isDoctorCollaborator(callerData)
  ) {
    throw new HttpsError(
      "permission-denied",
      "إنشاء مجموعات الدكاترة متاح للدكاترة والعمداء وإدارة النظام فقط"
    );
  }

  if (
    audience === GROUP_AUDIENCES.workers &&
    callerRole !== "admin0"
  ) {
    throw new HttpsError(
      "permission-denied",
      "إنشاء مجموعات العمال متاح لإدارة النظام فقط"
    );
  }

  let groupDepartment = callerDepartment;
  if (audience === GROUP_AUDIENCES.workers) {
    groupDepartment = WORKER_DEPARTMENT;
  } else if (callerRole === "admin0" && requestedDepartment) {
    groupDepartment = requestedDepartment;
  }

  if (!groupDepartment) {
    throw new HttpsError("failed-precondition", "القسم غير محدد");
  }

  if (!ALLOWED_DEPARTMENTS.has(groupDepartment)) {
    throw new HttpsError("invalid-argument", "القسم المحدد غير صالح");
  }

  const db = admin.firestore();
  const groupRef = db.collection("groups").doc();
  const lockRef = groupNameLockRef(groupNameNormalized);

  const groupPayload = {
    groupId: groupRef.id,
    groupName,
    groupNameNormalized,
    groupIcon: "",
    groupIconPath: "",
    adminId: callerUid,
    adminName: callerName,
    adminIds: [callerUid],
    memberCount: 1,
    membershipSchemaVersion: 2,
    department: groupDepartment,
    audience,
    recentMessage: "",
    recentMessageEn: "",
    recentMessageSender: "",
    recentMessageSenderId: "",
    recentMessageTime: 0,
    messageCount: 0,
    writePermission: "all",
    isActive: true,
    archivedAt: null,
    archivedBy: "",
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  await db.runTransaction(async (transaction) => {
    const lockSnap = await transaction.get(lockRef);

    if (lockSnap.exists) {
      throw new HttpsError("already-exists", "توجد مجموعة بنفس الاسم بالفعل");
    }

    transaction.set(lockRef, {
      groupId: groupRef.id,
      groupName,
      groupNameNormalized,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      createdBy: callerUid,
    });

    transaction.set(groupRef, groupPayload);

    transaction.set(
      db.collection("users").doc(callerUid),
      {
        groupIds: admin.firestore.FieldValue.arrayUnion(groupRef.id),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    transaction.set(
      groupRef.collection("memberStates").doc(callerUid),
      {
        uid: callerUid,
        groupId: groupRef.id,
        lastDeliveredMessageTime: 0,
        lastReadMessageTime: 0,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
  });

  const createdGroupData = (await groupRef.get()).data() || groupPayload;
  await setUserGroupSummary({
    uid: callerUid,
    groupId: groupRef.id,
    groupData: createdGroupData,
    unreadCount: 0,
    lastReadMessageTime: 0,
    lastDeliveredMessageTime: 0,
  });

  await writeDashboardAuditLog({
    actorUid: callerUid,
    actorRole: callerRole,
    action: "group.created",
    category: "groups",
    level: "info",
    targetType: "group",
    targetId: groupRef.id,
    targetLabel: groupName,
    summary: `created group ${groupName}`,
    details: {
      department: groupDepartment,
      audience,
      adminId: callerUid,
      source: "createGroupSafe",
    },
  });

  return { success: true, groupId: groupRef.id };
});
