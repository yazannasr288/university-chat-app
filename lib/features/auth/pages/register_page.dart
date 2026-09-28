import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_departments.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../../data/controllers/bulk_import_controller.dart';
import '../controllers/register_controller.dart';
import '../widgets/account_type_option_tile.dart';
import '../widgets/auth_page_body.dart';
import '../widgets/bulk_import_status_card.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final controller = RegisterController();
  final bulkController = BulkImportController();

  @override
  void dispose() {
    controller.dispose();
    bulkController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final registerFuture = controller.register();
    setState(() {});
    final error = await registerFuture;
    if (!mounted) return;
    setState(() {});

    if (error != null) {
      showAppSnackBar(context, error, type: SnackType.error);
      return;
    }

    showAppSnackBar(
      context,
      'auth.register.success'.tr(),
      type: SnackType.success,
    );

    controller.reset();
    setState(() {});
  }

  Future<void> _pickBulkFile() async {
    final pickFuture = bulkController.pickFile();
    setState(() {});
    final error = await pickFuture;
    if (!mounted) return;
    setState(() {});

    if (error != null) {
      showAppSnackBar(context, error, type: SnackType.error);
      return;
    }

    showAppSnackBar(
      context,
      'auth.bulk_import.file_read_success'.tr(),
      type: SnackType.success,
    );
  }

  Future<void> _uploadStudents() async {
    final error = await bulkController.uploadStudents(
      onChanged: () {
        if (mounted) {
          setState(() {});
        }
      },
    );

    if (!mounted) return;

    if (error != null) {
      showAppSnackBar(context, error, type: SnackType.error);
      return;
    }

    showAppSnackBar(
      context,
      'auth.bulk_import.upload_started'.tr(),
      type: SnackType.success,
    );
  }

  Widget _buildDepartmentField() {
    return AppDropdownField<String>(
      value: controller.department,
      fallbackValue: controller.departments.first,
      label: 'common.department'.tr(),
      options:
          controller.departments
              .map(
                (department) => AppDropdownOption<String>(
                  value: department,
                  label: tr(AppDepartments.labelKey(department)),
                ),
              )
              .toList(),
      onChanged: (v) {
        if (v == null) return;
        setState(() => controller.setDepartment(v));
      },
    );
  }

  Widget _buildAccountTypes() {
    return RadioGroup<String>(
      groupValue: controller.accountType,
      onChanged: (value) {
        if (value == null) return;
        setState(() => controller.setAccountType(value, true));
      },
      child: Column(
        children: [
          Row(
            children: [
              _buildAccountTypeTile('roles.dean', 'dean'),
              const SizedBox(width: AppSpacing.sm),
              _buildAccountTypeTile(
                'roles.presidency_employee',
                'presidency_employee',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              _buildAccountTypeTile('roles.doctor', 'doctor'),
              const SizedBox(width: AppSpacing.sm),
              _buildAccountTypeTile('roles.department_staff', 'employee'),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              _buildAccountTypeTile('roles.worker', 'worker'),
              const SizedBox(width: AppSpacing.sm),
              _buildAccountTypeTile('roles.student', 'user'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAccountTypeTile(String titleKey, String value) {
    return Expanded(
      child: AccountTypeOptionTile(
        title: titleKey.tr(),
        value: value,
        selected: controller.accountType == value,
      ),
    );
  }

  Widget _buildSelectedFileBox() {
    final hasSelectedFile = bulkController.selectedFileName.isNotEmpty;

    return AppSurface.soft(
      padding: const EdgeInsets.all(AppSpacing.md),
      color: context.appSurfaceSoft,
      borderColor: context.appBorder,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: Row(
        children: [
          AppIconBadge(icon: Icons.description_rounded, size: 36, iconSize: 19),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              hasSelectedFile
                  ? bulkController.selectedFileName
                  : 'auth.bulk_import.no_file_selected_yet'.tr(),
              style: context.textTheme.bodyMedium?.copyWith(
                color:
                    hasSelectedFile
                        ? context.appTextPrimary
                        : context.appTextMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBulkSection(BuildContext context) {
    return AppSurface.card(
      padding: const EdgeInsets.all(AppSpacing.lg),
      color: context.appCardColorStrong,
      borderColor: context.appBorder,
      borderRadius: BorderRadius.circular(AppRadii.lg),
      boxShadow: context.isDark ? const [] : AppShadows.subtle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'auth.bulk_import.title'.tr(),
            style: context.textTheme.titleMedium?.copyWith(
              color: context.appTextPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'auth.bulk_import.instructions'.tr(),
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.appTextSecondary,
              height: 1.55,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _buildSelectedFileBox(),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  text: 'auth.bulk_import.choose_file'.tr(),
                  icon: Icons.upload_file_rounded,
                  loading: false,
                  backgroundColor: context.appPrimary,
                  onPressed: _pickBulkFile,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: AppButton(
                  text: 'auth.upload_students'.tr(),
                  icon: Icons.cloud_upload_rounded,
                  loading: bulkController.isLoading,
                  gradient: AppGradients.accentGlow,
                  onPressed: _uploadStudents,
                ),
              ),
            ],
          ),
          BulkImportStatusCard(
            jobStatus: bulkController.jobStatus,
            activeJobId: bulkController.activeJobId,
            statusText: bulkController.statusText,
            progressValue: bulkController.progressValue,
            isJobRunning: bulkController.isJobRunning,
            totalStudents: bulkController.totalStudents,
            processedChunks: bulkController.processedChunks,
            totalChunks: bulkController.totalChunks,
            successCount: bulkController.successCount,
            failCount: bulkController.failCount,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPageShell(
      title: 'auth.register_new_student'.tr(),
      useBackground: false,
      body: AuthPageBody(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Form(
          key: controller.formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'auth.user_data'.tr(),
                style: context.textTheme.titleLarge?.copyWith(
                  color: context.appTextPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: controller.fullNameController,
                label: 'common.full_name'.tr(),
                hint: 'auth.enter_full_name_2'.tr(),
                icon: Icons.person_rounded,
                maxLength: RegisterLimits.fullNameMaxLength,
                validator: controller.validateFullName,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: controller.userIdController,
                label: 'common.student_id'.tr(),
                hint: 'auth.enter_university_id'.tr(),
                icon: Icons.badge_rounded,
                maxLength: RegisterLimits.userIdMaxLength,
                validator: controller.validateUserId,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: controller.phoneController,
                label: 'common.phone'.tr(),
                hint: 'auth.enter_phone_number_2'.tr(),
                icon: Icons.phone_rounded,
                keyboardType: TextInputType.phone,
                maxLength: RegisterLimits.phoneMaxLength,
                validator: controller.validatePhone,
              ),
              const SizedBox(height: AppSpacing.md),
              _buildDepartmentField(),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: controller.passwordController,
                label: 'auth.temporary_password'.tr(),
                hint: 'auth.enter_temporary_password_2'.tr(),
                icon: Icons.lock_reset_rounded,
                obscureText: true,
                maxLength: RegisterLimits.passwordMaxLength,
                validator: controller.validatePassword,
              ),
              const SizedBox(height: AppSpacing.md),
              _buildAccountTypes(),
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                text: 'auth.register_student'.tr(),
                icon: Icons.person_add_alt_1_rounded,
                loading: controller.isLoading,
                onPressed: _register,
              ),
              const SizedBox(height: AppSpacing.xl),
              _buildBulkSection(context),
            ],
          ),
        ),
      ),
    );
  }
}
