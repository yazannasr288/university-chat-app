import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/permissions/app_roles.dart';
import '../../core/constants/app_account_statuses.dart';
import '../../core/constants/app_group_statuses.dart';
import '../../core/utils/error_message.dart';
import '../models/cloud_billing_summary.dart';
import '../models/dashboard_audit_log.dart';
import '../models/dashboard_stats.dart';
import '../models/managed_group_details.dart';
import '../models/managed_group_summary.dart';
import '../models/managed_user.dart';
import '../models/managed_user_details.dart';
import '../models/notification_campaign.dart';

class DashboardAuditLogPageResult {
  final List<DashboardAuditLog> logs;
  final bool hasMore;
  final int nextCursorCreatedAtMs;

  const DashboardAuditLogPageResult({
    required this.logs,
    required this.hasMore,
    required this.nextCursorCreatedAtMs,
  });
}

class AdminDashboardRepository {
  final FirebaseFunctions _functions;

  AdminDashboardRepository({
    FirebaseFunctions? functions,
  }) : _functions = functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  Future<DashboardStats> getDashboardStats() async {
    final callable = _functions.httpsCallable('getDashboardStats');

    for (int attempt = 0; attempt < 3; attempt++) {
      try {
        final response = await callable.call();
        final data = Map<String, dynamic>.from(response.data);

        return DashboardStats.fromMap(
          Map<String, dynamic>.from(data['stats'] ?? {}),
        );
      } on FirebaseFunctionsException catch (e) {
        final retryable =
            e.code == 'resource-exhausted' || e.code == 'unavailable';

        if (retryable && attempt < 2) {
          await Future.delayed(Duration(milliseconds: 500 * (attempt + 1)));
          continue;
        }

        rethrow;
      }
    }

    throw FirebaseFunctionsException(
      code: 'unknown',
      message: 'تعذر تحميل إحصائيات لوحة التحكم',
    );
  }

  Future<List<ManagedUser>> listManagedUsers({
    String query = '',
    String department = '',
    String role = '',
    String accountStatus = '',
  }) async {
    final callable = _functions.httpsCallable('listManagedUsers');
    final normalizedRole = _normalizeRoleFilter(role);
    final normalizedStatus = _normalizeAccountStatusFilter(accountStatus);
    final usersById = <String, ManagedUser>{};
    String cursorUid = '';

    for (var page = 0; page < 25; page++) {
      final response = await callable.call({
        'query': query.trim(),
        'department': department.trim(),
        'role': normalizedRole,
        'accountStatus': normalizedStatus,
        'limit': 200,
        if (cursorUid.isNotEmpty) 'cursorUid': cursorUid,
      });

      final data = Map<String, dynamic>.from(response.data);
      final rawUsers = List<Map<String, dynamic>>.from(
        (data['users'] ?? const []).map((e) => Map<String, dynamic>.from(e)),
      );

      for (final item in rawUsers) {
        final user = ManagedUser.fromMap(item);
        usersById[user.uid] = user;
      }

      final hasMore = data['hasMore'] == true;
      final nextCursorUid = (data['nextCursorUid'] ?? '').toString().trim();
      if (!hasMore || nextCursorUid.isEmpty || nextCursorUid == cursorUid) {
        break;
      }
      cursorUid = nextCursorUid;
    }

    final users = usersById.values.toList()
      ..sort((a, b) => a.fullName.compareTo(b.fullName));
    return users;
  }

  String _normalizeAccountStatusFilter(String value) {
    final raw = value.trim();

    if (raw.isEmpty || raw == 'all') return '';

    switch (raw) {
      case AppAccountStatuses.active:
      case 'status_active':
      case 'dashboard.status_active':
      case 'نشط':
      case 'مفعل':
      case 'مفعّل':
        return AppAccountStatuses.active;

      case AppAccountStatuses.suspended:
      case 'status_suspended':
      case 'dashboard.status_suspended':
      case 'مجمد':
      case 'مجمّد':
      case 'معلق':
      case 'معلّق':
        return AppAccountStatuses.suspended;

      case AppAccountStatuses.removed:
      case 'status_removed':
      case 'dashboard.status_removed':
      case 'مزال':
      case 'محذوف':
        return AppAccountStatuses.removed;

      default:
        return raw;
    }
  }

  String _normalizeRoleFilter(String value) {
    final raw = value.trim();

    if (raw.isEmpty || raw == 'all') return '';

    switch (raw) {
      case 'student':
      case 'role_student':
      case 'dashboard.role_student':
      case 'طالب':
        return AppRoles.user;

      case 'role_admin0':
      case 'dashboard.role_admin0':
      case 'super_admin':
      case 'مدير النظام':
      case 'إدارة عليا':
        return AppRoles.systemAdmin;

      case 'role_admin1':
      case 'dashboard.role_admin1':
      case 'dean':
      case 'عميد':
        return AppRoles.dean;

      case 'role_admin2':
      case 'dashboard.role_admin2':
      case 'supervisor':
      case 'doctor':
      case 'employee':
      case 'مشرف':
      case 'دكتور':
      case 'موظف':
      case 'موظف قسم':
        return AppRoles.departmentStaff;

      default:
        return raw;
    }
  }

  Future<ManagedUserDetails> getManagedUserDetails(String uid) async {
    final callable = _functions.httpsCallable('getManagedUserDetails');
    final response = await callable.call({'uid': uid});
    final data = Map<String, dynamic>.from(response.data);
    return ManagedUserDetails.fromMap(
      Map<String, dynamic>.from(data['user'] ?? const {}),
    );
  }

  Future<CloudBillingSummary> getCloudBillingSummary({
    required int year,
    required int month,
    bool forceRefresh = false,
  }) async {
    final callable = _functions.httpsCallable('getCloudBillingSummary');

    final response = await callable.call({
      'year': year,
      'month': month,
      'forceRefresh': forceRefresh,
    });

    final data = Map<String, dynamic>.from(response.data);

    return CloudBillingSummary.fromMap(
      Map<String, dynamic>.from(data['summary'] ?? const {}),
    );
  }

  Future<String?> updateManagedUser({
    required String uid,
    required String fullName,
    required String userId,
    required String phone,
    required String department,
    required String accountType,
    required String accountStatus,
    required String accountStatusReason,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.getIdToken(true);
      }

      final callable = _functions.httpsCallable('updateManagedUserProfile');
      await callable.call({
        'uid': uid,
        'fullName': fullName,
        'userId': userId,
        'phone': phone,
        'department': department,
        'accountType': accountType,
        'accountStatus': _normalizeAccountStatusFilter(accountStatus),
        'accountStatusReason': accountStatusReason,
      });
      return null;
    } on FirebaseFunctionsException catch (e) {
      return cleanErrorMessage(e, fallback: 'تعذر حفظ التعديلات حاليا');
    } catch (e) {
      return cleanErrorMessage(e, fallback: 'تعذر حفظ التعديلات حاليا');
    }
  }

  Future<String?> freezeStudent(String uid) async => _simpleCall(
    'freezeStudentAccount',
    {'uid': uid},
    'تعذر تجميد الحساب حاليا',
  );

  Future<String?> unfreezeStudent(String uid) async => _simpleCall(
    'unfreezeStudentAccount',
    {'uid': uid},
    'تعذر إعادة تفعيل الحساب حاليا',
  );

  Future<String?> removeStudent(String uid) async => _simpleCall(
    'removeStudentAccount',
    {'uid': uid},
    'تعذر حذف الحساب نهائيًا حاليًا',
  );

  Future<String?> resetManagedUserPassword({
    required String uid,
    required String password,
  }) async => _simpleCall(
    'adminResetManagedUserPassword',
    {'uid': uid, 'password': password},
    'تعذر إعادة تعيين كلمة المرور حاليا',
  );

  Future<String?> resetManagedUserPin(String uid) async => _simpleCall(
    'adminResetManagedUserPin',
    {'uid': uid},
    'تعذر إعادة تعيين PIN حاليا',
  );

  Future<String?> sendNotificationToUsers({
    required List<String> recipientUids,
    required String title,
    required String body,
  }) async => _simpleCall(
    'sendManagedUsersNotification',
    {
      'recipientUids': recipientUids,
      'title': title,
      'body': body,
    },
    'تعذر إرسال الإشعار حاليا',
  );

  Future<List<ManagedGroupSummary>> listManagedGroups({
    String query = '',
    String department = '',
    String groupStatus = AppGroupStatuses.all,
  }) async {
    final callable = _functions.httpsCallable('listManagedGroups');
    final response = await callable.call({
      'query': query,
      'department': department,
      'groupStatus': groupStatus,
    });

    final data = Map<String, dynamic>.from(response.data);
    final rawGroups = List<Map<String, dynamic>>.from(
      (data['groups'] ?? const []).map((e) => Map<String, dynamic>.from(e)),
    );

    return rawGroups.map(ManagedGroupSummary.fromMap).toList();
  }

  Future<ManagedGroupDetails> getManagedGroupDetails(String groupId) async {
    final callable = _functions.httpsCallable('getManagedGroupDetails');
    final response = await callable.call({'groupId': groupId});
    final data = Map<String, dynamic>.from(response.data);
    return ManagedGroupDetails.fromMap(
      Map<String, dynamic>.from(data['group'] ?? const {}),
    );
  }

  Future<String?> updateManagedGroup({
    required String groupId,
    required String groupName,
    required String department,
    required String writePermission,
    required String adminUid,
    List<String> adminIds = const [],
  }) async => _simpleCall(
    'updateManagedGroupProfile',
    {
      'groupId': groupId,
      'groupName': groupName,
      'department': department,
      'writePermission': writePermission,
      'adminUid': adminUid,
      'adminIds': adminIds,
    },
    'تعذر حفظ تعديلات المجموعة حاليا',
  );

  Future<String?> addManagedGroupMembers({
    required String groupId,
    required List<String> memberUids,
  }) async => _simpleCall(
    'addManagedGroupMembers',
    {'groupId': groupId, 'memberUids': memberUids},
    'تعذر إضافة الأعضاء حاليا',
  );

  Future<String?> removeManagedGroupMember({
    required String groupId,
    required String memberUid,
  }) async => _simpleCall(
    'removeManagedGroupMember',
    {'groupId': groupId, 'memberUid': memberUid},
    'تعذر إزالة العضو حاليا',
  );

  Future<String?> archiveManagedGroup(String groupId) async =>
      _simpleCall('archiveManagedGroup', {'groupId': groupId}, 'تعذر أرشفة المجموعة حاليا');

  Future<String?> unarchiveManagedGroup(String groupId) async =>
      _simpleCall('unarchiveManagedGroup', {'groupId': groupId}, 'تعذر إلغاء أرشفة المجموعة حاليا');

  Future<String?> deleteManagedGroup(String groupId) async =>
      _simpleCall('deleteManagedGroup', {'groupId': groupId}, 'تعذر حذف المجموعة حاليا');

  Future<DashboardAuditLogPageResult> listDashboardAuditLogs({
    required String category,
    required DateTime startAt,
    required DateTime endAt,
    String level = 'all',
    int limit = 50,
    int cursorCreatedAtMs = 0,
  }) async {
    final callable = _functions.httpsCallable('listDashboardAuditLogs');
    final response = await callable.call({
      'category': category.trim(),
      'level': level.trim().isEmpty ? 'all' : level.trim(),
      'startAtMs': startAt.millisecondsSinceEpoch,
      'endAtMs': endAt.millisecondsSinceEpoch,
      'limit': limit,
      'cursorCreatedAtMs': cursorCreatedAtMs,
    });

    final data = Map<String, dynamic>.from(response.data);
    final rawLogs = List<Map<String, dynamic>>.from(
      (data['logs'] ?? const []).map((e) => Map<String, dynamic>.from(e)),
    );

    return DashboardAuditLogPageResult(
      logs: rawLogs.map(DashboardAuditLog.fromMap).toList(),
      hasMore: data['hasMore'] == true,
      nextCursorCreatedAtMs:
          int.tryParse('${data['nextCursorCreatedAtMs'] ?? 0}') ?? 0,
    );
  }

  Future<List<NotificationCampaign>> listNotificationCampaigns() async {
    final callable = _functions.httpsCallable('listNotificationCampaigns');
    final response = await callable.call();
    final data = Map<String, dynamic>.from(response.data);
    final rawItems = List<Map<String, dynamic>>.from(
      (data['campaigns'] ?? const []).map((e) => Map<String, dynamic>.from(e)),
    );

    return rawItems.map(NotificationCampaign.fromMap).toList();
  }

  Future<String?> _simpleCall(
    String functionName,
    Map<String, dynamic> payload,
    String fallbackMessage,
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.getIdToken(true);
      }
      
      final callable = _functions.httpsCallable(functionName);
      await callable.call(payload);
      return null;
    } on FirebaseFunctionsException catch (e) {
      return cleanErrorMessage(e, fallback: fallbackMessage);
    } catch (e) {
      return cleanErrorMessage(e, fallback: fallbackMessage);
    }
  }
}
