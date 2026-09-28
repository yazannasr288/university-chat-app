abstract final class AppAccountStatuses {
  static const String active = 'active';
  static const String suspended = 'suspended';
  static const String removed = 'removed';

  static const List<String> values = <String>[
    active,
    suspended,
    removed,
  ];

  static String normalize(dynamic value) {
    final raw = (value ?? '').toString().trim();

    switch (raw) {
      case suspended:
      case 'status_suspended':
      case 'dashboard.status_suspended':
      case 'مجمد':
      case 'مجمّد':
      case 'معلق':
      case 'معلّق':
        return suspended;

      case removed:
      case 'status_removed':
      case 'dashboard.status_removed':
      case 'مزال':
      case 'محذوف':
        return removed;

      case active:
      case 'status_active':
      case 'dashboard.status_active':
      case 'نشط':
      case 'مفعل':
      case 'مفعّل':
      default:
        return active;
    }
  }

  static bool isActive(String value) => normalize(value) == active;
  static bool isSuspended(String value) => normalize(value) == suspended;
  static bool isRemoved(String value) => normalize(value) == removed;

  static String labelKey(String value) {
    switch (normalize(value)) {
      case suspended:
        return 'dashboard.status_suspended';
      case removed:
        return 'dashboard.status_removed';
      case active:
      default:
        return 'dashboard.status_active';
    }
  }
}
