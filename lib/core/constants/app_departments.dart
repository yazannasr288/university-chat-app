abstract final class AppDepartments {
  static const String dentistry = 'طب الاسنان';
  static const String pharmacy = 'الصيدلة';
  static const String architecture = 'هندسة العمارة';
  static const String computerEngineering = 'هندسة الحاسوب';
  static const String business = 'إدارة الأعمال';
  static const String civilEngineering = 'الهندسة المدنية';
  static const String telecomEngineering = 'هندسة الإتصالات';
  static const String staff = 'موظف';
  static const String worker = 'عامل';

  static const List<String> values = <String>[
    dentistry,
    pharmacy,
    architecture,
    computerEngineering,
    business,
    civilEngineering,
    telecomEngineering,
    staff,
    worker,
  ];

  static String labelKey(String value) {
    switch (value) {
      case dentistry:
        return 'departments.dentistry';
      case pharmacy:
        return 'departments.pharmacy';
      case architecture:
        return 'departments.architecture';
      case computerEngineering:
        return 'departments.computer_engineering';
      case business:
        return 'departments.business';
      case civilEngineering:
        return 'departments.civil_engineering';
      case telecomEngineering:
        return 'departments.telecom_engineering';
      case staff:
        return 'departments.staff';
      case worker:
        return 'departments.worker';
      default:
        return value;
    }
  }
}
