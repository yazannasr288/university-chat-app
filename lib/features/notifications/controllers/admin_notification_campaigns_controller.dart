import '../../../core/utils/error_message.dart';
import '../../../data/models/notification_campaign.dart';
import '../../../data/repositories/admin_dashboard_repository.dart';

class AdminNotificationCampaignsController {
  final AdminDashboardRepository _repository;

  bool isLoading = false;
  List<NotificationCampaign> campaigns = [];

  AdminNotificationCampaignsController({
    AdminDashboardRepository? repository,
  }) : _repository = repository ?? AdminDashboardRepository();

  Future<String?> loadCampaigns() async {
    isLoading = true;
    try {
      campaigns = await _repository.listNotificationCampaigns();
      return null;
    } catch (e) {
      return cleanErrorMessage(e, fallback: 'تعذر تحميل حملات الإشعارات');
    } finally {
      isLoading = false;
    }
  }
}
