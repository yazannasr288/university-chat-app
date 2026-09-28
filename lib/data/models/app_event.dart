class AppEvent {
  final String id;
  final String title;
  final String details;
  final String location;
  final String notes;
  final String scopeType;
  final String department;
  final String targetGroupId;
  final String targetGroupName;
  final int eventAt;
  final int interestedCount;
  final bool isCancelled;
  final String createdBy;
  final String createdByName;
  final String createdByRole;
  final List<String> visibilityKeys;

  const AppEvent({
    required this.id,
    required this.title,
    required this.details,
    required this.location,
    required this.notes,
    required this.scopeType,
    required this.department,
    required this.targetGroupId,
    required this.targetGroupName,
    required this.eventAt,
    required this.interestedCount,
    required this.isCancelled,
    required this.createdBy,
    required this.createdByName,
    required this.createdByRole,
    required this.visibilityKeys,
  });

  factory AppEvent.fromMap(String id, Map<String, dynamic> map) {
    return AppEvent(
      id: id,
      title: (map['title'] ?? '').toString(),
      details: (map['details'] ?? '').toString(),
      location: (map['location'] ?? '').toString(),
      notes: (map['notes'] ?? '').toString(),
      scopeType: (map['scopeType'] ?? '').toString(),
      department: (map['department'] ?? '').toString(),
      targetGroupId: (map['targetGroupId'] ?? '').toString(),
      targetGroupName: (map['targetGroupName'] ?? '').toString(),
      eventAt: int.tryParse((map['eventAt'] ?? '0').toString()) ?? 0,
      interestedCount:
      int.tryParse((map['interestedCount'] ?? '0').toString()) ?? 0,
      isCancelled: map['isCancelled'] == true,
      createdBy: (map['createdBy'] ?? '').toString(),
      createdByName: (map['createdByName'] ?? '').toString(),
      createdByRole: (map['createdByRole'] ?? '').toString(),
      visibilityKeys:
      (map['visibilityKeys'] as List?)
          ?.map((e) => e.toString())
          .toList() ??
          const [],
    );
  }

  bool get isPast => eventAt <= DateTime.now().millisecondsSinceEpoch;
}
