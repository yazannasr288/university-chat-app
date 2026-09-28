import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'core/storage/app_prefs.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/pages/app_gate_page.dart';
import 'services/app_error_monitor.dart';
import 'services/notification_service.dart';

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(
        NotificationService.init().catchError((
          Object error,
          StackTrace stackTrace,
        ) {
          AppErrorMonitor.recordHandled(
            error,
            stackTrace,
            context: 'notification_init',
          );
        }),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppPrefs.themeModeNotifier,
      builder: (_, themeMode, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          onGenerateTitle: (context) => 'Alwatanya Chat',
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: themeMode,
          themeAnimationDuration: AppMotion.slow,
          themeAnimationCurve: AppMotion.emphasized,
          locale: context.locale,
          supportedLocales: context.supportedLocales,
          localizationsDelegates: context.localizationDelegates,
          home: const AppGatePage(),
        );
      },
    );
  }
}
