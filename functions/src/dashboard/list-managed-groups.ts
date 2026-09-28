import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import {
  assertAdminRoleOrThrow,
  buildManagedGroupSummary,
  canManageGroup,
  matchesGroupSearch,
  normalizeSearch,
} from "../services/dashboard-user.service";

function applyGroupStatusFilter(
  ref: FirebaseFirestore.Query,
  groupStatus: string
) {
  if (groupStatus === "active") {
    return ref.where("isActive", "==", true);
  }

  if (groupStatus === "archived") {
    return ref.where("isActive", "==", false);
  }

  return ref;
}

export const listManagedGroups = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "يجب تسجيل الدخول");
  }

  const callerData = await assertAdminRoleOrThrow(request.auth.uid, [
    "admin0",
    "admin1",
    "admin2",
  ]);

  const callerRole = String(callerData.role ?? "user");
  const callerDepartment = String(callerData.department ?? "").trim();
  const query = String(request.data.query ?? "");
  const requestedDepartment = String(request.data.department ?? "").trim();
  const groupStatus = String(request.data.groupStatus ?? "all").trim();

  const snapshots: FirebaseFirestore.QuerySnapshot[] = [];

  if (callerRole === "admin2") {
    const primaryAdminRef = applyGroupStatusFilter(
      admin
        .firestore()
        .collection("groups")
        .where("adminId", "==", request.auth.uid),
      groupStatus
    );

    const secondaryAdminRef = applyGroupStatusFilter(
      admin
        .firestore()
        .collection("groups")
        .where("adminIds", "array-contains", request.auth.uid),
      groupStatus
    );

    const [primarySnapshot, secondarySnapshot] = await Promise.all([
      primaryAdminRef.get(),
      secondaryAdminRef.get(),
    ]);

    snapshots.push(primarySnapshot, secondarySnapshot);
  } else {
    let ref: FirebaseFirestore.Query = admin.firestore().collection("groups");

    if (callerRole === "admin0") {
      if (requestedDepartment) {
        ref = ref.where("department", "==", requestedDepartment);
      }
    } else if (callerRole === "admin1") {
      if (!callerDepartment) {
        return {
          success: true,
          groups: [],
        };
      }

      ref = ref.where("department", "==", callerDepartment);
    }

    snapshots.push(await applyGroupStatusFilter(ref, groupStatus).get());
  }

  const normalizedQuery = normalizeSearch(query);
  const groupDocsById = new Map<string, Record<string, unknown>>();

  for (const snapshot of snapshots) {
    for (const doc of snapshot.docs) {
      groupDocsById.set(doc.id, doc.data() || {});
    }
  }

  const groups = Array.from(groupDocsById.entries())
    .map(([id, data]) => ({ id, data }))
    .filter(({ data }) =>
      canManageGroup(data, request.auth!.uid, callerRole, callerDepartment)
    )
    .filter(({ data }) => matchesGroupSearch(data, normalizedQuery))
    .map(({ id, data }) => buildManagedGroupSummary(id, data))
    .sort((a, b) => a.groupName.localeCompare(b.groupName, "ar"));

  return {
    success: true,
    groups,
  };
});
