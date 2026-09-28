import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";
import { upsertEventFeed } from "../services/event-feed.service";
import type { EventScopeType } from "../types/event-types";
import {
	assertSignedIn,
	getCallerData,
} from "../services/event-access.service";
import {
	publishEventMessageToGroup,
	resolveScopeMeta,
} from "../services/event-group.service";
import { notifyEventAudience } from "../services/event-notification.service";
import {
	findNextEventReminderAt,
	formatEventDate,
} from "../utils/event-helpers";
import { writeDashboardAuditLog } from "../services/dashboard-audit.service";
import { assertEventTextLimits } from "../utils/event-validation";
import { fastMediumCallableOptions } from "../runtime-options";

export const createEvent = onCall(
	fastMediumCallableOptions,
	async (request) => {
		const callerUid = assertSignedIn(request);
		const callerData = await getCallerData(callerUid);

		const callerRole = String(callerData.role ?? "user");
		const callerFullName = String(callerData.fullName ?? "").trim();
		const callerDepartment = String(callerData.department ?? "").trim();

		const scopeType = String(
			request.data.scopeType ?? "",
		).trim() as EventScopeType;
		const groupId = String(request.data.groupId ?? "").trim();
		const title = String(request.data.title ?? "").trim();
		const details = String(request.data.details ?? "").trim();
		const location = String(request.data.location ?? "").trim();
		const notes = String(request.data.notes ?? "").trim();
		const eventAt = Number(request.data.eventAt ?? 0);

		if (!["university", "department", "group"].includes(scopeType)) {
			throw new HttpsError("invalid-argument", "نطاق الحدث غير صالح");
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

		const scopeMeta = await resolveScopeMeta({
			scopeType,
			groupId,
			callerUid,
			callerRole,
			callerDepartment,
		});

		const eventRef = admin.firestore().collection("events").doc();
		const reminderBaseAt = admin.firestore.Timestamp.now();
		const eventData = {
			eventId: eventRef.id,
			scopeType,
			title,
			details,
			location,
			notes,
			eventAt,
			department: scopeMeta.department,
			targetGroupId: scopeMeta.targetGroupId,
			targetGroupName: scopeMeta.targetGroupName,
			visibilityKeys: scopeMeta.visibilityKeys,
			interestedCount: 0,
			isCancelled: false,
			createdBy: callerUid,
			createdByName: callerFullName,
			createdByRole: callerRole,
			createdAt: admin.firestore.FieldValue.serverTimestamp(),
			updatedAt: null,
			cancelledAt: null,
			cancelledBy: "",
			reminderBaseAt,
			nextReminderAt: findNextEventReminderAt({
				createdAtMs: reminderBaseAt.toMillis(),
				eventAt,
				nowMs: reminderBaseAt.toMillis(),
			}),
			halfReminderSentAt: null,
			quarterReminderSentAt: null,
			hourReminderSentAt: null,
		};

		const deliveryWarnings: string[] = [];
		await eventRef.set(eventData);

		const setupWarnings = await Promise.all([
			upsertEventFeed(eventRef.id, eventData)
				.then(() => "")
				.catch((error) => {
					logger.error("Failed to update event feed", {
						eventId: eventRef.id,
						error,
					});
					return "event_feed_failed";
				}),
			writeDashboardAuditLog({
				actorUid: callerUid,
				actorRole: callerRole,
				action: "event.created",
				category: "events",
				level: "info",
				targetType: "event",
				targetId: eventRef.id,
				targetLabel: title,
				summary: `created event ${title}`,
				details: {
					scopeType,
					department: scopeMeta.department,
					targetGroupId: scopeMeta.targetGroupId,
					targetGroupName: scopeMeta.targetGroupName,
					eventAt,
					location,
				},
			})
				.then(() => "")
				.catch((error) => {
					logger.error("Failed to write event creation audit log", {
						eventId: eventRef.id,
						error,
					});
					return "audit_log_failed";
				}),
		]);
		deliveryWarnings.push(...setupWarnings.filter(Boolean));

		const groupMessagePromise = publishEventMessageToGroup({
			groupId: scopeMeta.targetGroupId,
			eventId: eventRef.id,
			title,
			createdBy: callerUid,
			createdByName: callerFullName,
		})
			.then(() => "")
			.catch((error) => {
				logger.error("Failed to publish event message to group", {
					eventId: eventRef.id,
					groupId: scopeMeta.targetGroupId,
					error,
				});
				return "group_message_failed";
			});

		let scopeBody = {
			ar: "يوجد حدث جديد",
			en: "There is a new event",
		};
		if (scopeType === "university") {
			scopeBody = {
				ar: "تم إنشاء حدث جديد على مستوى الجامعة",
				en: "A new university-wide event was created",
			};
		} else if (scopeType === "department") {
			scopeBody = {
				ar: `تم إنشاء حدث جديد لقسم ${scopeMeta.department}`,
				en: `A new event was created for ${scopeMeta.department}`,
			};
		} else if (scopeType === "group") {
			scopeBody = {
				ar: `تم إنشاء حدث جديد في الغرفة ${scopeMeta.targetGroupName}`,
				en: `A new event was created in ${scopeMeta.targetGroupName}`,
			};
		}

		const notificationPromise = notifyEventAudience({
			eventId: eventRef.id,
			title: { ar: `📅 ${title}`, en: `📅 ${title}` },
			body: {
				ar: `${scopeBody.ar} - ${formatEventDate(eventAt)}`,
				en: `${scopeBody.en} - ${formatEventDate(eventAt)}`,
			},
			scopeType,
			department: scopeMeta.department,
			targetGroupId: scopeMeta.targetGroupId,
			dataType: "event",
		})
			.then(() => "")
			.catch((error) => {
				logger.error("Failed to notify event audience", {
					eventId: eventRef.id,
					scopeType,
					targetGroupId: scopeMeta.targetGroupId,
					error,
				});
				return "notification_failed";
			});

		const deliveryResults = await Promise.all([
			groupMessagePromise,
			notificationPromise,
		]);
		deliveryWarnings.push(...deliveryResults.filter(Boolean));

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
			eventId: eventRef.id,
			deliveryWarnings,
		};
	},
);
