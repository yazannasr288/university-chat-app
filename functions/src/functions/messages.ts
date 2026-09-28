import { onDocumentCreated } from "firebase-functions/v2/firestore";
import * as logger from "firebase-functions/logger";
import * as admin from "firebase-admin";
import { createHash } from "node:crypto";
import { chunkArray } from "../utils/array";
import { sendMulticastAndClean } from "../services/fcm.service";
import { collectTokensByLanguageForUserIds } from "../services/event-notification.service";
import {
	chatMessagePreview,
	localizedText,
} from "../utils/localized-notifications";
import { userGroupSummaryRef } from "../services/group-summary.service";
import { FCM_BATCH_SIZE, UNREAD_COUNTER_FANOUT_LIMIT } from "../constants";
import { firestoreTriggerOptions } from "../runtime-options";
import { resolveGroupAudience } from "../services/group-access.service";
import { listIndexedGroupMemberUids } from "../services/group-member-index.service";

const MESSAGE_TIME_MAX_SKEW_MS = 60 * 1000;

function resolveRecentMessageTime(messageData: any): number {
	const createdAt = messageData?.createdAt;
	const serverTime =
		createdAt instanceof admin.firestore.Timestamp
			? createdAt.toMillis()
			: Date.now();

	const clientTime = Number(messageData?.time ?? 0);
	if (
		Number.isFinite(clientTime) &&
		clientTime > 0 &&
		Math.abs(clientTime - serverTime) <= MESSAGE_TIME_MAX_SKEW_MS
	) {
		return clientTime;
	}

	return serverTime;
}

function timestampMillis(value: unknown): number {
	if (value instanceof admin.firestore.Timestamp) return value.toMillis();
	if (value instanceof Date) return value.getTime();
	const numericValue = Number(value ?? 0);
	return Number.isFinite(numericValue) && numericValue > 0
		? numericValue
		: 0;
}
const CHAT_UNREAD_COUNTER_FANOUT_QUEUE_COLLECTION =
	"chatUnreadCounterFanoutQueue";
const CHAT_NOTIFICATION_QUEUE_COLLECTION = "chatNotificationQueue";

function messageQueueKey(groupId: string, messageId: string): string {
	return createHash("sha256").update(`${groupId}/${messageId}`).digest("hex");
}

async function sendQueuedChatNotifications(payload: Record<string, any>) {
	const groupId = String(payload.groupId ?? "").trim();
	const groupName = String(payload.groupName ?? "الدردشة");
	const senderId = String(payload.senderId ?? "");
	const senderName = String(payload.senderName ?? "مستخدم");
	const messageId = String(payload.messageId ?? "").trim();
	const messageType = String(payload.messageType ?? "text");
	const messageTime = Number(payload.messageTime ?? 0);
	const safeMessageTime =
		Number.isFinite(messageTime) && messageTime > 0
			? Math.floor(messageTime)
			: Date.now();
	const messagePreview = {
		ar: String(payload.messagePreview?.ar ?? ""),
		en: String(payload.messagePreview?.en ?? ""),
	};
	const memberIds = Array.isArray(payload.memberIds)
		? payload.memberIds
				.map((e: any) => String(e ?? "").trim())
				.filter((e: string) => e.length > 0)
		: [];

	if (!groupId || memberIds.length === 0) {
		logger.info("No members to notify", { groupId });
		return;
	}

	const tokensByLanguage = await collectTokensByLanguageForUserIds(
		memberIds,
		groupId,
	);

	const tokenCount = [
		...new Set([...tokensByLanguage.ar, ...tokensByLanguage.en]),
	].length;
	if (tokenCount === 0) {
		logger.info("No FCM tokens found", { groupId });
		return;
	}

	let successCount = 0;
	let failureCount = 0;
	let invalidTokenCount = 0;

	const localizedResults = await Promise.all(
		(["ar", "en"] as const).map(async (languageCode) => {
			const uniqueTokens = [...new Set(tokensByLanguage[languageCode])];
			if (uniqueTokens.length === 0) return null;

			const localizedBody = localizedText(messagePreview, languageCode);
			const notificationBody = `${senderName}: ${localizedBody}`;
			const result = await sendMulticastAndClean({
				tokens: uniqueTokens,
				title: groupName,
				body: notificationBody,
				dataOnly: true,
				data: {
					notificationKind: "chat_message",
					groupId,
					groupName,
					messageId,
					messageType,
					messageTime: String(safeMessageTime),
					senderId,
					sender: senderName,
					type: "chat_message",
				},
			});

			return result;
		}),
	);

	for (const result of localizedResults) {
		if (!result) continue;
		successCount += result.successCount;
		failureCount += result.failureCount;
		invalidTokenCount += result.invalidTokenCount;
	}

	logger.info("Notification sent", {
		successCount,
		failureCount,
		invalidTokenCount,
		groupId,
		tokenCount,
	});
}

export const onMessageCreated = onDocumentCreated(
	{
		...firestoreTriggerOptions,
		document: "groups/{groupId}/messages/{messageId}",
		retry: true,
	},
	async (event) => {
		const snapshot = event.data;
		if (!snapshot) {
			logger.info("No message data found");
			return;
		}

		const messageData = snapshot.data();
		const groupId = event.params.groupId;
		const senderId = String(messageData.senderId ?? "");
		const senderName = String(messageData.sender ?? "مستخدم");
		const messagePreview = chatMessagePreview(
			messageData.type,
			messageData.message ?? messageData.recentMessage,
		);
		const body = messagePreview.ar;
		const recentMessageTime = resolveRecentMessageTime(messageData);

		const firestore = admin.firestore();
		const groupRef = firestore.collection("groups").doc(groupId);
		const queueKey = messageQueueKey(groupId, event.params.messageId);
		const senderUnreadRef = senderId
			? firestore
					.collection("users")
					.doc(senderId)
					.collection("unreadGroups")
					.doc(groupId)
			: null;
		const membershipSource = await groupRef.get();
		if (!membershipSource.exists) return;
		const indexedMemberIds = await listIndexedGroupMemberUids({
			groupRef,
			groupData: membershipSource.data() || {},
		});

		const processed = await firestore.runTransaction(async (transaction) => {
			const documents = await transaction.getAll(
				snapshot.ref,
				groupRef,
				...(senderUnreadRef ? [senderUnreadRef] : []),
			);
			const freshMessageDoc = documents.at(0);
			const freshGroupDoc = documents.at(1);
			const senderUnreadDoc = senderUnreadRef ? documents.at(2) : null;
			if (!freshMessageDoc || !freshGroupDoc) return null;
			if (!freshMessageDoc.exists || !freshGroupDoc.exists) return null;

			const freshMessageData = freshMessageDoc.data() || {};
			if (freshMessageData.serverFanoutProcessedAt != null) return null;

			const freshGroupData = freshGroupDoc.data() || {};
			const groupName = String(freshGroupData.groupName ?? "الدردشة");
			const previousMessageCount = Number(freshGroupData.messageCount ?? 0);
			const messageCount =
				Number.isFinite(previousMessageCount) && previousMessageCount >= 0
					? previousMessageCount + 1
					: 1;
			const previousRecentMessageTime = Number(
				freshGroupData.recentMessageTime ?? 0,
			);
			const isLatestMessage =
				!Number.isFinite(previousRecentMessageTime) ||
				recentMessageTime >= previousRecentMessageTime;

			const clientMessageTime = Number(messageData.time ?? 0);
			const shouldCorrectMessageTime =
				!Number.isFinite(clientMessageTime) ||
				clientMessageTime <= 0 ||
				Math.abs(clientMessageTime - recentMessageTime) >
					MESSAGE_TIME_MAX_SKEW_MS;

			transaction.set(
				snapshot.ref,
				{
					serverFanoutProcessedAt: admin.firestore.FieldValue.serverTimestamp(),
					...(shouldCorrectMessageTime ? { time: recentMessageTime } : {}),
				},
				{ merge: true },
			);

			transaction.update(groupRef, {
				messageCount,
				...(isLatestMessage
					? {
							recentMessage: body,
							recentMessageEn: messagePreview.en,
							recentMessageSender: senderName,
							recentMessageSenderId: senderId,
							recentMessageTime,
							lastMessageId: event.params.messageId,
						}
					: {}),
			});

			const summaryPatch = {
				groupId,
				groupName,
				groupIcon: String(freshGroupData.groupIcon ?? ""),
				adminId: String(freshGroupData.adminId ?? ""),
				adminName: String(freshGroupData.adminName ?? ""),
				adminIds: Array.isArray(freshGroupData.adminIds)
					? freshGroupData.adminIds
					: [],
				department: String(freshGroupData.department ?? ""),
				audience: resolveGroupAudience(freshGroupData),
				createdAt: timestampMillis(freshGroupData.createdAt),
				recentMessage: isLatestMessage
					? body
					: String(freshGroupData.recentMessage ?? ""),
				recentMessageEn: isLatestMessage
					? messagePreview.en
					: String(
							freshGroupData.recentMessageEn ??
								freshGroupData.recentMessage ??
								"",
						),
				recentMessageSender: isLatestMessage
					? senderName
					: String(freshGroupData.recentMessageSender ?? ""),
				recentMessageSenderId: isLatestMessage
					? senderId
					: String(freshGroupData.recentMessageSenderId ?? ""),
				recentMessageTime: isLatestMessage
					? recentMessageTime
					: previousRecentMessageTime,
				messageCount,
				lastMessageId: isLatestMessage
					? event.params.messageId
					: String(freshGroupData.lastMessageId ?? ""),
				writePermission: String(freshGroupData.writePermission ?? "all"),
				isActive: freshGroupData.isActive === true,
			};

			if (senderId) {
				const newestUnreadMessageTime = Number(
					senderUnreadDoc?.data()?.lastMessageTime ?? 0,
				);
				const canMarkSenderRead =
					isLatestMessage &&
					(!Number.isFinite(newestUnreadMessageTime) ||
						recentMessageTime >= newestUnreadMessageTime);

				if (senderUnreadRef && canMarkSenderRead) {
					transaction.set(
						senderUnreadRef,
						{
							groupId,
							count: 0,
							lastReadMessageTime: recentMessageTime,
							lastReadMessageCount: messageCount,
							updatedAt: admin.firestore.FieldValue.serverTimestamp(),
						},
						{ merge: true },
					);
				}

				transaction.set(
					userGroupSummaryRef(senderId, groupId),
					{
						...summaryPatch,
						memberIds: [senderId],
						...(canMarkSenderRead
							? {
									unreadCount: 0,
									lastReadMessageTime: recentMessageTime,
									lastDeliveredMessageTime: recentMessageTime,
								}
							: {}),
						updatedAt: admin.firestore.FieldValue.serverTimestamp(),
					},
					{ merge: true },
				);
			}

			const memberIds = indexedMemberIds.filter(
				(uid) => uid && uid !== senderId,
			);
			const memberChunks = chunkArray(memberIds, UNREAD_COUNTER_FANOUT_LIMIT);
			const unreadQueue = firestore.collection(
				CHAT_UNREAD_COUNTER_FANOUT_QUEUE_COLLECTION,
			);

			memberChunks.forEach((memberChunk, index) => {
				transaction.set(unreadQueue.doc(`${queueKey}_${index}`), {
					groupId,
					memberIds: memberChunk,
					recentMessageTime,
					messageCount,
					summaryPatch,
					status: "pending",
					createdAt: admin.firestore.FieldValue.serverTimestamp(),
				});
			});

			if (messageData.type !== "event" && memberIds.length > 0) {
				const notificationQueue = firestore.collection(
					CHAT_NOTIFICATION_QUEUE_COLLECTION,
				);
				chunkArray(memberIds, FCM_BATCH_SIZE).forEach(
					(notificationMemberIds, index) => {
						transaction.set(notificationQueue.doc(`${queueKey}_${index}`), {
							groupId,
							groupName,
							senderId,
							senderName,
							memberIds: notificationMemberIds,
							messageId: event.params.messageId,
							messageType: String(messageData.type ?? "text"),
							messageTime: recentMessageTime,
							messagePreview,
							status: "pending",
							createdAt: admin.firestore.FieldValue.serverTimestamp(),
						});
					},
				);
			}

			return {
				memberCount: memberIds.length,
				queueItemCount: memberChunks.length,
				skippedNotification: messageData.type === "event",
			};
		});

		if (!processed) {
			logger.info("Skipped an already processed message or a missing group", {
				groupId,
				messageId: event.params.messageId,
			});
			return;
		}

		logger.info("Message fanout queued atomically", {
			groupId,
			messageId: event.params.messageId,
			...processed,
		});
	},
);

export const processUnreadCounterFanoutQueue = onDocumentCreated(
	{
		...firestoreTriggerOptions,
		document: `${CHAT_UNREAD_COUNTER_FANOUT_QUEUE_COLLECTION}/{queueId}`,
		retry: true,
	},
	async (event) => {
		const snapshot = event.data;
		if (!snapshot) return;

		try {
			await admin.firestore().runTransaction(async (transaction) => {
				const current = await transaction.get(snapshot.ref);
				if (!current.exists) return;

				const payload = current.data() || {};
				const groupId = String(payload.groupId ?? "").trim();
				const recentMessageTime = Number(payload.recentMessageTime ?? 0);
				const messageCount = Number(payload.messageCount ?? 0);
				const summaryPatch =
					typeof payload.summaryPatch === "object" &&
					payload.summaryPatch !== null
						? payload.summaryPatch
						: {};
				const memberIds = Array.isArray(payload.memberIds)
					? Array.from(
							new Set(
								payload.memberIds
									.map((value: any) => String(value ?? "").trim())
									.filter((value: string) => value.length > 0),
							),
						)
					: [];

				if (!groupId || memberIds.length === 0) {
					transaction.delete(snapshot.ref);
					return;
				}

				const summaryRefs = memberIds.map((uid) =>
					userGroupSummaryRef(uid, groupId),
				);
				const unreadRefs = memberIds.map((uid) =>
					admin
						.firestore()
						.collection("users")
						.doc(uid)
						.collection("unreadGroups")
						.doc(groupId),
				);
				const existingDocuments = await transaction.getAll(
					...summaryRefs,
					...unreadRefs,
				);

				memberIds.forEach((uid, index) => {
					const existingSummary = existingDocuments[index];
					const existingUnread = existingDocuments[summaryRefs.length + index];
					const existingMessageCount = Number(
						existingSummary?.data()?.messageCount ?? 0,
					);
					const existingLastReadMessageTime = Number(
						existingSummary?.data()?.lastReadMessageTime ?? 0,
					);
					const existingLastMessageTime = Number(
						existingUnread?.data()?.lastMessageTime ?? 0,
					);
					const existingLastMessageCount = Number(
						existingUnread?.data()?.lastMessageCount ?? 0,
					);
					const canApplyCorePatch =
						!Number.isFinite(existingMessageCount) ||
						messageCount >= existingMessageCount;
					const shouldIncrementUnread =
						!Number.isFinite(existingLastReadMessageTime) ||
						recentMessageTime > existingLastReadMessageTime;

					if (shouldIncrementUnread) {
						transaction.set(
							unreadRefs[index]!,
							{
								groupId,
								count: admin.firestore.FieldValue.increment(1),
								lastMessageTime: Math.max(
									recentMessageTime,
									Number.isFinite(existingLastMessageTime)
										? existingLastMessageTime
										: 0,
								),
								lastMessageCount: Math.max(
									messageCount,
									Number.isFinite(existingLastMessageCount)
										? existingLastMessageCount
										: 0,
								),
								updatedAt: admin.firestore.FieldValue.serverTimestamp(),
							},
							{ merge: true },
						);
					}

					transaction.set(
						summaryRefs[index]!,
						{
							...(canApplyCorePatch ? summaryPatch : { groupId }),
							memberIds: [uid],
							...(shouldIncrementUnread
								? {
										unreadCount: admin.firestore.FieldValue.increment(1),
									}
								: {}),
							updatedAt: admin.firestore.FieldValue.serverTimestamp(),
						},
						{ merge: true },
					);
				});

				transaction.delete(snapshot.ref);
			});
		} catch (error) {
			logger.error("Unread counter fanout failed", {
				queueId: event.params.queueId,
				error,
			});
			throw error;
		}
	},
);

export const processChatNotificationQueue = onDocumentCreated(
	{
		...firestoreTriggerOptions,
		document: `${CHAT_NOTIFICATION_QUEUE_COLLECTION}/{queueId}`,
		retry: true,
	},
	async (event) => {
		const snapshot = event.data;
		if (!snapshot) return;

		const claim = await admin
			.firestore()
			.runTransaction(async (transaction) => {
				const current = await transaction.get(snapshot.ref);
				if (!current.exists) return null;

				const data = current.data() || {};
				const status = String(data.status ?? "pending");
				if (status === "sent") {
					transaction.delete(snapshot.ref);
					return null;
				}

				const processingStartedAt = data.processingStartedAt;
				const processingStartedAtMs =
					processingStartedAt instanceof admin.firestore.Timestamp
						? processingStartedAt.toMillis()
						: 0;
				if (
					status === "processing" &&
					Date.now() - processingStartedAtMs < 5 * 60 * 1000
				) {
					return { state: "busy" as const, payload: {} };
				}

				transaction.set(
					snapshot.ref,
					{
						status: "processing",
						attempts: admin.firestore.FieldValue.increment(1),
						processingStartedAt: admin.firestore.FieldValue.serverTimestamp(),
						updatedAt: admin.firestore.FieldValue.serverTimestamp(),
					},
					{ merge: true },
				);

				return { state: "claimed" as const, payload: data };
			});

		if (!claim) return;
		if (claim.state === "busy") {
			throw new Error(
				`Notification queue item ${event.params.queueId} is still leased`,
			);
		}

		try {
			await sendQueuedChatNotifications(claim.payload);
		} catch (error) {
			logger.error("Queued chat notification failed", {
				queueId: event.params.queueId,
				error,
			});
			await snapshot.ref.set(
				{
					status: "pending",
					lastError: error instanceof Error ? error.message : String(error),
					failedAt: admin.firestore.FieldValue.serverTimestamp(),
					updatedAt: admin.firestore.FieldValue.serverTimestamp(),
				},
				{ merge: true },
			);
			throw error;
		}

		await snapshot.ref.set(
			{
				status: "sent",
				sentAt: admin.firestore.FieldValue.serverTimestamp(),
				updatedAt: admin.firestore.FieldValue.serverTimestamp(),
			},
			{ merge: true },
		);
		await snapshot.ref.delete();
	},
);
