import { HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import { mapDepartmentToGroup } from "../utils/group-mapping";
import { ResolveScopeMetaArgs, ScopeMeta } from "../types/event-types";

export async function resolveGroupByName(groupName: string) {
	const snap = await admin
		.firestore()
		.collection("groups")
		.where("groupName", "==", groupName)
		.limit(1)
		.get();

	if (snap.empty) {
		throw new HttpsError(
			"failed-precondition",
			`مجموعة الأحداث ${groupName} غير موجودة`,
		);
	}

	const doc = snap.docs.at(0);
	if (!doc) {
		throw new HttpsError(
			"failed-precondition",
			`مجموعة الأحداث ${groupName} غير موجودة`,
		);
	}
	return {
		targetGroupId: doc.id,
		targetGroupName: String(doc.data().groupName ?? groupName),
	};
}

export async function resolveDepartmentMainGroup(department: string) {
	return resolveGroupByName(mapDepartmentToGroup(department));
}

export async function resolveScopeMeta({
	scopeType,
	groupId,
	callerUid,
	callerRole,
	callerDepartment,
}: ResolveScopeMetaArgs): Promise<ScopeMeta> {
	if (scopeType === "university") {
		if (callerRole !== "admin0") {
			throw new HttpsError(
				"permission-denied",
				"ليس لديك صلاحية إنشاء حدث جامعي",
			);
		}

		const g = await resolveGroupByName("main_wpu");
		return {
			department: "",
			targetGroupId: g.targetGroupId,
			targetGroupName: g.targetGroupName,
			visibilityKeys: ["all"],
		};
	}

	if (scopeType === "department") {
		if (!["admin0", "admin1", "admin2"].includes(callerRole)) {
			throw new HttpsError(
				"permission-denied",
				"ليس لديك صلاحية إنشاء حدث قسم",
			);
		}
		if (!callerDepartment)
			throw new HttpsError("failed-precondition", "القسم غير محدد");

		const g = await resolveDepartmentMainGroup(callerDepartment);
		return {
			department: callerDepartment,
			targetGroupId: g.targetGroupId,
			targetGroupName: g.targetGroupName,
			visibilityKeys: [`dept:${callerDepartment}`],
		};
	}

	if (!groupId)
		throw new HttpsError("invalid-argument", "groupId مطلوب لحدث الغرفة");

	const groupDoc = await admin
		.firestore()
		.collection("groups")
		.doc(groupId)
		.get();
	if (!groupDoc.exists)
		throw new HttpsError("not-found", "المجموعة غير موجودة");

	const groupData = groupDoc.data() || {};
	const adminId = String(groupData.adminId ?? "").trim();
	const adminIds = Array.isArray(groupData.adminIds)
		? groupData.adminIds.map((id: any) => String(id).trim()).filter(Boolean)
		: [];
	const groupDepartment = String(groupData.department ?? "").trim();

	const canManageGroup =
		callerRole === "admin0" ||
		(callerRole === "admin1" &&
			!!callerDepartment &&
			groupDepartment === callerDepartment) ||
		adminId === callerUid ||
		adminIds.includes(callerUid);

	if (!canManageGroup) {
		throw new HttpsError(
			"permission-denied",
			"ليس لديك صلاحية إنشاء حدث لهذه الغرفة",
		);
	}

	const targetGroupName = String(groupData.groupName ?? "").trim();
	if (!targetGroupName)
		throw new HttpsError("failed-precondition", "اسم الغرفة غير صالح");

	return {
		department: groupDepartment || String(callerDepartment ?? ""),
		targetGroupId: groupId,
		targetGroupName,
		visibilityKeys: [`group:${groupId}`],
	};
}

export async function publishEventMessageToGroup({
	groupId,
	eventId,
	title,
	createdBy,
	createdByName,
}: {
	groupId: string;
	eventId: string;
	title: string;
	createdBy: string;
	createdByName: string;
}) {
	if (!groupId.trim()) {
		throw new HttpsError("failed-precondition", "مجموعة نشر الحدث غير محددة");
	}

	const groupRef = admin.firestore().collection("groups").doc(groupId);
	const groupDoc = await groupRef.get();

	if (!groupDoc.exists) {
		throw new HttpsError("failed-precondition", "مجموعة نشر الحدث غير موجودة");
	}

	const messageRef = groupRef.collection("messages").doc();
	const now = Date.now();

	await messageRef.set({
		sender: createdByName,
		senderId: createdBy,
		time: now,
		createdAt: admin.firestore.FieldValue.serverTimestamp(),
		type: "event",
		message: title,
		eventId,
	});
}
