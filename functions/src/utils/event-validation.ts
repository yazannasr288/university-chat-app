import { HttpsError } from "firebase-functions/v2/https";

export const EVENT_LIMITS = {
  title: 80,
  details: 1000,
  location: 120,
  notes: 500,
} as const;

export function assertEventTextLimits({
  title,
  details,
  location,
  notes,
}: {
  title: string;
  details: string;
  location: string;
  notes: string;
}) {
  if (title.length > EVENT_LIMITS.title) {
    throw new HttpsError("invalid-argument", "اسم الحدث طويل جدًا");
  }

  if (details.length > EVENT_LIMITS.details) {
    throw new HttpsError("invalid-argument", "تفاصيل الحدث طويلة جدًا");
  }

  if (location.length > EVENT_LIMITS.location) {
    throw new HttpsError("invalid-argument", "مكان الحدث طويل جدًا");
  }

  if (notes.length > EVENT_LIMITS.notes) {
    throw new HttpsError("invalid-argument", "الملاحظات طويلة جدًا");
  }
}
