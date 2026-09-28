part of '../admin_dashboard_page.dart';

extension on _AdminDashboardPageState {
  void _openStudentsManagement() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => AdminStudentsPage(
              currentRole: widget.role,
              currentDepartment: widget.department,
            ),
      ),
    );
  }

  void _openBilling() {
    Navigator.pop(context);

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AdminCloudBillingPage()),
    );
  }

  void _openGroupsManagement() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => AdminGroupsPage(
              currentRole: widget.role,
              currentDepartment: widget.department,
            ),
      ),
    );
  }

  Future<void> _openDrawerPage(Widget page) async {
    _scaffoldKey.currentState?.closeDrawer();

    await Future.delayed(const Duration(milliseconds: 240));

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
  }

  void _openLanguagePicker() {
    Navigator.pop(context);
    showAppLanguagePicker(context);
  }

  void _openPortal() {
    _openDrawerPage(
      const WebPage(url: 'http://portal.wpu.edu.sy/login'),
    );
  }

  Future<void> _backToGroupsPage() async {
    _scaffoldKey.currentState?.closeDrawer();

    await Future.delayed(const Duration(milliseconds: 300));

    if (!mounted) return;

    Navigator.of(context).pop();
  }

}
