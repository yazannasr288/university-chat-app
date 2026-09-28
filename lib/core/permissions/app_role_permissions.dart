import '../../data/models/app_user.dart';
import 'app_roles.dart';

class AppRolePermissions {
  const AppRolePermissions._();

  static bool isSystemAdminRole(String role) => AppRoles.isSystemAdmin(role);
  static bool isDeanRole(String role) => AppRoles.isDean(role);
  static bool isDepartmentStaffRole(String role) =>
      AppRoles.isDepartmentStaff(role);
  static bool isStudentRole(String role) => AppRoles.isStudent(role);
  static bool isDashboardRole(String role) =>
      AppRoles.isSystemAdmin(role) || AppRoles.isDean(role);
  static bool isNotificationSenderRole(String role) => AppRoles.isAdmin(role);

  static bool isSystemAdmin(AppUser? user) =>
      isSystemAdminRole(user?.role ?? '');
  static bool isDean(AppUser? user) => isDeanRole(user?.role ?? '');
  static bool isDepartmentStaff(AppUser? user) =>
      isDepartmentStaffRole(user?.role ?? '');
  static bool isStudent(AppUser? user) =>
      isStudentRole(user?.role ?? AppRoles.user);

  static bool canOpenDashboard(AppUser? user) =>
      isDashboardRole(user?.role ?? '');

  static bool canViewAuditLogs(AppUser? user) => isSystemAdmin(user);
  static bool canViewAuditLogsRole(String role) => isSystemAdminRole(role);

  static bool canViewNotificationCampaigns(AppUser? user) =>
      isNotificationSenderRole(user?.role ?? '');

  static bool canUseBulkImport(AppUser? user) => isSystemAdmin(user);

  static bool canCreateUniversityEvent(AppUser? user) => isSystemAdmin(user);

  static bool canCreateDepartmentEvent(AppUser? user) {
    final role = user?.role ?? '';
    return isSystemAdminRole(role) ||
        isDeanRole(role) ||
        isDepartmentStaffRole(role);
  }

  static bool canCreateGroupEvent(AppUser? user) =>
      isNotificationSenderRole(user?.role ?? '');

  static bool canCreateAnyEvent(AppUser? user) =>
      isNotificationSenderRole(user?.role ?? '');

  static bool canManageAllDepartments(AppUser? user) => isSystemAdmin(user);

  static bool canManageDepartment(AppUser? user, String department) {
    if (isSystemAdmin(user)) return true;
    return isNotificationSenderRole(user?.role ?? '') &&
        (user?.department ?? '') == department;
  }

  static int getRoleRank(String role) {
    switch (role.trim()) {
      case AppRoles.systemAdmin:
        return 3;
      case AppRoles.dean:
        return 2;
      case AppRoles.departmentStaff:
        return 1;
      default:
        return 0; // student/user
    }
  }

  static bool canManageUsersRole(String role) =>
      isSystemAdminRole(role) || isDeanRole(role);

  static bool canAddUsersRole(String role) => isSystemAdminRole(role);

  static bool canDeleteUsersRole(String role) => isSystemAdminRole(role);

  static bool canFreezeUsersRole(String role) =>
      isSystemAdminRole(role) || isDeanRole(role);

  static bool canAccessManagedGroupsRole(String role) => AppRoles.isAdmin(role);

  static bool canManageRestrictedGroupMessagesRole(String role) {
    return isSystemAdminRole(role) || isDeanRole(role);
  }

  static bool isGroupAdminUid({
    required String currentUid,
    required String groupAdminId,
    List<String> groupAdminIds = const <String>[],
  }) {
    final uid = currentUid.trim();
    if (uid.isEmpty) {
      return false;
    }
    return groupAdminId.trim() == uid ||
        groupAdminIds
            .map((id) => id.trim())
            .where((id) => id.isNotEmpty)
            .contains(uid);
  }

  static bool canSendToRestrictedGroup({
    required String currentUid,
    required String groupAdminId,
    required String role,
    List<String> groupAdminIds = const <String>[],
  }) {
    return isGroupAdminUid(
          currentUid: currentUid,
          groupAdminId: groupAdminId,
          groupAdminIds: groupAdminIds,
        ) ||
        canManageRestrictedGroupMessagesRole(role);
  }

  static bool canManageGroup({
    required String groupAdminId,
    required String currentUid,
    required String currentRole,
    required String currentDepartment,
    required String groupDepartment,
    required String groupName,
    List<String> groupAdminIds = const <String>[],
  }) {
    final cleanGroupName = groupName.trim();
    final cleanRole = currentRole.trim();

    if (cleanGroupName == 'main_wpu') {
      return cleanRole == AppRoles.systemAdmin;
    }

    if (isGroupAdminUid(
      currentUid: currentUid,
      groupAdminId: groupAdminId,
      groupAdminIds: groupAdminIds,
    )) {
      return true;
    }
    if (cleanRole == AppRoles.systemAdmin) {
      return true;
    }

    if (cleanRole == AppRoles.dean) {
      return currentDepartment.trim().isNotEmpty &&
          currentDepartment.trim() == groupDepartment.trim();
    }

    return false;
  }

  static bool canManageEventSync({
    required AppUser user,
    required String createdBy,
    required String scopeType,
    required String department,
    String? groupAdminId,
    List<String> groupAdminIds = const <String>[],
  }) {
    if (user.uid.trim() == createdBy.trim()) return true;
    if (isSystemAdmin(user)) return true;

    if (scopeType == 'department') {
      return (isDean(user) || isDepartmentStaff(user)) &&
          user.department.trim() == department.trim();
    }

    if (scopeType == 'group') {
      return isGroupAdminUid(
        currentUid: user.uid,
        groupAdminId: groupAdminId ?? '',
        groupAdminIds: groupAdminIds,
      );
    }

    return false;
  }

  static bool canDepartmentStaffManageGroupEvent({
    required AppUser user,
    required String groupAdminId,
    List<String> groupAdminIds = const <String>[],
  }) {
    return isDepartmentStaff(user) &&
        isGroupAdminUid(
          currentUid: user.uid,
          groupAdminId: groupAdminId,
          groupAdminIds: groupAdminIds,
        );
  }
}
