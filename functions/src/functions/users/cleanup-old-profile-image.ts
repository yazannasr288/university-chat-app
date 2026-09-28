import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import { assertActiveUserData } from "../../services/account-status.service";
import {
  deleteUserStorageObjectIfAllowed,
  isStoragePathAllowedForUser,
  normalizeStoragePath,
  PROFILE_IMAGE_STORAGE_ROOTS,
} from "../../utils/storage-path";

export const cleanupOldProfileImage = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "يجب تسجيل الدخول");
  }

  const uid = request.auth.uid;
  const storagePath = normalizeStoragePath(request.data.storagePath);

  if (!storagePath) {
    throw new HttpsError("invalid-argument", "مسار الصورة مطلوب");
  }

  if (
    !isStoragePathAllowedForUser(storagePath, {
      uid,
      allowedRoots: PROFILE_IMAGE_STORAGE_ROOTS,
      reason: "cleanup old profile image",
    })
  ) {
    throw new HttpsError("invalid-argument", "مسار الصورة غير صالح");
  }

  const userDoc = await admin.firestore().collection("users").doc(uid).get();
  if (!userDoc.exists) {
    throw new HttpsError("permission-denied", "المستخدم غير موجود");
  }

  const userData = userDoc.data() || {};
  assertActiveUserData(userData);

  const currentProfilePic = normalizeStoragePath(userData.profilepic);
  if (currentProfilePic === storagePath) {
    return { success: true, skipped: true, reason: "linked" };
  }

  await deleteUserStorageObjectIfAllowed(storagePath, {
    uid,
    allowedRoots: PROFILE_IMAGE_STORAGE_ROOTS,
    reason: "cleanup old profile image",
  });

  return { success: true };
});
