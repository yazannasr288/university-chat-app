import 'dart:ui' as ui;

import 'package:alwatanyachat/core/constants/app_account_statuses.dart';
import 'package:alwatanyachat/core/permissions/app_role_permissions.dart';
import 'package:alwatanyachat/core/permissions/app_roles.dart';
import 'package:alwatanyachat/core/utils/bidi_text.dart';
import 'package:alwatanyachat/data/models/app_user.dart';
import 'package:flutter_test/flutter_test.dart';

AppUser _user({
  required String uid,
  required String role,
  String department = '',
}) {
  return AppUser(
    uid: uid,
    fullName: 'Test User',
    email: 'test@example.com',
    userId: '100',
    department: department,
    phone: '',
    phoneE164: '',
    role: role,
    accountType: role,
    accountStatus: AppAccountStatuses.active,
    accountStatusReason: '',
    profilepic: '',
    groupIds: const <String>[],
  );
}

void main() {
  group('Bidirectional chat text', () {
    test('uses the first strong character', () {
      expect(chatTextDirectionFor('مرحبا Ahmed'), ui.TextDirection.rtl);
      expect(chatTextDirectionFor('Ahmed مرحبا'), ui.TextDirection.ltr);
    });

    test('uses the requested fallback for neutral text', () {
      expect(
        chatTextDirectionFor('1234 🙂', fallback: ui.TextDirection.rtl),
        ui.TextDirection.rtl,
      );
    });
  });

  group('Account status normalization', () {
    test('supports server keys and legacy Arabic values', () {
      expect(
        AppAccountStatuses.normalize('dashboard.status_suspended'),
        AppAccountStatuses.suspended,
      );
      expect(AppAccountStatuses.normalize('مزال'), AppAccountStatuses.removed);
      expect(AppAccountStatuses.normalize('مفعّل'), AppAccountStatuses.active);
    });
  });

  group('Role permissions', () {
    test('system admin manages every regular group', () {
      expect(
        AppRolePermissions.canManageGroup(
          groupAdminId: 'owner',
          currentUid: 'admin',
          currentRole: ' ${AppRoles.systemAdmin} ',
          currentDepartment: '',
          groupDepartment: 'dentistry',
          groupName: 'general',
        ),
        isTrue,
      );
    });

    test('dean is limited to the same department', () {
      expect(
        AppRolePermissions.canManageGroup(
          groupAdminId: 'owner',
          currentUid: 'dean',
          currentRole: AppRoles.dean,
          currentDepartment: ' dentistry ',
          groupDepartment: 'dentistry',
          groupName: 'department',
        ),
        isTrue,
      );
      expect(
        AppRolePermissions.canManageGroup(
          groupAdminId: 'owner',
          currentUid: 'dean',
          currentRole: AppRoles.dean,
          currentDepartment: 'pharmacy',
          groupDepartment: 'dentistry',
          groupName: 'department',
        ),
        isFalse,
      );
    });

    test('event creator and same-department staff can manage an event', () {
      final creator = _user(uid: 'creator', role: AppRoles.user);
      final staff = _user(
        uid: 'staff',
        role: AppRoles.departmentStaff,
        department: ' computer ',
      );

      expect(
        AppRolePermissions.canManageEventSync(
          user: creator,
          createdBy: ' creator ',
          scopeType: 'university',
          department: '',
        ),
        isTrue,
      );
      expect(
        AppRolePermissions.canManageEventSync(
          user: staff,
          createdBy: 'other',
          scopeType: 'department',
          department: 'computer',
        ),
        isTrue,
      );
    });
  });
}
