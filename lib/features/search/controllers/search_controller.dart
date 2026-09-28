import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/utils/error_message.dart';
import '../../../data/models/group_model.dart';
import '../../../data/repositories/group_repository.dart';
import '../../../data/repositories/user_repository.dart';

class SearchController {
  final GroupRepository _groupRepository;
  final UserRepository _userRepository;

  Set<String> joinedGroupIds = <String>{};
  String userName = '';
  String userDepartment = '';
  String uid = '';
  bool isLoading = false;
  String? errorMessage;

  List<GroupModel> allGroups = [];
  List<GroupModel> filteredGroups = [];

  SearchController({
    GroupRepository? groupRepository,
    UserRepository? userRepository,
  })  : _groupRepository = groupRepository ?? GroupRepository(),
        _userRepository = userRepository ?? UserRepository();

  Future<void> init() async {
    isLoading = true;
    errorMessage = null;

    try {
      uid = FirebaseAuth.instance.currentUser?.uid ?? '';

      final user = await _userRepository.getCurrentUser();

      userName = user?.fullName ?? '';
      userDepartment = user?.department ?? '';

      final role = user?.role ?? 'user';

      joinedGroupIds = Set<String>.from(
        (user?.groupIds ?? const []).map((e) => e.toString()),
      );

      if (role == 'admin0') {
        allGroups = await _groupRepository.getDepartmentGroups(
          '',
          allDepartments: true,
        );
      } else if (userDepartment.isNotEmpty) {
        allGroups = await _groupRepository.getDepartmentGroups(userDepartment);
      } else {
        allGroups = [];
      }

      filteredGroups = List<GroupModel>.from(allGroups);

    } catch (e) {
      errorMessage = cleanErrorMessage(
        e,
        fallback: tr('chat.unable_load_available_groups'),
      );

      allGroups = [];
      filteredGroups = [];
    } finally {
      isLoading = false;
    }
  }

  void search(String query) {
    final value = _normalize(query);

    if (value.isEmpty) {
      filteredGroups = List<GroupModel>.from(allGroups);
      return;
    }

    filteredGroups = allGroups.where((group) {
      final groupName = _normalize(group.groupName);
      final adminName = _normalize(adminNameOf(group));
      final department = _normalize(group.department);

      return groupName.contains(value) ||
          adminName.contains(value) ||
          department.contains(value);
    }).toList();
  }

  String adminNameOf(GroupModel group) {
    return group.adminName;
  }

  Future<bool> isJoined(GroupModel group) async {
    return joinedGroupIds.contains(group.groupId);
  }

  Future<String?> toggleGroup(GroupModel group) async {
    if (uid.isEmpty) {
      return tr('auth.errors.no_signed_in_user');
    }

    if (userName.trim().isEmpty) {
      return tr('search.could_not_determine_user_name');
    }

    final error = await _groupRepository.toggleGroup(
      groupId: group.groupId,
    );

    if (error == null) {
      if (joinedGroupIds.contains(group.groupId)) {
        joinedGroupIds.remove(group.groupId);
      } else {
        joinedGroupIds.add(group.groupId);
      }
    }

    return error;
  }

  String _normalize(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }
}
