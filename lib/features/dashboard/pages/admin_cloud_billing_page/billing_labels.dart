part of '../admin_cloud_billing_page.dart';

extension on _AdminCloudBillingPageState {
  String _categoryTitle(String key) {
    switch (key) {
      case 'auth':
        return tr('dashboard.billing_category_auth');
      case 'database':
        return tr('dashboard.billing_category_database');
      case 'storage':
        return tr('dashboard.billing_category_storage');
      case 'functions_runtime':
        return tr('dashboard.billing_category_functions');
      case 'messaging':
        return tr('dashboard.billing_category_messaging');
      case 'hosting':
        return tr('dashboard.billing_category_hosting');
      case 'billing_analytics':
        return tr('dashboard.billing_category_bigquery');
      case 'deploy_build':
        return tr('dashboard.billing_category_deploy');
      case 'logs_monitoring':
        return tr('dashboard.billing_category_logs');
      case 'network':
        return tr('dashboard.billing_category_network');
      case 'tax_adjustments':
        return tr('dashboard.billing_category_tax_adjustments');
      default:
        return tr('dashboard.billing_category_other');
    }
  }

  String _categoryDescription(String key) {
    switch (key) {
      case 'auth':
        return tr('dashboard.billing_category_auth_desc');
      case 'database':
        return tr('dashboard.billing_category_database_desc');
      case 'storage':
        return tr('dashboard.billing_category_storage_desc');
      case 'functions_runtime':
        return tr('dashboard.billing_category_functions_desc');
      case 'messaging':
        return tr('dashboard.billing_category_messaging_desc');
      case 'hosting':
        return tr('dashboard.billing_category_hosting_desc');
      case 'billing_analytics':
        return tr('dashboard.billing_category_bigquery_desc');
      case 'deploy_build':
        return tr('dashboard.billing_category_deploy_desc');
      case 'logs_monitoring':
        return tr('dashboard.billing_category_logs_desc');
      case 'network':
        return tr('dashboard.billing_category_network_desc');
      case 'tax_adjustments':
        return tr('dashboard.billing_category_tax_adjustments_desc');
      default:
        return tr('dashboard.billing_category_other_desc');
    }
  }

  bool _isCoreCategory(String key) {
    return const {
      'auth',
      'database',
      'storage',
      'functions_runtime',
      'messaging',
      'hosting',
    }.contains(key);
  }

  String _servicesIncludedText(List<String> services) {
    if (services.isEmpty) {
      return tr('dashboard.billing_no_billed_service_this_month');
    }

    final visible = services.take(3).join(', ');

    if (services.length <= 3) {
      return tr('dashboard.billing_includes_services', args: [visible]);
    }

    return tr(
      'dashboard.billing_includes_services_more',
      args: [visible, '${services.length - 3}'],
    );
  }

  String _serviceDescription(String name) {
    final lower = name.toLowerCase();

    if (lower.contains('firestore')) {
      return tr('dashboard.billing_service_firestore');
    }
    if (lower.contains('cloud storage') || lower.contains('storage')) {
      return tr('dashboard.billing_service_storage');
    }
    if (lower.contains('cloud functions') || lower.contains('function')) {
      return tr('dashboard.billing_service_functions');
    }
    if (lower.contains('cloud run')) {
      return tr('dashboard.billing_service_cloud_run');
    }
    if (lower.contains('artifact registry')) {
      return tr('dashboard.billing_service_artifact_registry');
    }
    if (lower.contains('cloud build')) {
      return tr('dashboard.billing_service_cloud_build');
    }
    if (lower.contains('bigquery')) {
      return tr('dashboard.billing_service_bigquery');
    }
    if (lower.contains('logging')) {
      return tr('dashboard.billing_service_logging');
    }
    if (lower.contains('auth') || lower.contains('identity')) {
      return tr('dashboard.billing_service_auth');
    }
    if (lower.contains('network')) {
      return tr('dashboard.billing_service_network');
    }

    return tr('dashboard.billing_service_other');
  }

  String _costTypeLabel(String value) {
    final lower = value.toLowerCase().trim();

    switch (lower) {
      case 'regular':
        return tr('dashboard.billing_cost_type_regular');
      case 'tax':
        return tr('dashboard.billing_cost_type_tax');
      case 'adjustment':
        return tr('dashboard.billing_cost_type_adjustment');
      case 'rounding_error':
        return tr('dashboard.billing_cost_type_rounding');
      default:
        return value.trim().isEmpty
            ? tr('dashboard.billing_uncategorized')
            : value;
    }
  }

  String _costTypeDescription(String value) {
    final lower = value.toLowerCase().trim();

    switch (lower) {
      case 'regular':
        return tr('dashboard.billing_cost_type_regular_desc');
      case 'tax':
        return tr('dashboard.billing_cost_type_tax_desc');
      case 'adjustment':
        return tr('dashboard.billing_cost_type_adjustment_desc');
      case 'rounding_error':
        return tr('dashboard.billing_cost_type_rounding_desc');
      default:
        return tr('dashboard.billing_cost_type_other_desc');
    }
  }

}
