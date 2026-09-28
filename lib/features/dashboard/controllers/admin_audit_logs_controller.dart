import '../../../core/constants/app_audit_filters.dart';
import '../../../core/utils/error_message.dart';
import '../../../data/models/dashboard_audit_log.dart';
import '../../../data/models/notification_campaign.dart';
import '../../../data/repositories/admin_dashboard_repository.dart';

class AdminAuditLogsController {
  final AdminDashboardRepository _repository;

  static const int pageSize = 50;

  bool isLoading = false;
  bool isLoadingMore = false;
  bool isLoadingCampaigns = false;
  bool hasSearched = false;
  bool hasMoreLogs = false;

  String selectedCategory = '';
  String selectedLevel = AppAuditLevels.all;
  DateTime? selectedStartDate;
  DateTime? selectedEndDate;
  int nextCursorCreatedAtMs = 0;

  List<DashboardAuditLog> logs = [];
  List<NotificationCampaign> campaigns = [];

  AdminAuditLogsController({
    AdminDashboardRepository? repository,
  }) : _repository = repository ?? AdminDashboardRepository();

  bool get filtersReady =>
      selectedCategory.trim().isNotEmpty &&
      selectedStartDate != null &&
      selectedEndDate != null;

  Future<String?> loadAuditLogs({bool reset = true}) async {
    if (!filtersReady) {
      return 'اختر نوع السجل والفترة الزمنية أولًا';
    }

    final start = _startOfDay(selectedStartDate!);
    final end = _endOfDay(selectedEndDate!);

    if (end.isBefore(start)) {
      return 'تاريخ النهاية يجب أن يكون بعد تاريخ البداية';
    }

    if (reset) {
      isLoading = true;
      hasSearched = true;
      logs = [];
      hasMoreLogs = false;
      nextCursorCreatedAtMs = 0;
    } else {
      if (!hasMoreLogs || isLoadingMore) return null;
      isLoadingMore = true;
    }

    try {
      final result = await _repository.listDashboardAuditLogs(
        category: selectedCategory,
        level: selectedLevel,
        startAt: start,
        endAt: end,
        limit: pageSize,
        cursorCreatedAtMs: reset ? 0 : nextCursorCreatedAtMs,
      );

      if (reset) {
        logs = result.logs;
      } else {
        logs = [...logs, ...result.logs];
      }

      hasMoreLogs = result.hasMore;
      nextCursorCreatedAtMs = result.nextCursorCreatedAtMs;
      return null;
    } catch (e) {
      return cleanErrorMessage(e, fallback: 'تعذر تحميل سجل العمليات');
    } finally {
      isLoading = false;
      isLoadingMore = false;
    }
  }

  Future<String?> loadCampaigns() async {
    isLoadingCampaigns = true;
    try {
      campaigns = await _repository.listNotificationCampaigns();
      return null;
    } catch (e) {
      return cleanErrorMessage(e, fallback: 'تعذر تحميل حملات الإشعارات');
    } finally {
      isLoadingCampaigns = false;
    }
  }

  void setCategory(String value) => selectedCategory = value;
  void setLevel(String value) => selectedLevel = value;
  void setStartDate(DateTime? value) => selectedStartDate = value;
  void setEndDate(DateTime? value) => selectedEndDate = value;

  DateTime _startOfDay(DateTime value) => DateTime(value.year, value.month, value.day);

  DateTime _endOfDay(DateTime value) =>
      DateTime(value.year, value.month, value.day, 23, 59, 59, 999);
}
