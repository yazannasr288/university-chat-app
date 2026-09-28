import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../pin/pages/pin_setup_page.dart';
import '../../pin/pages/pin_unlock_page.dart';
import '../controllers/app_gate_controller.dart';
import '../controllers/change_password_controller.dart';
import '../widgets/auth_page_body.dart';
import 'login_page.dart';

class ChangePasswordPage extends StatefulWidget {
  final bool isMandatory;

  const ChangePasswordPage({super.key, this.isMandatory = false});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final controller = ChangePasswordController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    setState(() {
      controller.isLoading = true;
    });

    final error = await controller.changePassword();

    if (!mounted) return;

    setState(() {
      controller.isLoading = false;
    });

    if (error != null) {
      showAppSnackBar(context, error, type: SnackType.error);
      return;
    }

    showAppSnackBar(
      context,
      'auth.password_changed_successfully'.tr(),
      type: SnackType.success,
    );

    if (!widget.isMandatory) {
      Navigator.pop(context);
      return;
    }

    final next = await controller.resolveNextAfterMandatoryChange();

    if (!mounted) return;

    switch (next) {
      case AppGateDestination.pinSetup:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const PinSetupPage()),
        );
        break;

      case AppGateDestination.pinUnlock:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const PinUnlockPage()),
        );
        break;

      case AppGateDestination.login:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginPage()),
        );
        break;

      case AppGateDestination.forceChangePassword:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !widget.isMandatory,
      child: AppPageShell(
        title: widget.isMandatory
            ? 'auth.set_new_password'.tr()
            : 'profile.change_password'.tr(),
        automaticallyImplyLeading: !widget.isMandatory,
        useBackground: false,
        body: AuthPageBody(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.isMandatory) ...[
                AppNotice(
                  icon: Icons.lock_reset_rounded,
                  text: 'auth.must_change_temporary_password_before_continuing'.tr(),
                  color: AppColors.accent,
                  backgroundColor: context.isDark
                      ? AppColors.accent.withValues(alpha: 0.12)
                      : AppColors.accentSoft,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
              AppTextField(
                controller: controller.oldPasswordController,
                label: 'auth.old_password'.tr(),
                hint: 'auth.enter_old_password'.tr(),
                icon: Icons.lock_rounded,
                obscureText: true,
                maxLength: 128,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: controller.newPasswordController,
                label: 'auth.new_password'.tr(),
                hint: 'auth.enter_new_password'.tr(),
                icon: Icons.lock_outline_rounded,
                obscureText: true,
                maxLength: 128,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: controller.confirmPasswordController,
                label: 'auth.confirm_new_password'.tr(),
                hint: 'auth.re_enter_new_password'.tr(),
                icon: Icons.verified_user_outlined,
                obscureText: true,
                maxLength: 128,
              ),
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                text: 'auth.save_password'.tr(),
                icon: Icons.save_rounded,
                loading: controller.isLoading,
                onPressed: _changePassword,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
