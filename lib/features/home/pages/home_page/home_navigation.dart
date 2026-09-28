part of '../home_page.dart';

extension on _HomePageState {

  Future<void> _openDrawerPage(Widget page) async {
    Navigator.pop(context);

    await Future<void>.delayed(const Duration(milliseconds: 220));
    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
  }

  Future<void> _openDashboard() async {
    Navigator.pop(context); // إغلاق الـ drawer

    await Future.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminDashboardPage(
          userName: controller.userName,
          role: controller.role,
          department: controller.department,
          onLogout: _handleLogout,
        ),
      ),
    );
  }

  Future<void> _openBilling() async {
    Navigator.pop(context);

    await Future.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AdminCloudBillingPage(),
      ),
    );
  }

  Future<void> _handleLogout() async {
    Navigator.pop(context);
    await controller.logout();
    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (_) => false,
    );
  }

  Future<void> _showCreateGroupDialog() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => _CreateGroupDialog(controller: controller),
    );

    if (!mounted || created != true) return;

    showAppSnackBar(
      context,
      'home.group_created'.tr(),
      type: SnackType.success,
    );
  }

  void _openLanguagePicker() {
    Navigator.pop(context);
    showAppLanguagePicker(context);
  }

}
