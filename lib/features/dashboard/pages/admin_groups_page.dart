import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/permissions/app_role_permissions.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../../core/widgets/app_async_icon_button.dart';
import '../../../core/widgets/app_confirm_dialog.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_loader.dart';
import '../../../core/widgets/app_page_shell.dart';
import '../controllers/admin_groups_controller.dart';
import '../widgets/admin_group_details_dialog.dart';
import '../widgets/dashboard_group_filter_bar.dart';
import '../widgets/dashboard_section.dart';
import '../widgets/managed_group_card.dart';

class AdminGroupsPage extends StatefulWidget {
  final String currentRole;
  final String currentDepartment;

  const AdminGroupsPage({
    super.key,
    required this.currentRole,
    required this.currentDepartment,
  });

  @override
  State<AdminGroupsPage> createState() => _AdminGroupsPageState();
}

class _AdminGroupsPageState extends State<AdminGroupsPage> {
  late final AdminGroupsController controller;
  String? _busyGroupId;
  String? _busyGroupAction;

  bool _isGroupActionLoading(String groupId, String action) {
    return _busyGroupId == groupId && _busyGroupAction == action;
  }

  Future<void> _runGroupAction({
    required String groupId,
    required String action,
    required Future<String?> Function() operation,
    required String successMessage,
  }) async {
    if (_busyGroupId != null) return;

    setState(() {
      _busyGroupId = groupId;
      _busyGroupAction = action;
    });

    final error = await operation();
    if (!mounted) return;

    setState(() {
      _busyGroupId = null;
      _busyGroupAction = null;
    });

    if (error != null) {
      showAppSnackBar(context, error, type: SnackType.error);
      return;
    }

    showAppSnackBar(context, successMessage, type: SnackType.success);
  }

  @override
  void initState() {
    super.initState();

    controller = AdminGroupsController(
      currentRole: widget.currentRole,
      currentDepartment: widget.currentDepartment,
    );

    _search();
  }

  Future<void> _search() async {
    final searchFuture = controller.searchGroups();
    setState(() {});
    final result = await searchFuture;
    if (!mounted) return;
    setState(() {});

    if (result != null) {
      showAppSnackBar(context, tr(result), type: SnackType.error);
    }
  }

  Future<void> _archive(String groupId) {
    return _runGroupAction(
      groupId: groupId,
      action: 'archive',
      operation: () => controller.archiveGroup(groupId),
      successMessage: tr('dashboard.group_archive_success'),
    );
  }

  Future<void> _unarchive(String groupId) {
    return _runGroupAction(
      groupId: groupId,
      action: 'unarchive',
      operation: () => controller.unarchiveGroup(groupId),
      successMessage: tr('dashboard.group_unarchive_success'),
    );
  }

  Future<void> _delete(String groupId) async {
    final confirm = await showAppConfirmDialog(
      context: context,
      title: tr('dashboard.group_delete_title'),
      message: tr('dashboard.group_delete_body'),
      cancelText: tr('common.cancel'),
      confirmText: tr('dashboard.group_delete'),
    );

    if (!confirm) return;

    await _runGroupAction(
      groupId: groupId,
      action: 'delete',
      operation: () => controller.deleteGroup(groupId),
      successMessage: tr('dashboard.group_delete_success'),
    );
  }

  Future<void> _openDetails(String groupId) async {
    await showDialog<void>(
      context: context,
      builder: (_) => AdminGroupDetailsDialog(
        groupId: groupId,
        currentRole: widget.currentRole,
        currentDepartment: widget.currentDepartment,
        onSaved: () async {
          await controller.searchGroups();
          if (mounted) setState(() {});
        },
        onDeleted: () async {
          await controller.searchGroups();
          if (mounted) setState(() {});
        },
      ),
    );

    if (!mounted) return;
    setState(() {});
  }

  Widget _buildBody() {
    if (!controller.hasSearched && controller.isLoading) {
      return const AppLoader();
    }

    if (controller.errorMessage != null && controller.groups.isEmpty) {
      return AppEmptyState(
        icon: Icons.wifi_off_rounded,
        text: tr(controller.errorMessage!),
        actionLabel: tr('common.retry'),
        actionLoading: controller.isLoading,
        onAction: _search,
      );
    }

    if (controller.groups.isEmpty) {
      return AppEmptyState(
        icon: Icons.groups_rounded,
        text: tr('dashboard.groups_empty_state'),
      );
    }

    return Column(
      children: controller.groups.map((group) {
        return ManagedGroupCard(
          group: group,
          onManage: () => _openDetails(group.groupId),
          onArchive: group.isActive ? () => _archive(group.groupId) : null,
          onUnarchive: !group.isActive ? () => _unarchive(group.groupId) : null,
          onDelete: () => _delete(group.groupId),
          archiveLoading: _isGroupActionLoading(group.groupId, 'archive'),
          unarchiveLoading: _isGroupActionLoading(group.groupId, 'unarchive'),
          deleteLoading: _isGroupActionLoading(group.groupId, 'delete'),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPageShell(
      title: tr('dashboard.manage_groups'),
      actions: [
        AppAsyncIconButton(
          icon: Icons.refresh_rounded,
          loading: controller.isLoading,
          onPressed: _search,
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.all(16),
          children: [
            DashboardSection(
              title: tr('dashboard.manage_groups'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DashboardGroupFilterBar(
                    query: controller.query,
                    selectedDepartment: controller.selectedDepartment,
                    selectedStatus: controller.selectedStatus,
                    showDepartmentFilter:
                    AppRolePermissions.isSystemAdminRole(widget.currentRole),
                    onQueryChanged: controller.setQuery,
                    onDepartmentChanged: controller.setDepartment,
                    onStatusChanged: controller.setStatus,
                    onApply: _search,
                    loading: controller.isLoading,
                    onClear: () async {
                      controller.clearFilters();
                      setState(() {});
                      await _search();
                    },
                  ),
                  const SizedBox(height: 16),
                  if (controller.isLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: AppLoader(),
                    )
                  else
                    _buildBody(),
                ],
              ),
            ),
          ],
      ),
    );
  }
}
