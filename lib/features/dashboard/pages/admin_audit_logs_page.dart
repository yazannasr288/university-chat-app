import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/permissions/app_role_permissions.dart';
import '../../../core/storage/app_prefs.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../../core/widgets/app_loader.dart';
import '../../../core/widgets/app_page_shell.dart';
import '../controllers/admin_audit_logs_controller.dart';
import '../widgets/dashboard_audit_filter_bar.dart';
import '../widgets/dashboard_audit_log_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../widgets/dashboard_section.dart';

class AdminAuditLogsPage extends StatefulWidget {
  const AdminAuditLogsPage({super.key});

  @override
  State<AdminAuditLogsPage> createState() => _AdminAuditLogsPageState();
}

class _AdminAuditLogsPageState extends State<AdminAuditLogsPage> {
  final controller = AdminAuditLogsController();

  bool get _canViewAuditLogs =>
      AppRolePermissions.isSystemAdminRole(AppPrefs.userRole);

  Future<void> _loadAuditLogs({bool reset = true}) async {
    final loadFuture = controller.loadAuditLogs(reset: reset);
    setState(() {});
    final error = await loadFuture;
    if (!mounted) return;
    setState(() {});
    if (error != null) {
      showAppSnackBar(context, error, type: SnackType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_canViewAuditLogs) {
      return AppPageShell(
        title: tr('dashboard.audit_center'),
        body: AppEmptyState(
          icon: Icons.lock_outline_rounded,
          text: tr('dashboard.dashboard_stats_permission_error'),
        ),
      );
    }

    return AppPageShell(
      title: tr('dashboard.audit_center'),
      body: RefreshIndicator(
        onRefresh: () => _loadAuditLogs(reset: true),
        child: _buildAuditLogsTab(),
      ),
    );
  }

  Widget _buildAuditLogsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        DashboardSection(
          title: tr('dashboard.audit_filters'),
          child: DashboardAuditFilterBar(
            selectedCategory: controller.selectedCategory,
            selectedLevel: controller.selectedLevel,
            selectedStartDate: controller.selectedStartDate,
            selectedEndDate: controller.selectedEndDate,
            onCategoryChanged: (v) => setState(() => controller.setCategory(v)),
            onLevelChanged: (v) => setState(() => controller.setLevel(v)),
            onStartDateChanged: (v) => setState(() => controller.setStartDate(v)),
            onEndDateChanged: (v) => setState(() => controller.setEndDate(v)),
            onApply: () => _loadAuditLogs(reset: true),
            loading: controller.isLoading,
          ),
        ),
        const SizedBox(height: 16),
        if (controller.isLoading)
          const AppLoader()
        else if (!controller.hasSearched)
          AppEmptyState(
            icon: Icons.filter_alt_rounded,
            text: 'dashboard.choose_log_type_date_range_apply_filters'.tr(),
          )
        else if (controller.logs.isEmpty)
          AppEmptyState(
            icon: Icons.history_toggle_off_rounded,
            text: tr('dashboard.audit_empty'),
          )
        else ...[
          ...controller.logs.map((e) => DashboardAuditLogCard(log: e)),
          if (controller.hasMoreLogs) ...[
            const SizedBox(height: 8),
            Center(
              child: controller.isLoadingMore
                  ? const AppLoader()
                  : OutlinedButton.icon(
                      onPressed: () => _loadAuditLogs(reset: false),
                      icon: const Icon(Icons.expand_more_rounded),
                      label: Text('dashboard.load_more'.tr()),
                    ),
            ),
          ],
        ],
      ],
    );
  }
}
