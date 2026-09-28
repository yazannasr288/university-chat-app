import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/permissions/app_role_permissions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../../core/widgets/app_confirm_dialog.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_loader.dart';
import '../../../core/widgets/app_page_shell.dart';
import '../../../core/widgets/app_surface.dart';
import '../controllers/admin_students_controller.dart';
import '../widgets/admin_user_details_dialog.dart';
import '../widgets/dashboard_section.dart';
import '../widgets/dashboard_user_filter_bar.dart';
import '../widgets/managed_user_card.dart';

class AdminStudentsPage extends StatefulWidget {
  final String currentRole;
  final String currentDepartment;

  const AdminStudentsPage({
    super.key,
    required this.currentRole,
    required this.currentDepartment,
  });

  @override
  State<AdminStudentsPage> createState() => _AdminStudentsPageState();
}

class _AdminStudentsPageState extends State<AdminStudentsPage> {
  final controller = AdminStudentsController();

  @override
  void initState() {
    super.initState();
    if (!AppRolePermissions.isSystemAdminRole(widget.currentRole)) {
      controller.selectedDepartment = widget.currentDepartment;
      controller.selectedRole = 'user';
    }
  }
  String? _busyUserUid;
  String? _busyUserAction;

  bool _isUserActionLoading(String uid, String action) {
    return _busyUserUid == uid && _busyUserAction == action;
  }

  Future<void> _runUserAction({
    required String uid,
    required String action,
    required Future<String?> Function() operation,
    required String successMessage,
  }) async {
    if (_busyUserUid != null) return;

    setState(() {
      _busyUserUid = uid;
      _busyUserAction = action;
    });

    final error = await operation();
    if (!mounted) return;

    setState(() {
      _busyUserUid = null;
      _busyUserAction = null;
    });

    if (error != null) {
      showAppSnackBar(context, error, type: SnackType.error);
      return;
    }

    showAppSnackBar(
      context,
      successMessage,
      type: SnackType.success,
    );
  }

  Future<void> _search() async {
    final searchFuture = controller.searchStudents();
    setState(() {});
    final result = await searchFuture;
    if (!mounted) return;
    setState(() {});

    if (result != null) {
      showAppSnackBar(context, tr(result), type: SnackType.error);
    }
  }

  Future<void> _freeze(String uid) {
    return _runUserAction(
      uid: uid,
      action: 'freeze',
      operation: () => controller.freezeStudent(uid),
      successMessage: tr('dashboard.freeze_success'),
    );
  }

  Future<void> _unfreeze(String uid) {
    return _runUserAction(
      uid: uid,
      action: 'unfreeze',
      operation: () => controller.unfreezeStudent(uid),
      successMessage: tr('dashboard.unfreeze_success'),
    );
  }

  Future<void> _remove(String uid) async {
    final confirm = await showAppConfirmDialog(
      context: context,
      title: tr('dashboard.remove_title'),
      message: tr('dashboard.remove_body'),
      cancelText: tr('common.cancel'),
      confirmText: tr('dashboard.remove'),
    );

    if (!confirm) return;

    await _runUserAction(
      uid: uid,
      action: 'remove',
      operation: () => controller.removeStudent(uid),
      successMessage: tr('dashboard.remove_success'),
    );
  }

  Future<void> _openDetails(String uid) async {
    await showDialog<void>(
      context: context,
      builder: (_) => AdminUserDetailsDialog(
        uid: uid,
        currentRole: widget.currentRole,
        onSaved: () async {
          await controller.searchStudents();
          if (mounted) setState(() {});
        },
      ),
    );

    if (!mounted) return;
    setState(() {});
  }


  Widget _buildSelectionBar() {
    if (!controller.hasSearched || controller.users.isEmpty) {
      return const SizedBox.shrink();
    }

    final allSelected = controller.users.isNotEmpty &&
        controller.selectedCount == controller.users.length;

    return AppSurface.soft(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(AppSpacing.md),
      color: context.appSurfaceSoft,
      borderColor: context.appBorder,
      borderRadius: AppDecorations.radius(AppRadii.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              OutlinedButton.icon(
                onPressed: () {
                  controller.toggleSelectAllVisible(!allSelected);
                  setState(() {});
                },
                icon: Icon(allSelected
                    ? Icons.deselect_rounded
                    : Icons.select_all_rounded),
                label: Text(
                  allSelected
                      ? tr('dashboard.clear_selection')
                      : tr('dashboard.select_all_results'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (!controller.hasSearched) {
      return AppEmptyState(
        icon: Icons.manage_search_rounded,
        text: tr('dashboard.students_start_hint'),
      );
    }

    if (controller.isLoading) {
      return const AppLoader();
    }

    if (controller.errorMessage != null && controller.users.isEmpty) {
      return AppEmptyState(
        icon: Icons.wifi_off_rounded,
        text: tr(controller.errorMessage!),
        actionLabel: tr('common.retry'),
        actionLoading: controller.isLoading,
        onAction: _search,
      );
    }

    if (controller.users.isEmpty) {
      return AppEmptyState(
        icon: Icons.person_search_rounded,
        text: tr('dashboard.no_results'),
      );
    }

    final canManageUsers = AppRolePermissions.canManageUsersRole(widget.currentRole);
    final canFreezeUsers = AppRolePermissions.canFreezeUsersRole(widget.currentRole);
    final canDeleteUsers = AppRolePermissions.canDeleteUsersRole(widget.currentRole);
    final canOpenDetails = canManageUsers;

    return Column(
      children: controller.users.map((user) {
        final isTargetLowerRole = AppRolePermissions.getRoleRank(widget.currentRole) >
                                  AppRolePermissions.getRoleRank(user.role);

        final canFreeze = canFreezeUsers && isTargetLowerRole && !user.isSuspended && !user.isRemoved;
        final canUnfreeze = canFreezeUsers && isTargetLowerRole && user.isSuspended;
        final canRemove = canDeleteUsers && isTargetLowerRole;
        final canManageThisAccount =
            (canOpenDetails && isTargetLowerRole && !user.isRemoved) ||
            canFreeze ||
            canUnfreeze ||
            canRemove;

        return ManagedUserCard(
          user: user,
          canManageAccount: canManageThisAccount,
          isSelected: controller.isSelected(user.uid),
          onSelectionChanged: (selected) {
            controller.toggleSelection(user.uid, selected);
            setState(() {});
          },
          onManage: canOpenDetails && isTargetLowerRole && !user.isRemoved
              ? () => _openDetails(user.uid)
              : null,
          onFreeze: canFreeze ? () => _freeze(user.uid) : null,
          onUnfreeze: canUnfreeze ? () => _unfreeze(user.uid) : null,
          onRemove: canRemove ? () => _remove(user.uid) : null,
          freezeLoading: _isUserActionLoading(user.uid, 'freeze'),
          unfreezeLoading: _isUserActionLoading(user.uid, 'unfreeze'),
          removeLoading: _isUserActionLoading(user.uid, 'remove'),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPageShell(
      title: tr('dashboard.manage_students'),
      actions: [
        if (controller.selectedCount > 0)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Center(
              child: Text(
                '${controller.selectedCount}',
                style: context.textTheme.titleMedium?.copyWith(
                  color: context.appTextPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
      body: ListView(
        padding: const EdgeInsets.all(16),
          children: [
            DashboardSection(
              title: tr('dashboard.manage_students'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DashboardUserFilterBar(
                    query: controller.query,
                    selectedDepartment: controller.selectedDepartment,
                    selectedRole: controller.selectedRole,
                    selectedAccountStatus: controller.selectedAccountStatus,
                    showDepartmentFilter: AppRolePermissions.isSystemAdminRole(widget.currentRole),
                    showRoleFilter: AppRolePermissions.isSystemAdminRole(widget.currentRole),
                    onQueryChanged: (v) => controller.setQuery(v),
                    onDepartmentChanged: (v) => controller.setDepartment(v),
                    onRoleChanged: (v) => controller.setRole(v),
                    onStatusChanged: (v) => controller.setAccountStatus(v),
                    onApply: _search,
                    loading: controller.isLoading,
                    onClear: () async {
                      controller.clearFilters();
                      if (!AppRolePermissions.isSystemAdminRole(widget.currentRole)) {
                        controller.selectedDepartment = widget.currentDepartment;
                        controller.selectedRole = 'user';
                      }
                      setState(() {});
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildSelectionBar(),
                  _buildBody(),
                ],
              ),
            ),
          ],
      ),
    );
  }
}
