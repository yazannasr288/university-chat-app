import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/constants/app_departments.dart';
import '../../../core/constants/app_group_write_permissions.dart';
import '../../../core/constants/app_group_audiences.dart';
import '../../../core/constants/app_account_statuses.dart';
import '../../../core/permissions/app_role_permissions.dart';
import '../../../data/models/managed_group_details.dart';
import '../../../data/models/managed_user.dart';
import '../../../data/repositories/admin_dashboard_repository.dart';
import '../../../data/repositories/group_repository.dart';

class AdminGroupDetailsController {
  final AdminDashboardRepository _repository;
  final GroupRepository _groupRepository;
  final String currentRole;
  final String currentDepartment;

  final groupNameController = TextEditingController();

  bool isSaving = false;
  bool isArchiving = false;
  bool isDeleting = false;
  bool isMemberActionLoading = false;
  bool isInitialLoading = false;

  ManagedGroupDetails? details;

  String groupId = '';
  String department = '';
  String writePermission = AppGroupWritePermissions.all;
  String adminUid = '';
  List<String> adminIds = [];

  final List<String> departments = AppDepartments.values;
  AdminGroupDetailsController({
    AdminDashboardRepository? repository,
    GroupRepository? groupRepository,
    required this.currentRole,
    required this.currentDepartment,
  })  : _repository = repository ?? AdminDashboardRepository(),
        _groupRepository = groupRepository ?? GroupRepository();
  Future<String?> load(String value) async {
    isInitialLoading = true;
    try {
      groupId = value;
      details = await _repository.getManagedGroupDetails(value);
      final loaded = details!;
      groupNameController.text = loaded.groupName;
      department = loaded.department;
      if (!AppRolePermissions.isSystemAdminRole(currentRole)) {
        department = currentDepartment.trim();
      }
      writePermission = loaded.writePermission;
      adminUid = loaded.adminUid;
      adminIds = List.from(loaded.adminIds);
      return null;
    } catch (_) {
      return 'dashboard.group_load_error';
    } finally {
      isInitialLoading = false;
    }
  }

  Future<String?> save() async {
    final groupName = groupNameController.text.trim();

    if (groupId.isEmpty || groupName.isEmpty || department.isEmpty || adminUid.isEmpty) {
      return 'dashboard.group_form_required';
    }

    if (groupName.length > 50) {
      return 'اسم المجموعة طويل جدًا';
    }

    isSaving = true;
    try {
      // Ensure primary admin is always in the list
      if (!adminIds.contains(adminUid)) {
        adminIds.add(adminUid);
      }
      if (!AppRolePermissions.isSystemAdminRole(currentRole)) {
        department = currentDepartment.trim();

        if (department.isEmpty) {
          return 'ليس لديك قسم مرتبط بحسابك';
        }
      }
      final error = await _repository.updateManagedGroup(
        groupId: groupId,
        groupName: groupName,
        department: department,
        writePermission: writePermission,
        adminUid: adminUid,
        adminIds: adminIds,
      );
      if (error != null) return error;
      return await load(groupId);
    } finally {
      isSaving = false;
    }
  }

  Future<String?> updateGroupIcon({
    required File file,
    String? originalFileName,
  }) async {
    if (groupId.isEmpty) return 'dashboard.group_load_error';

    isSaving = true;
    try {
      await _groupRepository.updateGroupIcon(
        groupId: groupId,
        file: file,
        originalFileName: originalFileName,
      );
      return await load(groupId);
    } catch (_) {
      return 'dashboard.group_icon_update_error';
    } finally {
      isSaving = false;
    }
  }

  Future<String?> addMembers(List<String> memberUids) async {
    if (memberUids.isEmpty) {
      return 'dashboard.select_group_members_first';
    }

    isMemberActionLoading = true;
    try {
      final error = await _repository.addManagedGroupMembers(
        groupId: groupId,
        memberUids: memberUids,
      );
      if (error != null) return error;
      return await load(groupId);
    } finally {
      isMemberActionLoading = false;
    }
  }

  Future<String?> removeMember(String memberUid) async {
    isMemberActionLoading = true;
    try {
      final error = await _repository.removeManagedGroupMember(
        groupId: groupId,
        memberUid: memberUid,
      );
      if (error != null) return error;
      return await load(groupId);
    } finally {
      isMemberActionLoading = false;
    }
  }

  Future<String?> archiveGroup() async {
    isArchiving = true;
    try {
      final error = await _repository.archiveManagedGroup(groupId);
      if (error != null) return error;
      return await load(groupId);
    } finally {
      isArchiving = false;
    }
  }

  Future<String?> unarchiveGroup() async {
    isArchiving = true;
    try {
      final error = await _repository.unarchiveManagedGroup(groupId);
      if (error != null) return error;
      return await load(groupId);
    } finally {
      isArchiving = false;
    }
  }

  Future<String?> deleteGroup() async {
    isDeleting = true;
    try {
      return await _repository.deleteManagedGroup(groupId);
    } finally {
      isDeleting = false;
    }
  }

  Future<List<ManagedUser>> searchCandidateMembers(String query) {
    return _repository.listManagedUsers(
      query: query,
      department: AppGroupAudiences.isCrossDepartment(
        details?.audience ?? AppGroupAudiences.department,
      )
          ? ''
          : department,
      accountStatus: AppAccountStatuses.active,
    );
  }

  bool isMemberSelected(String uid) {
    return details?.members.any((member) => member.uid == uid) == true;
  }

  void dispose() {
    groupNameController.dispose();
  }
}
