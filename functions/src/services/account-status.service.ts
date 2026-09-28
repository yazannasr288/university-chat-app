import { HttpsError } from "firebase-functions/v2/https";

export function normalizeAccountStatus(value: unknown) {
  const status = String(value ?? "active").trim();
  if (status === "suspended") return "suspended";
  if (status === "removed") return "removed";
  return "active";
}

export function assertActiveUserData(userData: Record<string, any>) {
  const status = normalizeAccountStatus(userData.accountStatus);

  if (status === "suspended") {
    throw new HttpsError("permission-denied", "تم تجميد حسابك من قبل الإدارة، يرجى مراجعة المسؤول");
  }

  if (status === "removed") {
    throw new HttpsError("permission-denied", "تمت إزالة حسابك من النظام");
  }
}
