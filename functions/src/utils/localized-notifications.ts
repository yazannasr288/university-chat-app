export type SupportedLanguageCode = "ar" | "en";

export interface LocalizedText {
  ar: string;
  en: string;
}

export function normalizeLanguageCode(value: unknown): SupportedLanguageCode {
  const clean = String(value ?? "").trim().toLowerCase();
  return clean.startsWith("en") ? "en" : "ar";
}

export function localizedText(text: LocalizedText, languageCode: unknown): string {
  return text[normalizeLanguageCode(languageCode)];
}

export function chatMessagePreview(type: unknown, message: unknown): LocalizedText {
  const cleanType = String(type ?? "text").trim();
  const cleanMessage = String(message ?? "").trim();

  switch (cleanType) {
  case "text":
    return {
      ar: cleanMessage || "رسالة جديدة",
      en: cleanMessage || "New message",
    };
  case "image":
    return { ar: "📷 صورة", en: "📷 Image" };
  case "video":
    return { ar: "🎥 فيديو", en: "🎥 Video" };
  case "audio":
    return { ar: "🎤 رسالة صوتية", en: "🎤 Voice message" };
  case "file":
    return { ar: "📎 ملف", en: "📎 File" };
  case "poll":
    return { ar: "📊 استبيان جديد", en: "📊 New poll" };
  case "event":
    return {
      ar: `📅 ${cleanMessage || "حدث جديد"}`,
      en: `📅 ${cleanMessage || "New event"}`,
    };
  default:
    return { ar: "رسالة جديدة", en: "New message" };
  }
}

export function loginAttemptNotification(languageCode: unknown): { title: string; body: string } {
  return {
    title: localizedText(
      {
        ar: "هناك محاولة تسجيل من جهاز آخر",
        en: "New sign-in attempt from another device",
      },
      languageCode
    ),
    body: localizedText(
      {
        ar: "إذا لم تكن أنت، أبلغ الإدارة",
        en: "If this was not you, notify administration",
      },
      languageCode
    ),
  };
}
