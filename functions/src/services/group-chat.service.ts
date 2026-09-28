import { HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import { assertActiveUserData } from "./account-status.service";
import {
	CHAT_AUDIO_STORAGE_ROOT,
	CHAT_FILE_STORAGE_ROOT,
	CHAT_IMAGE_STORAGE_ROOT,
	CHAT_VIDEO_STORAGE_ROOT,
	isStoragePathAllowedForGroup,
	normalizeStoragePath,
} from "../utils/storage-path";
import { chatMessagePreview } from "../utils/localized-notifications";
import {
	canUserAccessGroup,
	resolveGroupAudience,
} from "./group-access.service";

export function assertSignedIn(request: any): string {
	if (!request.auth)
		throw new HttpsError("unauthenticated", "يجب تسجيل الدخول");
	return request.auth.uid;
}

export async function getCallerData(uid: string) {
	const callerDoc = await admin.firestore().collection("users").doc(uid).get();
	if (!callerDoc.exists)
		throw new HttpsError("permission-denied", "المستخدم غير موجود");

	const data = callerDoc.data() || {};
	assertActiveUserData(data);
	return data;
}



export function canManageGroup(
	groupData: Record<string, any>,
	callerUid: string,
	callerRole: string,
	callerDepartment = "",
) {
	const adminId = String(groupData.adminId ?? "").trim();
	const adminIds = Array.isArray(groupData.adminIds)
		? groupData.adminIds.map((id: any) => String(id).trim())
		: [];
	const groupDepartment = String(groupData.department ?? "").trim();
	const groupName = String(groupData.groupName ?? "").trim();

	if (groupName === "main_wpu") {
		return callerRole === "admin0";
	}

	if (adminId === callerUid || adminIds.includes(callerUid)) return true;
	if (callerRole === "admin0") return true;
	if (callerRole === "admin1")
		return !!callerDepartment && callerDepartment === groupDepartment;
	return false;
}
export function buildRecentMessageBody(
	messageData: Record<string, any>,
): string {
	if (messageData.type === "text")
		return String(messageData.message ?? "رسالة جديدة");
	if (messageData.type === "image") return "📷 صورة";
	if (messageData.type === "video") return "🎥 فيديو";
	if (messageData.type === "audio") return "🎤 رسالة صوتية";
	if (messageData.type === "file") return "📎 ملف";
	if (messageData.type === "poll") return "📊 استبيان جديد";
	if (messageData.type === "event")
		return `📅 ${String(messageData.message ?? "حدث جديد")}`;
	return "رسالة جديدة";
}

export function buildRecentMessageTime(
	messageData: Record<string, any>,
): number {
	const createdAt = messageData.createdAt;
	if (createdAt instanceof admin.firestore.Timestamp)
		return createdAt.toMillis();
	const fallback = Number(messageData.time ?? 0);
	return Number.isFinite(fallback) && fallback > 0 ? fallback : Date.now();
}

export async function deleteVotesSubcollection(
	groupId: string,
	messageId: string,
) {
	const votesRef = admin
		.firestore()
		.collection("groups")
		.doc(groupId)
		.collection("messages")
		.doc(messageId)
		.collection("votes");

	while (true) {
		const snap = await votesRef.limit(400).get();
		if (snap.empty) break;

		const batch = admin.firestore().batch();
		for (const doc of snap.docs) batch.delete(doc.ref);
		await batch.commit();

		if (snap.size < 400) break;
	}
}

export async function refreshGroupRecentMessage(
	groupRef: FirebaseFirestore.DocumentReference,
) {
	const latestMessageSnap = await groupRef
		.collection("messages")
		.orderBy("createdAt", "desc")
		.limit(1)
		.get();

	if (latestMessageSnap.empty) {
		await groupRef.update({
			recentMessage: "",
			recentMessageEn: "",
			recentMessageSender: "",
			recentMessageSenderId: "",
			recentMessageTime: 0,
		});
		return;
	}

	const latestMessage = latestMessageSnap.docs.at(0)?.data() || {};
	const preview = chatMessagePreview(
		latestMessage.type,
		latestMessage.message ?? latestMessage.recentMessage,
	);
	await groupRef.update({
		recentMessage: preview.ar,
		recentMessageEn: preview.en,
		recentMessageSender: String(latestMessage.sender ?? ""),
		recentMessageSenderId: String(latestMessage.senderId ?? ""),
		recentMessageTime: buildRecentMessageTime(latestMessage),
	});
}

export function buildSafeGroupSummary(
	groupData: Record<string, any>,
	callerUid: string,
	isJoined: boolean,
): Record<string, any> {
	const createdAt = groupData.createdAt instanceof admin.firestore.Timestamp
		? groupData.createdAt.toMillis()
		: Number(groupData.createdAt ?? 0) || 0;

	return {
		groupId: String(groupData.groupId ?? ""),
		groupName: String(groupData.groupName ?? ""),
		groupIcon: String(groupData.groupIcon ?? ""),
		adminId: "",
		adminName: String(groupData.adminName ?? ""),
		memberIds: isJoined ? [callerUid] : [],
		department: String(groupData.department ?? ""),
		audience: resolveGroupAudience(groupData),
		createdAt,
		recentMessage: "",
		recentMessageEn: "",
		recentMessageSender: "",
		recentMessageSenderId: "",
		recentMessageTime: 0,
		messageCount: 0,
		writePermission: "all",
		isActive: groupData.isActive === true,
	};
}

export function canSendMessageToGroup(
	groupData: Record<string, any>,
	callerUid: string,
	callerRole: string,
	callerDepartment: string,
	isMember: boolean,
	callerAccountType = "user",
): boolean {
	if (groupData.isActive !== true) return false;
	if (!isMember) return false;
	if (
		!canUserAccessGroup({
			groupData,
			userData: {
				role: callerRole,
				department: callerDepartment,
				accountType: callerAccountType,
				isGroupMember: true,
			},
		})
	)
		return false;

	const groupName = String(groupData.groupName ?? "").trim();
	const groupDepartment = String(groupData.department ?? "").trim();
	const audience = resolveGroupAudience(groupData);

	if (groupName === "main_wpu") {
		return callerRole === "admin0";
	}

	if (audience !== "department") {
		const writePermission = String(groupData.writePermission ?? "all").trim();
		if (writePermission === "all") return true;
		if (writePermission === "admins") {
			return canManageGroup(
				groupData,
				callerUid,
				callerRole,
				callerDepartment,
			);
		}
		return false;
	}

	if (groupName.startsWith("main_")) {
		return (
			callerRole === "admin0" ||
			((callerRole === "admin1" || callerRole === "admin2") &&
				callerDepartment.trim().length > 0 &&
				callerDepartment.trim() === groupDepartment)
		);
	}

	const writePermission = String(groupData.writePermission ?? "all").trim();
	if (writePermission === "all") return true;

	if (writePermission === "admins") {
		return canManageGroup(groupData, callerUid, callerRole, callerDepartment);
	}

	return false;
}

export function messageStorageRootForType(type: string): string {
	switch (type) {
		case "image":
			return CHAT_IMAGE_STORAGE_ROOT;
		case "video":
			return CHAT_VIDEO_STORAGE_ROOT;
		case "audio":
			return CHAT_AUDIO_STORAGE_ROOT;
		case "file":
			return CHAT_FILE_STORAGE_ROOT;
		default:
			return "";
	}
}

export function cleanForwardedFileName(value: unknown): string {
	const clean = String(value ?? "").trim();
	if (!clean) return "";
	return clean.length > 120 ? clean.slice(0, 120) : clean;
}

export function safeCopiedObjectPath(
	sourcePath: string,
	targetGroupId: string,
	targetRoot: string,
): string {
	const sourceName = sourcePath.split("/").pop() || "";
	const dot = sourceName.lastIndexOf(".");
	const extension =
		dot >= 0 ? sourceName.slice(dot).replace(/[^.A-Za-z0-9_-]/g, "") : "";
	const id = admin.firestore().collection("_ids").doc().id;
	return `${targetRoot}/${targetGroupId}/${Date.now()}_${id}${extension}`;
}

export async function copyMessageStorageObject({
	sourcePath,
	sourceGroupId,
	targetGroupId,
	sourceRoot,
	targetRoot,
}: {
	sourcePath: unknown;
	sourceGroupId: string;
	targetGroupId: string;
	sourceRoot: string;
	targetRoot: string;
}): Promise<string> {
	const cleanSourcePath = normalizeStoragePath(sourcePath);
	if (!cleanSourcePath) {
		throw new HttpsError("failed-precondition", "مسار المرفق غير موجود");
	}

	if (
		!isStoragePathAllowedForGroup(cleanSourcePath, {
			groupId: sourceGroupId,
			allowedRoots: [sourceRoot],
			reason: "forward source attachment",
		})
	) {
		throw new HttpsError("invalid-argument", "مسار المرفق غير صالح");
	}

	const targetPath = safeCopiedObjectPath(
		cleanSourcePath,
		targetGroupId,
		targetRoot,
	);
	const bucket = admin.storage().bucket();
	await bucket.file(cleanSourcePath).copy(bucket.file(targetPath));
	return targetPath;
}

export function buildForwardedMessagePayload({
	callerUid,
	callerName,
	sourceData,
	storagePath,
	videoThumbnailPath,
}: {
	callerUid: string;
	callerName: string;
	sourceData: Record<string, any>;
	storagePath?: string;
	videoThumbnailPath?: string;
}): Record<string, any> {
	const type = String(sourceData.type ?? "text").trim();
	const sourceMessage = String(sourceData.message ?? "").trim();
	const now = Date.now();
	const basePayload: Record<string, any> = {
		sender: callerName,
		senderId: callerUid,
		time: now,
		createdAt: admin.firestore.FieldValue.serverTimestamp(),
	};

	if (type === "text") {
		return {
			...basePayload,
			type: "text",
			message: sourceMessage.slice(0, 4000) || "رسالة",
		};
	}

	if (type === "poll") {
		const options = Array.isArray(sourceData.pollOptions)
			? sourceData.pollOptions
					.map((e) => String(e ?? "").trim())
					.filter((e) => e.length > 0)
					.slice(0, 6)
			: [];
		if (options.length < 2) {
			return {
				...basePayload,
				type: "text",
				message: sourceMessage.slice(0, 4000) || "📊 استبيان",
			};
		}

		return {
			...basePayload,
			type: "poll",
			message:
				String(sourceData.pollQuestion ?? sourceMessage)
					.trim()
					.slice(0, 120) || "استبيان",
			pollQuestion:
				String(sourceData.pollQuestion ?? sourceMessage)
					.trim()
					.slice(0, 120) || "استبيان",
			pollOptions: options.map((option) => option.slice(0, 80)),
			pollExpiresAt: now + 24 * 60 * 60 * 1000,
			pollIsClosed: false,
			pollTotalVotes: 0,
		};
	}

	if (["image", "video", "audio", "file"].includes(type)) {
		if (!storagePath) {
			throw new HttpsError(
				"failed-precondition",
				"المرفق غير متوفر لإعادة التوجيه",
			);
		}

		const payload: Record<string, any> = {
			...basePayload,
			type,
			message: sourceMessage || buildRecentMessageBody(sourceData),
			storagePath,
		};

		const fileName = cleanForwardedFileName(sourceData.fileName);
		if (fileName) payload.fileName = fileName;
		if (type === "video" && videoThumbnailPath) {
			payload.videoThumbnailPath = videoThumbnailPath;
		}

		return payload;
	}

	return {
		...basePayload,
		type: "text",
		message: sourceMessage.slice(0, 4000) || buildRecentMessageBody(sourceData),
	};
}
