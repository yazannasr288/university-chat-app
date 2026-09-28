import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class PinStorage {
  PinStorage._();

  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static const Duration offlineUnlockValidity = Duration(hours: 72);
  static const Duration legacyOfflineGraceValidity = Duration(hours: 24);

  static String _pinKey(String uid) => 'pin_hash_$uid';
  static String _pinAttemptsKey(String uid) => 'pin_attempts_$uid';
  static String _pinLastVerifiedAtKey(String uid) => 'pin_last_verified_at_$uid';
  static String _legacyPinGraceStartedAtKey(String uid) =>
      'pin_legacy_grace_started_at_$uid';

  static String _hashPin(String uid, String pin) {
    final bytes = utf8.encode('$uid::$pin');
    return sha256.convert(bytes).toString();
  }

  static Future<void> savePin({
    required String uid,
    required String pin,
  }) async {
    await _storage.write(
      key: _pinKey(uid),
      value: _hashPin(uid, pin),
    );
    await markServerPinVerified(uid);
    await resetFailedAttempts(uid);
  }

  static Future<void> markServerPinVerified(String uid) async {
    await _storage.write(
      key: _pinLastVerifiedAtKey(uid),
      value: DateTime.now().toUtc().millisecondsSinceEpoch.toString(),
    );
    await _storage.delete(key: _legacyPinGraceStartedAtKey(uid));
  }

  static Future<DateTime?> _readUtcMillis(String key) async {
    final value = await _storage.read(key: key);
    final millis = int.tryParse(value ?? '');
    if (millis == null || millis <= 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
  }

  static Future<DateTime?> getLastServerPinVerifiedAt(String uid) {
    return _readUtcMillis(_pinLastVerifiedAtKey(uid));
  }

  static Future<bool> _isLegacyOfflineGraceAllowed(String uid) async {
    if (!(await hasPin(uid))) return false;

    final now = DateTime.now().toUtc();
    final key = _legacyPinGraceStartedAtKey(uid);
    final existingGraceStartedAt = await _readUtcMillis(key);

    if (existingGraceStartedAt == null) {
      await _storage.write(
        key: key,
        value: now.millisecondsSinceEpoch.toString(),
      );
      return true;
    }

    return now.isBefore(
      existingGraceStartedAt.add(legacyOfflineGraceValidity),
    );
  }

  static Future<bool> isOfflineUnlockAllowed(String uid) async {
    final lastVerifiedAt = await getLastServerPinVerifiedAt(uid);
    if (lastVerifiedAt == null) {
      return _isLegacyOfflineGraceAllowed(uid);
    }

    final expiresAt = lastVerifiedAt.add(offlineUnlockValidity);
    return DateTime.now().toUtc().isBefore(expiresAt);
  }

  static Future<bool> hasPin(String uid) async {
    final value = await _storage.read(key: _pinKey(uid));
    return value != null && value.isNotEmpty;
  }

  static Future<bool> verifyPin({
    required String uid,
    required String pin,
  }) async {
    final saved = await _storage.read(key: _pinKey(uid));
    if (saved == null || saved.isEmpty) return false;
    return saved == _hashPin(uid, pin);
  }

  static Future<int> getFailedAttempts(String uid) async {
    final value = await _storage.read(key: _pinAttemptsKey(uid));
    return int.tryParse(value ?? '0') ?? 0;
  }

  static Future<int> incrementFailedAttempts(String uid) async {
    final current = await getFailedAttempts(uid);
    final next = current + 1;
    await _storage.write(key: _pinAttemptsKey(uid), value: '$next');
    return next;
  }

  static Future<void> resetFailedAttempts(String uid) async {
    await _storage.delete(key: _pinAttemptsKey(uid));
  }

  static Future<void> clearPin(String uid) async {
    await _storage.delete(key: _pinKey(uid));
    await _storage.delete(key: _pinLastVerifiedAtKey(uid));
    await _storage.delete(key: _legacyPinGraceStartedAtKey(uid));
    await resetFailedAttempts(uid);
  }

  static String hashPin({
    required String uid,
    required String pin,
  }) {
    return _hashPin(uid, pin);
  }
}
