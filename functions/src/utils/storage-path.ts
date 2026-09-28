import * as admin from "firebase-admin";

export const CHAT_IMAGE_STORAGE_ROOT = "chat_images";
export const CHAT_VIDEO_STORAGE_ROOT = "chat_videos";
export const CHAT_VIDEO_THUMBNAIL_STORAGE_ROOT = "chat_video_thumbnails";
export const CHAT_AUDIO_STORAGE_ROOT = "chat_audio";
export const CHAT_FILE_STORAGE_ROOT = "files";
export const GROUP_ICON_STORAGE_ROOT = "group_icons";
export const PROFILE_IMAGE_STORAGE_ROOT = "profile_images";

export const MESSAGE_ATTACHMENT_STORAGE_ROOTS = [
  CHAT_IMAGE_STORAGE_ROOT,
  CHAT_VIDEO_STORAGE_ROOT,
  CHAT_AUDIO_STORAGE_ROOT,
  CHAT_FILE_STORAGE_ROOT,
] as const;

export const VIDEO_THUMBNAIL_STORAGE_ROOTS = [
  CHAT_VIDEO_THUMBNAIL_STORAGE_ROOT,
] as const;

export const GROUP_ICON_STORAGE_ROOTS = [GROUP_ICON_STORAGE_ROOT] as const;
export const PROFILE_IMAGE_STORAGE_ROOTS = [PROFILE_IMAGE_STORAGE_ROOT] as const;


export interface StorageDeleteOptions {
  groupId: string;
  allowedRoots: readonly string[];
  reason?: string;
}

export interface UserStorageDeleteOptions {
  uid: string;
  allowedRoots: readonly string[];
  reason?: string;
}

/**
 * Normalizes a Firebase Storage object path before validation.
 *
 * @param {unknown} storagePath User or document supplied storage path.
 * @return {string} Trimmed path without a leading slash.
 */
export function normalizeStoragePath(storagePath: unknown): string {
  return String(storagePath ?? "")
    .trim()
    .replace(/^\/+/, "");
}

/**
 * Returns the only Storage roots that may contain a message attachment.
 *
 * @param {Record<string, unknown>} messageData Firestore message data.
 * @return {string[]} Allowed Storage roots for this message type.
 */
export function allowedStorageRootsForMessage(
  messageData: Record<string, unknown>
): readonly string[] {
  switch (String(messageData.type ?? "").trim()) {
  case "image":
    return [CHAT_IMAGE_STORAGE_ROOT];
  case "video":
    return [CHAT_VIDEO_STORAGE_ROOT];
  case "audio":
    return [CHAT_AUDIO_STORAGE_ROOT];
  case "file":
    return [CHAT_FILE_STORAGE_ROOT];
  default:
    // Legacy safety: if old data is missing `type`, deletion is still limited
    // to known attachment roots for the same group.
    return MESSAGE_ATTACHMENT_STORAGE_ROOTS;
  }
}

/**
 * Checks whether a Storage path belongs to the expected group namespace.
 *
 * @param {unknown} storagePath Storage object path to validate.
 * @param {StorageDeleteOptions} options Group and root constraints.
 * @return {boolean} Whether the path is safe to delete.
 */
export function isStoragePathAllowedForGroup(
  storagePath: unknown,
  options: StorageDeleteOptions
): boolean {
  const path = normalizeStoragePath(storagePath);
  const groupId = String(options.groupId ?? "").trim();

  if (!path || !groupId || path.includes("..")) {
    return false;
  }

  return options.allowedRoots.some((root) => {
    const prefix = `${root}/${groupId}/`;
    if (!path.startsWith(prefix)) return false;

    const objectName = path.slice(prefix.length);
    return objectName.length > 0 && !objectName.includes("/");
  });
}

/**
 * Deletes a Storage object only when it is scoped to the provided group.
 *
 * @param {unknown} storagePath Storage object path to delete.
 * @param {StorageDeleteOptions} options Group and root constraints.
 */
export async function deleteStorageObjectIfAllowed(
  storagePath: unknown,
  options: StorageDeleteOptions
): Promise<void> {
  const path = normalizeStoragePath(storagePath);
  if (!path) return;

  if (!isStoragePathAllowedForGroup(path, options)) {
    console.warn("Blocked unsafe Storage deletion", {
      path,
      groupId: options.groupId,
      allowedRoots: options.allowedRoots,
      reason: options.reason ?? "unspecified",
    });
    return;
  }

  await admin
    .storage()
    .bucket()
    .file(path)
    .delete()
    .catch((error) => {
      console.warn("Storage object deletion skipped or failed", {
        path,
        reason: options.reason ?? "unspecified",
        message: error instanceof Error ? error.message : String(error),
      });
    });
}


/**
 * Checks whether a Storage path belongs to the expected user namespace.
 *
 * @param {unknown} storagePath Storage object path to validate.
 * @param {UserStorageDeleteOptions} options User and root constraints.
 * @return {boolean} Whether the path is safe to delete.
 */
export function isStoragePathAllowedForUser(
  storagePath: unknown,
  options: UserStorageDeleteOptions
): boolean {
  const path = normalizeStoragePath(storagePath);
  const uid = String(options.uid ?? "").trim();

  if (!path || !uid || path.includes("..")) {
    return false;
  }

  return options.allowedRoots.some((root) => {
    const prefix = `${root}/${uid}/`;
    if (!path.startsWith(prefix)) return false;

    const objectName = path.slice(prefix.length);
    return objectName.length > 0 && !objectName.includes("/");
  });
}

/**
 * Deletes a Storage object only when it is scoped to the provided user.
 *
 * @param {unknown} storagePath Storage object path to delete.
 * @param {UserStorageDeleteOptions} options User and root constraints.
 */
export async function deleteUserStorageObjectIfAllowed(
  storagePath: unknown,
  options: UserStorageDeleteOptions
): Promise<void> {
  const path = normalizeStoragePath(storagePath);
  if (!path) return;

  if (!isStoragePathAllowedForUser(path, options)) {
    console.warn("Blocked unsafe user Storage deletion", {
      path,
      uid: options.uid,
      allowedRoots: options.allowedRoots,
      reason: options.reason ?? "unspecified",
    });
    return;
  }

  await admin
    .storage()
    .bucket()
    .file(path)
    .delete()
    .catch((error) => {
      console.warn("User Storage object deletion skipped or failed", {
        path,
        reason: options.reason ?? "unspecified",
        message: error instanceof Error ? error.message : String(error),
      });
    });
}
