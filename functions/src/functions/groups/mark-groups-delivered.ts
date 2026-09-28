import { onCall } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import {
	assertSignedIn,
	getCallerData,
} from "../../services/group-chat.service";
import { userGroupSummaryRef } from "../../services/group-summary.service";
import { fastMediumCallableOptions } from "../../runtime-options";
import { canUserAccessGroup } from "../../services/group-access.service";

export const markGroupsDelivered = onCall(
	fastMediumCallableOptions,
	async (request) => {
		const callerUid = assertSignedIn(request);
		const callerData = await getCallerData(callerUid);

		const rawGroups = Array.isArray(request.data.groups)
			? request.data.groups.slice(0, 100)
			: [];
		if (rawGroups.length === 0) return { success: true, updated: 0 };

		const requestedTimes = new Map<string, number>();
		for (const item of rawGroups) {
			const groupId = String(item?.groupId ?? "").trim();
			const requestedTime = Number(item?.lastDeliveredMessageTime ?? 0);
			const lastDeliveredMessageTime =
				Number.isFinite(requestedTime) && requestedTime > 0 ? requestedTime : 0;

			if (!groupId || lastDeliveredMessageTime <= 0) continue;
			requestedTimes.set(
				groupId,
				Math.max(requestedTimes.get(groupId) ?? 0, lastDeliveredMessageTime),
			);
		}

		if (requestedTimes.size === 0) return { success: true, updated: 0 };

		const db = admin.firestore();
		const userRef = db.collection("users").doc(callerUid);
		const updated = await db.runTransaction(async (transaction) => {
			const groupIds = [...requestedTimes.keys()];
			const groupRefs = groupIds.map((groupId) =>
				db.collection("groups").doc(groupId),
			);
			const groupDocs = await transaction.getAll(...groupRefs);
			const memberStateDocs = await transaction.getAll(
				...groupRefs.map((groupRef) =>
					groupRef.collection("memberStates").doc(callerUid),
				),
			);
			const accepted: Array<{
				groupId: string;
				groupData: Record<string, any>;
				safeRecentMessageTime: number;
				lastDeliveredMessageTime: number;
				memberStateRef: FirebaseFirestore.DocumentReference;
				unreadRef: FirebaseFirestore.DocumentReference;
			}> = [];

			for (const [index, groupDoc] of groupDocs.entries()) {
				if (!groupDoc.exists) continue;
				const groupId = groupIds[index];
				if (!groupId) continue;
				if (memberStateDocs[index]?.exists !== true) continue;

				const groupData = groupDoc.data() || {};

				if (!canUserAccessGroup({
					groupData,
					userData: { ...callerData, isGroupMember: true },
				})) continue;

				const recentMessageTime = Number(groupData.recentMessageTime ?? 0);
				const safeRecentMessageTime =
					Number.isFinite(recentMessageTime) && recentMessageTime > 0
						? recentMessageTime
						: 0;
				const maxDeliveredTime =
					safeRecentMessageTime > 0 ? safeRecentMessageTime : Date.now();
				const requestedTime = requestedTimes.get(groupId) ?? 0;
				const groupRef = groupDoc.ref;

				accepted.push({
					groupId,
					groupData,
					safeRecentMessageTime,
					lastDeliveredMessageTime: Math.min(requestedTime, maxDeliveredTime),
					memberStateRef: groupRef.collection("memberStates").doc(callerUid),
					unreadRef: userRef.collection("unreadGroups").doc(groupId),
				});
			}

			if (accepted.length === 0) return 0;

			const stateAndUnreadDocs = await transaction.getAll(
				...accepted.map((entry) => entry.memberStateRef),
				...accepted.map((entry) => entry.unreadRef),
			);

			for (const [index, entry] of accepted.entries()) {
				const previousState = stateAndUnreadDocs[index];
				const unreadDoc = stateAndUnreadDocs[index + accepted.length];
				const previousDeliveredTime = Number(
					previousState?.data()?.lastDeliveredMessageTime ?? 0,
				);

				const safeDeliveredTime = Math.max(
					previousDeliveredTime || 0,
					entry.lastDeliveredMessageTime,
				);

				transaction.set(
					entry.memberStateRef,
					{
						uid: callerUid,
						groupId: entry.groupId,
						lastDeliveredMessageTime: safeDeliveredTime,
						updatedAt: admin.firestore.FieldValue.serverTimestamp(),
					},
					{ merge: true },
				);

				if (!unreadDoc?.exists) {
					transaction.set(
						entry.unreadRef,
						{
							groupId: entry.groupId,
							count: 0,
							lastReadMessageTime: entry.safeRecentMessageTime,
							lastReadMessageCount:
								Number(entry.groupData.messageCount ?? 0) || 0,
							updatedAt: admin.firestore.FieldValue.serverTimestamp(),
						},
						{ merge: true },
					);
				}

				transaction.set(
					userGroupSummaryRef(callerUid, entry.groupId),
					{
						lastDeliveredMessageTime: safeDeliveredTime,
						updatedAt: admin.firestore.FieldValue.serverTimestamp(),
					},
					{ merge: true },
				);
			}

			return accepted.length;
		});

		return { success: true, updated };
	},
);
