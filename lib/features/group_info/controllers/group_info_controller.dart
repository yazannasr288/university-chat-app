import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/permissions/app_role_permissions.dart';
import '../../../data/models/app_user.dart';
import '../../../data/models/group_model.dart';
import '../../../data/repositories/group_repository.dart';
import '../../../data/repositories/user_repository.dart';

class GroupInfoController {
  final String groupId;
  final GroupRepository _groupRepository;
  final UserRepository _userRepository;

  late final Stream<DocumentSnapshot<Map<String, dynamic>>> groupStream;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> memberStatesStream;
  final Map<String, Stream<DocumentSnapshot<Map<String, dynamic>>>>
      _groupSettingsStreams = {};

  GroupInfoController(
    this.groupId, {
    GroupRepository? groupRepository,
    UserRepository? userRepository,
  })  : _groupRepository = groupRepository ?? GroupRepository(),
        _userRepository = userRepository ?? UserRepository() {
    groupStream = _groupRepository.groupStream(groupId);
    memberStatesStream = _groupRepository.memberStatesStream(groupId);
  }

  final Map<String, AppUser?> _userCache = {};

  Stream<DocumentSnapshot<Map<String, dynamic>>> groupSettingsStream(String uid) {
    return _groupSettingsStreams.putIfAbsent(
      uid,
      () => _groupRepository.groupSettingsDocStream(uid: uid, groupId: groupId),
    );
  }

  Future<void> preloadUsers(List<String> memberIds) async {
    final cleanMemberIds = memberIds
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    if (cleanMemberIds.isEmpty) return;

    final missing = cleanMemberIds.where((uid) => !_userCache.containsKey(uid));
    if (missing.isEmpty) return;

    final users = await _userRepository.listGroupMembersPublic(groupId);
    for (final user in users) {
      _userCache[user.uid] = user;
    }
  }

  AppUser? getCachedUser(String uid) => _userCache[uid];

  Stream<AppUser?> watchCurrentUser() => _userRepository.watchCurrentUser();

  bool canManageGroup(
    GroupModel group,
    String currentUid,
    String currentRole, {
    String currentDepartment = '',
  }) {
    final department = currentDepartment.trim();
    final groupDepartment = group.department.trim();

    return AppRolePermissions.canManageGroup(
      groupAdminId: group.adminId,
      groupAdminIds: group.adminIds,
      currentUid: currentUid,
      currentRole: currentRole,
      currentDepartment: department,
      groupDepartment: groupDepartment,
      groupName: group.groupName
    );
  }

  Future<void> unarchive() {
    return _groupRepository.unarchiveGroup(groupId);
  }



  Future<void> toggleLock(bool currentlyLocked) {
    return _groupRepository.updateWritePermission(
      groupId: groupId,
      locked: !currentlyLocked,
    );
  }

  Future<void> archive(String adminName) {
    return _groupRepository.archiveGroup(
      groupId: groupId,
      adminName: adminName,
    );
  }

  Future<void> deleteGroup() {
    return _groupRepository.deleteGroup(groupId);
  }

  Future<void> kickMember(String memberUid) {
    return _groupRepository.kickMember(
      groupId: groupId,
      memberUid: memberUid,
    );
  }

  Future<void> setGroupMuted(bool muted) {
    return _groupRepository.setGroupMuted(
      groupId: groupId,
      muted: muted,
    );
  }

  Future<void> changeGroupIcon(XFile pickedFile) async {
    await _groupRepository.updateGroupIcon(
      groupId: groupId,
      file: File(pickedFile.path),
      originalFileName: pickedFile.name,
    );
  }
}
