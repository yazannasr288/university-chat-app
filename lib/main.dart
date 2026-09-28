import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'app.dart';
import 'core/storage/app_prefs.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/app_button.dart';
import 'core/widgets/app_scaffold_background.dart';
import 'core/widgets/app_surface.dart';
import 'data/repositories/chat_cache_repository.dart';
import 'firebase_options.dart';
import 'services/app_error_monitor.dart';
import 'services/notification_service.dart';

Future<void> _initializeServices() async {
  final firebaseInitialization = Firebase.apps.isEmpty
      ? Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        ).then<void>((_) {})
      : Future<void>.value();

  try {
    await Future.wait<void>([
      EasyLocalization.ensureInitialized(),
      firebaseInitialization,
      Hive.initFlutter().then((_) => ChatCacheRepository().init()),
      AppPrefs.init(),
    ]);
  } catch (error, stackTrace) {
    AppErrorMonitor.recordHandled(
      error,
      stackTrace,
      context: 'app_bootstrap',
    );
    rethrow;
  }

  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
}

Future<void> main() async {
  await runZonedGuarded<Future<void>>(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      AppErrorMonitor.init();
      runApp(const _AppBootstrap());
    },
    (error, stack) {
      AppErrorMonitor.recordHandled(
        error,
        stack,
        context: 'root_zone',
      );
    },
  );
}

class _AppBootstrap extends StatefulWidget {
  const _AppBootstrap();

  @override
  State<_AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<_AppBootstrap> {
  late Future<void> _initialization;

  @override
  void initState() {
    super.initState();
    _initialization = _initializeServices();
  }

  void _retry() {
    setState(() {
      _initialization = _initializeServices();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initialization,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _BootstrapLoadingScreen();
        }

        if (snapshot.hasError) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            home: Scaffold(
              body: AppScaffoldBackground(
                child: SafeArea(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 460),
                        child: AppSurface.card(
                          padding: const EdgeInsets.all(AppSpacing.xl),
                          boxShadow: AppShadows.card,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 82,
                                height: 82,
                                decoration: BoxDecoration(
                                  gradient: AppGradients.primary,
                                  borderRadius: BorderRadius.circular(
                                    AppRadii.xl,
                                  ),
                                  boxShadow: AppShadows.brandGlow,
                                ),
                                child: const Icon(
                                  Icons.sync_problem_rounded,
                                  size: 38,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                'تعذر تشغيل التطبيق',
                                textAlign: TextAlign.center,
                                style: AppTheme.light.textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w900),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'تحقق من الاتصال ثم أعد المحاولة.\n'
                                'The app could not start. Check your connection and retry.',
                                textAlign: TextAlign.center,
                                style: AppTheme.light.textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 22),
                              AppButton(
                                text: 'إعادة المحاولة / Retry',
                                icon: Icons.refresh_rounded,
                                onPressed: _retry,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        return EasyLocalization(
          supportedLocales: const [Locale('ar'), Locale('en')],
          path: 'assets/translations',
          fallbackLocale: const Locale('en'),
          saveLocale: true,
          useOnlyLangCode: true,
          child: const MyApp(),
        );
      },
    );
  }
}

class _BootstrapLoadingScreen extends StatefulWidget {
  const _BootstrapLoadingScreen();

  @override
  State<_BootstrapLoadingScreen> createState() =>
      _BootstrapLoadingScreenState();
}

class _BootstrapLoadingScreenState extends State<_BootstrapLoadingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 920),
    );
    _pulse = Tween<double>(begin: 0.97, end: 1.03).animate(
      CurvedAnimation(parent: _controller, curve: AppMotion.standard),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      _controller
        ..stop()
        ..value = 0.5;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: Scaffold(
        body: AppScaffoldBackground(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ScaleTransition(
                  scale: _pulse,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 94,
                        height: 94,
                        decoration: BoxDecoration(
                          gradient: AppGradients.brand,
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: AppShadows.brandGlow,
                        ),
                        child: const Icon(
                          Icons.forum_rounded,
                          size: 44,
                          color: Colors.white,
                        ),
                      ),
                      PositionedDirectional(
                        end: -4,
                        bottom: -4,
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            gradient: AppGradients.gold,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: AppShadows.goldGlow,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Alwatanya Chat',
                  style: AppTheme.light.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: AppColors.primaryDark,
                    letterSpacing: -0.35,
                  ),
                ),
                const SizedBox(height: 14),
                const SizedBox(
                  width: 30,
                  height: 30,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: AppColors.primary,
                    backgroundColor: AppColors.primarySoft,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
