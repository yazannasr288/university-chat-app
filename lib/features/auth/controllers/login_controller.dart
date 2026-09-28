import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/session_repository.dart';

enum LoginDestination {
  forceChangePassword,
  pinSetup,
  pinUnlock,
}

class LoginController {
  final formKey = GlobalKey<FormState>();
  final userIdController = TextEditingController();
  final passwordController = TextEditingController();

  final AuthRepository _authRepository;
  final SessionRepository _sessionRepository;

  bool isLoading = false;

  LoginController({
    AuthRepository? authRepository,
    SessionRepository? sessionRepository,
  })  : _authRepository = authRepository ?? AuthRepository(),
        _sessionRepository = sessionRepository ?? SessionRepository();

  Future<T> _runWithLoading<T>(Future<T> Function() action) async {
    isLoading = true;
    try {
      return await action();
    } finally {
      isLoading = false;
    }
  }

  Future<LoginDestination> login() async {
    if (!formKey.currentState!.validate()) {
      throw Exception(tr('validation.fill_required_fields'));
    }

    return _runWithLoading(() async {
      final error = await _authRepository.login(
        userId: userIdController.text,
        password: passwordController.text,
      );

      if (error != null) {
        throw Exception(error);
      }

      final result = await _sessionRepository.prepareAfterPasswordLogin();

      if (result.mustChangePassword) {
        return LoginDestination.forceChangePassword;
      }

      if (result.pinResetRequired || !result.hasServerPin) {
        return LoginDestination.pinSetup;
      }

      return LoginDestination.pinUnlock;
    });
  }

  void dispose() {
    userIdController.dispose();
    passwordController.dispose();
  }
}
