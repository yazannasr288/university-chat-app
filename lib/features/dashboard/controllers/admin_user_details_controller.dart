import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_account_statuses.dart';
import '../../../core/constants/app_departments.dart';
import '../../../core/permissions/app_roles.dart';
import '../../../data/models/managed_user_details.dart';
import '../../../data/repositories/admin_dashboard_repository.dart';

class AdminUserDetailsController {
  final AdminDashboardRepository _repository;

  final fullNameController = TextEditingController();
  final userIdController = TextEditingController();
  final phoneController = TextEditingController();
  final accountStatusReasonController = TextEditingController();
  bool isLoading = false;
  bool isSaving = false;

  ManagedUserDetails? details;
  String department = AppDepartments.dentistry;
  String accountType = AppRoles.user;
  String accountStatus = AppAccountStatuses.active;

  AdminUserDetailsController({
    AdminDashboardRepository? repository,
  }) : _repository = repository ?? AdminDashboardRepository();

  List<String> get departments => AppDepartments.values;

  List<String> get accountTypes => const [
        AppRoles.user,
        'doctor',
        'employee',
        'dean',
        'presidency_employee',
        'worker',
      ];

  List<String> get accountStatuses => AppAccountStatuses.values;

  void setDepartment(String value) {
    department = value;
    if (value == AppDepartments.worker) {
      accountType = 'worker';
    } else if (accountType == 'worker') {
      accountType = AppRoles.user;
    }
  }

  void setAccountType(String value) {
    accountType = value;
    if (value == 'worker') {
      department = AppDepartments.worker;
    } else if (department == AppDepartments.worker) {
      department = AppDepartments.dentistry;
    }
  }

  Future<String?> load(String uid) async {
    isLoading = true;
    try {
      details = await _repository.getManagedUserDetails(uid);
      final user = details!;
      fullNameController.text = user.fullName;
      userIdController.text = user.userId;
      phoneController.text = user.phone;
      accountStatusReasonController.text = user.accountStatusReason;
      department = user.department;
      accountType = user.accountType;
      accountStatus = user.accountStatus;
      return null;
    } catch (_) {
      return tr('dashboard.manage_user_load_error');
    } finally {
      isLoading = false;
    }
  }

  Future<String?> save() async {
    final user = details;
    if (user == null) return tr('dashboard.manage_user_load_error');

    if (fullNameController.text.trim().isEmpty ||
        userIdController.text.trim().isEmpty ||
        phoneController.text.trim().isEmpty) {
      return tr('dashboard.user_form_required');
    }

    isSaving = true;
    try {
      return await _repository.updateManagedUser(
        uid: user.uid,
        fullName: fullNameController.text.trim(),
        userId: userIdController.text.trim(),
        phone: phoneController.text.trim(),
        department: department,
        accountType: accountType,
        accountStatus: accountStatus,
        accountStatusReason: accountStatusReasonController.text.trim(),
      );
    } finally {
      isSaving = false;
    }
  }

  Future<String?> resetPassword(String password) {
    final user = details;
    if (user == null) return Future.value(tr('dashboard.manage_user_load_error'));
    return _repository.resetManagedUserPassword(uid: user.uid, password: password);
  }

  Future<String?> resetPin() {
    final user = details;
    if (user == null) return Future.value(tr('dashboard.manage_user_load_error'));
    return _repository.resetManagedUserPin(user.uid);
  }

  void dispose() {
    fullNameController.dispose();
    userIdController.dispose();
    phoneController.dispose();
    accountStatusReasonController.dispose();
  }
}
