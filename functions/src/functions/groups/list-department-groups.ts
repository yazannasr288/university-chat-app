import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import {
	assertSignedIn,
	buildSafeGroupSummary,
	getCallerData,
} from "../../services/group-chat.service";
import { fastCallableOptions } from "../../runtime-options";
import {
	canUserAccessGroup,
	shouldScanAllDepartments,
} from "../../services/group-access.service";
import { loadGroupDocumentsForUser } from "../../services/group-member-index.service";

export const listDepartmentGroups = onCall(
	fastCallableOptions,
	async (request) => {
		const callerUid = assertSignedIn(request);
		const callerData = await getCallerData(callerUid);
		const callerRole = String(callerData.role ?? "user").trim();
		const callerDepartment = String(callerData.department ?? "").trim();
		const includeAllDepartments = request.data.allDepartments === true;
		const scanAllDepartments =
			includeAllDepartments || shouldScanAllDepartments(callerData);
		const requestedLimit = Number(request.data.limit ?? 300);
		const limit = Math.max(
			1,
			Math.min(
				500,
				Math.floor(Number.isFinite(requestedLimit) ? requestedLimit : 300),
			),
		);
		const cursorGroupName = String(request.data.cursorGroupName ?? "").trim();
		const cursorGroupId = String(request.data.cursorGroupId ?? "").trim();

		if (includeAllDepartments && callerRole !== "admin0") {
			throw new HttpsError("permission-denied", "ليس لديك صلاحية");
		}

		if (!scanAllDepartments && !callerDepartment) {
			throw new HttpsError("failed-precondition", "القسم غير محدد");
		}

		let groupsQuery: FirebaseFirestore.Query = admin
			.firestore()
			.collection("groups")
			.where("isActive", "==", true);

		if (!scanAllDepartments) {
			groupsQuery = groupsQuery.where("department", "==", callerDepartment);
		}

		let orderedQuery = groupsQuery
			.orderBy("groupName")
			.orderBy(admin.firestore.FieldPath.documentId());

		if (cursorGroupName && cursorGroupId) {
			orderedQuery = orderedQuery.startAfter(cursorGroupName, cursorGroupId);
		}

		const groupsSnap = await orderedQuery
			.limit(limit + 1)
			.select(
				"groupId",
				"groupName",
				"groupIcon",
				"adminName",
				"department",
				"audience",
				"createdAt",
				"isActive",
			)
			.get();

		const hasMore = groupsSnap.size > limit;
		const pageDocuments = groupsSnap.docs.slice(0, limit);
		const joinedGroupIds = new Set(
			(await loadGroupDocumentsForUser(callerUid)).map((doc) => doc.id),
		);
		const groups = pageDocuments
			.filter((doc) => {
				const isJoined = joinedGroupIds.has(doc.id);
				return canUserAccessGroup({
					groupData: { groupId: doc.id, ...doc.data() },
					userData: { ...callerData, isGroupMember: isJoined },
				});
			})
			.map((doc) =>
				buildSafeGroupSummary(
					{ groupId: doc.id, ...doc.data() },
					callerUid,
					joinedGroupIds.has(doc.id),
				),
			)
			.filter((group) => String(group.groupId).trim().length > 0);
		const lastDocument = pageDocuments.at(-1);

		return {
			success: true,
			groups,
			hasMore,
			nextCursor:
				hasMore && lastDocument
					? {
							groupName: String(lastDocument.get("groupName") ?? ""),
							groupId: lastDocument.id,
						}
					: null,
		};
	},
);
