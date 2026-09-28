import { onCall } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";

function cleanString(value: unknown, maxLength: number): string {
  const clean = String(value ?? "").trim();
  return clean.length <= maxLength ? clean : clean.slice(0, maxLength);
}

export const recordClientError = onCall(async (request) => {
  const data = request.data || {};
  const uid = request.auth?.uid ?? "";

  await admin.firestore().collection("clientErrorLogs").add({
    uid,
    fatal: data.fatal === true,
    context: cleanString(data.context, 120),
    errorType: cleanString(data.errorType, 80),
    message: cleanString(data.message, 500),
    stack: cleanString(data.stack, 3500),
    isDebug: data.isDebug === true,
    platform: cleanString(data.platform || "flutter", 40),
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return { success: true };
});
