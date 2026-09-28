import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_departments.dart';
import '../../../core/permissions/app_roles.dart';
import '../../../data/repositories/user_repository.dart';

class RegisterLimits {
  static const int fullNameMaxLength = 80;
  static const int userIdMaxLength = 40;
  static const int phoneMaxLength = 25;
  static const int passwordMaxLength = 128;
  static const int passwordMinLength = 6;
}

class RegisterController {
  static const String defaultDepartment = AppDepartments.dentistry;
  static const String defaultAccountType = AppRoles.user;
  static const String workerAccountType = 'worker';

  final formKey = GlobalKey<FormState>();
  final fullNameController = TextEditingController();
  final userIdController = TextEditingController();
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();

  final UserRepository _userRepository;

  bool isLoading = false;
  String department = defaultDepartment;
  String accountType = defaultAccountType;

  RegisterController({
    UserRepository? userRepository,
  }) : _userRepository = userRepository ?? UserRepository();

  final List<String> departments = AppDepartments.values;

  Future<T> _runWithLoading<T>(Future<T> Function() action) async {
    isLoading = true;
    try {
      return await action();
    } finally {
      isLoading = false;
    }
  }

  Future<String?> register() async {
    if (formKey.currentState?.validate() != true) {
      return tr('validation.fill_required_fields');
    }

    final fullName = fullNameController.text.trim();
    final userId = userIdController.text.trim();
    final phone = phoneController.text.trim();
    final password = passwordController.text.trim();

    final validationError = _validateTrimmedInput(
      fullName: fullName,
      userId: userId,
      phone: phone,
      password: password,
    );

    if (validationError != null) return validationError;

    return _runWithLoading(() {
      return _userRepository.registerStudent(
        fullName: fullName,
        userId: userId,
        phone: phone,
        department: department.trim(),
        password: password,
        accountType: accountType,
      );
    });
  }

  String? validateFullName(String? value) {
    return _validateRequiredText(
      value,
      requiredMessage: tr('auth.enter_full_name'),
      maxLength: RegisterLimits.fullNameMaxLength,
      maxLengthMessage: tr('auth.full_name_too_long'),
    );
  }

  String? validateUserId(String? value) {
    return _validateRequiredText(
      value,
      requiredMessage: tr('auth.enter_university_id_2'),
      maxLength: RegisterLimits.userIdMaxLength,
      maxLengthMessage: tr('auth.university_id_too_long'),
    );
  }

  String? validatePhone(String? value) {
    return _validateRequiredText(
      value,
      requiredMessage: tr('auth.enter_phone_number'),
      maxLength: RegisterLimits.phoneMaxLength,
      maxLengthMessage: tr('auth.phone_number_too_long'),
    );
  }

  String? validatePassword(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return tr('auth.enter_temporary_password');
    }
    if (trimmed.length < RegisterLimits.passwordMinLength) {
      return tr('validation.password_min_6');
    }
    if (trimmed.length > RegisterLimits.passwordMaxLength) {
      return tr('validation.password_too_long');
    }
    return null;
  }

  String? _validateRequiredText(
    String? value, {
    required String requiredMessage,
    required int maxLength,
    required String maxLengthMessage,
  }) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return requiredMessage;
    if (trimmed.length > maxLength) return maxLengthMessage;
    return null;
  }

  String? _validateTrimmedInput({
    required String fullName,
    required String userId,
    required String phone,
    required String password,
  }) {
    if (fullName.isEmpty || userId.isEmpty || phone.isEmpty || password.isEmpty) {
      return tr('validation.fill_required_fields');
    }

    if (fullName.length > RegisterLimits.fullNameMaxLength) {
      return tr('auth.full_name_too_long');
    }

    if (userId.length > RegisterLimits.userIdMaxLength) {
      return tr('auth.university_id_too_long');
    }

    if (phone.length > RegisterLimits.phoneMaxLength) {
      return tr('auth.phone_number_too_long');
    }

    if (password.length < RegisterLimits.passwordMinLength) {
      return tr('validation.password_min_6');
    }

    if (password.length > RegisterLimits.passwordMaxLength) {
      return tr('validation.password_too_long');
    }

    return null;
  }

  void setDepartment(String value) {
    department = value;
    if (value == AppDepartments.worker) {
      accountType = workerAccountType;
    } else if (accountType == workerAccountType) {
      accountType = defaultAccountType;
    }
  }

  void setAccountType(String type, bool selected) {
    if (!selected) {
      accountType = defaultAccountType;
      return;
    }
    accountType = type;
    if (type == workerAccountType) {
      department = AppDepartments.worker;
    } else if (department == AppDepartments.worker) {
      department = defaultDepartment;
    }
  }

  void reset() {
    fullNameController.clear();
    userIdController.clear();
    phoneController.clear();
    passwordController.clear();
    department = defaultDepartment;
    accountType = defaultAccountType;
  }

  void dispose() {
    fullNameController.dispose();
    userIdController.dispose();
    phoneController.dispose();
    passwordController.dispose();
  }
}
