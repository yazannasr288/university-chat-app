import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import { assertAdminRoleOrThrow, normalizeAppRole } from "../services/dashboard-user.service";
import { isEventVisibleToUser } from "../services/event-access.service";
async function countQuery(ref: FirebaseFirestore.Query) {
  const snap = await ref.count().get();
  return snap.data().count;
}
function zeroStats() {
  return {
    totalUsers: 0,
    totalAdmin0: 0,
    totalAdmin1: 0,
    totalAdmin2: 0,
    totalStudents: 0,
    totalActiveGroups: 0,
    totalArchivedGroups: 0,
    totalUpcomingEvents: 0,
    totalSuspendedUsers: 0,
    totalRemovedUsers: 0,
    bulkImportProcessing: 0,
  };
}
export const getDashboardStats = onCall(async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "يجب تسجيل الدخول");
  const callerData = await assertAdminRoleOrThrow(request.auth.uid, ["admin0", "admin1", "admin2"]);
  const db = admin.firestore();
  const now = Date.now();
  const callerRole = normalizeAppRole(callerData.role);
  const callerDepartment = String(callerData.department ?? "").trim();
  if (callerRole !== "admin0" && !callerDepartment) return { success: true, stats: zeroStats() };
  let usersBase: FirebaseFirestore.Query = db.collection("users");
  let groupsBase: FirebaseFirestore.Query = db.collection("groups");
  if (callerRole !== "admin0") {
    usersBase = usersBase.where("department", "==", callerDepartment);
    groupsBase = groupsBase.where("department", "==", callerDepartment);
  }
  const [
    totalUsers,
    totalAdmin0,
    totalAdmin1,
    totalAdmin2,
    totalStudents,
    totalSuspendedUsers,
    totalRemovedUsers,
    totalActiveGroups,
    totalArchivedGroups,
    bulkImportProcessing,
  ] = await Promise.all([
    countQuery(usersBase),
    countQuery(usersBase.where("role", "==", "admin0")),
    countQuery(usersBase.where("role", "==", "admin1")),
    countQuery(usersBase.where("role", "==", "admin2")),
    countQuery(usersBase.where("role", "in", ["user", "student"])),
    countQuery(usersBase.where("accountStatus", "==", "suspended")),
    countQuery(usersBase.where("accountStatus", "==", "removed")),
    countQuery(groupsBase.where("isActive", "==", true)),
    countQuery(groupsBase.where("isActive", "==", false)),
    callerRole === "admin0"
      ? countQuery(db.collection("bulkImports").where("status", "in", ["queued", "processing"]))
      : Promise.resolve(0),
  ]);
  let totalUpcomingEvents = 0;
  if (callerRole === "admin0")
    totalUpcomingEvents = await countQuery(
      db.collection("events").where("isCancelled", "==", false).where("eventAt", ">=", now)
    );
  else {
    const eventsSnap = await db
      .collection("events")
      .where("isCancelled", "==", false)
      .where("eventAt", ">=", now)
      .limit(500)
      .get();
    totalUpcomingEvents = eventsSnap.docs.filter((doc) =>
      isEventVisibleToUser(doc.data() || {}, callerData)
    ).length;
  }
  return {
    success: true,
    stats: {
      totalUsers,
      totalAdmin0,
      totalAdmin1,
      totalAdmin2,
      totalStudents,
      totalActiveGroups,
      totalArchivedGroups,
      totalUpcomingEvents,
      totalSuspendedUsers,
      totalRemovedUsers,
      bulkImportProcessing,
    },
  };
});
