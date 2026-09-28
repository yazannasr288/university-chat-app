abstract final class AppGroupAudiences {
  static const String department = 'department';
  static const String doctorsDepartment = 'doctors_department';
  static const String doctorsAll = 'doctors_all';
  static const String workers = 'workers';

  // Legacy system groups are normalized to these internal audience values.
  static const String deansAll = 'deans_all';
  static const String employeesAll = 'employees_all';
  static const String presidency = 'presidency';

  static const List<String> creatableValues = <String>[
    department,
    doctorsDepartment,
    doctorsAll,
    workers,
  ];

  static String normalize(String? value, {String groupName = ''}) {
    final cleanValue = value?.trim() ?? '';
    if (cleanValue.isNotEmpty) return cleanValue;

    switch (groupName.trim()) {
      case 'main_doctor':
        return doctorsAll;
      case 'main_worker':
        return workers;
      case 'main_dean':
        return deansAll;
      case 'main_employee':
        return employeesAll;
      case 'main_presidency_employee':
        return presidency;
      default:
        return department;
    }
  }

  static bool isMemberCollaboration(String audience) =>
      audience.trim() != department;

  static bool isCrossDepartment(String audience) =>
      <String>{doctorsAll, deansAll, employeesAll, presidency}.contains(
        audience.trim(),
      );

  static bool canAccess({
    required String audience,
    required String role,
    required String accountType,
    required String userDepartment,
    required String groupDepartment,
  }) {
    if (role.trim() == 'admin0') return true;

    final cleanAudience = audience.trim();
    final cleanRole = role.trim();
    final cleanAccountType = accountType.trim();
    final cleanUserDepartment = userDepartment.trim();
    final cleanGroupDepartment = groupDepartment.trim();
    final isDoctor =
        cleanRole == 'admin1' ||
        cleanAccountType == 'dean' ||
        cleanAccountType == 'doctor';

    switch (cleanAudience) {
      case doctorsDepartment:
        return isDoctor &&
            cleanUserDepartment.isNotEmpty &&
            cleanUserDepartment == cleanGroupDepartment;
      case doctorsAll:
        return isDoctor;
      case workers:
        return cleanUserDepartment == 'عامل' &&
            (cleanAccountType == 'worker' ||
                cleanRole == 'admin1' ||
                cleanRole == 'admin2');
      case deansAll:
        return cleanRole == 'admin1' || cleanAccountType == 'dean';
      case employeesAll:
        return cleanAccountType == 'employee';
      case presidency:
        return cleanAccountType == 'presidency_employee';
      default:
        return cleanUserDepartment.isNotEmpty &&
            cleanUserDepartment == cleanGroupDepartment;
    }
  }

  static String labelKey(String audience) {
    switch (audience.trim()) {
      case doctorsDepartment:
        return 'home.group_audience_doctors_department';
      case doctorsAll:
        return 'home.group_audience_doctors_all';
      case workers:
        return 'home.group_audience_workers';
      default:
        return 'home.group_audience_department';
    }
  }
}
