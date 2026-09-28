import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import '../../core/permissions/app_roles.dart';
import '../../core/constants/app_account_statuses.dart';
import '../../core/storage/app_prefs.dart';
import '../../core/storage/pin_storage.dart';
import 'notification_repository.dart';

class SessionActivationResult {
  final bool pinResetRequired;
  final bool hasServerPin;
  final bool mustChangePassword;

  const SessionActivationResult({
    required this.pinResetRequired,
    required this.hasServerPin,
    required this.mustChangePassword,
  });
}

class SessionRepository {
  final CollectionReference<Map<String, dynamic>> _users;
  final FlutterSecureStorage _secureStorage;
  final DeviceInfoPlugin _deviceInfo;
  final Uuid _uuid;
  final FirebaseFunctions _functions;
  final FirebaseMessaging _messaging;
  final FirebaseAuth _auth;
  final NotificationRepository _notificationRepository;

  static const String _deviceIdKey = 'device_id';

  bool _isManualLogout = false;

  SessionRepository({
    CollectionReference<Map<String, dynamic>>? usersCollection,
    FlutterSecureStorage? secureStorage,
    DeviceInfoPlugin? deviceInfo,
    Uuid? uuid,
    FirebaseFunctions? functions,
    FirebaseMessaging? messaging,
    FirebaseAuth? auth,
    NotificationRepository? notificationRepository,
  })  : _users = usersCollection ?? FirebaseFirestore.instance.collection('users'),
        _secureStorage = secureStorage ?? const FlutterSecureStorage(),
        _deviceInfo = deviceInfo ?? DeviceInfoPlugin(),
        _uuid = uuid ?? const Uuid(),
        _functions = functions ?? FirebaseFunctions.instanceFor(region: 'us-central1'),
        _messaging = messaging ?? FirebaseMessaging.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _notificationRepository =
            notificationRepository ?? NotificationRepository();

  String _sessionKey(String uid) => 'session_id_$uid';

  String _pendingSessionKey(String uid) => 'pending_session_id_$uid';

  User? get _currentUser => _auth.currentUser;

  String get _languageCode {
    final code = PlatformDispatcher.instance.locale.languageCode.trim().toLowerCase();
    return code == 'en' ? 'en' : 'ar';
  }

  Future<String> _getOrCreateDeviceId() async {
    final existing = await _secureStorage.read(key: _deviceIdKey);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }

    final deviceId = _uuid.v4();
    await _secureStorage.write(key: _deviceIdKey, value: deviceId);
    return deviceId;
  }

  Future<void> _clearCurrentFcmTokenOnServer({required String sessionId}) async {
    final user = _currentUser;
    if (user == null || sessionId.trim().isEmpty) return;

    try {
      final callable = _functions.httpsCallable('clearCurrentFcmToken');
      await callable.call({'sessionId': sessionId.trim()});
    } catch (_) {}
  }

  Future<String> _getDeviceName() async {
    if (Platform.isAndroid) {
      final info = await _deviceInfo.androidInfo;
      return '${info.brand} ${info.model}';
    }

    if (Platform.isIOS) {
      final info = await _deviceInfo.iosInfo;
      return '${info.name} ${info.model}';
    }

    return tr('common.unknown_device');
  }

  Future<String?> getLocalSessionId(String uid) async {
    return _secureStorage.read(key: _sessionKey(uid));
  }

  Future<String?> getPendingSessionId(String uid) async {
    return _secureStorage.read(key: _pendingSessionKey(uid));
  }

  Future<void> _saveLocalSessionId(String uid, String sessionId) async {
    await _secureStorage.write(key: _sessionKey(uid), value: sessionId);
  }

  Future<void> _savePendingSessionId(String uid, String sessionId) async {
    await _secureStorage.write(key: _pendingSessionKey(uid), value: sessionId);
  }

  Future<void> _clearLocalSessionId(String uid) async {
    await _secureStorage.delete(key: _sessionKey(uid));
  }

  Future<void> _clearPendingSessionId(String uid) async {
    await _secureStorage.delete(key: _pendingSessionKey(uid));
  }

  Future<SessionActivationResult> prepareAfterPasswordLogin() async {
    final currentUser = _currentUser;
    if (currentUser == null) {
      throw Exception(tr('auth.errors.no_signed_in_user'));
    }

    final sessionId = _uuid.v4();
    final deviceId = await _getOrCreateDeviceId();
    final deviceName = await _getDeviceName();
    final fcmToken = await _messaging.getToken() ?? '';

    final callable = _functions.httpsCallable(
      'startPendingSessionAfterPassword',
    );

    final response = await callable.call({
      'sessionId': sessionId,
      'deviceId': deviceId,
      'deviceName': deviceName,
      'fcmToken': fcmToken,
      'languageCode': _languageCode,
    });

    final data = Map<String, dynamic>.from(response.data);
    final user = Map<String, dynamic>.from(data['user'] ?? {});

    await AppPrefs.saveUserSession(
      name: (user['fullName'] ?? '').toString(),
      email: (user['email'] ?? '').toString(),
      role: (user['role'] ?? AppRoles.user).toString(),
      accountType: (user['accountType'] ?? AppRoles.user).toString(),
      department: (user['department'] ?? '').toString(),
      profilepic: (user['profilepic'] ?? '').toString(),
    );

    await _savePendingSessionId(currentUser.uid, sessionId);

    final hasServerPin = data['hasPin'] == true;
    return SessionActivationResult(
      pinResetRequired: data['pinResetRequired'] == true,
      hasServerPin: hasServerPin,
      mustChangePassword: data['mustChangePassword'] == true,
    );
  }

  Future<void> _ensureAuthenticated() async {
    final user = _currentUser;
    if (user == null) {
      throw Exception(tr('auth.errors.no_signed_in_user'));
    }

    await user.getIdToken(true);
  }

  Future<void> saveUserPin({required String pin}) async {
    await _ensureAuthenticated();

    final callable = _functions.httpsCallable('saveUserPin');

    await callable.call({'pin': pin});
  }
  Future<void> changeUserPin({
    required String oldPin,
    required String newPin,
  }) async {
    await _ensureAuthenticated();

    final callable = _functions.httpsCallable('changeUserPin');

    await callable.call({
      'oldPin': oldPin,
      'newPin': newPin,
    });
  }

  Future<Map<String, dynamic>> verifyUserPinState({required String pin}) async {
    await _ensureAuthenticated();

    final callable = _functions.httpsCallable('verifyUserPin');
    final response = await callable.call({'pin': pin});

    return Map<String, dynamic>.from(response.data);
  }

  Future<bool> verifyUserPin({required String pin}) async {
    final data = await verifyUserPinState(pin: pin);
    return data['success'] == true;
  }

  Future<void> activatePendingAfterPinIfAny() async {
    final user = _currentUser;
    if (user == null) return;

    final pendingSessionId = await getPendingSessionId(user.uid);
    if (pendingSessionId == null || pendingSessionId.isEmpty) return;

    await _ensureAuthenticated();

    final callable = _functions.httpsCallable('activatePendingSessionAfterPin');

    await callable.call({'sessionId': pendingSessionId});

    await _saveLocalSessionId(user.uid, pendingSessionId);
    await _clearPendingSessionId(user.uid);

    await _notificationRepository.saveTokenToUser(
      user.uid,
      sessionId: pendingSessionId,
    );
  }


  Future<void> _verifyCurrentSessionAfterListenerError({
    required String uid,
    required void Function() onSessionInvalid,
    void Function(String reason)? onSessionForcedLogout,
  }) async {
    await Future<void>.delayed(const Duration(seconds: 3));

    if (_isManualLogout || _currentUser?.uid != uid) return;

    try {
      final doc = await _users.doc(uid).get();
      if (_isManualLogout || _currentUser?.uid != uid) return;

      final data = doc.data();
      if (data == null) {
        await forceLocalLogout();
        if (!_isManualLogout) onSessionInvalid();
        return;
      }

      final accountStatus = AppAccountStatuses.normalize(data['accountStatus']);

      if (AppAccountStatuses.isSuspended(accountStatus)) {
        final reason = tr('auth.errors.account_suspended_by_admin');
        await AppPrefs.saveForcedLogoutReason(reason);
        await forceLocalLogout();
        if (!_isManualLogout) {
          onSessionForcedLogout?.call(reason);
          onSessionInvalid();
        }
        return;
      }

      if (AppAccountStatuses.isRemoved(accountStatus)) {
        final reason = tr('auth.errors.account_removed');
        await AppPrefs.saveForcedLogoutReason(reason);
        await forceLocalLogout();
        if (!_isManualLogout) {
          onSessionForcedLogout?.call(reason);
          onSessionInvalid();
        }
        return;
      }

      final localSessionId = await getLocalSessionId(uid);
      final remoteSessionId = (data['activeSessionId'] ?? '').toString();

      if (localSessionId == null ||
          localSessionId.isEmpty ||
          remoteSessionId != localSessionId) {
        await forceLocalLogout();
        if (!_isManualLogout) onSessionInvalid();
      }
    } catch (_) {
      // A listener/read error by itself is not proof that the session is invalid.
      // Keep the user signed in and let Firestore reconnect automatically.
    }
  }

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>
  watchCurrentSession({
    required void Function() onSessionInvalid,
    void Function(String reason)? onSessionForcedLogout,
  }) {
    final user = _currentUser;
    if (user == null) {
      throw Exception(tr('auth.errors.no_signed_in_user'));
    }

    var invalidationStarted = false;

    Future<void> invalidateSession({String? reason}) async {
      if (_isManualLogout || invalidationStarted) return;
      invalidationStarted = true;

      if (reason != null) {
        await AppPrefs.saveForcedLogoutReason(reason);
      }

      await forceLocalLogout();
      if (_isManualLogout) return;

      if (reason != null) {
        onSessionForcedLogout?.call(reason);
      }
      onSessionInvalid();
    }

    return _users.doc(user.uid).snapshots().listen(
      (doc) async {
        if (_isManualLogout || invalidationStarted) return;

        // The session is activated by a callable function, so the local cache
        // can briefly contain the previous activeSessionId after navigation.
        if (doc.metadata.isFromCache) return;

        final data = doc.data();
        if (data == null) {
          await invalidateSession();
          return;
        }
        final accountStatus = AppAccountStatuses.normalize(data['accountStatus']);

        if (AppAccountStatuses.isSuspended(accountStatus)) {
          await invalidateSession(
            reason: tr('auth.errors.account_suspended_by_admin'),
          );
          return;
        }

        if (AppAccountStatuses.isRemoved(accountStatus)) {
          await invalidateSession(reason: tr('auth.errors.account_removed'));
          return;
        }

        final localSessionId = await getLocalSessionId(user.uid);
        final remoteSessionId = (data['activeSessionId'] ?? '').toString();

        if (localSessionId == null || localSessionId.isEmpty) {
          await invalidateSession();
          return;
        }

        if (remoteSessionId != localSessionId) {
          await invalidateSession();
        }
      },
      onError: (_) {
        unawaited(
          _verifyCurrentSessionAfterListenerError(
            uid: user.uid,
            onSessionInvalid: onSessionInvalid,
            onSessionForcedLogout: onSessionForcedLogout,
          ),
        );
      },
    );
  }

  Future<void> closeCurrentSessionIfNeeded() async {
    final user = _currentUser;
    if (user == null) return;

    final sessionId = await getLocalSessionId(user.uid);
    if (sessionId == null || sessionId.isEmpty) return;

    final callable = _functions.httpsCallable('closeCurrentSession');

    await callable.call({'sessionId': sessionId});
  }

  Future<void> forceLocalLogout() async {
    final user = _currentUser;

    if (user != null) {
      final localSessionId = await getLocalSessionId(user.uid);
      final pendingSessionId = await getPendingSessionId(user.uid);

      if (localSessionId != null && localSessionId.isNotEmpty) {
        await _clearCurrentFcmTokenOnServer(sessionId: localSessionId);
      }

      if (pendingSessionId != null && pendingSessionId.isNotEmpty) {
        await _clearCurrentFcmTokenOnServer(sessionId: pendingSessionId);
      }

      await _clearLocalSessionId(user.uid);
      await _clearPendingSessionId(user.uid);
      await PinStorage.clearPin(user.uid);
    }

    await AppPrefs.clear();
    await NotificationRepository.disposeTokenRefreshListener();
    await _auth.signOut();
  }

  Future<void> logout() async {
    _isManualLogout = true;

    try {
      await closeCurrentSessionIfNeeded();
    } finally {
      await forceLocalLogout();
    }
  }
}
