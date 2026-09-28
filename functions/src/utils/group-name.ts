import * as admin from "firebase-admin";

const GROUP_NAME_LOCKS_COLLECTION = "groupNameLocks";

export function normalizeGroupName(value: unknown): string {
  return String(value ?? "")
    .trim()
    .replace(/\s+/g, " ")
    .toLocaleLowerCase("ar");
}

export function groupNameLockId(normalizedName: string): string {
  return encodeURIComponent(normalizedName)
    .replace(/\./g, "%2E")
    .replace(/~/g, "%7E");
}

export function groupNameLockRef(normalizedName: string) {
  return admin
    .firestore()
    .collection(GROUP_NAME_LOCKS_COLLECTION)
    .doc(groupNameLockId(normalizedName));
}