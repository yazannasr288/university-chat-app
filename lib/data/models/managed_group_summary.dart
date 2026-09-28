import '../../core/constants/app_group_write_permissions.dart';
import '../../core/constants/app_group_audiences.dart';

class ManagedGroupSummary {
  final String groupId;
  final String groupName;
  final String groupIcon;
  final String department;
  final String audience;
  final String writePermission;
  final bool isActive;
  final int membersCount;
  final String adminUid;
  final String adminName;
  final List<String> adminIds;
  final String recentMessage;
  final String recentMessageEn;
  final String recentMessageSender;
  final int recentMessageTime;

  const ManagedGroupSummary({
    required this.groupId,
    required this.groupName,
    required this.groupIcon,
    required this.department,
    required this.audience,
    required this.writePermission,
    required this.isActive,
    required this.membersCount,
    required this.adminUid,
    required this.adminName,
    required this.adminIds,
    required this.recentMessage,
    required this.recentMessageEn,
    required this.recentMessageSender,
    required this.recentMessageTime,
  });

  factory ManagedGroupSummary.fromMap(Map<String, dynamic> map) {
    int parseInt(String key) => int.tryParse('${map[key] ?? 0}') ?? 0;
    final rawAdminIds = map['adminIds'];

    return ManagedGroupSummary(
      groupId: (map['groupId'] ?? '').toString(),
      groupName: (map['groupName'] ?? '').toString(),
      groupIcon: (map['groupIcon'] ?? '').toString(),
      department: (map['department'] ?? '').toString(),
      audience: AppGroupAudiences.normalize(
        map['audience']?.toString(),
        groupName: (map['groupName'] ?? '').toString(),
      ),
      writePermission: (map['writePermission'] ?? AppGroupWritePermissions.all).toString(),
      isActive: map['isActive'] == true,
      membersCount: parseInt('membersCount'),
      adminUid: (map['adminUid'] ?? '').toString(),
      adminName: (map['adminName'] ?? '').toString(),
      adminIds: rawAdminIds is List
          ? rawAdminIds.map((e) => e.toString()).toList()
          : (map['adminUid'] != null ? [map['adminUid'].toString()] : const []),
      recentMessage: (map['recentMessage'] ?? '').toString(),
      recentMessageEn: (map['recentMessageEn'] ?? map['recentMessage'] ?? '').toString(),
      recentMessageSender: (map['recentMessageSender'] ?? '').toString(),
      recentMessageTime: parseInt('recentMessageTime'),
    );
  }
}
