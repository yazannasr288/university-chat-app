import 'package:flutter/material.dart';

import '../../../core/permissions/app_role_permissions.dart';
import '../../../core/permissions/app_roles.dart';
import '../../../data/models/app_user.dart';
import '../../../data/models/group_model.dart';
import '../../../data/repositories/event_repository.dart';
import '../../../data/repositories/group_repository.dart';
import '../../../data/repositories/user_repository.dart';

enum EventScopeOption { university, department, group }

extension EventScopeOptionX on EventScopeOption {
  String get value {
    switch (this) {
      case EventScopeOption.university:
        return 'university';
      case EventScopeOption.department:
        return 'department';
      case EventScopeOption.group:
        return 'group';
    }
  }
}

class CreateEventController {
  static const int titleMaxLength = 80;
  static const int detailsMaxLength = 1000;
  static const int locationMaxLength = 120;
  static const int notesMaxLength = 500;

  final titleController = TextEditingController();
  final detailsController = TextEditingController();
  final locationController = TextEditingController();
  final notesController = TextEditingController();

  final EventRepository _eventRepository;
  final GroupRepository _groupRepository;
  final UserRepository _userRepository;

  bool isLoading = false;
  bool isSubmitting = false;

  AppUser? currentUser;
  List<GroupModel> manageableGroups = [];
  EventScopeOption? selectedScope;
  String selectedGroupId = '';
  DateTime selectedDateTime = DateTime.now().add(const Duration(days: 1));

  CreateEventController({
    EventRepository? eventRepository,
    GroupRepository? groupRepository,
    UserRepository? userRepository,
  })  : _eventRepository = eventRepository ?? EventRepository(),
        _groupRepository = groupRepository ?? GroupRepository(),
        _userRepository = userRepository ?? UserRepository();

  Future<void> init() async {
    isLoading = true;

    try {
      currentUser = await _userRepository.getCurrentUser();

      final user = currentUser;
      if (user == null) return;

      if (AppRolePermissions.canAccessManagedGroupsRole(user.role)) {
        manageableGroups = await _groupRepository.getManageableGroups(
          uid: user.uid,
          userName: user.fullName,
          role: user.role,
        );
      }

      selectedScope = _defaultScopeForUser(user.role);

      if (selectedScope == EventScopeOption.group && manageableGroups.isNotEmpty) {
        selectedGroupId = manageableGroups.first.groupId;
      }
    } finally {
      isLoading = false;
    }
  }

  EventScopeOption _defaultScopeForUser(String role) {
    switch (role) {
      case AppRoles.systemAdmin:
        return EventScopeOption.university;
      case AppRoles.dean:
        return EventScopeOption.department;
      case AppRoles.departmentStaff:
        return EventScopeOption.department;
      default:
        return EventScopeOption.group;
    }
  }

  List<EventScopeOption> get availableScopes {
    final role = currentUser?.role ?? AppRoles.user;

    switch (role) {
      case AppRoles.systemAdmin:
        return const [
          EventScopeOption.university,
          EventScopeOption.department,
          EventScopeOption.group,
        ];
      case AppRoles.dean:
        return const [
          EventScopeOption.department,
          EventScopeOption.group,
        ];
      case AppRoles.departmentStaff:
        return manageableGroups.isEmpty
            ? const [EventScopeOption.department]
            : const [EventScopeOption.department, EventScopeOption.group];
      default:
        return const [];
    }
  }

  GroupModel? get selectedGroup {
    for (final group in manageableGroups) {
      if (group.groupId == selectedGroupId) return group;
    }
    return null;
  }

  void setScope(EventScopeOption value) {
    selectedScope = value;

    if (value == EventScopeOption.group &&
        selectedGroupId.isEmpty &&
        manageableGroups.isNotEmpty) {
      selectedGroupId = manageableGroups.first.groupId;
    }
  }

  void setSelectedGroup(String value) {
    selectedGroupId = value;
  }

  String? validate() {
    final title = titleController.text.trim();
    final details = detailsController.text.trim();
    final location = locationController.text.trim();
    final notes = notesController.text.trim();

    if (selectedScope == null) {
      return 'events.validation.scope_required';
    }

    if (title.isEmpty) {
      return 'events.validation.title_required';
    }

    if (title.length > titleMaxLength) {
      return 'events.validation.title_too_long';
    }

    if (details.isEmpty) {
      return 'events.validation.details_required';
    }

    if (details.length > detailsMaxLength) {
      return 'events.validation.details_too_long';
    }

    if (location.isEmpty) {
      return 'events.validation.location_required';
    }

    if (location.length > locationMaxLength) {
      return 'events.validation.location_too_long';
    }

    if (notes.length > notesMaxLength) {
      return 'events.validation.notes_too_long';
    }

    if (selectedDateTime.isBefore(DateTime.now().add(const Duration(minutes: 5)))) {
      return 'events.validation.time_invalid';
    }

    if (selectedScope == EventScopeOption.group && selectedGroupId.isEmpty) {
      return 'events.validation.target_group_required';
    }

    return null;
  }

  Future<String?> submit() async {
    final validationError = validate();
    if (validationError != null) {
      return validationError;
    }

    isSubmitting = true;
    try {
      return await _eventRepository.createEvent(
        scopeType: selectedScope!.value,
        title: titleController.text.trim(),
        details: detailsController.text.trim(),
        location: locationController.text.trim(),
        notes: notesController.text.trim(),
        eventAt: selectedDateTime.millisecondsSinceEpoch,
        groupId: selectedGroupId,
      );
    } finally {
      isSubmitting = false;
    }
  }

  void dispose() {
    titleController.dispose();
    detailsController.dispose();
    locationController.dispose();
    notesController.dispose();
  }
}
