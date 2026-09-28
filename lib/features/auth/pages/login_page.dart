import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/storage/app_prefs.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../../core/utils/error_message.dart';
import '../../pin/pages/pin_setup_page.dart';
import '../../pin/pages/pin_unlock_page.dart';
import '../controllers/login_controller.dart';
import '../widgets/auth_page_body.dart';
import 'change_password_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final controller = LoginController();

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final reason = await AppPrefs.consumeForcedLogoutReason();
      if (!mounted || reason == null || reason.isEmpty) return;

      showAppSnackBar(
        context,
        cleanErrorMessage(reason),
        type: SnackType.error,
      );
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  String _errorText(Object e) => cleanErrorMessage(e);

  Future<void> _login() async {
    try {
      final loginFuture = controller.login();
      setState(() {});
      final destination = await loginFuture;
      if (!mounted) return;
      setState(() {});

      switch (destination) {
        case LoginDestination.forceChangePassword:
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (_) => const ChangePasswordPage(isMandatory: true),
            ),
            (_) => false,
          );
          break;
        case LoginDestination.pinSetup:
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const PinSetupPage()),
            (_) => false,
          );
          break;
        case LoginDestination.pinUnlock:
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const PinUnlockPage()),
            (_) => false,
          );
          break;
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {});
      showAppSnackBar(context, _errorText(e), type: SnackType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppPageShell(
      title: 'auth.sign'.tr(),
      useBackground: false,
      body: AuthPageBody(
        child: Form(
          key: controller.formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppStaggeredEntrance(
                child: Center(
                  child: AppStaggeredEntrance(
                    child: Center(
                      child: Image.asset(
                        AppBranding.logoAsset,
                        width: 100,
                        height: 100,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                        semanticLabel: 'Alwatanya Chat logo',
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                AppBranding.appNameArabic.tr(),
                textAlign: TextAlign.center,
                style: context.textTheme.headlineSmall?.copyWith(fontSize: 24),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'auth.enter_university_id_password'.tr(),
                textAlign: TextAlign.center,
                style: context.textTheme.bodyLarge?.copyWith(
                  color: context.appTextSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              AppTextField(
                controller: controller.userIdController,
                label: 'common.student_id'.tr(),
                hint: 'auth.enter_university_id'.tr(),
                icon: Icons.badge_rounded,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'auth.enter_university_id_2'.tr();
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: controller.passwordController,
                label: 'auth.password'.tr(),
                hint: 'auth.enter_password'.tr(),
                icon: Icons.lock_rounded,
                obscureText: true,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'auth.enter_password_2'.tr();
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                text: 'auth.sign'.tr(),
                icon: Icons.login_rounded,
                loading: controller.isLoading,
                onPressed: _login,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
