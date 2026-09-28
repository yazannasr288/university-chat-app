import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/storage/pin_storage.dart';
import '../../../data/repositories/session_repository.dart';

class ChangePinController {
  final oldPinController = TextEditingController();
  final newPinController = TextEditingController();
  final confirmPinController = TextEditingController();

  final SessionRepository _sessionRepository;

  ChangePinController({
    SessionRepository? sessionRepository,
  }) : _sessionRepository = sessionRepository ?? SessionRepository();

  bool _isValidPin(String pin) {
    return pin.length == 4 && int.tryParse(pin) != null;
  }

  Future<String?> changePin() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null||uid.isEmpty) return tr('auth.errors.session_expired_sign_in_again_short');

    final oldPin = oldPinController.text.trim();
    final newPin = newPinController.text.trim();
    final confirmPin = confirmPinController.text.trim();

    if (!_isValidPin(oldPin)) {
      return tr('pin.old_pin_must_4_digits');
    }

    if (!_isValidPin(newPin)) {
      return tr('pin.new_pin_must_4_digits');
    }

    if (newPin != confirmPin) {
      return tr('pin.new_pins_do_not_match');
    }

    try {
      await _sessionRepository.changeUserPin(
        oldPin: oldPin,
        newPin: newPin,
      );

      await PinStorage.savePin(
        uid: uid,
        pin: newPin,
      );

      return null;
    } catch (e) {
      return tr('pin.failed_change_pin');
    }
  }
  void dispose() {
    oldPinController.dispose();
    newPinController.dispose();
    confirmPinController.dispose();
  }
}
