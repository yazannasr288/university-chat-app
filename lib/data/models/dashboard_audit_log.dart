import '../../core/constants/app_audit_filters.dart';

class DashboardAuditLog {
  final String id;
  final String action;
  final String category;
  final String level;
  final String targetType;
  final String targetId;
  final String targetLabel;
  final String targetDisplayName;
  final String targetUserId;
  final String targetDepartment;
  final String targetAccountType;
  final String actorUid;
  final String actorRole;
  final String actorDisplayName;
  final String actorUserId;
  final String actorDepartment;
  final String actorAccountType;
  final String summary;
  final Map<String, dynamic> details;
  final int createdAtMs;

  const DashboardAuditLog({
    required this.id,
    required this.action,
    required this.category,
    required this.level,
    required this.targetType,
    required this.targetId,
    required this.targetLabel,
    required this.targetDisplayName,
    required this.targetUserId,
    required this.targetDepartment,
    required this.targetAccountType,
    required this.actorUid,
    required this.actorRole,
    required this.actorDisplayName,
    required this.actorUserId,
    required this.actorDepartment,
    required this.actorAccountType,
    required this.summary,
    required this.details,
    required this.createdAtMs,
  });

  factory DashboardAuditLog.fromMap(Map<String, dynamic> map) {
    int readInt(dynamic value) => int.tryParse('${value ?? 0}') ?? 0;
    String readString(String key) => (map[key] ?? '').toString().trim();

    return DashboardAuditLog(
      id: readString('id'),
      action: _normalizeAction(readString('action')),
      category: readString('category').isEmpty ? AppAuditCategories.system : readString('category'),
      level: readString('level').isEmpty ? AppAuditLevels.info : readString('level'),
      targetType:
          readString('targetType').isEmpty ? 'system' : readString('targetType'),
      targetId: readString('targetId'),
      targetLabel: readString('targetLabel'),
      targetDisplayName: readString('targetDisplayName').isNotEmpty
          ? readString('targetDisplayName')
          : readString('targetLabel'),
      targetUserId: readString('targetUserId'),
      targetDepartment: readString('targetDepartment'),
      targetAccountType: readString('targetAccountType'),
      actorUid: readString('actorUid'),
      actorRole: readString('actorRole'),
      actorDisplayName: readString('actorDisplayName').isNotEmpty
          ? readString('actorDisplayName')
          : readString('actorName'),
      actorUserId: readString('actorUserId'),
      actorDepartment: readString('actorDepartment'),
      actorAccountType: readString('actorAccountType'),
      summary: readString('summary'),
      details: Map<String, dynamic>.from(map['details'] ?? const {}),
      createdAtMs: readInt(map['createdAtMs']),
    );
  }

  static String _normalizeAction(String value) {
    switch (value.trim()) {
      case 'user.profile.update':
        return 'user.profile.updated';
      case 'user.password.update':
      case 'user.password.changed':
        return 'user.password.reset';
      case 'user.pin.update':
      case 'user.pin.changed':
        return 'user.pin.reset';
      case 'group.profile.update':
        return 'group.profile.updated';
      default:
        return value.trim();
    }
  }
}
