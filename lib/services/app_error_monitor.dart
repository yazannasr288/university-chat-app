import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

class AppErrorMonitor {
  AppErrorMonitor._();

  static bool _initialized = false;
  static FlutterExceptionHandler? _previousFlutterErrorHandler;
  static final Map<String, int> _lastReportByKey = <String, int>{};

  static void init() {
    if (_initialized) return;
    _initialized = true;

    _previousFlutterErrorHandler = FlutterError.onError;
    FlutterError.onError = (details) {
      _previousFlutterErrorHandler?.call(details);
      unawaited(
        recordError(
          details.exception,
          details.stack ?? StackTrace.current,
          fatal: false,
          context: details.context?.toDescription(),
        ),
      );
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      unawaited(
        recordError(
          error,
          stack,
          fatal: true,
          context: 'platform_dispatcher',
        ),
      );
      return true;
    };
  }

  static Future<void> recordError(
    Object error,
    StackTrace stack, {
    bool fatal = false,
    String? context,
  }) async {
    if (!_shouldReport(error, context)) return;

    if (kDebugMode) {
      debugPrint('AppErrorMonitor[$context]: $error');
      debugPrintStack(stackTrace: stack);
    }

    try {
      await FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('recordClientError')
          .call({
        'fatal': fatal,
        'context': _limit(context ?? 'unknown', 120),
        'errorType': _limit(error.runtimeType.toString(), 80),
        'message': _limit(error.toString(), 500),
        'stack': _limit(stack.toString(), 3500),
        'platform': defaultTargetPlatform.name,
        'isDebug': kDebugMode,
      });
    } catch (_) {
      // Monitoring must never affect the user flow.
    }
  }

  static void recordHandled(
    Object error,
    StackTrace stack, {
    String? context,
  }) {
    unawaited(recordError(error, stack, fatal: false, context: context));
  }

  static bool _shouldReport(Object error, String? context) {
    final key = '${error.runtimeType}|${context ?? ''}|${error.toString()}';
    final now = DateTime.now().millisecondsSinceEpoch;
    final last = _lastReportByKey[key] ?? 0;
    if (now - last < 5000) return false;
    _lastReportByKey[key] = now;

    if (_lastReportByKey.length > 80) {
      final keysToRemove = _lastReportByKey.keys.take(20).toList();
      for (final oldKey in keysToRemove) {
        _lastReportByKey.remove(oldKey);
      }
    }

    return true;
  }

  static String _limit(String value, int maxLength) {
    final clean = value.trim();
    if (clean.length <= maxLength) return clean;
    return clean.substring(0, maxLength);
  }
}
