abstract final class AppAuditCategories {
  static const String events = 'events';
  static const String students = 'students';
  static const String groups = 'groups';
  static const String notifications = 'notifications';
  static const String system = 'system';
  static const String all = 'all';

  static const List<String> filterValues = <String>[
    events,
    students,
    groups,
    notifications,
    system,
    all,
  ];

  static String labelKey(String value) {
    switch (value) {
      case events:
        return 'audit.category.events';
      case students:
        return 'audit.category.students';
      case groups:
        return 'audit.category.groups';
      case notifications:
        return 'audit.category.notifications';
      case system:
        return 'audit.category.system';
      case all:
        return 'audit.category.all';
      default:
        return value;
    }
  }
}

abstract final class AppAuditLevels {
  static const String all = 'all';
  static const String info = 'info';
  static const String warning = 'warning';
  static const String critical = 'critical';

  static const List<String> filterValues = <String>[
    all,
    info,
    warning,
    critical,
  ];

  static String labelKey(String value) {
    switch (value) {
      case info:
        return 'dashboard.audit_level_info';
      case warning:
        return 'dashboard.audit_level_warning';
      case critical:
        return 'dashboard.audit_level_critical';
      case all:
      default:
        return 'dashboard.audit_level_all';
    }
  }
}
