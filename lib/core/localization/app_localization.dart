import 'package:easy_localization/easy_localization.dart';

import '../permissions/app_roles.dart';

String localizedRoleLabel(String role, {String accountType = ''}) =>
    tr(roleLabelKey(role, accountType: accountType));

String roleLabelKey(String role, {String accountType = ''}) {
  if (accountType.trim() == 'worker') return 'roles.worker';

  switch (role) {
    case AppRoles.systemAdmin:
      return 'roles.system_admin';
    case AppRoles.dean:
      return 'roles.dean';
    case AppRoles.departmentStaff:
      return 'roles.department_staff';
    default:
      return 'roles.student';
  }
}
