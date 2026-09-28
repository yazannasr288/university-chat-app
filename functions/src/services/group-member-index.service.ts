import * as admin from "firebase-admin";

const MEMBER_STATE_PAGE_SIZE = 500;
const GROUP_DOCUMENT_FETCH_SIZE = 300;

function cleanUid(value: unknown): string {
	return String(value ?? "").trim();
}

export function groupMemberStateRef(
	groupRef: FirebaseFirestore.DocumentReference,
	uid: string,
) {
	return groupRef.collection("memberStates").doc(uid.trim());
}

export async function isIndexedGroupMember({
	groupRef,
	uid,
}: {
	groupRef: FirebaseFirestore.DocumentReference;
	uid: string;
	groupData?: Record<string, any>;
}): Promise<boolean> {
	const memberUid = cleanUid(uid);
	if (!memberUid) return false;

	const memberState = await groupMemberStateRef(groupRef, memberUid).get();
	return memberState.exists;
}

export async function listIndexedGroupMemberUids({
	groupRef,
}: {
	groupRef: FirebaseFirestore.DocumentReference;
	groupData?: Record<string, any>;
}): Promise<string[]> {
	const memberUids = new Set<string>();
	let lastDocument:
		| FirebaseFirestore.QueryDocumentSnapshot
		| undefined;

	while (true) {
		let query = groupRef
			.collection("memberStates")
			.orderBy(admin.firestore.FieldPath.documentId())
			.limit(MEMBER_STATE_PAGE_SIZE);

		if (lastDocument) {
			query = query.startAfter(lastDocument);
		}

		const snapshot = await query.select("uid").get();
		for (const document of snapshot.docs) {
			const uid = cleanUid(document.data().uid || document.id);
			if (uid) memberUids.add(uid);
		}

		if (snapshot.size < MEMBER_STATE_PAGE_SIZE) break;
		lastDocument = snapshot.docs.at(-1);
		if (!lastDocument) break;
	}

	return Array.from(memberUids);
}

export function groupMemberCountPatch(
	groupData: Record<string, any>,
	delta: number,
): number | FirebaseFirestore.FieldValue {
	const currentCount = Number(groupData.memberCount);

	if (!Number.isFinite(currentCount) || currentCount < 0) {
		return Math.max(0, delta);
	}

	if (currentCount === 0 && delta < 0) return 0;
	return admin.firestore.FieldValue.increment(delta);
}

export async function loadGroupDocumentsForUser(
	uid: string,
): Promise<FirebaseFirestore.DocumentSnapshot[]> {
	const memberUid = cleanUid(uid);
	if (!memberUid) return [];

	const db = admin.firestore();
	const userDoc = await db.collection("users").doc(memberUid).get();
	if (!userDoc.exists) return [];

	const userData = userDoc.data() || {};
	const groupIds = Array.isArray(userData.groupIds)
		? Array.from(
				new Set(
					userData.groupIds
						.map(cleanUid)
						.filter((groupId: string) => groupId.length > 0),
				),
			)
		: [];
	const groupDocuments: FirebaseFirestore.DocumentSnapshot[] = [];

	for (
		let index = 0;
		index < groupIds.length;
		index += GROUP_DOCUMENT_FETCH_SIZE
	) {
		const groupRefs = groupIds
			.slice(index, index + GROUP_DOCUMENT_FETCH_SIZE)
			.map((groupId) => db.collection("groups").doc(groupId));
		const documents = await db.getAll(...groupRefs);
		const existingDocuments = documents.filter((document) => document.exists);
		if (existingDocuments.length === 0) continue;

		const memberStates = await db.getAll(
			...existingDocuments.map((document) =>
				groupMemberStateRef(document.ref, memberUid),
			),
		);

		for (const [documentIndex, document] of existingDocuments.entries()) {
			if (memberStates[documentIndex]?.exists) {
				groupDocuments.push(document);
			}
		}
	}

	return groupDocuments;
}
