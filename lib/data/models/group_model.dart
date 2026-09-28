import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/app_group_write_permissions.dart';
import '../../core/constants/app_group_audiences.dart';

int _timestampMillis(dynamic value) {
  if (value is Timestamp) return value.millisecondsSinceEpoch;
  if (value is DateTime) return value.millisecondsSinceEpoch;
  return int.tryParse(value?.toString() ?? '0') ?? 0;
}

class GroupModel {
  final String groupId;
  final String groupName;
  final String groupIcon;
  final String adminId;
  final String adminName;
  final List<String> adminIds;
  final List<String> memberIds;
  final String department;
  final String audience;
  final int createdAt;
  final String recentMessage;
  final String recentMessageEn;
  final String recentMessageSender;
  final String recentMessageSenderId;
  final int recentMessageTime;
  final int messageCount;
  final String writePermission;
  final bool isActive;
  final int unreadCount;
  final bool isMuted;
  final bool isPinned;
  final int lastReadMessageTime;
  final int lastDeliveredMessageTime;

  const GroupModel({
    required this.groupId,
    required this.groupName,
    required this.groupIcon,
    required this.adminId,
    required this.adminName,
    required this.adminIds,
    required this.memberIds,
    required this.department,
    required this.audience,
    this.createdAt = 0,
    required this.recentMessage,
    required this.recentMessageEn,
    required this.recentMessageSender,
    required this.recentMessageSenderId,
    required this.recentMessageTime,
    required this.messageCount,
    required this.writePermission,
    required this.isActive,
    this.unreadCount = 0,
    this.isMuted = false,
    this.isPinned = false,
    this.lastReadMessageTime = 0,
    this.lastDeliveredMessageTime = 0,
  });

  factory GroupModel.fromMap(Map<String, dynamic> map) {
    final rawMemberIds = map['memberIds'];
    final rawAdminIds = map['adminIds'];

    return GroupModel(
      groupId: map['groupId']?.toString() ?? '',
      groupName: map['groupName']?.toString() ?? '',
      groupIcon: map['groupIcon']?.toString() ?? '',
      adminId: map['adminId']?.toString() ?? '',
      adminName: map['adminName']?.toString() ?? '',
      adminIds: rawAdminIds is List
          ? rawAdminIds
              .map((e) => e.toString().trim())
              .where((e) => e.isNotEmpty)
              .toSet()
              .toList()
          : (map['adminId'] != null ? [map['adminId'].toString()] : const <String>[]),
      memberIds: rawMemberIds is List
          ? rawMemberIds
              .map((e) => e.toString().trim())
              .where((e) => e.isNotEmpty)
              .toSet()
              .toList()
          : const <String>[],
      department: map['department']?.toString() ?? '',
      audience: AppGroupAudiences.normalize(
        map['audience']?.toString(),
        groupName: map['groupName']?.toString() ?? '',
      ),
      createdAt: _timestampMillis(map['createdAt']),
      recentMessage: map['recentMessage']?.toString() ?? '',
      recentMessageEn: map['recentMessageEn']?.toString() ?? map['recentMessage']?.toString() ?? '',
      recentMessageSender: map['recentMessageSender']?.toString() ?? '',
      recentMessageSenderId: map['recentMessageSenderId']?.toString() ?? '',
      recentMessageTime:
          int.tryParse(map['recentMessageTime']?.toString() ?? '0') ?? 0,
      messageCount: int.tryParse(map['messageCount']?.toString() ?? '0') ?? 0,
      writePermission: map['writePermission']?.toString() ?? AppGroupWritePermissions.all,
      isActive: map['isActive'] is bool ? map['isActive'] as bool : true,
      unreadCount: int.tryParse(map['unreadCount']?.toString() ?? '0') ?? 0,
      isMuted: map['isMuted'] == true,
      isPinned: map['isPinned'] == true || map['pinned'] == true,
      lastReadMessageTime:
          int.tryParse(map['lastReadMessageTime']?.toString() ?? '0') ?? 0,
      lastDeliveredMessageTime:
          int.tryParse(map['lastDeliveredMessageTime']?.toString() ?? '0') ?? 0,
    );
  }

  factory GroupModel.fromCacheMap(Map<String, dynamic> map) =>
      GroupModel.fromMap(map);

  GroupModel copyWith({
    int? unreadCount,
    bool? isMuted,
    bool? isPinned,
    int? lastReadMessageTime,
    int? lastDeliveredMessageTime,
    List<String>? adminIds,
  }) {
    return GroupModel(
      groupId: groupId,
      groupName: groupName,
      groupIcon: groupIcon,
      adminId: adminId,
      adminName: adminName,
      adminIds: adminIds ?? this.adminIds,
      memberIds: memberIds,
      department: department,
      audience: audience,
      createdAt: createdAt,
      recentMessage: recentMessage,
      recentMessageEn: recentMessageEn,
      recentMessageSender: recentMessageSender,
      recentMessageSenderId: recentMessageSenderId,
      recentMessageTime: recentMessageTime,
      messageCount: messageCount,
      writePermission: writePermission,
      isActive: isActive,
      unreadCount: unreadCount ?? this.unreadCount,
      isMuted: isMuted ?? this.isMuted,
      isPinned: isPinned ?? this.isPinned,
      lastReadMessageTime: lastReadMessageTime ?? this.lastReadMessageTime,
      lastDeliveredMessageTime:
          lastDeliveredMessageTime ?? this.lastDeliveredMessageTime,
    );
  }

  Map<String, dynamic> toCacheMap() {
    return {
      'groupId': groupId,
      'groupName': groupName,
      'groupIcon': groupIcon,
      'adminId': adminId,
      'adminName': adminName,
      'adminIds': adminIds,
      'memberIds': memberIds,
      'department': department,
      'audience': audience,
      'createdAt': createdAt,
      'recentMessage': recentMessage,
      'recentMessageEn': recentMessageEn,
      'recentMessageSender': recentMessageSender,
      'recentMessageSenderId': recentMessageSenderId,
      'recentMessageTime': recentMessageTime,
      'messageCount': messageCount,
      'writePermission': writePermission,
      'isActive': isActive,
      'unreadCount': unreadCount,
      'isMuted': isMuted,
      'isPinned': isPinned,
      'lastReadMessageTime': lastReadMessageTime,
      'lastDeliveredMessageTime': lastDeliveredMessageTime,
    };
  }

  bool isMember(String uid) => memberIds.contains(uid);
}
