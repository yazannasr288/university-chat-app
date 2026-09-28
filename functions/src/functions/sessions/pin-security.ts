import { HttpsError } from "firebase-functions/v2/https";
import * as crypto from "crypto";
import { fastCallableOptions } from "../../runtime-options";
import { PIN_PEPPER } from "../../config/runtime-secrets";

export const MAX_PIN_ATTEMPTS = 3;
export const PIN_LOCK_MS = 15 * 60 * 1000;

export const pinCallableOptions = {
  ...fastCallableOptions,
  secrets: [PIN_PEPPER],
};

export function hashPinOnServer(uid: string, pin: string) {
  const pepper = PIN_PEPPER.value();

  if (!pepper) {
    throw new HttpsError("failed-precondition", "PIN_PEPPER غير مضبوط");
  }

  return crypto.createHmac("sha256", pepper).update(`${uid}:${pin}`).digest("hex");
}

export function assertValidPin(pin: string) {
  if (!/^\d{4}$/.test(pin)) {
    throw new HttpsError("invalid-argument", "رمز PIN يجب أن يكون 4 أرقام");
  }
}
