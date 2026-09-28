import 'package:cloud_functions/cloud_functions.dart';

import '../../core/utils/error_message.dart';
import '../models/cloud_billing_summary.dart';
import '../repositories/admin_dashboard_repository.dart';

class AdminCloudBillingController {
  final AdminDashboardRepository _repository;

  bool isLoading = false;
  String? errorMessage;
  CloudBillingSummary? summary;

  DateTime selectedMonth;

  AdminCloudBillingController({
    AdminDashboardRepository? repository,
    DateTime? initialMonth,
  })  : _repository = repository ?? AdminDashboardRepository(),
        selectedMonth = DateTime(
          (initialMonth ?? DateTime.now()).year,
          (initialMonth ?? DateTime.now()).month,
        );

  Future<void> load({bool forceRefresh = false}) async {
    isLoading = true;
    errorMessage = null;

    try {
      summary = await _repository.getCloudBillingSummary(
        year: selectedMonth.year,
        month: selectedMonth.month,
        forceRefresh: forceRefresh,
      );
    } on FirebaseFunctionsException catch (e) {
      errorMessage = _mapFunctionError(e);
    } catch (e) {
      errorMessage = cleanErrorMessage(
        e,
        fallback: 'dashboard.billing_load_error',
      );
    } finally {
      isLoading = false;
    }
  }

  String _mapFunctionError(FirebaseFunctionsException e) {
    switch (e.code) {
      case 'unauthenticated':
        return 'dashboard.unauthenticated_error';
      case 'permission-denied':
        return 'dashboard.billing_permission_error';
      case 'failed-precondition':
        return e.message ?? 'dashboard.billing_settings_error';
      case 'unavailable':
        return 'dashboard.dashboard_stats_unavailable_error';
      case 'resource-exhausted':
        return 'dashboard.dashboard_stats_quota_error';
      default:
        return e.message ?? 'dashboard.billing_load_error';
    }
  }

  Future<void> previousMonth() async {
    selectedMonth = DateTime(selectedMonth.year, selectedMonth.month - 1);
    await load();
  }

  Future<void> nextMonth() async {
    final next = DateTime(selectedMonth.year, selectedMonth.month + 1);
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month);

    if (next.isAfter(currentMonth)) return;

    selectedMonth = next;
    await load();
  }

  bool get canGoNext {
    final next = DateTime(selectedMonth.year, selectedMonth.month + 1);
    final now = DateTime.now();

    return !next.isAfter(DateTime(now.year, now.month));
  }
}
