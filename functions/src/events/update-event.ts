import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";
import { upsertEventFeed } from "../services/event-feed.service";
import type { EventScopeType } from "../types/event-types";
import {
	assertSignedIn,
	canCallerManageEvent,
	getCallerData,
	getEventOrThrow,
} from "../services/event-access.service";
import { notifyEventAudience } from "../services/event-notification.service";
import {
	findNextEventReminderAt,
	formatEventDate,
} from "../utils/event-helpers";
import { writeDashboardAuditLog } from "../services/dashboard-audit.service";
import { assertEventTextLimits } from "../utils/event-validation";
import { fastMediumCallableOptions } from "../runtime-options";

export const updateEvent = onCall(
	fastMediumCallableOptions,
	async (request) => {
		const deliveryWarnings: string[] = [];
		const callerUid = assertSignedIn(request);
		const callerData = await getCallerData(callerUid);

		const callerRole = String(callerData.role ?? "user");
		const callerDepartment = String(callerData.department ?? "").trim();

		const eventId = String(request.data.eventId ?? "").trim();
		const title = String(request.data.title ?? "").trim();
		const details = String(request.data.details ?? "").trim();
		const location = String(request.data.location ?? "").trim();
		const notes = String(request.data.notes ?? "").trim();
		const eventAt = Number(request.data.eventAt ?? 0);

		if (!eventId) {
			throw new HttpsError("invalid-argument", "eventId مطلوب");
		}

		if (
			!title ||
			!details ||
			!location ||
			!Number.isFinite(eventAt) ||
			eventAt <= 0
		) {
			throw new HttpsError("invalid-argument", "بيانات الحدث غير مكتملة");
		}

		assertEventTextLimits({ title, details, location, notes });

		if (eventAt <= Date.now() + 5 * 60 * 1000) {
			throw new HttpsError(
				"invalid-argument",
				"موعد الحدث يجب أن يكون مستقبليًا",
			);
		}

		const { eventRef, eventData } = await getEventOrThrow(eventId);

		const canManage = await canCallerManageEvent({
			callerUid,
			callerRole,
			callerDepartment,
			eventData,
		});

		if (!canManage) {
			throw new HttpsError(
				"permission-denied",
				"ليس لديك صلاحية تعديل هذا الحدث",
			);
		}

		if (eventData.isCancelled === true) {
			throw new HttpsError(
				"failed-precondition",
				"لا يمكن تعديل حدث تم إلغاؤه",
			);
		}

		const oldEventAt = Number(eventData.eventAt ?? 0);
		const timeChanged = oldEventAt !== eventAt;

		const updates: Record<string, unknown> = {
			title,
			details,
			location,
			notes,
			eventAt,
			updatedAt: admin.firestore.FieldValue.serverTimestamp(),
		};

		if (timeChanged) {
			const reminderBaseAt = admin.firestore.Timestamp.now();
			updates.reminderBaseAt = reminderBaseAt;
			updates.nextReminderAt = findNextEventReminderAt({
				createdAtMs: reminderBaseAt.toMillis(),
				eventAt,
				nowMs: reminderBaseAt.toMillis(),
			});
			updates.halfReminderSentAt = null;
			updates.quarterReminderSentAt = null;
			updates.hourReminderSentAt = null;
			updates.halfReminderProcessingAt = admin.firestore.FieldValue.delete();
			updates.quarterReminderProcessingAt = admin.firestore.FieldValue.delete();
			updates.hourReminderProcessingAt = admin.firestore.FieldValue.delete();
			updates.halfReminderProcessingToken = admin.firestore.FieldValue.delete();
			updates.quarterReminderProcessingToken =
				admin.firestore.FieldValue.delete();
			updates.hourReminderProcessingToken = admin.firestore.FieldValue.delete();
		}

		await eventRef.update(updates);
		const updatedEventData = { ...eventData, ...updates };
		const operationWarnings = await Promise.all([
			upsertEventFeed(eventId, updatedEventData)
				.then(() => "")
				.catch((error) => {
					logger.error("Failed to update event feed", { eventId, error });
					return "event_feed_failed";
				}),
			writeDashboardAuditLog({
				actorUid: callerUid,
				actorRole: callerRole,
				action: "event.updated",
				category: "events",
				level: timeChanged ? "warning" : "info",
				targetType: "event",
				targetId: eventId,
				targetLabel: title,
				summary: `updated event ${title}`,
				details: {
					previousTitle: String(eventData.title ?? ""),
					title,
					previousEventAt: oldEventAt,
					eventAt,
					timeChanged,
					location,
					scopeType: String(eventData.scopeType ?? ""),
					department: String(eventData.department ?? ""),
					targetGroupId: String(eventData.targetGroupId ?? ""),
				},
			})
				.then(() => "")
				.catch((error) => {
					logger.error("Failed to write event update audit log", {
						eventId,
						error,
					});
					return "audit_log_failed";
				}),
			notifyEventAudience({
				eventId,
				title: { ar: `✏️ ${title}`, en: `✏️ ${title}` },
				body: {
					ar: `تم تعديل الحدث - ${formatEventDate(eventAt)}`,
					en: `The event was updated - ${formatEventDate(eventAt)}`,
				},
				scopeType: String(eventData.scopeType ?? "") as EventScopeType,
				department: String(eventData.department ?? ""),
				targetGroupId: String(eventData.targetGroupId ?? ""),
				dataType: "event_updated",
			})
				.then(() => "")
				.catch((error) => {
					logger.error("Failed to notify event update audience", {
						eventId,
						scopeType: String(eventData.scopeType ?? ""),
						targetGroupId: String(eventData.targetGroupId ?? ""),
						error,
					});
					return "notification_failed";
				}),
		]);
		deliveryWarnings.push(...operationWarnings.filter(Boolean));

		if (deliveryWarnings.length > 0) {
			await eventRef.set(
				{
					deliveryWarnings,
					deliveryWarningAt: admin.firestore.FieldValue.serverTimestamp(),
				},
				{ merge: true },
			);
		}

		return {
			success: true,
			deliveryWarnings,
		};
	},
);
