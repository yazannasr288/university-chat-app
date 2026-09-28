import { HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import { CallerManageEventArgs } from "../types/event-types";
import { assertActiveUserData } from "./account-status.service";

export function assertSignedIn(request: any): string {
  if (!request.auth) throw new HttpsError("unauthenticated", "يجب تسجيل الدخول");
  return request.auth.uid;
}

export async function getCallerData(uid: string) {
  const callerDoc = await admin.firestore().collection("users").doc(uid).get();

  if (!callerDoc.exists) {
    throw new HttpsError("permission-denied", "المستخدم غير موجود");
  }

  const data = callerDoc.data() || {};
  assertActiveUserData(data);
  return data;
}

export async function getEventOrThrow(eventId: string) {
  const eventRef = admin.firestore().collection("events").doc(eventId);
  const eventDoc = await eventRef.get();

  if (!eventDoc.exists) throw new HttpsError("not-found", "الحدث غير موجود");

  return { eventRef, eventData: eventDoc.data() || {} };
}

function userGroupIds(userData: Record<string, any>) {
  return Array.isArray(userData.groupIds)
    ? userData.groupIds.map((e: any) => String(e)).filter(Boolean)
    : [];
}

export function isEventVisibleToUser(
  eventData: Record<string, any>,
  userData: Record<string, any>
) {
  const scopeType = String(eventData.scopeType ?? "university");

  if (scopeType === "university" || scopeType === "all") return true;

  if (scopeType === "department") {
    const eventDepartment = String(eventData.department ?? eventData.targetDepartment ?? "");
    return eventDepartment === String(userData.department ?? "");
  }

  if (scopeType === "group") {
    return userGroupIds(userData).includes(String(eventData.targetGroupId ?? ""));
  }

  return false;
}

export async function canCallerManageEvent({
  callerUid,
  callerRole,
  callerDepartment,
  eventData,
}: CallerManageEventArgs) {
  if (callerRole === "admin0") return true;

  const scopeType = String(eventData.scopeType ?? "");
  const targetGroupId = String(eventData.targetGroupId ?? "");
  const department = String(eventData.department ?? eventData.targetDepartment ?? "");

  if (scopeType === "department") {
    return ["admin1", "admin2"].includes(callerRole) && !!callerDepartment && department === callerDepartment;
  }

  if (scopeType === "group" && targetGroupId) {
    const groupDoc = await admin.firestore().collection("groups").doc(targetGroupId).get();
    if (!groupDoc.exists) return false;

    const groupData = groupDoc.data() || {};
    const groupDepartment = String(groupData.department ?? "");
    const adminId = String(groupData.adminId ?? "").trim();
    const adminIds = Array.isArray(groupData.adminIds)
      ? groupData.adminIds.map((id: any) => String(id).trim()).filter(Boolean)
      : [];

    if (callerRole === "admin1") return !!callerDepartment && groupDepartment === callerDepartment;
    if (callerRole === "admin2") return adminId === callerUid || adminIds.includes(callerUid);
  }

  return false;
}
