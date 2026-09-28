part of '../admin_dashboard_page.dart';

extension on _AdminDashboardPageState {
  Widget _buildStudentsOverviewSection() {
    final stats = controller.stats;
    if (stats == null) return const SizedBox.shrink();

    return DashboardSection(
      title: tr('dashboard.manage_students'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: ElevatedButton.icon(
              onPressed: _openStudentsManagement,
              icon: const Icon(Icons.manage_search_rounded),
              label: Text(tr('dashboard.open_students_management')),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildStats() {
    final stats = controller.stats;
    if (stats == null) return const SizedBox.shrink();

    return Center(
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          DashboardStatCard(
            title: tr('dashboard.total_users'),
            value: '${stats.totalUsers}',
            icon: Icons.groups_rounded,
          ),
          DashboardStatCard(
            title: tr('dashboard.role_admin0'),
            value: '${stats.totalAdmin0}',
            icon: Icons.admin_panel_settings_outlined,
          ),
          DashboardStatCard(
            title: tr('dashboard.total_admin1'),
            value: '${stats.totalAdmin1}',
            icon: Icons.admin_panel_settings_rounded,
          ),
          DashboardStatCard(
            title: tr('dashboard.total_admin2'),
            value: '${stats.totalAdmin2}',
            icon: Icons.shield_rounded,
          ),
          DashboardStatCard(
            title: tr('dashboard.total_students'),
            value: '${stats.totalStudents}',
            icon: Icons.school_rounded,
          ),
          DashboardStatCard(
            title: tr('dashboard.total_active_groups'),
            value: '${stats.totalActiveGroups}',
            icon: Icons.groups_3_rounded,
          ),
          DashboardStatCard(
            title: tr('dashboard.total_archived_groups'),
            value: '${stats.totalArchivedGroups}',
            icon: Icons.archive_rounded,
          ),
          DashboardStatCard(
            title: tr('dashboard.total_upcoming_events'),
            value: '${stats.totalUpcomingEvents}',
            icon: Icons.event_available_rounded,
          ),
          DashboardStatCard(
            title: tr('dashboard.total_suspended_users'),
            value: '${stats.totalSuspendedUsers}',
            icon: Icons.block_rounded,
          ),
          DashboardStatCard(
            title: tr('dashboard.total_removed_users'),
            value: '${stats.totalRemovedUsers}',
            icon: Icons.person_off_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    final bool isAdmin0 = AppRolePermissions.isSystemAdminRole(widget.role);
    void openBilling() {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AdminCloudBillingPage()),
      );
    }

    final items = <Widget>[
      if (isAdmin0)
        DashboardQuickActionTile(
          title: tr('dashboard.add_user'),
          icon: Icons.person_add_alt_1_rounded,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RegisterPage()),
            );
          },
        ),
      if (isAdmin0)
        DashboardQuickActionTile(
          title: tr('dashboard.monthly_billing'),
          icon: Icons.receipt_long_rounded,
          onTap: openBilling,
        ),

      DashboardQuickActionTile(
        title: tr('dashboard.manage_groups'),
        icon: Icons.groups_rounded,
        onTap: _openGroupsManagement,
      ),
      DashboardQuickActionTile(
        title: tr('dashboard.create_event'),
        icon: Icons.event_available_rounded,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateEventPage()),
          );
        },
      ),
      DashboardQuickActionTile(
        title: tr('dashboard.events'),
        icon: Icons.event_note_rounded,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const EventsPage()),
          );
        },
      ),
      DashboardQuickActionTile(
        title: tr('dashboard.archive'),
        icon: Icons.archive_outlined,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ArchivePage()),
          );
        },
      ),
      DashboardQuickActionTile(
        title: tr('dashboard.search_groups'),
        icon: Icons.search_rounded,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SearchPage()),
          );
        },
      ),
      if (isAdmin0)
        DashboardQuickActionTile(
          title: tr('dashboard.audit_center'),
          icon: Icons.history_rounded,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AdminAuditLogsPage()),
            );
          },
        ),
      DashboardQuickActionTile(
        title: tr('dashboard.profile'),
        icon: Icons.person_rounded,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ProfilePage()),
          );
        },
      ),
    ];

    return Wrap(spacing: 12, runSpacing: 12, children: items);
  }

}
