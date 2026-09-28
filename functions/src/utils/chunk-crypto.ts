import { createCipheriv, createDecipheriv, randomBytes } from "crypto";
import { BULK_IMPORT_AES_KEY_B64 } from "../config/runtime-secrets";

function getKeyBuffer(): Buffer {
  const secret = BULK_IMPORT_AES_KEY_B64.value();

  if (!secret) {
    throw new Error("BULK_IMPORT_AES_KEY_B64 is not configured");
  }

  const key = Buffer.from(secret, "base64");

  if (key.length !== 32) {
    throw new Error("BULK_IMPORT_AES_KEY_B64 must decode to exactly 32 bytes");
  }

  return key;
}

export function encryptChunkPayload(value: unknown) {
  const iv = randomBytes(12);
  const cipher = createCipheriv("aes-256-gcm", getKeyBuffer(), iv);

  const plaintext = Buffer.from(JSON.stringify(value), "utf8");
  const ciphertext = Buffer.concat([cipher.update(plaintext), cipher.final()]);
  const authTag = cipher.getAuthTag();

  return {
    ciphertextB64: ciphertext.toString("base64"),
    ivB64: iv.toString("base64"),
    authTagB64: authTag.toString("base64"),
  };
}

export function decryptChunkPayload<T>(
  ciphertextB64: string,
  ivB64: string,
  authTagB64: string
): T {
  const decipher = createDecipheriv("aes-256-gcm", getKeyBuffer(), Buffer.from(ivB64, "base64"));

  decipher.setAuthTag(Buffer.from(authTagB64, "base64"));

  const decrypted = Buffer.concat([
    decipher.update(Buffer.from(ciphertextB64, "base64")),
    decipher.final(),
  ]);

  return JSON.parse(decrypted.toString("utf8")) as T;
}
