import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_async_icon_button.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_loader.dart';
import '../../../core/widgets/app_info_row.dart';
import '../../../core/widgets/app_status_chip.dart';
import '../../../core/widgets/app_page_shell.dart';
import '../../../data/controllers/admin_cloud_billing_controller.dart';
import '../../../data/models/cloud_billing_summary.dart';

import '../widgets/dashboard_section.dart';
import '../widgets/dashboard_stat_card.dart';

part '../widgets/admin_cloud_billing_widgets.dart';
part 'admin_cloud_billing_page/billing_value_formatters.dart';
part 'admin_cloud_billing_page/billing_icons.dart';
part 'admin_cloud_billing_page/billing_labels.dart';
part 'admin_cloud_billing_page/billing_header_sections.dart';
part 'admin_cloud_billing_page/billing_category_sections.dart';
part 'admin_cloud_billing_page/billing_service_sections.dart';
part 'admin_cloud_billing_page/billing_advanced_sections.dart';
part 'admin_cloud_billing_page/billing_body.dart';

class AdminCloudBillingPage extends StatefulWidget {
  const AdminCloudBillingPage({super.key});

  @override
  State<AdminCloudBillingPage> createState() => _AdminCloudBillingPageState();
}

class _AdminCloudBillingPageState extends State<AdminCloudBillingPage> {
  static const double _moneyEpsilon = 0.005;

  final controller = AdminCloudBillingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool forceRefresh = false}) async {
    final future = controller.load(forceRefresh: forceRefresh);
    if (mounted) setState(() {});
    await future;
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _previousMonth() async {
    final future = controller.previousMonth();
    setState(() {});
    await future;
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _nextMonth() async {
    if (!controller.canGoNext) return;

    final future = controller.nextMonth();
    setState(() {});
    await future;
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return AppPageShell(
      title: tr('dashboard.monthly_billing'),
      actions: [
        AppAsyncIconButton(
          icon: Icons.refresh_rounded,
          loading: controller.isLoading,
          tooltip: tr('dashboard.billing_refresh'),
          onPressed: () => _load(forceRefresh: true),
        ),
      ],
      body: _body(),
    );
  }
}
