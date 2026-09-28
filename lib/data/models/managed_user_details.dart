import '../../core/permissions/app_roles.dart';
import '../../core/constants/app_account_statuses.dart';

class ManagedUserDetails {
  final String uid;
  final String fullName;
  final String userId;
  final String department;
  final String role;
  final String accountType;
  final String accountStatus;
  final String accountStatusReason;
  final String phone;
  final String phoneE164;
  final String email;
  final List<String> groupIds;
  final bool hasPin;
  final bool pinResetRequired;
  final bool mustChangePassword;
  final String activeDeviceName;
  final String pendingDeviceName;

  const ManagedUserDetails({
    required this.uid,
    required this.fullName,
    required this.userId,
    required this.department,
    required this.role,
    required this.accountType,
    required this.accountStatus,
    required this.accountStatusReason,
    required this.phone,
    required this.phoneE164,
    required this.email,
    required this.groupIds,
    required this.hasPin,
    required this.pinResetRequired,
    required this.mustChangePassword,
    required this.activeDeviceName,
    required this.pendingDeviceName,
  });

  factory ManagedUserDetails.fromMap(Map<String, dynamic> map) {
    final email = (map['email'] ?? '').toString().trim();
    final rawUserId = (map['userId'] ?? '').toString().trim();

    return ManagedUserDetails(
      uid: (map['uid'] ?? '').toString().trim(),
      fullName: (map['fullName'] ?? '').toString().trim(),
      userId: rawUserId.isNotEmpty ? rawUserId : _userIdFromEmail(email),
      department: (map['department'] ?? '').toString().trim(),
      role: (map['role'] ?? AppRoles.user).toString().trim(),
      accountType: (map['accountType'] ?? AppRoles.user).toString().trim(),
      accountStatus: AppAccountStatuses.normalize(map['accountStatus']),
      accountStatusReason: (map['accountStatusReason'] ?? '').toString().trim(),
      phone: (map['phone'] ?? '').toString().trim(),
      phoneE164: (map['phoneE164'] ?? '').toString().trim(),
      email: email,
      groupIds: (map['groupIds'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      hasPin: map['hasPin'] == true,
      pinResetRequired: map['pinResetRequired'] == true,
      mustChangePassword: map['mustChangePassword'] == true,
      activeDeviceName: (map['activeDeviceName'] ?? '').toString().trim(),
      pendingDeviceName: (map['pendingDeviceName'] ?? '').toString().trim(),
    );
  }

  static String _userIdFromEmail(String email) {
    final atIndex = email.indexOf('@');
    if (atIndex <= 0) return '';
    return email.substring(0, atIndex).trim();
  }

  String get displayUserId {
    if (userId.trim().isNotEmpty) return userId.trim();
    final fromEmail = _userIdFromEmail(email);
    return fromEmail.isNotEmpty ? fromEmail : uid;
  }
}
