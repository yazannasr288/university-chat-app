import 'package:cloud_functions/cloud_functions.dart';

import '../../../core/utils/error_message.dart';
import '../../../data/models/dashboard_stats.dart';
import '../../../data/repositories/admin_dashboard_repository.dart';

class AdminDashboardController {
  final AdminDashboardRepository _repository;

  bool isLoading = false;
  DashboardStats? stats;
  String? errorMessage;

  AdminDashboardController({
    AdminDashboardRepository? repository,
  }) : _repository = repository ?? AdminDashboardRepository();

  Future<void> loadStats() async {
    isLoading = true;
    errorMessage = null;

    try {
      stats = await _repository.getDashboardStats();
    } on FirebaseFunctionsException catch (e) {
      errorMessage = _mapError(e);
    } catch (e) {
      errorMessage = cleanErrorMessage(
        e,
        fallback: 'تعذر تحميل إحصائيات لوحة التحكم حاليا',
      );
    } finally {
      isLoading = false;
    }
  }

  Future<void> init() async {
    await loadStats();
  }

  String _mapError(FirebaseFunctionsException e) {
    switch (e.code) {
      case 'resource-exhausted':
        return 'الخادم مشغول أو تم تجاوز الحصة، حاول بعد قليل';
      case 'unavailable':
        return 'الخدمة غير متاحة حاليا، حاول مرة أخرى';
      case 'permission-denied':
        return 'ليس لديك صلاحية للوصول إلى الإحصائيات';
      default:
        return e.message ?? 'حدث خطأ أثناء تحميل الإحصائيات';
    }
  }
}
