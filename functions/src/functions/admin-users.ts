import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";

import { joinDefaultGroups } from "../services/group-membership.service";
import { mapAccountTypeToRole } from "../utils/group-mapping";
import { normalizeSyrianPhone } from "../utils/phone";
import { writeDashboardAuditLog } from "../services/dashboard-audit.service";
import { assertUserProfileFieldLimits } from "../utils/user-field-validation";
import { assertActiveUserData } from "../services/account-status.service";
import { finalizeUniqueUserFields, releaseUniqueUserFields, reserveUniqueUserFields } from "../services/unique-user.service";
import { assertWorkerAccountCompatibility } from "../services/group-access.service";

export const registerStudentByAdmin = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "يجب تسجيل الدخول");
  }

  const callerUid = request.auth.uid;
  const callerDoc = await admin.firestore().collection("users").doc(callerUid).get();

  if (!callerDoc.exists) {
    throw new HttpsError("permission-denied", "المستخدم غير موجود");
  }

  const callerData = callerDoc.data() || {};
  const callerRole = String(callerData.role ?? "");
  if (callerRole !== "admin0") {
    throw new HttpsError("permission-denied", "ليس لديك صلاحية");
  }

  assertActiveUserData(callerData);

  const fullName = String(request.data.fullName ?? "").trim();
  const userId = String(request.data.userId ?? "").trim();
  const phone = String(request.data.phone ?? "").trim();
  const department = String(request.data.department ?? "").trim();
  const password = String(request.data.password ?? "").trim();
  const accountType = String(request.data.accountType ?? "user").trim();

  if (!fullName || !userId || !department || !phone || !password) {
    throw new HttpsError("invalid-argument", "بيانات ناقصة");
  }

  assertWorkerAccountCompatibility({ department, accountType });

  assertUserProfileFieldLimits({
    fullName,
    userId,
    phone,
    department,
    accountType,
    password,
  });

  const phoneE164 = normalizeSyrianPhone(phone);
  if (!phoneE164) {
    throw new HttpsError("invalid-argument", "رقم الهاتف غير صالح");
  }

  const sameUserId = await admin
    .firestore()
    .collection("users")
    .where("userId", "==", userId)
    .limit(1)
    .get();

  if (!sameUserId.empty) {
    throw new HttpsError("already-exists", "الرقم الجامعي مسجل بالفعل");
  }

  const samePhone = await admin
    .firestore()
    .collection("users")
    .where("phoneE164", "==", phoneE164)
    .limit(1)
    .get();

  if (!samePhone.empty) {
    throw new HttpsError("already-exists", "رقم الهاتف مستخدم بالفعل");
  }

  const email = `${userId}@wpu.edu`;
  const role = mapAccountTypeToRole(accountType);

  let createdUid = "";
  let reservedUniqueFields = false;

  try {
    await reserveUniqueUserFields({ userId, phoneE164 });
    reservedUniqueFields = true;
    const userRecord = await admin.auth().createUser({
      email,
      password,
      displayName: fullName,
    });

    const uid = userRecord.uid;
    createdUid = uid;

    await admin.firestore().collection("users").doc(uid).set({
      uid,
      fullName,
      userId,
      phone,
      phoneE164,
      department,
      email,
      role,
      accountType,
      accountStatus: "active",
      accountStatusReason: "",
      groupIds: [],
      profilepic: "",
      activeSessionId: "",
      activeDeviceId: "",
      activeDeviceName: "",
      pendingSessionId: "",
      pendingDeviceId: "",
      pendingDeviceName: "",
      pendingFcmToken: "",
      pendingLoginAt: null,
      hasPin: false,
      lastLoginAt: null,
      pinResetRequired: false,
      mustChangePassword: true,
      passwordChangedAt: null,
      resetByAdminAt: admin.firestore.FieldValue.serverTimestamp(),
      resetByAdminId: callerUid,
      fcmToken: "",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    await joinDefaultGroups({
      uid,
      department,
      accountType,
    });

    await finalizeUniqueUserFields({ userId, phoneE164, uid });

    await writeDashboardAuditLog({
      actorUid: callerUid,
      actorRole: callerRole,
      action: "student.created",
      category: "students",
      level: "info",
      targetType: "user",
      targetId: uid,
      targetLabel: fullName,
      summary: `created student ${fullName}`,
      details: {
        userId,
        department,
        accountType,
        role,
        source: "registerStudentByAdmin",
      },
    });

    return { success: true, uid };
  } catch (e) {
    if (createdUid) {
      await admin
        .auth()
        .deleteUser(createdUid)
        .catch(() => {});
      await admin
        .firestore()
        .collection("users")
        .doc(createdUid)
        .delete()
        .catch(() => {});
      await admin
        .firestore()
        .collection("userPins")
        .doc(createdUid)
        .delete()
        .catch(() => {});
    }

    if (reservedUniqueFields) {
      await releaseUniqueUserFields({ userId, phoneE164 });
    }

    throw e;
  }
});
