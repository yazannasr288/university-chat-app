import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_departments.dart';
import '../../../core/constants/app_group_statuses.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_dropdown_field.dart';

class DashboardGroupFilterBar extends StatefulWidget {

  final String query;
  final String selectedDepartment;
  final String selectedStatus;
  final bool showDepartmentFilter;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String> onDepartmentChanged;
  final ValueChanged<String> onStatusChanged;
  final Future<void> Function() onApply;
  final Future<void> Function() onClear;
  final bool loading;

  const DashboardGroupFilterBar({
    super.key,
    required this.query,
    required this.selectedDepartment,
    this.showDepartmentFilter = true,
    required this.selectedStatus,
    required this.onQueryChanged,
    required this.onDepartmentChanged,
    required this.onStatusChanged,
    required this.onApply,
    required this.onClear,
    this.loading = false,
  });

  @override
  State<DashboardGroupFilterBar> createState() => _DashboardGroupFilterBarState();
}

class _DashboardGroupFilterBarState extends State<DashboardGroupFilterBar> {
  late final TextEditingController controller;

  static const List<String> statusValues = AppGroupStatuses.filterValues;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: widget.query);
  }

  @override
  void didUpdateWidget(covariant DashboardGroupFilterBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query && controller.text != widget.query) {
      controller.text = widget.query;
      controller.selection = TextSelection.collapsed(offset: controller.text.length);
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  String _statusKey(String value) => AppGroupStatuses.labelKey(value);

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

    final statusOptions = statusValues
        .map(
          (value) => AppDropdownOption<String>(
            value: value,
            label: tr(_statusKey(value)),
          ),
        )
        .toList();

    return Column(
      children: [
        TextField(
          controller: controller,
          onChanged: widget.onQueryChanged,
          decoration: InputDecoration(
            labelText: tr('dashboard.group_filter_search'),
            prefixIcon: const Icon(Icons.search_rounded),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
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
            SizedBox(
              width: 220,
              child: AppDropdownField<String>(
                value: widget.selectedStatus,
                fallbackValue: AppGroupStatuses.all,
                label: tr('dashboard.group_filter_status'),
                options: statusOptions,
                onChanged: (v) => widget.onStatusChanged(v ?? AppGroupStatuses.all),
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
