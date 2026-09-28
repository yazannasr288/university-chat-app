import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/storage/pin_storage.dart';
import '../../../data/repositories/session_repository.dart';

class PinSetupController {
  final pinController = TextEditingController();
  final confirmPinController = TextEditingController();

  final SessionRepository _sessionRepository;

  bool isLoading = false;

  PinSetupController({SessionRepository? sessionRepository})
    : _sessionRepository = sessionRepository ?? SessionRepository();

  bool _isValidPin(String pin) {
    return pin.length == 4 && int.tryParse(pin) != null;
  }

  Future<String?> savePin() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null || uid.isEmpty) {
      return tr('auth.errors.session_expired_sign_in_again_short');
    }
    final pin = pinController.text.trim();
    final confirm = confirmPinController.text.trim();

    if (!_isValidPin(pin)) {
      return tr('pin.pin_must_4_digits');
    }

    if (pin != confirm) {
      return tr('pin.pins_do_not_match');
    }

    isLoading = true;
    try {

      await _sessionRepository.saveUserPin(pin:pin);

      await PinStorage.savePin(uid: uid, pin: pin);
      await _sessionRepository.activatePendingAfterPinIfAny();
      return null;
    } catch (e) {
      return tr('pin.failed_save_pin_sign_again_try_again');
    } finally {
      isLoading = false;
    }
  }

  void dispose() {
    pinController.dispose();
    confirmPinController.dispose();
  }
}
