class DashboardStats {
  final int totalUsers;
  final int totalAdmin0;
  final int totalAdmin1;
  final int totalAdmin2;
  final int totalStudents;
  final int totalActiveGroups;
  final int totalArchivedGroups;
  final int totalUpcomingEvents;
  final int totalSuspendedUsers;
  final int totalRemovedUsers;
  final int bulkImportProcessing;

  const DashboardStats({
    required this.totalUsers,
    required this.totalAdmin0,
    required this.totalAdmin1,
    required this.totalAdmin2,
    required this.totalStudents,
    required this.totalActiveGroups,
    required this.totalArchivedGroups,
    required this.totalUpcomingEvents,
    required this.totalSuspendedUsers,
    required this.totalRemovedUsers,
    required this.bulkImportProcessing,
  });

  factory DashboardStats.fromMap(Map<String, dynamic> map) {
    int read(String key) => int.tryParse('${map[key] ?? 0}') ?? 0;

    return DashboardStats(
      totalUsers: read('totalUsers'),
      totalAdmin0: read('totalAdmin0'),
      totalAdmin1: read('totalAdmin1'),
      totalAdmin2: read('totalAdmin2'),
      totalStudents: read('totalStudents'),
      totalActiveGroups: read('totalActiveGroups'),
      totalArchivedGroups: read('totalArchivedGroups'),
      totalUpcomingEvents: read('totalUpcomingEvents'),
      totalSuspendedUsers: read('totalSuspendedUsers'),
      totalRemovedUsers: read('totalRemovedUsers'),
      bulkImportProcessing: read('bulkImportProcessing'),
    );
  }
}
