import { HttpsError } from "firebase-functions/v2/https";

export const GROUP_AUDIENCES = {
	department: "department",
	doctorsDepartment: "doctors_department",
	doctorsAll: "doctors_all",
	workers: "workers",
	deansAll: "deans_all",
	employeesAll: "employees_all",
	presidency: "presidency",
} as const;

export const WORKER_DEPARTMENT = "عامل";

const CREATABLE_GROUP_AUDIENCES = new Set<string>([
	GROUP_AUDIENCES.department,
	GROUP_AUDIENCES.doctorsDepartment,
	GROUP_AUDIENCES.doctorsAll,
	GROUP_AUDIENCES.workers,
]);

export function normalizeCreatableGroupAudience(value: unknown): string {
	const audience = String(value ?? GROUP_AUDIENCES.department).trim();
	return CREATABLE_GROUP_AUDIENCES.has(audience)
		? audience
		: GROUP_AUDIENCES.department;
}

export function resolveGroupAudience(
	groupData: Record<string, any>,
): string {
	const explicitAudience = String(groupData.audience ?? "").trim();
	if (explicitAudience) return explicitAudience;

	switch (String(groupData.groupName ?? "").trim()) {
		case "main_doctor":
			return GROUP_AUDIENCES.doctorsAll;
		case "main_worker":
			return GROUP_AUDIENCES.workers;
		case "main_dean":
			return GROUP_AUDIENCES.deansAll;
		case "main_employee":
			return GROUP_AUDIENCES.employeesAll;
		case "main_presidency_employee":
			return GROUP_AUDIENCES.presidency;
		default:
			return GROUP_AUDIENCES.department;
	}
}

export function isDoctorCollaborator(userData: Record<string, any>): boolean {
	const role = String(userData.role ?? "user").trim();
	const accountType = String(userData.accountType ?? "user").trim();
	return role === "admin1" || accountType === "dean" || accountType === "doctor";
}

export function isWorkerCollaborator(userData: Record<string, any>): boolean {
	const role = String(userData.role ?? "user").trim();
	const department = String(userData.department ?? "").trim();
	const accountType = String(userData.accountType ?? "user").trim();
	return (
		department === WORKER_DEPARTMENT &&
		(accountType === "worker" || role === "admin1" || role === "admin2")
	);
}

export function shouldScanAllDepartments(
	userData: Record<string, any>,
): boolean {
	const role = String(userData.role ?? "user").trim();
	const accountType = String(userData.accountType ?? "user").trim();
	return (
		role === "admin0" ||
		["doctor", "dean", "employee", "presidency_employee"].includes(
			accountType,
		)
	);
}

export function canUserAccessGroup({
	groupData,
	userData,
}: {
	groupData: Record<string, any>;
	userData: Record<string, any>;
}): boolean {
	const role = String(userData.role ?? "user").trim();
	if (role === "admin0") return true;

	const groupName = String(groupData.groupName ?? "").trim();
	if (groupName === "main_wpu") return true;

	const audience = resolveGroupAudience(groupData);
	const userDepartment = String(userData.department ?? "").trim();
	const groupDepartment = String(groupData.department ?? "").trim();
	const accountType = String(userData.accountType ?? "user").trim();

	switch (audience) {
		case GROUP_AUDIENCES.doctorsDepartment:
			return (
				isDoctorCollaborator(userData) &&
				userDepartment.length > 0 &&
				userDepartment === groupDepartment
			);
		case GROUP_AUDIENCES.doctorsAll:
			return isDoctorCollaborator(userData);
		case GROUP_AUDIENCES.workers:
			return isWorkerCollaborator(userData);
		case GROUP_AUDIENCES.deansAll:
			return role === "admin1" || accountType === "dean";
		case GROUP_AUDIENCES.employeesAll:
			return accountType === "employee";
		case GROUP_AUDIENCES.presidency:
			return accountType === "presidency_employee";
		default:

			return (
				userDepartment.length > 0 &&
				groupDepartment.length > 0 &&
				userDepartment === groupDepartment
			);
	}
}

export function assertWorkerAccountCompatibility({
	department,
	accountType,
}: {
	department: string;
	accountType: string;
}) {
	const isWorkerDepartment = department.trim() === WORKER_DEPARTMENT;
	const isWorkerAccount = accountType.trim() === "worker";

	if (isWorkerDepartment !== isWorkerAccount) {
		throw new HttpsError(
			"invalid-argument",
			"قسم عامل يجب أن يستخدم نوع حساب عامل، والعكس صحيح",
		);
	}
}
