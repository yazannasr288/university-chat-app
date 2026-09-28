import 'reset_password_dialog.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/permissions/app_role_permissions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../../core/constants/app_departments.dart';
import '../../../core/constants/app_account_statuses.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_dropdown_field.dart';
import '../../../core/widgets/app_loader.dart';
import '../../../core/widgets/app_text_field.dart';
import '../controllers/admin_user_details_controller.dart';

class AdminUserDetailsDialog extends StatefulWidget {
  final String uid;
  final String currentRole;
  final Future<void> Function() onSaved;

  const AdminUserDetailsDialog({
    super.key,
    required this.uid,
    required this.currentRole,
    required this.onSaved,
  });

  @override
  State<AdminUserDetailsDialog> createState() => _AdminUserDetailsDialogState();
}

class _AdminUserDetailsDialogState extends State<AdminUserDetailsDialog> {
  final controller = AdminUserDetailsController();
  bool _resettingPassword = false;
  bool _resettingPin = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final loadFuture = controller.load(widget.uid);
    setState(() {});
    final error = await loadFuture;
    if (!mounted) return;
    setState(() {});
    if (error != null) {
      showAppSnackBar(context, error, type: SnackType.error);
      Navigator.pop(context);
    }
  }

  Future<void> _save() async {
    final saveFuture = controller.save();
    setState(() {});
    final error = await saveFuture;
    if (!mounted) return;
    setState(() {});

    if (error != null) {
      showAppSnackBar(context, error, type: SnackType.error);
      return;
    }

    await widget.onSaved();
    if (!mounted) return;
    showAppSnackBar(context, tr('dashboard.user_saved_success'), type: SnackType.success);
    Navigator.pop(context);
  }

  Future<void> _resetPassword() async {
    final password = await showDialog<String>(
      context: context,
      builder: (_) => const ResetPasswordDialog(),
    );

    if (password == null || password.isEmpty) return;

    setState(() => _resettingPassword = true);

    final error = await controller.resetPassword(password);

    if (!mounted) return;

    setState(() => _resettingPassword = false);

    if (error != null) {
      showAppSnackBar(context, error, type: SnackType.error);
      return;
    }

    showAppSnackBar(
      context,
      tr('dashboard.password_reset_success'),
      type: SnackType.success,
    );
  }
  Future<void> _resetPin() async {
    if (_resettingPin) return;

    setState(() => _resettingPin = true);
    final error = await controller.resetPin();
    if (!mounted) return;
    setState(() => _resettingPin = false);

    if (error != null) {
      showAppSnackBar(context, error, type: SnackType.error);
      return;
    }

    showAppSnackBar(context, tr('dashboard.pin_reset_success'), type: SnackType.success);
  }

  Widget _dropdownField({
    required String label,
    required String value,
    required List<String> values,
    required ValueChanged<String?> onChanged,
    required String Function(String value) labelBuilder,
  }) {
    return AppDropdownField<String>(
      value: value,
      fallbackValue: values.isEmpty ? null : values.first,
      label: label,
      options: values
          .map(
            (item) => AppDropdownOption<String>(
              value: item,
              label: labelBuilder(item),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }

  String _accountTypeLabel(String type) {
    switch (type) {
      case 'doctor':
        return tr('dashboard.account_type_doctor');
      case 'employee':
        return tr('dashboard.account_type_employee');
      case 'dean':
        return tr('dashboard.account_type_dean');
      case 'presidency_employee':
        return tr('dashboard.account_type_presidency_employee');
      case 'worker':
        return tr('dashboard.account_type_worker');
      default:
        return tr('dashboard.account_type_student');
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case AppAccountStatuses.suspended:
        return tr('dashboard.status_suspended');
      case AppAccountStatuses.removed:
        return tr('dashboard.status_removed');
      default:
        return tr('dashboard.status_active');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin0 = AppRolePermissions.isSystemAdminRole(widget.currentRole);
    final isRemovedAccount =
        controller.accountStatus == AppAccountStatuses.removed;
    final statusValues = isRemovedAccount
        ? const [AppAccountStatuses.removed]
        : controller.accountStatuses
            .where((status) => status != AppAccountStatuses.removed)
            .toList();
    final canChangeStatus = !isRemovedAccount;
    final activeDeviceName =
        controller.details?.activeDeviceName.isNotEmpty == true
            ? controller.details!.activeDeviceName
            : tr('dashboard.no_active_device');
    final pinStatus = controller.details?.hasPin == true
        ? tr('dashboard.pin_set')
        : tr('dashboard.pin_not_set');

    return Dialog(
      insetPadding: const EdgeInsets.all(AppSpacing.lg),
      child: Container(
        width: 720,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: context.appCardColorStrong,
          borderRadius: BorderRadius.circular(AppRadii.xl),
        ),
        child: controller.isLoading
            ? const SizedBox(height: 240, child: Center(child: AppLoader()))
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      tr('dashboard.user_details'),
                      style: context.textTheme.titleLarge?.copyWith(
                        color: context.appTextPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppTextField(
                      controller: controller.fullNameController,
                      label: tr('dashboard.full_name'),
                      hint: tr('dashboard.full_name_hint'),
                      icon: Icons.person_rounded,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      controller: controller.userIdController,
                      label: tr('dashboard.user_id'),
                      hint: tr('dashboard.user_id_hint'),
                      icon: Icons.badge_rounded,
                      readOnly: true,
                      helperText: tr('dashboard.user_id_locked_hint'),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      controller: controller.phoneController,
                      label: tr('dashboard.phone_number'),
                      hint: tr('dashboard.phone_number_hint'),
                      icon: Icons.phone_rounded,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _dropdownField(
                      label: tr('dashboard.filter_department'),
                      value: controller.department,
                      values: controller.departments,
                      onChanged: isAdmin0
                          ? (v) {
                              if (v != null) {
                                setState(() => controller.setDepartment(v));
                              }
                            }
                          : (_) {},
                      labelBuilder: (value) => tr(AppDepartments.labelKey(value)),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _dropdownField(
                      label: tr('dashboard.account_type'),
                      value: controller.accountType,
                      values: controller.accountTypes,
                      onChanged: isAdmin0
                          ? (v) {
                              if (v != null) {
                                setState(() => controller.setAccountType(v));
                              }
                            }
                          : (_) {},
                      labelBuilder: _accountTypeLabel,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _dropdownField(
                      label: tr('dashboard.filter_status'),
                      value: controller.accountStatus,
                      values: statusValues,
                      onChanged: canChangeStatus
                          ? (v) {
                              if (v != null &&
                                  v != AppAccountStatuses.removed) {
                                setState(() => controller.accountStatus = v);
                              }
                            }
                          : (_) {},
                      labelBuilder: _statusLabel,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      controller: controller.accountStatusReasonController,
                      minLines: 3,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: tr('dashboard.status_reason'),
                        hintText: tr('dashboard.status_reason_hint'),
                        prefixIcon: const Icon(Icons.info_outline_rounded),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: context.appSurfaceSoft,
                        borderRadius: BorderRadius.circular(AppRadii.md),
                        border: Border.all(color: context.appBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tr('dashboard.user_security_summary'),
                            style: context.textTheme.titleSmall?.copyWith(
                              color: context.appTextPrimary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            '${tr('dashboard.email')}: '
                            '${controller.details?.email ?? ''}',
                          ),
                          Text('${tr('dashboard.pin_label')}: $pinStatus'),
                          Text(
                            '${tr('dashboard.active_device')}: '
                            '$activeDeviceName',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        if (!isRemovedAccount)
                          AppButton(
                            text: tr('dashboard.save_changes'),
                            icon: Icons.save_rounded,
                            loading: controller.isSaving,
                            onPressed: controller.isSaving ? null : _save,
                          ),
                        if (!isRemovedAccount &&
                            AppRolePermissions.canManageUsersRole(widget.currentRole))
                          AppButton(
                            text: tr('dashboard.reset_password'),
                            icon: Icons.lock_reset_rounded,
                            backgroundColor: AppColors.supportNavy,
                            loading: _resettingPassword,
                            onPressed:
                                _resettingPassword ? null : _resetPassword,
                          ),
                        if (!isRemovedAccount &&
                            AppRolePermissions.canManageUsersRole(widget.currentRole))
                          AppButton(
                            text: tr('dashboard.reset_pin'),
                            icon: Icons.password_rounded,
                            backgroundColor: AppColors.supportNavy,
                            loading: _resettingPin,
                            onPressed: _resettingPin ? null : _resetPin,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
