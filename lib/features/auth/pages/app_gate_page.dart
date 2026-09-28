import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/widgets/app_page_shell.dart';
import '../../../core/widgets/app_state_view.dart';
import '../../pin/pages/pin_setup_page.dart';
import '../../pin/pages/pin_unlock_page.dart';
import '../controllers/app_gate_controller.dart';
import 'change_password_page.dart';
import 'login_page.dart';

class AppGatePage extends StatefulWidget {
  const AppGatePage({super.key});

  @override
  State<AppGatePage> createState() => _AppGatePageState();
}

class _AppGatePageState extends State<AppGatePage> {
  final controller = AppGateController();
  late Future<AppGateDestination> _destinationFuture;

  @override
  void initState() {
    super.initState();
    _destinationFuture = controller.resolve();
  }

  void _retry() {
    setState(() {
      _destinationFuture = controller.resolve();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppGateDestination>(
      future: _destinationFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError || !snapshot.hasData) {
          return AppPageShell(
            body: AppStateView(
              loading: !snapshot.hasData && !snapshot.hasError,
              error: snapshot.hasError
                  ? 'auth.could_not_open_app_check_connection_try'.tr()
                  : null,
              empty: false,
              emptyText: '',
              errorIcon: Icons.wifi_off_rounded,
              onRetry: snapshot.hasError ? _retry : null,
              child: const SizedBox.shrink(),
            ),
          );
        }

        switch (snapshot.data!) {
          case AppGateDestination.login:
            return const LoginPage();
          case AppGateDestination.forceChangePassword:
            return const ChangePasswordPage(isMandatory: true);
          case AppGateDestination.pinSetup:
            return const PinSetupPage();
          case AppGateDestination.pinUnlock:
            return const PinUnlockPage();
        }
      },
    );
  }
}
