import { HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import { clearUserSessions } from "./dashboard-user.service";
import { writeDashboardAuditLog } from "./dashboard-audit.service";

export type ManagedAccountStatus = "active" | "suspended" | "removed";

export function normalizeManagedAccountStatus(value: unknown): ManagedAccountStatus {
  const raw = String(value ?? "")
    .trim()
    .toLowerCase();

  if (
    raw === "suspended" ||
    raw === "status_suspended" ||
    raw === "dashboard.status_suspended" ||
    raw === "مجمد" ||
    raw === "مجمّد" ||
    raw === "معلق" ||
    raw === "معلّق"
  ) {
    return "suspended";
  }

  if (
    raw === "removed" ||
    raw === "status_removed" ||
    raw === "dashboard.status_removed" ||
    raw === "مزال" ||
    raw === "محذوف"
  ) {
    return "removed";
  }

  return "active";
}

export function defaultAccountStatusReason(status: ManagedAccountStatus) {
  switch (status) {
    case "suspended":
      return "تم تجميد حسابك من قبل الإدارة، يرجى مراجعة المسؤول";
    case "removed":
      return "تمت إزالة حسابك من النظام";
    default:
      return "";
  }
}

function auditActionForStatus(status: ManagedAccountStatus) {
  switch (status) {
    case "suspended":
      return "user.suspended";
    case "removed":
      return "user.removed";
    default:
      return "user.unsuspended";
  }
}

function auditLevelForStatus(status: ManagedAccountStatus) {
  switch (status) {
    case "removed":
      return "critical";
    case "suspended":
      return "warning";
    default:
      return "warning";
  }
}

function auditSummaryForStatus(status: ManagedAccountStatus, label: string) {
  switch (status) {
    case "suspended":
      return `suspended account ${label}`;
    case "removed":
      return `removed account ${label}`;
    default:
      return `reactivated account ${label}`;
  }
}

/**
 * مصدر الحقيقة الوحيد لتغيير حالة حساب المستخدم.
 */
export async function applyManagedUserStatusTransition({
  userRef,
  targetUid,
  userData,
  callerUid,
  callerData,
  nextStatus,
  reason,
  auditDetails = {},
}: {
  userRef: FirebaseFirestore.DocumentReference;
  targetUid: string;
  userData: Record<string, any>;
  callerUid: string;
  callerData: Record<string, any>;
  nextStatus: ManagedAccountStatus;
  reason?: string;
  auditDetails?: Record<string, any>;
}) {
  const targetRole = String(userData.role ?? "user");

  // Restriction: Cannot change status of Admin0
  if (targetRole === "admin0") {
    throw new HttpsError("failed-precondition", "لا يمكن تغيير حالة حساب مدير النظام");
  }

  const previousStatus = normalizeManagedAccountStatus(userData.accountStatus);

  if (nextStatus === "removed") {
    throw new HttpsError(
      "failed-precondition",
      "يجب استخدام الحذف النهائي لحذف حساب الطالب",
    );
  }

  if (previousStatus === "removed") {
    throw new HttpsError(
      "failed-precondition",
      "الحساب المحذوف نهائيًا لا يمكن استعادته أو تغيير حالته",
    );
  }

  const nextReason = String(reason ?? "").trim() || defaultAccountStatusReason(nextStatus);
  const now = admin.firestore.FieldValue.serverTimestamp();

  const updatePayload: Record<string, any> = {
    accountStatus: nextStatus,
    accountStatusReason: nextReason,
    statusUpdatedAt: now,
    statusUpdatedBy: callerUid,
  };

  if (nextStatus === "suspended") {
    updatePayload.suspendedAt = now;
    updatePayload.removedAt = null;
  } else {
    updatePayload.accountStatusReason = "";
    updatePayload.removedAt = null;
    updatePayload.suspendedAt = null;
  }

  await userRef.set(updatePayload, { merge: true });

  if (nextStatus === "suspended") {
    await clearUserSessions(userRef);
  }

  await admin
    .auth()
    .updateUser(targetUid, { disabled: false })
    .catch(() => {});

  const updatedUser = (await userRef.get()).data() || {};
  const targetLabel = String(updatedUser.fullName ?? userData.fullName ?? "");

  if (previousStatus !== nextStatus) {
    await writeDashboardAuditLog({
      actorUid: callerUid,
      actorRole: String(callerData.role ?? ""),
      action: auditActionForStatus(nextStatus),
      level: auditLevelForStatus(nextStatus),
      targetType: "user",
      targetId: targetUid,
      targetLabel,
      summary: auditSummaryForStatus(nextStatus, targetLabel),
      details: {
        previousStatus,
        nextStatus,
        ...auditDetails,
      },
    });
  }

  return updatedUser;
}
