abstract final class AppGroupStatuses {
  static const String all = 'all';
  static const String active = 'active';
  static const String archived = 'archived';

  static const List<String> filterValues = <String>[
    all,
    active,
    archived,
  ];

  static String labelKey(String value) {
    switch (value) {
      case active:
        return 'dashboard.group_status_active';
      case archived:
        return 'dashboard.group_status_archived';
      case all:
      default:
        return 'dashboard.group_status_all';
    }
  }
}
