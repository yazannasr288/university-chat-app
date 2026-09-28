import { HttpsError } from "firebase-functions/v2/https";

export const USER_FIELD_LIMITS = {
  fullName: 80,
  userId: 40,
  phone: 25,
  department: 80,
  password: 128,
  accountType: 40,
  accountStatusReason: 300,
} as const;

export const INPUT_FIELD_LIMITS = {
  sessionId: 120,
  deviceId: 120,
  deviceName: 120,
  fcmToken: 4096,
  notificationTitle: 120,
  notificationBody: 1000,
  sourceFileName: 180,
} as const;

/**
 * Asserts that a string value does not exceed a maximum length.
 */
export function assertMaxLength(value: string, max: number, message: string) {
  if (value.length > max) {
    throw new HttpsError("invalid-argument", message);
  }
}

/**
 * Asserts that user profile fields do not exceed their defined limits.
 */
export function assertUserProfileFieldLimits({
  fullName,
  userId,
  phone,
  department,
  accountType,
  password,
  accountStatusReason,
}: {
  fullName: string;
  userId: string;
  phone: string;
  department: string;
  accountType: string;
  password?: string;
  accountStatusReason?: string;
}) {
  if (fullName.length > USER_FIELD_LIMITS.fullName) {
    throw new HttpsError("invalid-argument", "الاسم طويل جدًا");
  }

  if (userId.length > USER_FIELD_LIMITS.userId) {
    throw new HttpsError("invalid-argument", "الرقم الجامعي طويل جدًا");
  }

  if (phone.length > USER_FIELD_LIMITS.phone) {
    throw new HttpsError("invalid-argument", "رقم الهاتف طويل جدًا");
  }

  if (department.length > USER_FIELD_LIMITS.department) {
    throw new HttpsError("invalid-argument", "القسم طويل جدًا");
  }

  if (accountType.length > USER_FIELD_LIMITS.accountType) {
    throw new HttpsError("invalid-argument", "نوع الحساب طويل جدًا");
  }

  if (password != null && password.length > USER_FIELD_LIMITS.password) {
    throw new HttpsError("invalid-argument", "كلمة المرور طويلة جدًا");
  }

  if (
    accountStatusReason != null &&
    accountStatusReason.length > USER_FIELD_LIMITS.accountStatusReason
  ) {
    throw new HttpsError("invalid-argument", "سبب حالة الحساب طويل جدًا");
  }
}
