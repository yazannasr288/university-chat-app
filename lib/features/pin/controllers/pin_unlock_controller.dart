import 'dart:async';
import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/storage/pin_storage.dart';
import '../../../data/repositories/session_repository.dart';

class PinUnlockResult {
  final String? error;
  final bool forceLogout;
  final int remainingAttempts;

  const PinUnlockResult({
    this.error,
    this.forceLogout = false,
    this.remainingAttempts = 3,
  });
}

class PinUnlockController {
  final pinController = TextEditingController();
  final SessionRepository _sessionRepository;

  static const int maxAttempts = 3;
  static const Duration serverPinTimeout = Duration(seconds: 12);

  PinUnlockController({
    SessionRepository? sessionRepository,
  }) : _sessionRepository = sessionRepository ?? SessionRepository();

  Future<PinUnlockResult> unlock() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null || uid.isEmpty) {
      return PinUnlockResult(
        error: tr('auth.errors.session_expired_sign_in_again_short'),
        forceLogout: true,
      );
    }

    final enteredPin = pinController.text.trim();

    if (enteredPin.length != 4 || int.tryParse(enteredPin) == null) {
      return PinUnlockResult(
        error: tr('pin.pin_must_4_digits'),
      );
    }

    final localSessionId =
    await _sessionRepository.getLocalSessionId(uid);

    final pendingSessionId =
    await _sessionRepository.getPendingSessionId(uid);

    final hasActiveSession =
        localSessionId != null &&
            localSessionId.trim().isNotEmpty;

    final hasPendingSession =
        pendingSessionId != null &&
            pendingSessionId.trim().isNotEmpty;

    try {
      return await _unlockWithServer(uid, enteredPin).timeout(
        serverPinTimeout,
      );
    } catch (e) {
      if (!_isConnectivityError(e)) {
        return PinUnlockResult(
          error: tr('pin.could_not_verify_pin_try_again'),
        );
      }

      if (hasPendingSession && !hasActiveSession) {
        return PinUnlockResult(
          error: tr(
            'pin.must_connect_internet_once_activate_device_after',
          ),
        );
      }

      if (hasActiveSession) {
        return _unlockWithLocalPin(uid, enteredPin);
      }

      return PinUnlockResult(
        error: tr(
          'pin.could_not_verify_pin_check_connection_try',
        ),
      );
    }
  }

  Future<PinUnlockResult> _unlockWithServer(String uid, String pin) async {
    final serverState = await _sessionRepository.verifyUserPinState(pin: pin);
    final ok = serverState['success'] == true;

    if (!ok) {
      final remainingAttempts =
          (serverState['remainingAttempts'] ?? maxAttempts) as int;
      final forceLogout =
          serverState['forceLogout'] == true || remainingAttempts <= 0;

      if (forceLogout) {
        try {
          await _sessionRepository.logout();
        } catch (_) {}

        return PinUnlockResult(
          error: tr('pin.text_3_attempts_exceeded_have_been_signed_out'),
          forceLogout: true,
          remainingAttempts: 0,
        );
      }

      return PinUnlockResult(
        error: tr(
          'pin.incorrect_pin_value_attempts_remaining',
          args: ['$remainingAttempts'],
        ),
        remainingAttempts: remainingAttempts,
      );
    }

    await PinStorage.savePin(uid: uid, pin: pin);
    await PinStorage.resetFailedAttempts(uid);
    await _sessionRepository.activatePendingAfterPinIfAny();

    return const PinUnlockResult();
  }

  Future<PinUnlockResult> _unlockWithLocalPin(String uid, String pin) async {
    final hasLocalPin = await PinStorage.hasPin(uid);
    if (!hasLocalPin) {
      return PinUnlockResult(
        error: tr('pin.no_pin_saved_locally_connect_internet_once'),
      );
    }

    final offlineUnlockAllowed = await PinStorage.isOfflineUnlockAllowed(uid);
    if (!offlineUnlockAllowed) {
      return PinUnlockResult(
        error: tr(
          'pin.offline_pin_unlock_has_expired_connect_internet',
        ),
      );
    }

    final ok = await PinStorage.verifyPin(uid: uid, pin: pin);
    if (ok) {
      await PinStorage.resetFailedAttempts(uid);
      return const PinUnlockResult();
    }

    final attempts = await PinStorage.incrementFailedAttempts(uid);
    final remainingAttempts = (maxAttempts - attempts).clamp(0, maxAttempts);

    if (remainingAttempts <= 0) {
      await _sessionRepository.forceLocalLogout();
      return PinUnlockResult(
        error: tr('pin.text_3_attempts_exceeded_have_been_signed_out'),
        forceLogout: true,
        remainingAttempts: 0,
      );
    }

    return PinUnlockResult(
      error: tr(
        'pin.incorrect_pin_value_attempts_remaining',
        args: ['$remainingAttempts'],
      ),
      remainingAttempts: remainingAttempts,
    );
  }

  bool _isConnectivityError(Object error) {
    if (error is FirebaseFunctionsException) {
      return error.code == 'unavailable' ||
          error.code == 'deadline-exceeded';
    }

    if (error is FirebaseAuthException) {
      return error.code == 'network-request-failed';
    }

    return error is SocketException || error is TimeoutException;
  }
  Future<void> logout() async {
    await _sessionRepository.logout();
  }

  void dispose() {
    pinController.dispose();
  }
}
