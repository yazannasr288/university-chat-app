import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import {
  assertSignedIn,
  getCallerData,
  isEventVisibleToUser,
} from "../services/event-access.service";
import { eventFeedRef } from "../services/event-feed.service";

export const toggleEventInterest = onCall(async (request) => {
  const uid = assertSignedIn(request);
  const userData = await getCallerData(uid);
  const eventId = String(request.data.eventId ?? "").trim();

  if (!eventId) {
    throw new HttpsError("invalid-argument", "eventId مطلوب");
  }

  const db = admin.firestore();
  const eventRef = db.collection("events").doc(eventId);
  const interestRef = eventRef.collection("interestedUsers").doc(uid);
  const userInterestRef = db
    .collection("users")
    .doc(uid)
    .collection("eventInterests")
    .doc(eventId);

  return db.runTransaction(async (tx) => {
    const eventDoc = await tx.get(eventRef);

    if (!eventDoc.exists) {
      throw new HttpsError("not-found", "الحدث غير موجود");
    }

    const eventData = eventDoc.data() || {};
    const eventAt = Number(eventData.eventAt ?? 0);

    if (!isEventVisibleToUser(eventData, userData)) {
      throw new HttpsError("permission-denied", "ليس لديك صلاحية عرض هذا الحدث");
    }

    if (eventData.isCancelled === true || eventAt <= Date.now()) {
      throw new HttpsError("failed-precondition", "لا يمكن التفاعل مع هذا الحدث");
    }

    const feedRef = eventFeedRef(eventData, eventId);
    const interestDoc = await tx.get(interestRef);

    if (interestDoc.exists) {
      tx.delete(interestRef);
      tx.delete(userInterestRef);

      tx.update(eventRef, {
        interestedCount: admin.firestore.FieldValue.increment(-1),
      });

      tx.set(
        feedRef,
        {
          interestedCount: admin.firestore.FieldValue.increment(-1),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );

      return { success: true, interested: false };
    }

    tx.set(interestRef, {
      uid,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    tx.set(userInterestRef, {
      eventId,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    tx.update(eventRef, {
      interestedCount: admin.firestore.FieldValue.increment(1),
    });

    tx.set(
      feedRef,
      {
        interestedCount: admin.firestore.FieldValue.increment(1),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    return { success: true, interested: true };
  });
});