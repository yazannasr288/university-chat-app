import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";
import { markEventFeedCancelled } from "../services/event-feed.service";
import type { EventScopeType } from "../types/event-types";
import {
	assertSignedIn,
	canCallerManageEvent,
	getCallerData,
	getEventOrThrow,
} from "../services/event-access.service";
import { notifyEventAudience } from "../services/event-notification.service";
import { fastMediumCallableOptions } from "../runtime-options";
import { writeDashboardAuditLog } from "../services/dashboard-audit.service";

export const cancelEvent = onCall(
	fastMediumCallableOptions,
	async (request) => {
		const deliveryWarnings: string[] = [];
		const callerUid = assertSignedIn(request);
		const callerData = await getCallerData(callerUid);

		const callerRole = String(callerData.role ?? "user");
		const callerDepartment = String(callerData.department ?? "").trim();
		const callerFullName = String(callerData.fullName ?? "").trim();
		const eventId = String(request.data.eventId ?? "").trim();

		if (!eventId) {
			throw new HttpsError("invalid-argument", "eventId مطلوب");
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
				"ليس لديك صلاحية إلغاء هذا الحدث",
			);
		}

		if (eventData.isCancelled === true) {
			return { success: true, alreadyCancelled: true };
		}

		const eventAt = Number(eventData.eventAt ?? 0);

		if (!Number.isFinite(eventAt) || eventAt <= Date.now()) {
			throw new HttpsError(
				"failed-precondition",
				"لا يمكن إلغاء حدث انتهى موعده",
			);
		}

		const title = String(eventData.title ?? "حدث").trim() || "حدث";
		const cancellationUpdates = {
			isCancelled: true,
			nextReminderAt: null,
			halfReminderProcessingAt: admin.firestore.FieldValue.delete(),
			quarterReminderProcessingAt: admin.firestore.FieldValue.delete(),
			hourReminderProcessingAt: admin.firestore.FieldValue.delete(),
			halfReminderProcessingToken: admin.firestore.FieldValue.delete(),
			quarterReminderProcessingToken: admin.firestore.FieldValue.delete(),
			hourReminderProcessingToken: admin.firestore.FieldValue.delete(),
			cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
			cancelledBy: callerUid,
			cancelledByName: callerFullName,
			updatedAt: admin.firestore.FieldValue.serverTimestamp(),
		};
		await eventRef.update(cancellationUpdates);

		const cancelledEventData = { ...eventData, ...cancellationUpdates };
		const operationWarnings = await Promise.all([
			markEventFeedCancelled(eventId, cancelledEventData)
				.then(() => "")
				.catch((error) => {
					logger.error("Failed to cancel event feed entry", { eventId, error });
					return "event_feed_failed";
				}),
			writeDashboardAuditLog({
				actorUid: callerUid,
				actorRole: callerRole,
				action: "event.cancelled",
				category: "events",
				level: "warning",
				targetType: "event",
				targetId: eventId,
				targetLabel: title,
				summary: `cancelled event ${title}`,
				details: {
					eventAt,
					scopeType: String(eventData.scopeType ?? ""),
					department: String(eventData.department ?? ""),
					targetGroupId: String(eventData.targetGroupId ?? ""),
				},
			})
				.then(() => "")
				.catch((error) => {
					logger.error("Failed to write event cancellation audit log", {
						eventId,
						error,
					});
					return "audit_log_failed";
				}),
			notifyEventAudience({
				eventId,
				title: { ar: `🚫 ${title}`, en: `🚫 ${title}` },
				body: {
					ar: "تم إلغاء هذا الحدث",
					en: "This event has been cancelled",
				},
				scopeType: String(eventData.scopeType ?? "") as EventScopeType,
				department: String(eventData.department ?? ""),
				targetGroupId: String(eventData.targetGroupId ?? ""),
				dataType: "event_cancelled",
			})
				.then(() => "")
				.catch((error) => {
					logger.error("Failed to notify event cancellation audience", {
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

		return { success: true, deliveryWarnings };
	},
);
