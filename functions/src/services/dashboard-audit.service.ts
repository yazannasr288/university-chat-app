import * as admin from "firebase-admin";

export type DashboardAuditLevel = "info" | "warning" | "critical";
export type DashboardAuditCategory =
	| "events"
	| "students"
	| "groups"
	| "notifications"
	| "system";
export type DashboardAuditTargetType =
	| "user"
	| "group"
	| "event"
	| "notification"
	| "system";

type UserAuditMeta = {
	name: string;
	userId: string;
	department: string;
	accountType: string;
	role: string;
	email: string;
};

function userIdFromEmail(email: string) {
	const index = email.indexOf("@");
	return index > 0 ? email.slice(0, index).trim() : "";
}

async function loadUserAuditMeta(uid: string): Promise<UserAuditMeta> {
	const empty: UserAuditMeta = {
		name: "",
		userId: "",
		department: "",
		accountType: "",
		role: "",
		email: "",
	};

	const normalizedUid = String(uid ?? "").trim();
	if (!normalizedUid) return empty;

	const doc = await admin
		.firestore()
		.collection("users")
		.doc(normalizedUid)
		.get()
		.catch(() => null);

	if (!doc?.exists) return empty;

	const data = doc.data() || {};
	const email = String(data.email ?? "").trim();
	const explicitUserId = String(data.userId ?? "").trim();

	return {
		name: String(data.fullName ?? "").trim(),
		userId: explicitUserId || userIdFromEmail(email),
		department: String(data.department ?? "").trim(),
		accountType: String(data.accountType ?? "").trim(),
		role: String(data.role ?? "").trim(),
		email,
	};
}

function categoryForTargetType(
	targetType: DashboardAuditTargetType,
): DashboardAuditCategory {
	switch (targetType) {
		case "event":
			return "events";
		case "user":
			return "students";
		case "group":
			return "groups";
		case "notification":
			return "notifications";
		default:
			return "system";
	}
}

function normalizeCategory(
	category: DashboardAuditCategory | undefined,
	targetType: DashboardAuditTargetType,
): DashboardAuditCategory {
	return category || categoryForTargetType(targetType);
}

export async function writeDashboardAuditLog({
	actorUid,
	actorRole,
	action,
	category,
	level = "info",
	targetType = "system",
	targetId = "",
	targetLabel = "",
	summary = "",
	details = {},
}: {
	actorUid: string;
	actorRole: string;
	action: string;
	category?: DashboardAuditCategory;
	level?: DashboardAuditLevel;
	targetType?: DashboardAuditTargetType;
	targetId?: string;
	targetLabel?: string;
	summary?: string;
	details?: Record<string, any>;
}) {
	const actorMeta = await loadUserAuditMeta(actorUid);
	const targetMeta =
		targetType === "user"
			? await loadUserAuditMeta(targetId)
			: {
					name: "",
					userId: "",
					department: "",
					accountType: "",
					role: "",
					email: "",
				};

	const normalizedCategory = normalizeCategory(category, targetType);
	const resolvedTargetLabel = targetLabel || targetMeta.name;

	await admin
		.firestore()
		.collection("dashboardAuditLogs")
		.add({
			actorUid,
			actorRole: actorRole || actorMeta.role,
			actorName: actorMeta.name,
			actorDisplayName: actorMeta.name,
			actorUserId: actorMeta.userId,
			actorDepartment: actorMeta.department,
			actorAccountType: actorMeta.accountType,
			action,
			category: normalizedCategory,
			level,
			targetType,
			targetId,
			targetLabel: resolvedTargetLabel,
			targetDisplayName: resolvedTargetLabel,
			targetName: targetMeta.name,
			targetUserId: targetMeta.userId,
			targetDepartment: targetMeta.department,
			targetAccountType: targetMeta.accountType,
			summary,
			details,
			schemaVersion: 4,
			createdAt: admin.firestore.FieldValue.serverTimestamp(),
		});
}

