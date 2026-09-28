import '../../core/permissions/app_roles.dart';
import '../../core/constants/app_account_statuses.dart';

class AppUser {
  final String uid;
  final String fullName;
  final String email;
  final String userId;
  final String department;
  final String phone;
  final String phoneE164;
  final String role;
  final String accountType;
  final String accountStatus;
  final String accountStatusReason;
  final String profilepic;
  final List<String> groupIds;

  const AppUser({
    required this.uid,
    required this.fullName,
    required this.email,
    required this.userId,
    required this.department,
    required this.phone,
    required this.phoneE164,
    required this.role,
    required this.accountType,
    required this.accountStatus,
    required this.accountStatusReason,
    required this.profilepic,
    required this.groupIds,
  });

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      groupIds:
      (map['groupIds'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
      uid: (map['uid'] ?? '').toString(),
      fullName: (map['fullName'] ?? '').toString(),
      email: (map['email'] ?? '').toString(),
      userId: (map['userId'] ?? '').toString(),
      department: (map['department'] ?? '').toString(),
      phone: (map['phone'] ?? '').toString(),
      phoneE164: (map['phoneE164'] ?? '').toString(),
      role: (map['role'] ?? AppRoles.user).toString(),
      accountType: (map['accountType'] ?? AppRoles.user).toString(),
      accountStatus: AppAccountStatuses.normalize(map['accountStatus']),
      accountStatusReason: (map['accountStatusReason'] ?? '').toString(),
      profilepic: (map['profilepic'] ?? '').toString(),
    );
  }

  bool get isSystemAdmin => AppRoles.isSystemAdmin(role);
  bool get isDean => AppRoles.isDean(role);
  bool get isDepartmentStaff => AppRoles.isDepartmentStaff(role);
  bool get isStudent => AppRoles.isStudent(role);
  bool get canOpenDashboard => AppRoles.isSystemAdmin(role) || AppRoles.isDean(role);
  bool get canViewAuditLogs => AppRoles.isSystemAdmin(role);
  bool get canUseBulkImport => AppRoles.isSystemAdmin(role);
  bool get isSuspended => AppAccountStatuses.isSuspended(accountStatus);
  bool get isRemoved => AppAccountStatuses.isRemoved(accountStatus);
}
