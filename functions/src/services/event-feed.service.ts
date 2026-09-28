import * as admin from "firebase-admin";

function eventFeedData(eventId: string, data: Record<string, any>) {
  return {
    eventId,
    scopeType: String(data.scopeType ?? ""),
    title: String(data.title ?? ""),
    details: String(data.details ?? ""),
    location: String(data.location ?? ""),
    notes: String(data.notes ?? ""),
    eventAt: Number(data.eventAt ?? 0) || 0,
    department: String(data.department ?? ""),
    targetGroupId: String(data.targetGroupId ?? ""),
    targetGroupName: String(data.targetGroupName ?? ""),
    interestedCount: Number(data.interestedCount ?? 0) || 0,
    isCancelled: data.isCancelled === true,
    createdBy: String(data.createdBy ?? ""),
    createdByName: String(data.createdByName ?? ""),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };
}

export function eventFeedRef(data: Record<string, any>, eventId: string) {
  const db = admin.firestore();
  const scopeType = String(data.scopeType ?? "");

  if (scopeType === "university" || scopeType === "all") {
    return db
      .collection("eventFeeds")
      .doc("university")
      .collection("events")
      .doc(eventId);
  }

  if (scopeType === "department") {
    const department = String(data.department ?? "").trim();

    return db
      .collection("eventFeeds")
      .doc("departments")
      .collection(department)
      .doc("feed")
      .collection("events")
      .doc(eventId);
  }

  const groupId = String(data.targetGroupId ?? "").trim();

  return db
    .collection("eventFeeds")
    .doc("groups")
    .collection(groupId)
    .doc("feed")
    .collection("events")
    .doc(eventId);
}

export async function upsertEventFeed(eventId: string, data: Record<string, any>) {
  const ref = eventFeedRef(data, eventId);

  await ref.set(eventFeedData(eventId, data), { merge: true });
}

export async function markEventFeedCancelled(eventId: string, data: Record<string, any>) {
  const ref = eventFeedRef(data, eventId);

  await ref.set(
    {
      ...eventFeedData(eventId, data),
      isCancelled: true,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );
}