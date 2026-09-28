import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import {
	assertAdminRoleOrThrow,
	buildManagedUserResponse,
	canViewOrManageTargetUser,
	matchesUserSearch,
	normalizeSearch,
	normalizeAppRole,
} from "../services/dashboard-user.service";
import { normalizeManagedAccountStatus } from "../services/managed-user-status.service";

function normalizeRoleFilter(value: unknown) {
	const raw = String(value ?? "").trim();

	if (!raw || raw === "all" || raw === "dashboard.role_all") return "";

	switch (raw) {
		case "student":
		case "role_student":
		case "dashboard.role_student":
		case "طالب":
			return "user";

		case "super_admin":
		case "role_admin0":
		case "dashboard.role_admin0":
		case "إدارة عليا":
		case "مدير النظام":
			return "admin0";

		case "dean":
		case "role_admin1":
		case "dashboard.role_admin1":
		case "عميد":
			return "admin1";

		case "supervisor":
		case "doctor":
		case "employee":
		case "role_admin2":
		case "dashboard.role_admin2":
		case "مشرف":
		case "دكتور":
		case "موظف":
		case "موظف قسم":
			return "admin2";

		default:
			return raw;
	}
}

function normalizedPageLimit(value: unknown) {
	const raw = Number(value ?? 100);
	if (!Number.isFinite(raw)) return 100;
	return Math.max(20, Math.min(Math.floor(raw), 200));
}

export const listManagedUsers = onCall(async (request) => {
	if (!request.auth) {
		throw new HttpsError("unauthenticated", "يجب تسجيل الدخول");
	}

	const callerData = await assertAdminRoleOrThrow(request.auth.uid, [
		"admin0",
		"admin1",
		"admin2",
	]);

	const query = String(request.data.query ?? "");
	const callerRole = normalizeAppRole(callerData.role);
	const callerDepartment = String(callerData.department ?? "").trim();
	const requestedDepartment = String(request.data.department ?? "").trim();
	const department =
		callerRole === "admin0" ? requestedDepartment : callerDepartment;
	let role = normalizeRoleFilter(request.data.role);
	const rawAccountStatus = String(request.data.accountStatus ?? "").trim();
	const accountStatus = rawAccountStatus
		? normalizeManagedAccountStatus(rawAccountStatus)
		: "";
	const limit = normalizedPageLimit(request.data.limit);
	const cursorUid = String(request.data.cursorUid ?? "").trim();

	if (callerRole !== "admin0" && !department) {
		return {
			success: true,
			users: [],
			hasMore: false,
			nextCursorUid: "",
		};
	}

	if (callerRole === "admin2") {
		if (role && role !== "user") {
			return {
				success: true,
				users: [],
				hasMore: false,
				nextCursorUid: "",
			};
		}

		role = "user";
	}

	let ref: FirebaseFirestore.Query = admin.firestore().collection("users");

	if (department) {
		ref = ref.where("department", "==", department);
	}

	if (role === "user") {
		ref = ref.where("role", "in", ["user", "student"]);
	} else if (role) {
		ref = ref.where("role", "==", role);
	}

	if (accountStatus && accountStatus !== "active") {
		ref = ref.where("accountStatus", "==", accountStatus);
	}

	const normalizedQuery = normalizeSearch(query);
	const users: ReturnType<typeof buildManagedUserResponse>[] = [];
	const serverPageSize = Math.max(limit, 200);
	const maxScanPages = 8;
	let scannedCursorUid = cursorUid;
	let hasMore = false;

	for (let page = 0; page < maxScanPages && users.length < limit; page++) {
		let pageQuery = ref
			.orderBy(admin.firestore.FieldPath.documentId())
			.limit(serverPageSize);

		if (scannedCursorUid) {
			pageQuery = pageQuery.startAfter(scannedCursorUid);
		}

		const snapshot = await pageQuery.get();
		if (snapshot.empty) {
			hasMore = false;
			scannedCursorUid = "";
			break;
		}

		const lastDocument = snapshot.docs.at(-1);
		if (!lastDocument) break;
		scannedCursorUid = lastDocument.id;
		hasMore = snapshot.size === serverPageSize;

		for (const doc of snapshot.docs) {
			const data = doc.data() || {};

			if (
				accountStatus &&
				normalizeManagedAccountStatus(data.accountStatus) !== accountStatus
			)
				continue;
			if (!canViewOrManageTargetUser(callerData, data)) continue;
			if (!matchesUserSearch(data, normalizedQuery)) continue;

			users.push(buildManagedUserResponse(doc.id, data));
			if (users.length >= limit) break;
		}

		if (!hasMore) {
			scannedCursorUid = "";
			break;
		}
	}

	users.sort((a, b) =>
		String(a.fullName ?? "").localeCompare(String(b.fullName ?? ""), "ar"),
	);

	return {
		success: true,
		users,
		hasMore,
		nextCursorUid: hasMore ? scannedCursorUid : "",
	};
});
