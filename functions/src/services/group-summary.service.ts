import * as admin from "firebase-admin";
import { resolveGroupAudience } from "./group-access.service";

const db = admin.firestore();

export function userGroupSummaryRef(uid: string, groupId: string) {
	return db
		.collection("users")
		.doc(uid)
		.collection("groupSummaries")
		.doc(groupId);
}

function timestampMillis(value: unknown): number {
	if (value instanceof admin.firestore.Timestamp) return value.toMillis();
	if (value instanceof Date) return value.getTime();
	const numericValue = Number(value ?? 0);
	return Number.isFinite(numericValue) && numericValue > 0
		? numericValue
		: 0;
}

export function buildUserGroupSummaryCoreFields(params: {
	groupId: string;
	groupData: Record<string, any>;
	uid: string;
}): Record<string, any> {
	const { groupId, groupData, uid } = params;
	const adminIds = Array.isArray(groupData.adminIds)
		? groupData.adminIds
				.map((id: any) => String(id ?? "").trim())
				.filter(Boolean)
		: [];

	return {
		groupId,
		groupName: String(groupData.groupName ?? ""),
		groupIcon: String(groupData.groupIcon ?? ""),
		adminId: String(groupData.adminId ?? ""),
		adminName: String(groupData.adminName ?? ""),
		adminIds,
		memberIds: [uid],
		department: String(groupData.department ?? ""),
		audience: resolveGroupAudience(groupData),
		createdAt: timestampMillis(groupData.createdAt),
		recentMessage: String(groupData.recentMessage ?? ""),
		recentMessageEn: String(
			groupData.recentMessageEn ?? groupData.recentMessage ?? "",
		),
		recentMessageSender: String(groupData.recentMessageSender ?? ""),
		recentMessageSenderId: String(groupData.recentMessageSenderId ?? ""),
		recentMessageTime: Number(groupData.recentMessageTime ?? 0) || 0,
		messageCount: Number(groupData.messageCount ?? 0) || 0,
		writePermission: String(groupData.writePermission ?? "all"),
		isActive: groupData.isActive === true,
	};
}

export function buildUserGroupSummary(params: {
	groupId: string;
	groupData: Record<string, any>;
	uid: string;
	unreadCount?: number;
	isMuted?: boolean;
	mutedUntil?: number | null;
	isPinned?: boolean;
	lastReadMessageTime?: number;
	lastDeliveredMessageTime?: number;
}): Record<string, any> {
	return {
		...buildUserGroupSummaryCoreFields({
			groupId: params.groupId,
			groupData: params.groupData,
			uid: params.uid,
		}),
		unreadCount: Math.max(0, Number(params.unreadCount ?? 0) || 0),
		isMuted: params.isMuted === true,
		mutedUntil: params.mutedUntil ?? null,
		isPinned: params.isPinned === true,
		lastReadMessageTime: Math.max(
			0,
			Number(params.lastReadMessageTime ?? 0) || 0,
		),
		lastDeliveredMessageTime: Math.max(
			0,
			Number(params.lastDeliveredMessageTime ?? 0) || 0,
		),
		updatedAt: admin.firestore.FieldValue.serverTimestamp(),
	};
}

export async function setUserGroupSummary(params: {
	uid: string;
	groupId: string;
	groupData: Record<string, any>;
	unreadCount?: number;
	isMuted?: boolean;
	mutedUntil?: number | null;
	isPinned?: boolean;
	lastReadMessageTime?: number;
	lastDeliveredMessageTime?: number;
	merge?: boolean;
}) {
	const ref = userGroupSummaryRef(params.uid, params.groupId);
	await ref.set(
		buildUserGroupSummary({
			groupId: params.groupId,
			groupData: params.groupData,
			uid: params.uid,
			...(params.unreadCount === undefined
				? {}
				: { unreadCount: params.unreadCount }),
			...(params.isMuted === undefined ? {} : { isMuted: params.isMuted }),
			...(params.mutedUntil === undefined
				? {}
				: { mutedUntil: params.mutedUntil }),
			...(params.isPinned === undefined ? {} : { isPinned: params.isPinned }),
			...(params.lastReadMessageTime === undefined
				? {}
				: { lastReadMessageTime: params.lastReadMessageTime }),
			...(params.lastDeliveredMessageTime === undefined
				? {}
				: { lastDeliveredMessageTime: params.lastDeliveredMessageTime }),
		}),
		{ merge: params.merge !== false },
	);
}

export async function updateUserGroupSummaryCoreFields(params: {
	uid: string;
	groupId: string;
	groupData: Record<string, any>;
}) {
	await userGroupSummaryRef(params.uid, params.groupId).set(
		{
			...buildUserGroupSummaryCoreFields({
				uid: params.uid,
				groupId: params.groupId,
				groupData: params.groupData,
			}),
			updatedAt: admin.firestore.FieldValue.serverTimestamp(),
		},
		{ merge: true },
	);
}

export async function createSummariesForMembers(params: {
	memberIds: string[];
	groupId: string;
	groupData: Record<string, any>;
}) {
	const { memberIds, groupId, groupData } = params;
	const uniqueMemberIds = Array.from(
		new Set(memberIds.map((uid) => String(uid ?? "").trim()).filter(Boolean)),
	);

	for (let i = 0; i < uniqueMemberIds.length; i += 400) {
		const batch = db.batch();
		for (const uid of uniqueMemberIds.slice(i, i + 400)) {
			batch.set(
				userGroupSummaryRef(uid, groupId),
				buildUserGroupSummary({ groupId, groupData, uid }),
				{ merge: true },
			);
		}
		await batch.commit();
	}
}


export async function updateGroupSummaryFieldsForMembers(params: {
	memberIds: string[];
	groupId: string;
	data: Record<string, any>;
}) {
	const uniqueMemberIds = Array.from(
		new Set(
			params.memberIds.map((uid) => String(uid ?? "").trim()).filter(Boolean),
		),
	);
	if (uniqueMemberIds.length === 0) return;

	for (let i = 0; i < uniqueMemberIds.length; i += 400) {
		const batch = db.batch();
		for (const uid of uniqueMemberIds.slice(i, i + 400)) {
			batch.set(
				userGroupSummaryRef(uid, params.groupId),
				{
					...params.data,
					updatedAt: admin.firestore.FieldValue.serverTimestamp(),
				},
				{ merge: true },
			);
		}
		await batch.commit();
	}
}
