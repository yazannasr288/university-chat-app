import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/utils/app_snackbar.dart';
import '../../home/pages/home_page.dart';
import '../controllers/pin_setup_controller.dart';
import 'pin_entry_view.dart';

class PinSetupPage extends StatefulWidget {
  const PinSetupPage({super.key});

  @override
  State<PinSetupPage> createState() => _PinSetupPageState();
}

class _PinSetupPageState extends State<PinSetupPage> {
  final controller = PinSetupController();
  String? firstPin;
  int errorTick = 0;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _handlePin(String pin) async {
    if (firstPin == null) {
      setState(() {
        firstPin = pin;
      });
      return;
    }

    controller.pinController.text = firstPin!;
    controller.confirmPinController.text = pin;

    final error = await controller.savePin();

    if (!mounted) return;

    if (error != null) {
      setState(() {
        firstPin = null;
        errorTick++;
      });

      showAppSnackBar(context, error, type: SnackType.error);
      return;
    }

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const HomePage()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PinEntryView(
      title: firstPin == null ? 'pin.set_pin'.tr() : 'pin.confirm_pin'.tr(),
      subtitle: firstPin == null
          ? 'pin.enter_4_digits'.tr()
          : 'pin.re_enter_same_pin_confirm'.tr(),
      onCompleted: _handlePin,
      errorTick: errorTick,
    );
  }
}
