import { onDocumentDeleted } from "firebase-functions/v2/firestore";
import { removeUserFromAllGroupsAndCleanup } from "../services/group-membership.service";


export const cleanupDeletedUserMemberships = onDocumentDeleted(
  "users/{uid}",
  async (event) => {
    const uid = String(event.params.uid ?? "").trim();
    if (!uid) return;

    await removeUserFromAllGroupsAndCleanup({
      uid,
      updatedBy: "firestore-delete-trigger",
      updateUserDocument: false,
    });
  }
);

export { cleanupOldProfileImage } from "./users/cleanup-old-profile-image";
