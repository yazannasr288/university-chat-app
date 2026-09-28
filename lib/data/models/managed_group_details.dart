import '../../core/permissions/app_roles.dart';
import '../../core/constants/app_account_statuses.dart';

import 'managed_group_summary.dart';

class ManagedGroupMember {
  final String uid;
  final String fullName;
  final String userId;
  final String department;
  final String role;
  final String accountType;
  final String accountStatus;
  final String phone;
  final String email;
  final bool isAdmin;

  const ManagedGroupMember({
    required this.uid,
    required this.fullName,
    required this.userId,
    required this.department,
    required this.role,
    required this.accountType,
    required this.accountStatus,
    required this.phone,
    required this.email,
    required this.isAdmin,
  });

  factory ManagedGroupMember.fromMap(Map<String, dynamic> map) {
    return ManagedGroupMember(
      uid: (map['uid'] ?? '').toString(),
      fullName: (map['fullName'] ?? '').toString(),
      userId: (map['userId'] ?? '').toString(),
      department: (map['department'] ?? '').toString(),
      role: (map['role'] ?? AppRoles.user).toString(),
      accountType: (map['accountType'] ?? AppRoles.user).toString(),
      accountStatus: AppAccountStatuses.normalize(map['accountStatus']),
      phone: (map['phone'] ?? '').toString(),
      email: (map['email'] ?? '').toString(),
      isAdmin: map['isAdmin'] == true,
    );
  }
}

class ManagedGroupDetails extends ManagedGroupSummary {
  final String archivedBy;
  final List<ManagedGroupMember> members;

  const ManagedGroupDetails({
    required super.groupId,
    required super.groupName,
    required super.groupIcon,
    required super.department,
    required super.audience,
    required super.writePermission,
    required super.isActive,
    required super.membersCount,
    required super.adminUid,
    required super.adminName,
    required super.adminIds,
    required super.recentMessage,
    required super.recentMessageEn,
    required super.recentMessageSender,
    required super.recentMessageTime,
    required this.archivedBy,
    required this.members,
  });

  factory ManagedGroupDetails.fromMap(Map<String, dynamic> map) {
    final summary = ManagedGroupSummary.fromMap(map);
    return ManagedGroupDetails(
      groupId: summary.groupId,
      groupName: summary.groupName,
      groupIcon: summary.groupIcon,
      department: summary.department,
      audience: summary.audience,
      writePermission: summary.writePermission,
      isActive: summary.isActive,
      membersCount: summary.membersCount,
      adminUid: summary.adminUid,
      adminName: summary.adminName,
      adminIds: summary.adminIds,
      recentMessage: summary.recentMessage,
      recentMessageEn: summary.recentMessageEn,
      recentMessageSender: summary.recentMessageSender,
      recentMessageTime: summary.recentMessageTime,
      archivedBy: (map['archivedBy'] ?? '').toString(),
      members: (map['members'] as List?)
              ?.map((e) => ManagedGroupMember.fromMap(Map<String, dynamic>.from(e)))
              .toList() ??
          const [],
    );
  }
}
