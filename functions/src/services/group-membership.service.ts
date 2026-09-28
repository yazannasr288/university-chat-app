import * as admin from "firebase-admin";
import {
	buildDefaultGroupNames,
	mapAccountTypeToRole,
} from "../utils/group-mapping";
import {
	setUserGroupSummary,
	updateUserGroupSummaryCoreFields,
	userGroupSummaryRef,
} from "./group-summary.service";
import { canUserAccessGroup } from "./group-access.service";
import {
	groupMemberCountPatch,
	groupMemberStateRef,
	loadGroupDocumentsForUser,
} from "./group-member-index.service";

export async function joinDefaultGroups({
	uid,
	department,
	accountType,
}: {
	uid: string;
	department: string;
	accountType: string;
}) {
	const wantedGroupNames = buildDefaultGroupNames(department, accountType);

	if (wantedGroupNames.length === 0) return;

	const snapshot = await admin
		.firestore()
		.collection("groups")
		.where("groupName", "in", wantedGroupNames)
		.get();

	if (snapshot.empty) return;

	const batch = admin.firestore().batch();
	const userGroupIds: string[] = [];
	const groupDataById = new Map<string, Record<string, any>>();
	const memberStateDocs = await admin.firestore().getAll(
		...snapshot.docs.map((groupDoc) => groupMemberStateRef(groupDoc.ref, uid)),
	);
	const indexedGroupIds = new Set(
		memberStateDocs.filter((doc) => doc.exists).map((doc) => doc.ref.parent.parent?.id),
	);
	const userData = {
		uid,
		department,
		accountType,
		role: mapAccountTypeToRole(accountType),
	};

	for (const groupDoc of snapshot.docs) {
		const groupId = groupDoc.id;
		const groupData = groupDoc.data() || {};
		if (!canUserAccessGroup({ groupData, userData })) continue;
		groupDataById.set(groupId, groupData);
		const alreadyJoined = indexedGroupIds.has(groupId);

		batch.set(
			groupDoc.ref,
			{
				...(alreadyJoined
					? {}
					: { memberCount: groupMemberCountPatch(groupData, 1) }),
				updatedAt: admin.firestore.FieldValue.serverTimestamp(),
			},
			{ merge: true },
		);

		batch.set(
			groupDoc.ref.collection("memberStates").doc(uid),
			{
				uid,
				groupId,
				updatedAt: admin.firestore.FieldValue.serverTimestamp(),
			},
			{ merge: true },
		);

		userGroupIds.push(groupId);
	}

	if (userGroupIds.length === 0) return;

	batch.set(
		admin.firestore().collection("users").doc(uid),
		{
			groupIds: admin.firestore.FieldValue.arrayUnion(...userGroupIds),
			updatedAt: admin.firestore.FieldValue.serverTimestamp(),
		},
		{ merge: true },
	);

	await batch.commit();

	await Promise.all(
		userGroupIds.map(async (groupId) => {
			const groupData = groupDataById.get(groupId);
			if (!groupData) return;
			await setUserGroupSummary({
				uid,
				groupId,
				groupData,
				unreadCount: 0,
				lastReadMessageTime: Number(groupData.recentMessageTime ?? 0) || 0,
				lastDeliveredMessageTime: 0,
			});
		}),
	);
}

export async function syncUserGroupMembershipAfterProfileUpdate({
	uid,
	fullName,
	department,
	accountType,
}: {
	uid: string;
	fullName: string;
	department: string;
	accountType: string;
}) {
	const db = admin.firestore();
	const nextUserData = {
		uid,
		department,
		accountType,
		role: mapAccountTypeToRole(accountType),
	};
	const wantedDefaultGroupNames = buildDefaultGroupNames(
		department,
		accountType,
	);

	const existingGroupDocs = await loadGroupDocumentsForUser(uid);

	if (wantedDefaultGroupNames.length === 0) {
		const writes: Array<(batch: FirebaseFirestore.WriteBatch) => void> = [];

		for (const groupDoc of existingGroupDocs) {
			const groupData = groupDoc.data() || {};
			writes.push((batch) => {
				batch.set(
					groupDoc.ref,
					{
						memberCount: groupMemberCountPatch(groupData, -1),
						updatedAt: admin.firestore.FieldValue.serverTimestamp(),
					},
					{ merge: true },
				);
			});
			writes.push((batch) => {
				batch.delete(
					db
						.collection("users")
						.doc(uid)
						.collection("unreadGroups")
						.doc(groupDoc.id),
				);
			});
			writes.push((batch) => {
				batch.delete(
					db
						.collection("users")
						.doc(uid)
						.collection("groupSettings")
						.doc(groupDoc.id),
				);
			});
			writes.push((batch) => {
				batch.delete(userGroupSummaryRef(uid, groupDoc.id));
			});
			writes.push((batch) => {
				batch.delete(groupDoc.ref.collection("memberStates").doc(uid));
			});
		}

		writes.push((batch) => {
			batch.set(
				db.collection("users").doc(uid),
				{
					fullName,
					department,
					accountType,
					groupIds: [],
					updatedAt: admin.firestore.FieldValue.serverTimestamp(),
				},
				{ merge: true },
			);
		});

		await commitBatchWrites(writes);
		return;
	}

	const wantedDefaultGroupsSnap = await db
		.collection("groups")
		.where("groupName", "in", wantedDefaultGroupNames)
		.get();

	const wantedDefaultGroupDocs = wantedDefaultGroupsSnap.docs.filter((doc) =>
		canUserAccessGroup({ groupData: doc.data() || {}, userData: nextUserData }),
	);
	const wantedDefaultGroupIds = new Set(
		wantedDefaultGroupDocs.map((doc) => doc.id),
	);

	const nextUserGroupIds: string[] = [];
	const keptGroupIds: string[] = [];
	const newlyAddedGroupIds: string[] = [];
	const writes: Array<(batch: FirebaseFirestore.WriteBatch) => void> = [];
	const groupDataById = new Map<string, Record<string, any>>();

	for (const groupDoc of existingGroupDocs) {
		const groupData = groupDoc.data() || {};
		const groupId = groupDoc.id;
		groupDataById.set(groupId, groupData);

		const keepBecauseWantedDefault = wantedDefaultGroupIds.has(groupId);

		const keepBecauseAudience = canUserAccessGroup({
			groupData,
			userData: { ...nextUserData, isGroupMember: true },
		});

		const shouldKeep =
			keepBecauseWantedDefault || keepBecauseAudience;

		if (!shouldKeep) {
			writes.push((batch) => {
				batch.set(
					groupDoc.ref,
					{
						memberCount: groupMemberCountPatch(groupData, -1),
						updatedAt: admin.firestore.FieldValue.serverTimestamp(),
					},
					{ merge: true },
				);
			});
			writes.push((batch) => {
				batch.delete(
					db
						.collection("users")
						.doc(uid)
						.collection("unreadGroups")
						.doc(groupId),
				);
			});
			writes.push((batch) => {
				batch.delete(
					db
						.collection("users")
						.doc(uid)
						.collection("groupSettings")
						.doc(groupId),
				);
			});
			writes.push((batch) => {
				batch.delete(userGroupSummaryRef(uid, groupId));
			});
			writes.push((batch) => {
				batch.delete(groupDoc.ref.collection("memberStates").doc(uid));
			});

			continue;
		}

		writes.push((batch) => {
			batch.set(
				groupDoc.ref,
				{
					updatedAt: admin.firestore.FieldValue.serverTimestamp(),
				},
				{ merge: true },
			);
		});

		writes.push((batch) => {
			batch.set(
				groupDoc.ref.collection("memberStates").doc(uid),
				{
					uid,
					groupId,
					updatedAt: admin.firestore.FieldValue.serverTimestamp(),
				},
				{ merge: true },
			);
		});

		nextUserGroupIds.push(groupId);
		keptGroupIds.push(groupId);
	}

	for (const groupDoc of wantedDefaultGroupDocs) {
		const groupId = groupDoc.id;
		groupDataById.set(groupId, groupDoc.data() || {});

		if (nextUserGroupIds.includes(groupId)) continue;

		writes.push((batch) => {
			batch.set(
				groupDoc.ref,
				{
					memberCount: groupMemberCountPatch(groupDoc.data() || {}, 1),
					updatedAt: admin.firestore.FieldValue.serverTimestamp(),
				},
				{ merge: true },
			);
		});

		writes.push((batch) => {
			batch.set(
				groupDoc.ref.collection("memberStates").doc(uid),
				{
					uid,
					groupId,
					updatedAt: admin.firestore.FieldValue.serverTimestamp(),
				},
				{ merge: true },
			);
		});

		nextUserGroupIds.push(groupId);
		newlyAddedGroupIds.push(groupId);
	}

	writes.push((batch) => {
		batch.set(
			db.collection("users").doc(uid),
			{
				fullName,
				department,
				accountType,
				groupIds: Array.from(new Set(nextUserGroupIds)),
				updatedAt: admin.firestore.FieldValue.serverTimestamp(),
			},
			{ merge: true },
		);
	});

	await commitBatchWrites(writes);

	const newlyAdded = new Set(newlyAddedGroupIds);
	const kept = new Set(keptGroupIds);
	const summaryGroupIds = Array.from(new Set(nextUserGroupIds));

	for (let index = 0; index < summaryGroupIds.length; index += 25) {
		await Promise.all(
			summaryGroupIds.slice(index, index + 25).map(async (groupId) => {
				const groupData = groupDataById.get(groupId);
				if (!groupData) return;

				if (newlyAdded.has(groupId)) {
					await setUserGroupSummary({
						uid,
						groupId,
						groupData,
						unreadCount: 0,
						lastReadMessageTime: Number(groupData.recentMessageTime ?? 0) || 0,
						lastDeliveredMessageTime: 0,
					});
					return;
				}

				if (kept.has(groupId)) {
					await updateUserGroupSummaryCoreFields({
						uid,
						groupId,
						groupData,
					});
				}
			}),
		);
	}
}

async function commitBatchWrites(
	writes: Array<(batch: FirebaseFirestore.WriteBatch) => void>,
	batchSize = 450,
) {
	const db = admin.firestore();

	for (let index = 0; index < writes.length; index += batchSize) {
		const batch = db.batch();
		for (const write of writes.slice(index, index + batchSize)) {
			write(batch);
		}
		await batch.commit();
	}
}

async function deleteUserSubcollectionDocs({
	uid,
	collectionName,
}: {
	uid: string;
	collectionName: string;
}) {
	const db = admin.firestore();
	const collectionRef = db
		.collection("users")
		.doc(uid)
		.collection(collectionName);

	while (true) {
		const snap = await collectionRef.limit(400).get();
		if (snap.empty) break;

		const batch = db.batch();
		for (const doc of snap.docs) {
			batch.delete(doc.ref);
		}
		await batch.commit();

		if (snap.size < 400) break;
	}
}

/**
 * يزيل المستخدم من كل المجموعات وينظف أي بيانات محادثة خاصة به.
 * لا يحذف رسائله القديمة لأن الرسائل جزء من سجل المحادثة.
 */
export async function removeUserFromAllGroupsAndCleanup({
	uid,
	updatedBy = "",
	updateUserDocument = true,
}: {
	uid: string;
	updatedBy?: string;
	updateUserDocument?: boolean;
}) {
	const db = admin.firestore();
	const userRef = db.collection("users").doc(uid);
	const userDoc = await userRef.get();
	const userData = userDoc.data() || {};
	const declaredGroupIds = new Set<string>();

	if (Array.isArray(userData.groupIds)) {
		for (const value of userData.groupIds) {
			const groupId = String(value ?? "").trim();
			if (groupId) declaredGroupIds.add(groupId);
		}
	}


	const groupDocsById = new Map<string, FirebaseFirestore.DocumentSnapshot>();
	for (const doc of await loadGroupDocumentsForUser(uid)) {
		groupDocsById.set(doc.id, doc);
	}

	const declaredGroupIdList = Array.from(declaredGroupIds);
	for (let index = 0; index < declaredGroupIdList.length; index += 300) {
		const refs = declaredGroupIdList
			.slice(index, index + 300)
			.map((groupId) => db.collection("groups").doc(groupId));
		if (refs.length === 0) continue;

		const docs = await db.getAll(...refs);
		for (const doc of docs) {
			if (doc.exists) groupDocsById.set(doc.id, doc);
		}
	}
	const groupDocs = Array.from(groupDocsById.values());
	const memberStateDocs = groupDocs.length > 0
		? await db.getAll(
				...groupDocs.map((groupDoc) => groupMemberStateRef(groupDoc.ref, uid)),
			)
		: [];
	const indexedGroupIds = new Set(
		memberStateDocs
			.filter((doc) => doc.exists)
			.map((doc) => doc.ref.parent.parent?.id),
	);

	const removedGroupIds = groupDocs.map((doc) => doc.id);
	const writes: Array<(batch: FirebaseFirestore.WriteBatch) => void> = [];

	for (const groupDoc of groupDocs) {
		const groupRef = groupDoc.ref;
		const groupData = groupDoc.data() || {};
		const wasMember = indexedGroupIds.has(groupDoc.id);
		writes.push((batch) => {
			batch.set(
				groupRef,
				{
					...(wasMember
						? { memberCount: groupMemberCountPatch(groupData, -1) }
						: {}),
					adminIds: admin.firestore.FieldValue.arrayRemove(uid),
					...(String(groupData.adminId ?? "").trim() === uid
						? { adminId: "", adminName: "" }
						: {}),
					updatedAt: admin.firestore.FieldValue.serverTimestamp(),
					...(updatedBy ? { updatedBy } : {}),
				},
				{ merge: true },
			);
		});

		writes.push((batch) => {
			batch.delete(groupRef.collection("memberStates").doc(uid));
		});
	}

	if (updateUserDocument) {
		writes.push((batch) => {
			batch.set(
				userRef,
				{
					groupIds: [],
					fcmToken: "",
					pendingFcmToken: "",
					removedFromGroupIds: removedGroupIds,
					removedFromGroupsAt: admin.firestore.FieldValue.serverTimestamp(),
					updatedAt: admin.firestore.FieldValue.serverTimestamp(),
					...(updatedBy ? { updatedBy } : {}),
				},
				{ merge: true },
			);
		});
	}

	await commitBatchWrites(writes);

	await Promise.all([
		deleteUserSubcollectionDocs({ uid, collectionName: "unreadGroups" }),
		deleteUserSubcollectionDocs({ uid, collectionName: "groupSettings" }),
		deleteUserSubcollectionDocs({ uid, collectionName: "groupSummaries" }),
		deleteUserSubcollectionDocs({ uid, collectionName: "eventInterests" }),
		deleteUserSubcollectionDocs({ uid, collectionName: "savedMessages" }),
	]);

	return {
		removedGroupIds,
		removedGroupCount: removedGroupIds.length,
	};
}
