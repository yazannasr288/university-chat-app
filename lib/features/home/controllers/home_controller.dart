import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/permissions/app_role_permissions.dart';
import '../../../core/permissions/app_roles.dart';
import '../../../core/constants/app_group_audiences.dart';
import '../../../core/storage/app_prefs.dart';
import '../../../data/models/group_model.dart';
import '../../../data/repositories/group_cache_repository.dart';
import '../../../data/repositories/group_repository.dart';
import '../../../data/repositories/session_repository.dart';
import '../../../data/repositories/user_repository.dart';

class HomeController {
  final SessionRepository _sessionRepository;
  final UserRepository _userRepository;
  final GroupRepository _groupRepository;
  final GroupCacheRepository _groupCacheRepository;

  String userName = '';
  String email = '';
  String role = AppRoles.user;
  String accountType = AppRoles.user;
  String department = '';
  String profilepic = '';
  List<GroupModel> cachedGroups = const [];
  final Map<String, int> _lastDeliveredTimes = {};
  Future<void> _prefsWriteQueue = Future<void>.value();

  StreamSubscription? _sessionSub;
  StreamSubscription? _currentUserSub;
  bool _isManualLogout = false;

  HomeController({
    SessionRepository? sessionRepository,
    UserRepository? userRepository,
    GroupRepository? groupRepository,
    GroupCacheRepository? groupCacheRepository,
  }) : _sessionRepository = sessionRepository ?? SessionRepository(),
       _userRepository = userRepository ?? UserRepository(),
       _groupRepository = groupRepository ?? GroupRepository(),
       _groupCacheRepository = groupCacheRepository ?? GroupCacheRepository();

  String get currentUid {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('not-authenticated');
    }
    return user.uid;
  }

  bool get canCreateGroup => AppRolePermissions.isNotificationSenderRole(role);

  Future<void> load() async {
    userName = AppPrefs.userName;
    email = AppPrefs.userEmail;
    role = AppPrefs.userRole;
    accountType = AppPrefs.userAccountType;
    department = AppPrefs.userDepartment;
    profilepic = AppPrefs.userProfilePic;
    try {
      final currentUser = await _userRepository.getCurrentUser();
      if (currentUser != null) {
        role = currentUser.role.isNotEmpty ? currentUser.role : role;
        accountType = currentUser.accountType.isNotEmpty
            ? currentUser.accountType
            : accountType;
        department = currentUser.department.isNotEmpty
            ? currentUser.department
            : department;
      }
    } catch (_) {
      // Cached session data keeps offline startup working.
    }
    try {
      await _groupRepository.syncCurrentUserGroups();
    } catch (_) {
      // Keep home available during a rolling backend deployment. Server-side
      // list/join checks and the local audience filter remain authoritative.
    }
    cachedGroups = (await _groupCacheRepository.loadGroups(currentUid))
        .where(_canAccessGroup)
        .toList();
  }

  void startCurrentUserWatcher({required void Function() onChanged}) {
    _currentUserSub?.cancel();

    _currentUserSub = _userRepository.watchCurrentUser().listen(
      (latestUser) async {
        if (latestUser == null) return;

        final nextName =
            latestUser.fullName.isNotEmpty ? latestUser.fullName : userName;
        final nextEmail =
            latestUser.email.isNotEmpty ? latestUser.email : email;
        final nextRole = latestUser.role.isNotEmpty ? latestUser.role : role;
        final nextAccountType = latestUser.accountType.isNotEmpty
            ? latestUser.accountType
            : accountType;
        final nextDepartment =
            latestUser.department.isNotEmpty
                ? latestUser.department
                : department;
        final nextProfilePic = latestUser.profilepic;

        final changed =
            nextName != userName ||
            nextEmail != email ||
            nextRole != role ||
            nextAccountType != accountType ||
            nextDepartment != department ||
            nextProfilePic != profilepic;

        userName = nextName;
        email = nextEmail;
        role = nextRole;
        accountType = nextAccountType;
        department = nextDepartment;
        profilepic = nextProfilePic;

        if (changed) onChanged();

        _prefsWriteQueue = _prefsWriteQueue
            .then(
              (_) => AppPrefs.saveUserSession(
                name: nextName,
                email: nextEmail,
                role: nextRole,
                accountType: nextAccountType,
                department: nextDepartment,
                profilepic: nextProfilePic,
              ),
            )
            .catchError((Object _) {
              // Remote state is already shown; a later snapshot retries cache.
            });
      },
      onError: (_) {
        // نبقي بيانات AppPrefs كـ fallback ولا نكسر الصفحة عند ضعف الاتصال.
      },
    );
  }

  void startSessionWatcher({
    required void Function() onSessionInvalid,
    void Function(String reason)? onSessionForcedLogout,
  }) {
    _sessionSub?.cancel();

    _sessionSub = _sessionRepository.watchCurrentSession(
      onSessionInvalid: () {
        if (_isManualLogout) return;
        onSessionInvalid();
      },
      onSessionForcedLogout: onSessionForcedLogout,
    );
  }

  Stream<List<GroupModel>> userGroupsStream({required bool isActive}) {
    return _groupRepository
        .userGroupsStream(
          uid: currentUid,
          userName: userName,
          isActive: isActive,
        )
        .map((snapshot) {
          final groups = mapAndSortGroups(snapshot.docs);
          unawaited(cacheGroups(groups));
          unawaited(markGroupsDelivered(groups));
          return groups;
        });
  }

  Future<void> createGroup(
    String groupName, {
    required String audience,
    required String department,
  }) async {
    await _groupRepository.createGroup(
      groupName: groupName.trim(),
      audience: audience,
      department: department,
    );
  }

  Future<void> setGroupPinned(GroupModel group, bool pinned) async {
    await _groupRepository.setGroupPinned(
      groupId: group.groupId,
      pinned: pinned,
    );
  }

  List<GroupModel> mapAndSortGroups(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final groups = docs
        .map((e) => GroupModel.fromMap(e.data()))
        .where(_canAccessGroup)
        .toList();
    groups.sort(_compareGroupsForHome);
    return groups;
  }

  bool _canAccessGroup(GroupModel group) {
    if (group.groupName.trim() == 'main_wpu') return true;

    return AppGroupAudiences.canAccess(
      audience: group.audience,
      role: role,
      accountType: accountType,
      userDepartment: department,
      groupDepartment: group.department,
    );
  }

  int _compareGroupsForHome(GroupModel a, GroupModel b) {
    if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;

    final byTime = b.recentMessageTime.compareTo(a.recentMessageTime);
    if (byTime != 0) return byTime;

    return a.groupName.toLowerCase().compareTo(b.groupName.toLowerCase());
  }

  Future<void> markGroupsDelivered(List<GroupModel> groups) async {
    final changedGroups = <GroupModel>[];

    for (final group in groups) {
      if (group.recentMessageTime <= 0) continue;
      final lastDelivered = _lastDeliveredTimes[group.groupId] ?? 0;
      if (group.recentMessageTime <= lastDelivered) continue;

      changedGroups.add(group);
      _lastDeliveredTimes[group.groupId] = group.recentMessageTime;
    }

    if (changedGroups.isEmpty) return;

    try {
      await _groupRepository.markGroupsDelivered(groups: changedGroups);
    } catch (_) {
      for (final group in changedGroups) {
        _lastDeliveredTimes.remove(group.groupId);
      }
    }
  }

  Future<void> cacheGroups(List<GroupModel> groups) async {
    cachedGroups = groups;
    await _groupCacheRepository.saveGroups(currentUid, groups);
  }

  Future<void> logout() async {
    _isManualLogout = true;

    await _sessionSub?.cancel();
    _sessionSub = null;
    await _currentUserSub?.cancel();
    _currentUserSub = null;

    await _sessionRepository.logout();
  }

  void dispose() {
    _sessionSub?.cancel();
    _sessionSub = null;
    _currentUserSub?.cancel();
    _currentUserSub = null;
  }
}
