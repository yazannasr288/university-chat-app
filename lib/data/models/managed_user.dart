import '../../core/permissions/app_roles.dart';
import '../../core/constants/app_account_statuses.dart';

class ManagedUser {
  final String uid;
  final String fullName;
  final String userId;
  final String department;
  final String role;
  final String accountType;
  final String accountStatus;
  final String phone;
  final String email;

  const ManagedUser({
    required this.uid,
    required this.fullName,
    required this.userId,
    required this.department,
    required this.role,
    required this.accountType,
    required this.accountStatus,
    required this.phone,
    required this.email,
  });

  factory ManagedUser.fromMap(Map<String, dynamic> map) {
    final email = (map['email'] ?? '').toString().trim();
    final rawUserId = (map['userId'] ?? '').toString().trim();

    return ManagedUser(
      uid: (map['uid'] ?? '').toString().trim(),
      fullName: (map['fullName'] ?? '').toString().trim(),
      userId: rawUserId.isNotEmpty ? rawUserId : _userIdFromEmail(email),
      department: (map['department'] ?? '').toString().trim(),
      role: (map['role'] ?? AppRoles.user).toString().trim(),
      accountType: (map['accountType'] ?? AppRoles.user).toString().trim(),
      accountStatus: AppAccountStatuses.normalize(map['accountStatus']),
      phone: (map['phone'] ?? '').toString().trim(),
      email: email,
    );
  }

  static String _userIdFromEmail(String email) {
    final atIndex = email.indexOf('@');
    if (atIndex <= 0) return '';
    return email.substring(0, atIndex).trim();
  }

  bool get isStudent => AppRoles.isStudent(role);
  bool get isActive => AppAccountStatuses.isActive(accountStatus);
  bool get isSuspended => AppAccountStatuses.isSuspended(accountStatus);
  bool get isRemoved => AppAccountStatuses.isRemoved(accountStatus);

  String get displayUserId {
    if (userId.trim().isNotEmpty) return userId.trim();
    final fromEmail = _userIdFromEmail(email);
    return fromEmail.isNotEmpty ? fromEmail : uid;
  }
}
