part of '../admin_cloud_billing_page.dart';

extension on _AdminCloudBillingPageState {
  Widget _body() {
    final summary = controller.summary;

    if (controller.isLoading && summary == null) {
      return const AppLoader();
    }

    if (controller.errorMessage != null && summary == null) {
      return AppEmptyState(
        icon: Icons.receipt_long_rounded,
        text: controller.errorMessage!.tr(),
        actionLabel: tr('common.retry'),
        actionLoading: controller.isLoading,
        onAction: () => _load(forceRefresh: true),
      );
    }

    if (summary == null) {
      return AppEmptyState(
        icon: Icons.receipt_long_rounded,
        text: tr('dashboard.billing_empty'),
        actionLabel: tr('common.retry'),
        onAction: () => _load(forceRefresh: true),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _load(forceRefresh: true),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _monthSelector(),
          const SizedBox(height: 16),
          _heroCard(summary),
          const SizedBox(height: 16),
          _summaryCards(summary),
          const SizedBox(height: 16),

          _coreCostCategoriesSection(summary),
          const SizedBox(height: 16),

          _supportCostCategoriesSection(summary),
          const SizedBox(height: 16),

          _billableServicesSection(summary),
          const SizedBox(height: 16),

          _invoicePartsSection(summary),
          const SizedBox(height: 16),

          _sourceSection(summary),
          const SizedBox(height: 16),

          _advancedSkuSection(summary),
          const SizedBox(height: 16),

          _notice(),
        ],
      ),
    );
  }

}
