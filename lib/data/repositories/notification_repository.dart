import 'dart:async';
import 'dart:ui';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationRepository {
  final FirebaseMessaging _messaging;
  final FirebaseFunctions _functions;

  static StreamSubscription<String>? _tokenRefreshSub;

  NotificationRepository({
    FirebaseMessaging? messaging,
    FirebaseFunctions? functions,
  })  : _messaging = messaging ?? FirebaseMessaging.instance,
        _functions = functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  String get _languageCode {
    final code = PlatformDispatcher.instance.locale.languageCode.trim().toLowerCase();
    return code == 'en' ? 'en' : 'ar';
  }

  Future<void> _saveToken({
    required String token,
    required String sessionId,
  }) async {
    final cleanToken = token.trim();
    final cleanSessionId = sessionId.trim();

    if (cleanToken.isEmpty || cleanSessionId.isEmpty) return;

    try {
      final callable = _functions.httpsCallable('saveCurrentFcmToken');
      await callable.call({
        'fcmToken': cleanToken,
        'sessionId': cleanSessionId,
        'languageCode': _languageCode,
      });
    } catch (_) {
      // لا نكسر تجربة المستخدم إذا تعذر تحديث توكن الإشعارات مؤقتًا.
    }
  }

  Future<void> saveTokenToUser(
    String _, {
    required String sessionId,
  }) async {
    final cleanSessionId = sessionId.trim();
    if (cleanSessionId.isEmpty) return;

    final token = await _messaging.getToken();
    if (token == null) return;

    await _saveToken(token: token, sessionId: cleanSessionId);

    await _tokenRefreshSub?.cancel();
    _tokenRefreshSub = _messaging.onTokenRefresh.listen((newToken) async {
      await _saveToken(token: newToken, sessionId: cleanSessionId);
    });
  }

  static Future<void> disposeTokenRefreshListener() async {
    await _tokenRefreshSub?.cancel();
    _tokenRefreshSub = null;
  }
}
