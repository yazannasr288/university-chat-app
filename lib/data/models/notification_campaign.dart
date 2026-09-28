class NotificationCampaign {
  final String id;
  final String title;
  final String body;
  final int recipientsCount;
  final int deliveredTokenCount;
  final String createdBy;
  final String createdByRole;
  final String targetDepartment;
  final List<String> targetDepartments;
  final int createdAtMs;

  const NotificationCampaign({
    required this.id,
    required this.title,
    required this.body,
    required this.recipientsCount,
    required this.deliveredTokenCount,
    required this.createdBy,
    required this.createdByRole,
    required this.targetDepartment,
    required this.targetDepartments,
    required this.createdAtMs,
  });

  factory NotificationCampaign.fromMap(Map<String, dynamic> map) {
    int readInt(dynamic value) => int.tryParse('${value ?? 0}') ?? 0;
    final departmentsRaw = map['targetDepartments'];

    return NotificationCampaign(
      id: (map['id'] ?? '').toString(),
      title: (map['title'] ?? '').toString(),
      body: (map['body'] ?? '').toString(),
      recipientsCount: readInt(map['recipientsCount']),
      deliveredTokenCount: readInt(map['deliveredTokenCount']),
      createdBy: (map['createdBy'] ?? '').toString(),
      createdByRole: (map['createdByRole'] ?? '').toString(),
      targetDepartment: (map['targetDepartment'] ?? '').toString(),
      targetDepartments: departmentsRaw is List
          ? departmentsRaw.map((department) => department.toString()).toList()
          : const [],
      createdAtMs: readInt(map['createdAtMs']),
    );
  }
}
