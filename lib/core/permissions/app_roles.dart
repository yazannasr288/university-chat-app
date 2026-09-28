abstract final class AppRoles {
  static const String systemAdmin = 'admin0';
  static const String dean = 'admin1';
  static const String departmentStaff = 'admin2';
  static const String user = 'user';
  static const String student = 'student';

  static const List<String> adminRoles = <String>[
    systemAdmin,
    dean,
    departmentStaff,
  ];

  static const List<String> studentRoles = <String>[
    user,
    student,
  ];

  static bool isSystemAdmin(String role) => role.trim() == systemAdmin;
  static bool isDean(String role) => role.trim() == dean;
  static bool isDepartmentStaff(String role) => role.trim() == departmentStaff;
  static bool isStudent(String role) => studentRoles.contains(role.trim());
  static bool isAdmin(String role) => adminRoles.contains(role.trim());
}
