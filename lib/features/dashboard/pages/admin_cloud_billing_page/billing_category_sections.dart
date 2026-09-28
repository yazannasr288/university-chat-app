part of '../admin_cloud_billing_page.dart';

extension on _AdminCloudBillingPageState {
  Widget _coreCostCategoriesSection(CloudBillingSummary summary) {
    final items = summary.categories
        .where((item) => _isCoreCategory(item.key))
        .toList();

    return DashboardSection(
      title: tr('dashboard.billing_core_costs'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionIntro(text: tr('dashboard.billing_core_costs_intro')),
          const SizedBox(height: 12),
          ...items.map(
                (item) => _BillingRow(
              icon: _categoryIcon(item.key),
              title: _categoryTitle(item.key),
              subtitle:
              '${_categoryDescription(item.key)} • '
                  '${_servicesIncludedText(item.services)}',
              amount: _money(item.totalCost, summary.currency),
              amountColor: _amountColor(item.totalCost),
              credits: item.credits.abs() < _AdminCloudBillingPageState._moneyEpsilon
                  ? null
                  : '${tr('dashboard.billing_credits_label')}: '
                  '${_money(item.credits, summary.currency)}',
            ),
          ),
        ],
      ),
    );
  }

  Widget _supportCostCategoriesSection(CloudBillingSummary summary) {
    final items = summary.categories.where((item) {
      final hasCost =
          item.grossCost.abs() >= _AdminCloudBillingPageState._moneyEpsilon ||
              item.credits.abs() >= _AdminCloudBillingPageState._moneyEpsilon ||
              item.totalCost.abs() >= _AdminCloudBillingPageState._moneyEpsilon;

      return !_isCoreCategory(item.key) && hasCost;
    }).toList();

    if (items.isEmpty) return const SizedBox.shrink();

    return DashboardSection(
      title: tr('dashboard.billing_support_costs'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionIntro(text: tr('dashboard.billing_support_costs_intro')),
          const SizedBox(height: 12),
          ...items.map(
                (item) => _BillingRow(
              icon: _categoryIcon(item.key),
              title: _categoryTitle(item.key),
              subtitle:
              '${_categoryDescription(item.key)} • '
                  '${_servicesIncludedText(item.services)}',
              amount: _money(item.totalCost, summary.currency),
              amountColor: _amountColor(item.totalCost),
              credits: item.credits.abs() < _AdminCloudBillingPageState._moneyEpsilon
                  ? null
                  : '${tr('dashboard.billing_credits_label')}: '
                  '${_money(item.credits, summary.currency)}',
            ),
          ),
        ],
      ),
    );
  }

}
