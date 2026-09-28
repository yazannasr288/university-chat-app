import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../auth/widgets/auth_page_body.dart';
import '../controllers/change_pin_controller.dart';
import '../widgets/pin_code_field.dart';

class ChangePinPage extends StatefulWidget {
  const ChangePinPage({super.key});

  @override
  State<ChangePinPage> createState() => _ChangePinPageState();
}

class _ChangePinPageState extends State<ChangePinPage> {
  final controller = ChangePinController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _handleChangePin() async {
    final error = await controller.changePin();
    if (!mounted) return;

    if (error != null) {
      showAppSnackBar(context, error, type: SnackType.error);
      return;
    }

    showAppSnackBar(
      context,
      'pin.pin_changed_successfully'.tr(),
      type: SnackType.success,
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AppPageShell(
      title: 'pin.change_pin'.tr(),
      useBackground: false,
      body: AuthPageBody(
        child: Column(
          children: [
            PinCodeField(
              controller: controller.oldPinController,
              label: 'pin.old_pin'.tr(),
              hint: 'pin.enter_old_pin'.tr(),
              icon: Icons.lock_rounded,
            ),
            const SizedBox(height: AppSpacing.md),
            PinCodeField(
              controller: controller.newPinController,
              label: 'pin.new_pin'.tr(),
              hint: 'pin.text_4_digits'.tr(),
              icon: Icons.pin_rounded,
            ),
            const SizedBox(height: AppSpacing.md),
            PinCodeField(
              controller: controller.confirmPinController,
              label: 'pin.confirm_new_pin'.tr(),
              hint: 'pin.re_enter_new_pin'.tr(),
              icon: Icons.pin_outlined,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              text: 'pin.save_changes'.tr(),
              icon: Icons.save_rounded,
              onPressed: _handleChangePin,
            ),
          ],
        ),
      ),
    );
  }
}
