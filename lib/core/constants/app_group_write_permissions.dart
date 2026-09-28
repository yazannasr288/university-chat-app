abstract final class AppGroupWritePermissions {
  static const String all = 'all';
  static const String admins = 'admins';

  static const List<String> values = <String>[
    all,
    admins,
  ];

  static bool isOpen(String value) => value.trim() == all;
  static bool isAdminsOnly(String value) => value.trim() == admins;

  static String labelKey(String value) {
    switch (value) {
      case admins:
        return 'dashboard.group_write_admins';
      case all:
      default:
        return 'dashboard.group_write_all';
    }
  }
}
