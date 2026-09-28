import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/storage/app_prefs.dart';
import '../../../core/constants/app_account_statuses.dart';
import '../../../data/repositories/session_repository.dart';

enum AppGateDestination { login, forceChangePassword, pinSetup, pinUnlock }

class AppGateController {
  final SessionRepository _sessionRepository;
  final CollectionReference<Map<String, dynamic>> _users;

  AppGateController({
    SessionRepository? sessionRepository,
    CollectionReference<Map<String, dynamic>>? usersCollection,
  }) : _sessionRepository = sessionRepository ?? SessionRepository(),
       _users =
           usersCollection ?? FirebaseFirestore.instance.collection('users');

  Future<AppGateDestination> resolve() async {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) {
      return AppGateDestination.login;
    }

    final localSessionId = await _sessionRepository.getLocalSessionId(
      firebaseUser.uid,
    );

    final localPendingSessionId = await _sessionRepository.getPendingSessionId(
      firebaseUser.uid,
    );

    final hasActive = localSessionId != null && localSessionId.isNotEmpty;
    final hasPending =
        localPendingSessionId != null && localPendingSessionId.isNotEmpty;

    if (!hasActive && !hasPending) {
      await _sessionRepository.forceLocalLogout();
      return AppGateDestination.login;
    }

    late final DocumentSnapshot<Map<String, dynamic>> doc;
    try {
      doc = await _users
          .doc(firebaseUser.uid)
          .get(const GetOptions(source: Source.server));
    } catch (_) {
      return _resolveOfflineDestination(
        hasActive: hasActive,
        hasPending: hasPending,
      );
    }

    if (!doc.exists) {
      await _sessionRepository.forceLocalLogout();
      return AppGateDestination.login;
    }

    final data = doc.data() ?? {};
    final accountStatus = AppAccountStatuses.normalize(data['accountStatus']);

    if (AppAccountStatuses.isSuspended(accountStatus)) {
      await AppPrefs.saveForcedLogoutReason(
        'auth.errors.account_suspended_by_admin',
      );
      await _sessionRepository.forceLocalLogout();
      return AppGateDestination.login;
    }

    if (AppAccountStatuses.isRemoved(accountStatus)) {
      await AppPrefs.saveForcedLogoutReason('auth.errors.account_removed');
      await _sessionRepository.forceLocalLogout();
      return AppGateDestination.login;
    }

    if (hasActive) {
      final remoteSessionId = (data['activeSessionId'] ?? '').toString();

      if (remoteSessionId != localSessionId) {
        await _sessionRepository.forceLocalLogout();
        return AppGateDestination.login;
      }
    } else {
      final remotePendingSessionId =
          (data['pendingSessionId'] ?? '').toString();

      if (remotePendingSessionId != localPendingSessionId) {
        await _sessionRepository.forceLocalLogout();
        return AppGateDestination.login;
      }
    }

    final mustChangePassword = data['mustChangePassword'] == true;
    if (mustChangePassword) {
      return AppGateDestination.forceChangePassword;
    }

    return _resolvePinDestination(data: data);
  }

  Future<AppGateDestination> resolveAfterMandatoryPasswordChange() async {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) {
      return AppGateDestination.login;
    }

    final localSessionId = await _sessionRepository.getLocalSessionId(
      firebaseUser.uid,
    );
    final localPendingSessionId = await _sessionRepository.getPendingSessionId(
      firebaseUser.uid,
    );
    final hasActive = localSessionId != null && localSessionId.isNotEmpty;
    final hasPending =
        localPendingSessionId != null && localPendingSessionId.isNotEmpty;

    late final DocumentSnapshot<Map<String, dynamic>> doc;
    try {
      doc = await _users
          .doc(firebaseUser.uid)
          .get(const GetOptions(source: Source.server));
    } catch (_) {
      return _resolveOfflineDestination(
        hasActive: hasActive,
        hasPending: hasPending,
      );
    }

    if (!doc.exists) {
      await _sessionRepository.forceLocalLogout();
      return AppGateDestination.login;
    }

    final data = doc.data() ?? {};

    return _resolvePinDestination(data: data);
  }

  Future<AppGateDestination> _resolvePinDestination({
    required Map<String, dynamic> data,
  }) async {
    final pinResetRequired = data['pinResetRequired'] == true;
    final hasServerPin = data['hasPin'] == true;

    if (pinResetRequired || !hasServerPin) {
      return AppGateDestination.pinSetup;
    }

    return AppGateDestination.pinUnlock;
  }

  Future<AppGateDestination> _resolveOfflineDestination({
    required bool hasActive,
    required bool hasPending,
  }) async {
    if (hasActive) {
      return AppGateDestination.pinUnlock;
    }

    if (hasPending) {
      return AppGateDestination.pinUnlock;
    }

    return AppGateDestination.login;
  }
}
