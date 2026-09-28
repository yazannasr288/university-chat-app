import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../../core/permissions/app_role_permissions.dart';
import '../../../core/widgets/app_async_icon_button.dart';
import '../../../core/widgets/app_language_picker.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_page_shell.dart';
import '../../../core/widgets/app_state_view.dart';
import '../../../features/archive/page/archive_page.dart';
import '../../../features/auth/pages/register_page.dart';
import '../../../features/events/pages/create_event_page.dart';
import '../../../features/events/pages/events_page.dart';
import '../../../features/downloads/pages/downloads_page.dart';
import '../../../features/gpa/pages/gpa_calculator_page.dart';
import '../../../features/home/widgets/home_drawer.dart';
import '../../../features/notifications/pages/admin_notifications_page.dart';
import '../../../features/profile/pages/profile_page.dart';
import '../../../features/saved_messages/pages/saved_messages_page.dart';
import '../../../features/search/pages/search_page.dart';
import '../../pages/web_page.dart';
import '../controllers/admin_dashboard_controller.dart';
import '../widgets/dashboard_header.dart';
import '../widgets/dashboard_quick_action_tile.dart';
import '../widgets/dashboard_section.dart';
import '../widgets/dashboard_stat_card.dart';
import 'admin_audit_logs_page.dart';
import 'admin_cloud_billing_page.dart';
import 'admin_groups_page.dart';
import 'admin_students_page.dart';


part 'admin_dashboard_page/admin_dashboard_navigation.dart';
part 'admin_dashboard_page/admin_dashboard_sections.dart';

class AdminDashboardPage extends StatefulWidget {
  final String userName;
  final String role;
  final String department;
  final Future<void> Function() onLogout;

  const AdminDashboardPage({
    super.key,
    required this.userName,
    required this.role,
    required this.department,
    required this.onLogout,
  });

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final controller = AdminDashboardController();

  @override
  void initState() {
    super.initState();
    _handleInit();
  }

  Future<void> _handleInit() async {
    final initFuture = controller.init();
    if (mounted) setState(() {});
    await initFuture;
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _refreshAll() async {
    if (controller.isLoading) return;

    final refreshFuture = controller.init();
    setState(() {});
    await refreshFuture;
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if ((controller.isLoading || controller.errorMessage != null) &&
        controller.stats == null) {
      return AppPageShell(
        title: tr('dashboard.title'),
        body: AppStateView(
          loading: controller.isLoading,
          error: controller.errorMessage?.tr(),
          empty: false,
          emptyText: '',
          errorIcon: Icons.dashboard_customize_rounded,
          onRetry: _refreshAll,
          child: const SizedBox.shrink(),
        ),
      );
    }

    return AppPageShell(
      scaffoldKey: _scaffoldKey,
      title: tr('dashboard.title'),
      actions: [
        AppAsyncIconButton(
          icon: Icons.refresh_rounded,
          loading: controller.isLoading,
          onPressed: _refreshAll,
        ),
      ],
      drawer: HomeDrawer(
        onBilling: _openBilling,
        userName: widget.userName,
        role: widget.role,
        onGroups: () {
          _backToGroupsPage();
        },
        onDashboard: () => Navigator.pop(context),
        onNotifications: () => _openDrawerPage(
          AdminNotificationsPage(
            currentRole: widget.role,
            currentDepartment: widget.department,
          ),
        ),
        onProfile: () => _openDrawerPage(const ProfilePage()),
        onArchive: () => _openDrawerPage(const ArchivePage()),
        onEvents: () => _openDrawerPage(const EventsPage()),
        onSavedMessages: () => _openDrawerPage(const SavedMessagesPage()),
        onDownloads: () => _openDrawerPage(const DownloadsPage()),
        onGpaCalculator: () => _openDrawerPage(const GpaCalculatorPage()),
        onOpenPortal: _openPortal,
        onRegister: () => _openDrawerPage(const RegisterPage()),
        onLogout: widget.onLogout,
        onLanguage: _openLanguagePicker,
      ),
      body: RefreshIndicator(
          onRefresh: _refreshAll,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              DashboardHeader(
                userName: widget.userName,
                role: widget.role,
                department: widget.department,
              ),
              if (controller.errorMessage != null) ...[
                const SizedBox(height: 12),
                AppEmptyState(
                  icon: Icons.info_outline_rounded,
                  text: controller.errorMessage!.tr(),
                  actionLabel: 'common.retry'.tr(),
                  actionLoading: controller.isLoading,
                  onAction: _refreshAll,
                ),
              ],
              const SizedBox(height: 16),
              _buildStats(),
              const SizedBox(height: 16),
              DashboardSection(
                title: tr('dashboard.quick_actions'),
                child: _buildQuickActions(),
              ),
              const SizedBox(height: 16),
              _buildStudentsOverviewSection(),
            ],
          ),
        ),
    );
  }
}
