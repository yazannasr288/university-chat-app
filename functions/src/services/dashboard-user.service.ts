import { HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import { assertActiveUserData } from "./account-status.service";
import { deleteStorageObjectIfAllowed, StorageDeleteOptions } from "../utils/storage-path";
import { resolveGroupAudience } from "./group-access.service";
import { chunkArray } from "../utils/array";

export type AdminRole = "admin0" | "admin1" | "admin2";
export type AppRole = AdminRole | "user";

export function normalizeAppRole(value: unknown): AppRole {
  const role = String(value ?? "user").trim();

  if (role === "student") return "user";
  if (["admin0", "admin1", "admin2"].includes(role)) {
    return role as AdminRole;
  }

  return "user";
}

export function isStudentLikeRole(value: unknown): boolean {
  return normalizeAppRole(value) === "user";
}

export async function assertAdminRoleOrThrow(uid: string, allowedRoles: AdminRole[] = ["admin0"]) {
  const callerDoc = await admin.firestore().collection("users").doc(uid).get();

  if (!callerDoc.exists) {
    throw new HttpsError("permission-denied", "المستخدم غير موجود");
  }

  const callerData = callerDoc.data() || {};
  assertActiveUserData(callerData);

  const role = normalizeAppRole(callerData.role);
  if (!allowedRoles.includes(role as AdminRole)) {
    throw new HttpsError("permission-denied", "ليس لديك صلاحية");
  }

  return callerData;
}

export async function assertAdmin0OrThrow(uid: string) {
  return assertAdminRoleOrThrow(uid, ["admin0"]);
}

export function normalizeSearch(value: string) {
  return String(value ?? "")
    .trim()
    .toLowerCase()
    .replace(/\s+/g, " ");
}

export async function getUserOrThrow(uid: string) {
  const userRef = admin.firestore().collection("users").doc(uid);
  const userDoc = await userRef.get();

  if (!userDoc.exists) {
    throw new HttpsError("not-found", "المستخدم غير موجود");
  }

  return {
    userRef,
    userData: userDoc.data() || {},
  };
}

export async function getGroupOrThrow(groupId: string) {
  const groupRef = admin.firestore().collection("groups").doc(groupId);
  const groupDoc = await groupRef.get();

  if (!groupDoc.exists) {
    throw new HttpsError("not-found", "المجموعة غير موجودة");
  }

  return {
    groupRef,
    groupData: groupDoc.data() || {},
  };
}

export function ensureStudentOnly(userData: Record<string, any>) {
  if (!isStudentLikeRole(userData.role)) {
    throw new HttpsError("failed-precondition", "هذا الإجراء متاح فقط على حسابات الطلاب");
  }
}

export function getRoleRank(role: string) {
  switch (normalizeAppRole(role)) {
    case "admin0":
      return 3;
    case "admin1":
      return 2;
    case "admin2":
      return 1;
    default:
      return 0;
  }
}

export function canViewOrManageTargetUser(
  callerData: Record<string, any>,
  targetData: Record<string, any>
) {
  const callerRole = normalizeAppRole(callerData.role);
  const callerDepartment = String(callerData.department ?? "").trim();
  const targetRole = normalizeAppRole(targetData.role);
  const targetDepartment = String(targetData.department ?? "").trim();

  if (callerRole === "admin0") return true;

  if (callerRole === "admin1") {
    if (targetRole === "admin0") return false;
    if (!callerDepartment) return false;
    return callerDepartment === targetDepartment;
  }

  if (callerRole === "admin2") {
    if (targetRole !== "user") return false;
    if (!callerDepartment) return false;
    return callerDepartment === targetDepartment;
  }

  return false;
}

export function assertCanViewOrManageTargetUserOrThrow(
  callerData: Record<string, any>,
  targetData: Record<string, any>
) {
  if (!canViewOrManageTargetUser(callerData, targetData)) {
    throw new HttpsError("permission-denied", "ليس لديك صلاحية");
  }
}

export async function clearUserSessions(userRef: FirebaseFirestore.DocumentReference) {
  await userRef.set(
    {
      activeSessionId: "",
      activeDeviceId: "",
      activeDeviceName: "",
      pendingSessionId: "",
      pendingDeviceId: "",
      pendingDeviceName: "",
      fcmToken: "",
      pendingFcmToken: "",
      pendingLoginAt: null,
    },
    { merge: true }
  );
}

export function matchesUserSearch(userData: Record<string, any>, normalizedQuery: string) {
  if (!normalizedQuery) return true;

  const fullName = normalizeSearch(userData.fullName ?? "");
  const userId = normalizeSearch(userData.userId ?? "");
  const department = normalizeSearch(userData.department ?? "");
  const phone = normalizeSearch(userData.phone ?? "");

  return (
    fullName.includes(normalizedQuery) ||
    userId.includes(normalizedQuery) ||
    department.includes(normalizedQuery) ||
    phone.includes(normalizedQuery)
  );
}

export function buildManagedUserResponse(uid: string, userData: Record<string, any>) {
  return {
    uid,
    fullName: String(userData.fullName ?? ""),
    userId: String(userData.userId ?? ""),
    department: String(userData.department ?? ""),
    role: normalizeAppRole(userData.role),
    accountType: String(userData.accountType ?? "user"),
    accountStatus: String(userData.accountStatus ?? "active"),
    accountStatusReason: String(userData.accountStatusReason ?? ""),
    phone: String(userData.phone ?? ""),
    phoneE164: String(userData.phoneE164 ?? ""),
    email: String(userData.email ?? ""),
    groupIds: Array.isArray(userData.groupIds) ? userData.groupIds.map((e: any) => String(e)) : [],
    hasPin: userData.hasPin === true,
    pinResetRequired: userData.pinResetRequired === true,
    mustChangePassword: userData.mustChangePassword === true,
    activeDeviceName: String(userData.activeDeviceName ?? ""),
    pendingDeviceName: String(userData.pendingDeviceName ?? ""),
  };
}

export function canManageGroup(
  groupData: Record<string, any>,
  callerUid: string,
  callerRole: string,
  callerDepartment = ""
) {
  const adminId = String(groupData.adminId ?? "").trim();
  const adminIds = Array.isArray(groupData.adminIds)
    ? groupData.adminIds.map((id: any) => String(id).trim())
    : [];
  const groupDepartment = String(groupData.department ?? "").trim();
  const normalizedDepartment = String(callerDepartment ?? "").trim();

  if (adminId === callerUid || adminIds.includes(callerUid)) return true;
  if (callerRole === "admin0") return true;

  if (callerRole === "admin1") {
    return (
      normalizedDepartment.length > 0 &&
      groupDepartment.length > 0 &&
      normalizedDepartment === groupDepartment
    );
  }

  return false;
}

export function assertCanManageGroupOrThrow(
  groupData: Record<string, any>,
  callerUid: string,
  callerRole: string,
  callerDepartment = ""
) {
  if (!canManageGroup(groupData, callerUid, callerRole, callerDepartment)) {
    throw new HttpsError("permission-denied", "ليس لديك صلاحية");
  }
}

export function matchesGroupSearch(groupData: Record<string, any>, normalizedQuery: string) {
  if (!normalizedQuery) return true;

  const groupName = normalizeSearch(groupData.groupName ?? "");
  const department = normalizeSearch(groupData.department ?? "");
  const adminName = normalizeSearch(groupData.adminName ?? "");
  const recentMessage = normalizeSearch(groupData.recentMessage ?? "");

  return (
    groupName.includes(normalizedQuery) ||
    department.includes(normalizedQuery) ||
    adminName.includes(normalizedQuery) ||
    recentMessage.includes(normalizedQuery)
  );
}

export function buildManagedGroupSummary(groupId: string, groupData: Record<string, any>) {
  const storedMemberCount = Number(groupData.memberCount);
  const membersCount =
    Number.isFinite(storedMemberCount) && storedMemberCount >= 0
      ? storedMemberCount
      : 0;
  const adminIds = Array.isArray(groupData.adminIds)
    ? groupData.adminIds.map((id: any) => String(id).trim())
    : [];

  return {
    groupId,
    groupName: String(groupData.groupName ?? ""),
    groupIcon: String(groupData.groupIcon ?? ""),
    groupIconPath: String(groupData.groupIconPath ?? ""),
    department: String(groupData.department ?? ""),
    audience: resolveGroupAudience(groupData),
    writePermission: String(groupData.writePermission ?? "all"),
    isActive: groupData.isActive === true,
    membersCount,
    adminUid: String(groupData.adminId ?? ""),
    adminName: String(groupData.adminName ?? ""),
    adminIds: adminIds.length > 0 ? adminIds : [String(groupData.adminId ?? "").trim()],
    recentMessage: String(groupData.recentMessage ?? ""),
    recentMessageEn: String(groupData.recentMessageEn ?? groupData.recentMessage ?? ""),
    recentMessageSender: String(groupData.recentMessageSender ?? ""),
    recentMessageTime: Number(groupData.recentMessageTime ?? 0) || 0,
  };
}



export async function loadUsersByIds(uids: string[]) {
  const uniqueUids = Array.from(
    new Set(uids.map((uid) => uid.trim()).filter((uid) => uid.length > 0))
  );
  const users: Array<{ uid: string; data: Record<string, any> }> = [];
  const db = admin.firestore();

  for (const uidChunk of chunkArray(uniqueUids, 300)) {
    const refs = uidChunk.map((uid) => db.collection("users").doc(uid));
    const docs = await db.getAll(...refs);

    for (const doc of docs) {
      if (doc.exists) {
        users.push({ uid: doc.id, data: doc.data() || {} });
      }
    }
  }

  return users;
}

export async function addGroupMembershipValueForUsers({
  memberUids,
  groupId,
}: {
  memberUids: string[];
  groupId: string;
}) {
  for (const uidChunk of chunkArray(Array.from(new Set(memberUids)), 300)) {
    const batch = admin.firestore().batch();

    for (const uid of uidChunk) {
      batch.set(
        admin.firestore().collection("users").doc(uid),
        {
          groupIds: admin.firestore.FieldValue.arrayUnion(groupId),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
    }

    await batch.commit();
  }
}

export async function removeGroupMembershipValueForUsers({
  memberUids,
  groupId,
}: {
  memberUids: string[];
  groupId: string;
}) {
  for (const uidChunk of chunkArray(Array.from(new Set(memberUids)), 300)) {
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
    }

    await batch.commit();
  }
}

export async function deleteVotesSubcollection(groupId: string, messageId: string) {
  const votesRef = admin
    .firestore()
    .collection("groups")
    .doc(groupId)
    .collection("messages")
    .doc(messageId)
    .collection("votes");

  while (true) {
    const snap = await votesRef.limit(400).get();
    if (snap.empty) break;

    const batch = admin.firestore().batch();
    for (const doc of snap.docs) {
      batch.delete(doc.ref);
    }

    await batch.commit();

    if (snap.size < 400) break;
  }
}

export async function deleteStorageObjectIfExists(
  storagePath: unknown,
  options: StorageDeleteOptions
) {
  await deleteStorageObjectIfAllowed(storagePath, options);
}
