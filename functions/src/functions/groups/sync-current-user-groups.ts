import { onCall } from "firebase-functions/v2/https";
import {
  assertSignedIn,
  getCallerData,
} from "../../services/group-chat.service";
import { syncUserGroupMembershipAfterProfileUpdate } from "../../services/group-membership.service";
import { fastMediumCallableOptions } from "../../runtime-options";
import { canUserAccessGroup } from "../../services/group-access.service";
import {
  isIndexedGroupMember,
  loadGroupDocumentsForUser,
} from "../../services/group-member-index.service";

export const syncCurrentUserGroups = onCall(
  fastMediumCallableOptions,
  async (request) => {
    const callerUid = assertSignedIn(request);
    const callerData = await getCallerData(callerUid);

    const candidateGroups = await loadGroupDocumentsForUser(callerUid);
    const membershipChecks = await Promise.all(
      candidateGroups.map((groupDoc) =>
        isIndexedGroupMember({
          groupRef: groupDoc.ref,
          uid: callerUid,
          groupData: groupDoc.data() || {},
        })
      )
    );
    const currentGroups = candidateGroups.filter(
      (_, index) => membershipChecks[index] === true
    );

    const ineligibleCount = currentGroups.filter(
      (doc) =>
        !canUserAccessGroup({
          groupData: doc.data() || {},
          userData: { ...callerData, isGroupMember: true },
        })
    ).length;

    if (ineligibleCount === 0) {
      return { success: true, removedCount: 0 };
    }

    await syncUserGroupMembershipAfterProfileUpdate({
      uid: callerUid,
      fullName: String(callerData.fullName ?? "").trim(),
      department: String(callerData.department ?? "").trim(),
      accountType: String(callerData.accountType ?? "user").trim() || "user",
    });

    return { success: true, removedCount: ineligibleCount };
  },
);
