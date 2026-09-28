import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../data/repositories/auth_repository.dart';
import 'app_gate_controller.dart';

class ChangePasswordController {
  final oldPasswordController = TextEditingController();
  final newPasswordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  final AuthRepository _authRepository;
  final AppGateController _appGateController;

  bool isLoading = false;

  ChangePasswordController({
    AuthRepository? authRepository,
    AppGateController? appGateController,
  })  : _authRepository = authRepository ?? AuthRepository(),
        _appGateController = appGateController ?? AppGateController();



  Future<String?> changePassword() async {
    final oldPassword = oldPasswordController.text.trim();
    final newPassword = newPasswordController.text.trim();
    final confirmPassword = confirmPasswordController.text.trim();

    if (oldPassword.isEmpty ||
        newPassword.isEmpty ||
        confirmPassword.isEmpty) {
      return tr('validation.fill_all_fields');
    }

    if (newPassword.length < 6) {
      return tr('validation.new_password_min_6');
    }

    if (oldPassword.length > 128 ||
        newPassword.length > 128 ||
        confirmPassword.length > 128) {
      return tr('validation.password_too_long');
    }

    if (newPassword != confirmPassword) {
      return tr('auth.new_passwords_do_not_match');
    }

    if (oldPassword == newPassword) {
      return tr('auth.new_password_must_different_old_one');
    }

    return await _authRepository.changePassword(
      oldPassword: oldPassword,
      newPassword: newPassword,
    );
  }
  Future<AppGateDestination> resolveNextAfterMandatoryChange() {
    return _appGateController.resolveAfterMandatoryPasswordChange();
  }

  void dispose() {
    oldPasswordController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
  }
}
