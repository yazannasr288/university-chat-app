import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/permissions/app_role_permissions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_loader.dart';
import '../../../core/widgets/app_page_shell.dart';
import '../controllers/admin_notification_campaigns_controller.dart';
import '../../dashboard/controllers/admin_students_controller.dart';
import '../../../core/widgets/app_surface.dart';
import '../../dashboard/widgets/dashboard_notification_campaign_card.dart';
import '../../dashboard/widgets/dashboard_section.dart';
import '../../dashboard/widgets/dashboard_user_filter_bar.dart';
import '../../dashboard/widgets/managed_user_card.dart';
import '../../dashboard/widgets/managed_users_notification_dialog.dart';

class AdminNotificationsPage extends StatefulWidget {
  final String currentRole;
  final String currentDepartment;

  const AdminNotificationsPage({
    super.key,
    required this.currentRole,
    required this.currentDepartment,
  });

  @override
  State<AdminNotificationsPage> createState() => _AdminNotificationsPageState();
}

class _AdminNotificationsPageState extends State<AdminNotificationsPage> {
  final controller = AdminStudentsController();
  final campaignsController = AdminNotificationCampaignsController();

  bool get _isAdmin0 => AppRolePermissions.isSystemAdminRole(widget.currentRole);
  @override
  void initState() {
    super.initState();

    controller.allowEmptySearch = true;
    controller.selectedDepartment = _isAdmin0 ? '' : widget.currentDepartment;
    controller.selectedRole = _isAdmin0 ? '' : 'user';

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      await _search();

      if (!mounted) return;

      await _loadCampaigns();
    });
  }

  Future<void> _search() async {
    if (!mounted) return;

    if (!_isAdmin0) {
      controller.selectedDepartment = widget.currentDepartment;
      controller.selectedRole = 'user';
    }

    final future = controller.searchStudents();

    if (!mounted) return;
    setState(() {});

    final result = await future;

    if (!mounted) return;
    setState(() {});

    if (result != null) {
      showAppSnackBar(context, tr(result), type: SnackType.error);
    }
  }
  Future<void> _loadCampaigns({bool showErrors = true}) async {
    if (!mounted) return;

    final future = campaignsController.loadCampaigns();

    if (!mounted) return;
    setState(() {});

    final result = await future;

    if (!mounted) return;
    setState(() {});

    if (showErrors && result != null) {
      showAppSnackBar(context, result, type: SnackType.error);
    }
  }

  Future<void> _openNotificationDialog() async {
    final result = await showDialog<String?>(
      context: context,
      builder: (_) => ManagedUsersNotificationDialog(
        selectedCount: controller.selectedCount,
        onSend: (title, body) => controller.sendNotificationToSelected(
          title: title,
          body: body,
        ),
      ),
    );

    if (!mounted || result == null) return;

    if (result.isNotEmpty) {
      final message = result.startsWith('dashboard.') ? tr(result) : result;
      showAppSnackBar(context, message, type: SnackType.error);
      return;
    }

    controller.clearSelection();

    if (!mounted) return;
    setState(() {});

    await _loadCampaigns(showErrors: false);

    if (!mounted) return;

    showAppSnackBar(
      context,
      tr('dashboard.notification_sent_success'),
      type: SnackType.success,
    );
  }

  Widget _buildSelectionBar() {
    final visibleSelected = controller.users.isNotEmpty &&
        controller.users.every((user) => controller.isSelected(user.uid));

    return AppSurface.soft(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(AppSpacing.md),
      color: context.appSurfaceSoft,
      borderColor: context.appBorder,
      borderRadius: AppDecorations.radius(AppRadii.lg),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Chip(
            avatar: const Icon(Icons.check_circle_outline_rounded, size: 18),
            label: Text('${'dashboard.selected'.tr()}: ${controller.selectedCount}'),
          ),
          OutlinedButton.icon(
            onPressed: controller.users.isEmpty
                ? null
                : () {
                    controller.toggleSelectAllVisible(!visibleSelected);
                    setState(() {});
                  },
            icon: Icon(visibleSelected
                ? Icons.deselect_rounded
                : Icons.select_all_rounded),
            label: Text(
              visibleSelected
                  ? tr('dashboard.clear_selection')
                  : tr('dashboard.select_all_results'),
            ),
          ),
          OutlinedButton.icon(
            onPressed: controller.selectedCount == 0
                ? null
                : () {
                    controller.clearSelection();
                    setState(() {});
                  },
            icon: const Icon(Icons.clear_all_rounded),
            label: Text(tr('dashboard.clear_selection')),
          ),
          ElevatedButton.icon(
            onPressed: controller.selectedCount == 0 ? null : _openNotificationDialog,
            icon: const Icon(Icons.notifications_active_rounded),
            label: Text(tr('dashboard.send_notification')),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (controller.isLoading) return const AppLoader();

    if (controller.errorMessage != null && controller.users.isEmpty) {
      return AppEmptyState(
        icon: Icons.wifi_off_rounded,
        text: tr(controller.errorMessage!),
        actionLabel: tr('common.retry'),
        actionLoading: controller.isLoading,
        onAction: _search,
      );
    }

    if (!controller.hasSearched) {
      return AppEmptyState(
        icon: Icons.notifications_active_rounded,
        text: tr('dashboard.students_start_hint'),
      );
    }

    if (controller.users.isEmpty) {
      return AppEmptyState(
        icon: Icons.person_search_rounded,
        text: tr('dashboard.no_results'),
      );
    }

    return Column(
      children: controller.users.map((user) {
        return ManagedUserCard(
          user: user,
          canManageAccount: false,
          isSelected: controller.isSelected(user.uid),
          onSelectionChanged: (selected) {
            controller.toggleSelection(user.uid, selected);
            setState(() {});
          },
        );
      }).toList(),
    );
  }

  Widget _buildCampaignsSection() {
    Widget child;

    if (campaignsController.isLoading && campaignsController.campaigns.isEmpty) {
      child = const AppLoader();
    } else if (campaignsController.campaigns.isEmpty) {
      child = AppEmptyState(
        icon: Icons.notifications_off_rounded,
        text: tr('dashboard.notification_campaigns_empty'),
      );
    } else {
      child = Column(
        children: campaignsController.campaigns
            .map((campaign) => DashboardNotificationCampaignCard(campaign: campaign))
            .toList(),
      );
    }

    return DashboardSection(
      title: tr('dashboard.notification_campaigns'),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPageShell(
      title: tr('dashboard.send_notification'),
      body: ListView(
        padding: const EdgeInsets.all(16),
          children: [
            DashboardSection(
              title: tr('dashboard.send_notification'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DashboardUserFilterBar(
                    query: controller.query,
                    selectedDepartment: controller.selectedDepartment,
                    selectedRole: controller.selectedRole,
                    selectedAccountStatus: controller.selectedAccountStatus,
                    showDepartmentFilter: _isAdmin0,
                    showRoleFilter: _isAdmin0,
                    onQueryChanged: (v) => controller.setQuery(v),
                    onDepartmentChanged: (v) => controller.setDepartment(v),
                    onRoleChanged: (v) => controller.setRole(v),
                    onStatusChanged: (v) => controller.setAccountStatus(v),
                    onApply: _search,
                    loading: controller.isLoading,
                    onClear: () async {
                      controller.clearFilters();
                      controller.allowEmptySearch = true;
                      controller.selectedRole = _isAdmin0 ? '' : 'user';
                      controller.selectedDepartment = _isAdmin0 ? '' : widget.currentDepartment;
                      await _search();
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildSelectionBar(),
                  _buildBody(),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildCampaignsSection(),
          ],
      ),
    );
  }
}
