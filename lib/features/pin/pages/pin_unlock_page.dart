import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/utils/app_snackbar.dart';
import '../../auth/pages/login_page.dart';
import '../../home/pages/home_page.dart';
import '../controllers/pin_unlock_controller.dart';
import 'pin_entry_view.dart';

class PinUnlockPage extends StatefulWidget {
  const PinUnlockPage({super.key});

  @override
  State<PinUnlockPage> createState() => _PinUnlockPageState();
}

class _PinUnlockPageState extends State<PinUnlockPage> {
  final controller = PinUnlockController();
  int errorTick = 0;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _handleCompletedPin(String pin) async {
    controller.pinController.text = pin;

    final result = await controller.unlock();

    if (!mounted) return;

    if (result.error != null) {
      setState(() {
        errorTick++;
      });

      showAppSnackBar(context, result.error!, type: SnackType.error);

      if (result.forceLogout) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginPage()),
          (_) => false,
        );
      }
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomePage()),
    );
  }

  Future<void> _handleLogout() async {
    await controller.logout();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PinEntryView(
      title: 'pin.unlock_app'.tr(),
      subtitle: 'pin.enter_pin'.tr(),
      onCompleted: _handleCompletedPin,
      errorTick: errorTick,
      bottomAction: TextButton(
        onPressed: _handleLogout,
        child: Text('auth.logout'.tr()),
      ),
    );
  }
}
