part of '../admin_cloud_billing_page.dart';

extension on _AdminCloudBillingPageState {
  IconData _serviceIcon(String name) {
    final lower = name.toLowerCase();

    if (lower.contains('firestore')) return Icons.storage_rounded;
    if (lower.contains('storage')) return Icons.cloud_rounded;
    if (lower.contains('function')) return Icons.functions_rounded;
    if (lower.contains('run')) return Icons.play_circle_rounded;
    if (lower.contains('artifact')) return Icons.inventory_2_rounded;
    if (lower.contains('build')) return Icons.construction_rounded;
    if (lower.contains('bigquery')) return Icons.query_stats_rounded;
    if (lower.contains('logging')) return Icons.article_rounded;
    if (lower.contains('auth') || lower.contains('identity')) {
      return Icons.verified_user_rounded;
    }
    if (lower.contains('network')) return Icons.public_rounded;

    return Icons.cloud_queue_rounded;
  }

  IconData _categoryIcon(String key) {
    switch (key) {
      case 'auth':
        return Icons.verified_user_rounded;
      case 'database':
        return Icons.storage_rounded;
      case 'storage':
        return Icons.cloud_rounded;
      case 'functions_runtime':
        return Icons.functions_rounded;
      case 'messaging':
        return Icons.notifications_active_rounded;
      case 'hosting':
        return Icons.language_rounded;
      case 'billing_analytics':
        return Icons.query_stats_rounded;
      case 'deploy_build':
        return Icons.construction_rounded;
      case 'logs_monitoring':
        return Icons.article_rounded;
      case 'network':
        return Icons.public_rounded;
      case 'tax_adjustments':
        return Icons.request_quote_rounded;
      default:
        return Icons.category_rounded;
    }
  }

}
