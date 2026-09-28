import * as admin from "firebase-admin";
import { FCM_BATCH_SIZE } from "../constants";
import { chunkArray } from "../utils/array";

const invalidTokenCodes = new Set([
	"messaging/invalid-registration-token",
	"messaging/registration-token-not-registered",
]);

type MulticastPayloadOptions = {
	tokens: string[];
	title: string;
	body: string;
	data: Record<string, string>;
	dataOnly?: boolean;
};

function sanitizeData(data: Record<string, string>) {
	const sanitized: Record<string, string> = {};

	for (const [key, value] of Object.entries(data)) {
		const cleanKey = String(key ?? "").trim();
		if (!cleanKey) continue;
		sanitized[cleanKey] = String(value ?? "");
	}

	return sanitized;
}

export async function clearInvalidFcmTokens(tokens: string[]) {
	const uniqueTokens = Array.from(new Set(tokens.filter(Boolean)));
	if (uniqueTokens.length === 0) return;

	for (const tokenChunk of chunkArray(uniqueTokens, 30)) {
		const snap = await admin
			.firestore()
			.collection("users")
			.where("fcmToken", "in", tokenChunk)
			.get();

		if (snap.empty) continue;

		const batch = admin.firestore().batch();

		for (const doc of snap.docs) {
			batch.set(doc.ref, { fcmToken: "" }, { merge: true });
		}

		await batch.commit();
	}
}

export async function sendMulticastAndClean({
	tokens,
	title,
	body,
	data,
	dataOnly = false,
}: MulticastPayloadOptions) {
	const uniqueTokens = Array.from(
		new Set(tokens.filter((token) => token.trim().length > 0)),
	);

	const baseData = sanitizeData(data);

	const messageData = sanitizeData({
		...baseData,
		notificationTitle: title,
		notificationBody: body,
	});

	let successCount = 0;
	let failureCount = 0;
	const invalidTokens: string[] = [];

	for (const tokenChunk of chunkArray(uniqueTokens, FCM_BATCH_SIZE)) {
		const multicastMessage: admin.messaging.MulticastMessage = {
			tokens: tokenChunk,
			data: messageData,
			android: {
				priority: "high",
			},
		};

		if (dataOnly) {
			multicastMessage.apns = {
				payload: {
					aps: {
						contentAvailable: true,
					},
				},
			};
		} else {
			const androidNotification: admin.messaging.AndroidNotification = {
				channelId: "chat_messages",
			};

			const notificationTagSource = String(
				data.groupId ?? data.eventId ?? "",
			).trim();

			if (notificationTagSource) {
				androidNotification.tag = notificationTagSource.slice(0, 64);
			}

			multicastMessage.notification = { title, body };
			multicastMessage.android = {
				priority: "high",
				notification: androidNotification,
			};
		}

		const response = await admin
			.messaging()
			.sendEachForMulticast(multicastMessage);

		successCount += response.successCount;
		failureCount += response.failureCount;

		response.responses.forEach((result, index) => {
			const code = result.error?.code ?? "";
			if (!result.success && invalidTokenCodes.has(code)) {
				const invalidToken = tokenChunk[index];
				if (invalidToken) invalidTokens.push(invalidToken);
			}
		});
	}

	await clearInvalidFcmTokens(invalidTokens);

	return {
		successCount,
		failureCount,
		invalidTokenCount: invalidTokens.length,
	};
}
