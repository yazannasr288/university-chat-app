import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_account_statuses.dart';
import '../../../core/constants/app_departments.dart';
import '../../../core/permissions/app_roles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_dropdown_field.dart';

class DashboardUserFilterBar extends StatefulWidget {
  final String query;
  final String selectedDepartment;
  final String selectedRole;
  final String selectedAccountStatus;
  final bool showDepartmentFilter;
  final bool showRoleFilter;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String> onDepartmentChanged;
  final ValueChanged<String> onRoleChanged;
  final ValueChanged<String> onStatusChanged;
  final Future<void> Function() onApply;
  final Future<void> Function() onClear;
  final bool loading;

  const DashboardUserFilterBar({
    super.key,
    required this.query,
    required this.selectedDepartment,
    required this.selectedRole,
    required this.selectedAccountStatus,
    this.showDepartmentFilter = true,
    this.showRoleFilter = true,
    required this.onQueryChanged,
    required this.onDepartmentChanged,
    required this.onRoleChanged,
    required this.onStatusChanged,
    required this.onApply,
    required this.onClear,
    this.loading = false,
  });

  @override
  State<DashboardUserFilterBar> createState() =>
      _DashboardUserFilterBarState();
}

class _DashboardUserFilterBarState extends State<DashboardUserFilterBar> {
  late final TextEditingController controller;

  static const List<String> roleValues = [
    AppRoles.systemAdmin,
    AppRoles.dean,
    AppRoles.departmentStaff,
    AppRoles.user,
  ];

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: widget.query);
  }

  @override
  void didUpdateWidget(covariant DashboardUserFilterBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query && controller.text != widget.query) {
      controller.text = widget.query;
      controller.selection = TextSelection.collapsed(
        offset: controller.text.length,
      );
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  String _roleKey(String value) {
    switch (value) {
      case AppRoles.systemAdmin:
        return 'dashboard.role_admin0';
      case AppRoles.dean:
        return 'dashboard.role_admin1';
      case AppRoles.departmentStaff:
        return 'dashboard.role_admin2';
      case AppRoles.user:
      default:
        return 'dashboard.role_student';
    }
  }

  @override
  Widget build(BuildContext context) {
    final departmentOptions = AppDepartments.values
        .map(
          (value) => AppDropdownOption<String>(
            value: value,
            label: tr(AppDepartments.labelKey(value)),
          ),
        )
        .toList();

    final roleOptions = roleValues
        .map(
          (value) => AppDropdownOption<String>(
            value: value,
            label: tr(_roleKey(value)),
          ),
        )
        .toList();

    final statusOptions = AppAccountStatuses.values
        .map(
          (value) => AppDropdownOption<String>(
            value: value,
            label: tr(AppAccountStatuses.labelKey(value)),
          ),
        )
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: controller,
          onChanged: widget.onQueryChanged,
          decoration: InputDecoration(
            labelText: tr('dashboard.filter_search'),
            prefixIcon: const Icon(Icons.search_rounded),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 10,
          children: [
            if (widget.showDepartmentFilter)
              SizedBox(
                width: 220,
                child: AppDropdownField<String>(
                  value: widget.selectedDepartment.isEmpty
                      ? null
                      : widget.selectedDepartment,
                  label: tr('dashboard.filter_department'),
                  options: departmentOptions,
                  onChanged: (v) => widget.onDepartmentChanged(v ?? ''),
                ),
              ),
            if (widget.showRoleFilter)
              SizedBox(
                width: 180,
                child: AppDropdownField<String>(
                  value: widget.selectedRole.isEmpty ? null : widget.selectedRole,
                  label: tr('dashboard.filter_role'),
                  options: roleOptions,
                  onChanged: (v) => widget.onRoleChanged(v ?? ''),
                ),
              ),
            SizedBox(
              width: 180,
              child: AppDropdownField<String>(
                value: widget.selectedAccountStatus.isEmpty
                    ? null
                    : widget.selectedAccountStatus,
                label: tr('dashboard.filter_status'),
                options: statusOptions,
                onChanged: (v) => widget.onStatusChanged(v ?? ''),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final isSmall = constraints.maxWidth < 420;

            if (isSmall) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppButton(
                    text: tr('dashboard.apply_filters'),
                    icon: Icons.filter_alt_rounded,
                    loading: widget.loading,
                    onPressed: widget.loading ? null : widget.onApply,
                  ),
                  const SizedBox(height: 10),
                  AppButton(
                    text: tr('dashboard.clear_filters'),
                    icon: Icons.clear_all_rounded,
                    backgroundColor: AppColors.supportNavy,
                    onPressed: widget.loading ? null : widget.onClear,
                  ),
                ],
              );
            }

            return Row(
              children: [
                Expanded(
                  child: AppButton(
                    text: tr('dashboard.apply_filters'),
                    icon: Icons.filter_alt_rounded,
                    loading: widget.loading,
                    onPressed: widget.loading ? null : widget.onApply,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AppButton(
                    text: tr('dashboard.clear_filters'),
                    icon: Icons.clear_all_rounded,
                    backgroundColor: AppColors.supportNavy,
                    onPressed: widget.loading ? null : widget.onClear,
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}
