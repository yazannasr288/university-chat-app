import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/permissions/app_role_permissions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/constants/app_group_write_permissions.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/storage/app_prefs.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../../core/utils/error_message.dart';
import '../../../data/models/app_user.dart';
import '../../../data/models/group_model.dart';
import '../controllers/group_info_controller.dart';
import '../widgets/group_info_header_card.dart';
import '../widgets/group_member_tile.dart';
import '../widgets/image_source_sheet.dart';

class GroupInfoPage extends StatefulWidget {
  final String adminName;
  final String groupId;
  final String groupName;

  const GroupInfoPage({
    super.key,
    required this.adminName,
    required this.groupId,
    required this.groupName,
  });

  @override
  State<GroupInfoPage> createState() => _GroupInfoPageState();
}

class _GroupInfoPageState extends State<GroupInfoPage> {
  String _lastMembersSignature = '';
  late final GroupInfoController controller;
  final ImagePicker _picker = ImagePicker();
  bool _updatingMute = false;
  Future<void>? _membersFuture;
  bool _retryingMembers = false;
  List<String> _lastKnownMemberIds = [];
  AppUser? _currentUser;
  StreamSubscription<AppUser?>? _currentUserSub;
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _groupSettingsStream;
  String _groupSettingsUid = '';
  int _groupStreamReloadKey = 0;

  @override
  void initState() {
    super.initState();
    controller = GroupInfoController(widget.groupId);
    _currentUserSub = controller.watchCurrentUser().listen(
      (user) {
        if (!mounted) return;
        setState(() => _currentUser = user);
      },
      onError: (_) {
      },
    );
  }

  @override
  void dispose() {
    _currentUserSub?.cancel();
    super.dispose();
  }

  void _initMembersFuture(List<String> ids) {
    final cleanIds =
        ids.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

    final signature = cleanIds.join('|');

    if (_membersFuture != null && _lastMembersSignature == signature) {
      return;
    }

    _lastMembersSignature = signature;
    _lastKnownMemberIds = List.from(cleanIds);
    _membersFuture = controller.preloadUsers(cleanIds);
  }

  List<String> _memberIdsFor(
    GroupModel group,
    QuerySnapshot<Map<String, dynamic>>? memberStates,
  ) {
    final memberIds = <String>{
      ...group.memberIds.map((uid) => uid.trim()).where((uid) => uid.isNotEmpty),
    };

    if (memberStates != null) {
      for (final document in memberStates.docs) {
        final uid = (document.data()['uid'] ?? document.id).toString().trim();
        if (uid.isNotEmpty) memberIds.add(uid);
      }
    }

    return memberIds.toList(growable: false);
  }

  Future<void> _retryLoadMembers() async {
    if (_retryingMembers) return;

    setState(() {
      _retryingMembers = true;
      _membersFuture = controller.preloadUsers(_lastKnownMemberIds);
    });

    try {
      await _membersFuture;
    } finally {
      if (mounted) {
        setState(() => _retryingMembers = false);
      }
    }
  }

  String _errorText(Object e) => cleanErrorMessage(e);

  void _showError(Object e) {
    showAppSnackBar(context, _errorText(e), type: SnackType.error);
  }

  Future<bool> _showConfirmDialog({
    required String title,
    required String content,
    required String confirmText,
  }) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            backgroundColor: context.appCardColorStrong,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.lg),
              side: BorderSide(color: context.appBorder),
            ),
            title: Text(
              title,
              style: context.textTheme.titleMedium?.copyWith(
                color: context.appTextPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
            content: Text(
              content,
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.appTextSecondary,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('common.cancel'.tr()),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(
                  confirmText,
                  style: const TextStyle(color: AppColors.error),
                ),
              ),
            ],
          ),
    );

    return confirm == true;
  }

  Future<ImageSource?> _pickImageSource() {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const ImageSourceSheet(),
    );
  }

  Future<void> _pickAndChangeIcon() async {
    try {
      final source = await _pickImageSource();
      if (source == null) return;

      final file = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 68,
      );
      if (file == null) return;

      await controller.changeGroupIcon(file);
      if (!mounted) return;

      showAppSnackBar(
        context,
        'group_info.group_image_updated'.tr(),
        type: SnackType.success,
      );
    } catch (e) {
      if (!mounted) return;
      _showError(e);
    }
  }

  Future<void> _setGroupMuted(bool muted) async {
    if (_updatingMute) return;

    setState(() => _updatingMute = true);
    try {
      await controller.setGroupMuted(muted);
      if (!mounted) return;

      showAppSnackBar(
        context,
        muted
            ? 'group_info.mute_success'.tr()
            : 'group_info.unmute_success'.tr(),
        type: SnackType.success,
      );
    } catch (e) {
      if (!mounted) return;
      _showError(e);
    } finally {
      if (mounted) setState(() => _updatingMute = false);
    }
  }

  Widget _buildMuteTile(String currentUid) {
    if (_groupSettingsStream == null || _groupSettingsUid != currentUid) {
      _groupSettingsUid = currentUid;
      _groupSettingsStream = controller.groupSettingsStream(currentUid);
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _groupSettingsStream,
      builder: (context, settingsSnapshot) {
        if (settingsSnapshot.hasError) {
          return AppSurface.card(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            padding: EdgeInsets.zero,
            color: context.appCardColor,
            borderColor: context.appBorder,
            borderRadius: BorderRadius.circular(AppRadii.lg),
            boxShadow: context.isDark ? const [] : AppShadows.subtle,
            child: ListTile(
              leading: Icon(
                Icons.notifications_off_rounded,
                color: context.appTextMuted,
              ),
              title: Text(
                'group_info.could_not_load_notification_settings'.tr(),
                style: context.textTheme.titleSmall?.copyWith(
                  color: context.appTextPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              subtitle: Text(
                'group_info.reopen_page_try_again_later'.tr(),
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.appTextSecondary,
                ),
              ),
            ),
          );
        }

        final data = settingsSnapshot.data?.data() ?? const <String, dynamic>{};
        final muted = data['muted'] == true;

        return AppSurface.card(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          padding: EdgeInsets.zero,
          color: context.appCardColor,
          borderColor: context.appBorder,
          borderRadius: BorderRadius.circular(AppRadii.lg),
          boxShadow: context.isDark ? const [] : AppShadows.subtle,
          child: SwitchListTile.adaptive(
            value: muted,
            onChanged: _updatingMute ? null : _setGroupMuted,
            secondary: Icon(
              muted
                  ? Icons.notifications_off_rounded
                  : Icons.notifications_active_rounded,
              color: muted ? context.appTextMuted : AppColors.primary,
            ),
            title: Text(
              'group_info.mute_notifications'.tr(),
              style: context.textTheme.titleSmall?.copyWith(
                color: context.appTextPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
            subtitle: Text(
              muted
                  ? 'group_info.mute_notifications_description'.tr()
                  : 'group_info.unmute_notifications_description'.tr(),
              style: context.textTheme.bodySmall?.copyWith(
                color: context.appTextSecondary,
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _toggleLock(bool locked) async {
    try {
      await controller.toggleLock(locked);
      if (!mounted) return;

      showAppSnackBar(
        context,
        locked
            ? 'group_info.group_unlocked'.tr()
            : 'group_info.group_locked'.tr(),
        type: SnackType.success,
      );
    } catch (e) {
      if (!mounted) return;
      _showError(e);
    }
  }

  Future<void> _toggleArchive(bool isActive, String adminName) async {
    try {
      if (isActive) {
        await controller.archive(adminName);
        if (!mounted) return;

        Navigator.popUntil(context, (route) => route.isFirst);
        showAppSnackBar(
          context,
          'group_info.archive_success'.tr(),
          type: SnackType.success,
        );
      } else {
        await controller.unarchive();
        if (!mounted) return;

        Navigator.pop(context);
        showAppSnackBar(
          context,
          'group_info.unarchive_success'.tr(),
          type: SnackType.success,
        );
      }
    } catch (e) {
      if (!mounted) return;
      _showError(e);
    }
  }

  Future<void> _deleteGroup() async {
    final confirm = await _showConfirmDialog(
      title: 'group_info.delete_group'.tr(),
      content: 'group_info.sure_want_permanently_delete_group'.tr(),
      confirmText: 'common.delete'.tr(),
    );

    if (!confirm) return;

    try {
      await controller.deleteGroup();
      if (!mounted) return;

      Navigator.popUntil(context, (route) => route.isFirst);
      showAppSnackBar(
        context,
        'group_info.group_deleted'.tr(),
        type: SnackType.success,
      );
    } catch (e) {
      if (!mounted) return;
      _showError(e);
    }
  }

  Future<void> _kickMember({
    required String memberUid,
    required String memberName,
  }) async {
    final confirm = await _showConfirmDialog(
      title: 'group_info.remove_member'.tr(),
      content: tr('group_info.do_want_remove_value_group', args: [memberName]),
      confirmText: 'group_info.remove'.tr(),
    );

    if (!confirm) return;

    try {
      await controller.kickMember(memberUid);
      if (!mounted) return;

      showAppSnackBar(
        context,
        'group_info.member_removed'.tr(),
        type: SnackType.success,
      );
    } catch (e) {
      if (!mounted) return;
      _showError(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final currentRole = _currentUser?.role ?? AppPrefs.userRole;
    final currentDepartment =
        _currentUser?.department ?? AppPrefs.userDepartment;

    if (currentUid.isEmpty) {
      return AppPageShell(
        title: 'group_info.title'.tr(),
        useBackground: false,
        body: AppScaffoldBackground(
          animate: false,
          child: AppEmptyState(
            icon: Icons.lock_outline_rounded,
            text: 'auth.errors.session_expired_sign_in_again'.tr(),
          ),
        ),
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      key: ValueKey<int>(_groupStreamReloadKey),
      stream: controller.groupStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return AppPageShell(
            title: 'group_info.title'.tr(),
            useBackground: false,
            body: AppScaffoldBackground(
              animate: false,
              child: AppEmptyState(
                icon: Icons.wifi_off_rounded,
                text: 'group_info.errors.load_failed_check_connection'.tr(),
                actionLabel: 'common.retry'.tr(),
                onAction: () => setState(() => _groupStreamReloadKey++),
              ),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const AppPageShell(
            useBackground: false,
            body: AppScaffoldBackground(animate: false, child: AppLoader()),
          );
        }

        final data = snapshot.data!.data();
        if (data == null) {
          return AppPageShell(
            title: 'group_info.title'.tr(),
            useBackground: false,
            body: AppScaffoldBackground(
              animate: false,
              child: AppEmptyState(
                icon: Icons.group_off_rounded,
                text: 'group_info.group_deleted'.tr(),
              ),
            ),
          );
        }

        final group = GroupModel.fromMap(data);
        final canManage = controller.canManageGroup(
          group,
          currentUid,
          currentRole,
          currentDepartment: currentDepartment,
        );

        final isLocked = AppGroupWritePermissions.isAdminsOnly(
          group.writePermission,
        );
        final displayGroupName =
            group.groupName.isNotEmpty ? group.groupName : widget.groupName;
        final displayAdminName =
            group.adminName.isNotEmpty ? group.adminName : widget.adminName;

        return AppPageShell(
          title: 'group_info.title'.tr(),
          useBackground: false,
          actions: [
            if (canManage)
              IconButton(
                icon: const Icon(
                  Icons.delete_forever_rounded,
                  color: AppColors.error,
                ),
                onPressed: _deleteGroup,
              ),
            if (canManage)
              IconButton(
                icon: Icon(
                  group.isActive
                      ? Icons.archive_outlined
                      : Icons.unarchive_outlined,
                  color: AppColors.accent,
                ),
                onPressed:
                    () => _toggleArchive(group.isActive, displayAdminName),
              ),
            if (canManage)
              IconButton(
                icon: Icon(
                  isLocked ? Icons.lock_rounded : Icons.lock_open_rounded,
                ),
                onPressed: () => _toggleLock(isLocked),
              ),
          ],
          body: AppScaffoldBackground(
            animate: false,
            child: Column(
              children: [
                GroupInfoHeaderCard(
                  createdAt: group.createdAt,
                  groupName: displayGroupName,
                  adminName: displayAdminName,
                  groupIconBase64: group.groupIcon,
                  canEditIcon: canManage,
                  onTapIcon: _pickAndChangeIcon,
                ),


                _buildMuteTile(currentUid),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.sm,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'group_info.members_title'.tr(),
                      style: context.textTheme.titleSmall?.copyWith(
                        color: context.appTextPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: controller.memberStatesStream,
                    builder: (context, memberStateSnapshot) {
                      if (memberStateSnapshot.hasError) {
                        return AppEmptyState(
                          icon: Icons.person_search_rounded,
                          text: 'group_info.errors.members_load_failed'.tr(),
                          actionLabel: 'common.retry'.tr(),
                          actionLoading: _retryingMembers,
                          onAction: _retryLoadMembers,
                        );
                      }

                      final memberIds = _memberIdsFor(
                        group,
                        memberStateSnapshot.data,
                      );
                      if (memberStateSnapshot.connectionState ==
                              ConnectionState.waiting &&
                          memberStateSnapshot.data == null &&
                          memberIds.isEmpty) {
                        return AppShimmer(
                          child: AppShimmer.memberSkeleton(),
                        );
                      }
                      _initMembersFuture(memberIds);

                      return FutureBuilder<void>(
                        future: _membersFuture,
                        builder: (context, userSnapshot) {
                          if (userSnapshot.hasError) {
                            return AppEmptyState(
                              icon: Icons.person_search_rounded,
                              text:
                                  'group_info.errors.members_load_failed'.tr(),
                              actionLabel: 'common.retry'.tr(),
                              actionLoading: _retryingMembers,
                              onAction: _retryLoadMembers,
                            );
                          }

                          if ((memberStateSnapshot.connectionState ==
                                      ConnectionState.waiting ||
                                  userSnapshot.connectionState ==
                                      ConnectionState.waiting) &&
                              memberIds.isNotEmpty) {
                            return AppShimmer(
                              child: AppShimmer.memberSkeleton(),
                            );
                          }

                          if (memberIds.isEmpty) {
                            return AppEmptyState(
                              icon: Icons.group_off_rounded,
                              text: 'group_info.empty_members'.tr(),
                            );
                          }

                          return ListView.builder(
                            padding: const EdgeInsets.only(bottom: 16),
                            itemCount: memberIds.length,
                            itemBuilder: (_, index) {
                              final memberUid = memberIds[index];
                              final user = controller.getCachedUser(memberUid);
                              final isGroupAdminMember =
                                  AppRolePermissions.isGroupAdminUid(
                                    currentUid: memberUid,
                                    groupAdminId: group.adminId,
                                    groupAdminIds: group.adminIds,
                                  );
                              final memberName =
                                  user?.fullName ??
                                  (isGroupAdminMember &&
                                          displayAdminName.isNotEmpty
                                      ? displayAdminName
                                      : memberUid);

                              return GroupMemberTile(
                                memberName: memberName,
                                subtitle: user?.userId ?? '',
                                profilepic: user?.profilepic ?? '',
                                canKick: canManage && !isGroupAdminMember,
                                onKick:
                                    () => _kickMember(
                                      memberUid: memberUid,
                                      memberName: memberName,
                                    ),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
