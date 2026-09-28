import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_departments.dart';
import '../../../core/constants/app_group_audiences.dart';
import '../../../core/permissions/app_roles.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../../core/utils/error_message.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../services/notification_service.dart';
import '../../archive/page/archive_page.dart';
import '../../chat/pages/chat_page.dart';
import '../../auth/pages/login_page.dart';
import '../../auth/pages/register_page.dart';
import '../../dashboard/pages/admin_cloud_billing_page.dart';
import '../../dashboard/pages/admin_dashboard_page.dart';
import '../../notifications/pages/admin_notifications_page.dart';
import '../../events/pages/events_page.dart';
import '../../gpa/pages/gpa_calculator_page.dart';
import '../../pages/web_page.dart';
import '../../downloads/pages/downloads_page.dart';
import '../../saved_messages/pages/saved_messages_page.dart';
import '../../profile/pages/profile_page.dart';
import '../../search/pages/search_page.dart';
import '../../../data/models/group_model.dart';
import '../controllers/home_controller.dart';
import '../widgets/group_tile.dart';
import '../widgets/home_drawer.dart';


part 'home_page/home_initialization.dart';
part 'home_page/home_navigation.dart';
part 'home_page/home_groups_body.dart';
part 'home_page/create_group_dialog.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final controller = HomeController();

  bool loading = true;
  String? initError;
  Stream<List<GroupModel>>? _userGroupsStream;

  void _safeSetState(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
  }

  @override
  void initState() {
    super.initState();
    _handleInit();
  }

  @override
  void dispose() {
    NotificationService.clearOpenGroupHandler();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (loading || initError != null) {
      return AppPageShell(
        body: AppStateView(
          loading: loading,
          error: initError,
          empty: false,
          emptyText: '',
          errorIcon: Icons.wifi_off_rounded,
          onRetry: initError != null ? _handleInit : null,
          child: const SizedBox.shrink(),
        ),
      );
    }

    return AppPageShell(
      appBar: AppBar(
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Alwatanya Chat',
              style: context.textTheme.titleMedium?.copyWith(
                fontSize: 21,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.25,
              ),
            ),

          ],
        ),
        actions: [
          IconButton.filledTonal(
            style: IconButton.styleFrom(
              backgroundColor: context.appPrimary.withValues(alpha: 0.10),
              foregroundColor: context.appPrimary,
            ),
            icon: const Icon(Icons.search_rounded),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SearchPage()),
              );
            },
          ),
        ],
      ),
      drawer: HomeDrawer(
        onBilling: _openBilling,
        userName: controller.userName,
        role: controller.role,
        accountType: controller.accountType,
        profilepic: controller.profilepic,
        onGroups: () => Navigator.pop(context),
        onProfile: () => _openDrawerPage(const ProfilePage()),
        onArchive: () => _openDrawerPage(const ArchivePage()),
        onEvents: () => _openDrawerPage(const EventsPage()),
        onSavedMessages: () => _openDrawerPage(const SavedMessagesPage()),
        onDownloads: () => _openDrawerPage(const DownloadsPage()),
        onGpaCalculator: () => _openDrawerPage(const GpaCalculatorPage()),

        onOpenPortal: () => _openDrawerPage(
          const WebPage(url: 'http://portal.wpu.edu.sy/login'),
        ),
        onDashboard: _openDashboard,
        onNotifications: () => _openDrawerPage(
          AdminNotificationsPage(
            currentRole: controller.role,
            currentDepartment: controller.department,
          ),
        ),
        onRegister: () => _openDrawerPage(const RegisterPage()),
        onLogout: _handleLogout,
        onLanguage: _openLanguagePicker,
      ),
      body: _buildBody(),
      floatingActionButton:
          controller.canCreateGroup
              ? DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: AppGradients.brand,
                    borderRadius: BorderRadius.circular(AppRadii.lg),
                    boxShadow:
                        context.isDark ? const [] : AppShadows.brandGlow,
                  ),
                  child: FloatingActionButton(
                    heroTag: 'home_create_group',
                    elevation: 0,
                    focusElevation: 0,
                    hoverElevation: 0,
                    highlightElevation: 0,
                    backgroundColor: Colors.transparent,
                    onPressed: _showCreateGroupDialog,
                    child: const Icon(Icons.add_rounded),
                  ),
                )
              : null,
    );
  }
}
