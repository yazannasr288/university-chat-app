part of '../admin_cloud_billing_page.dart';

extension on _AdminCloudBillingPageState {
  Widget _advancedSkuSection(CloudBillingSummary summary) {
    final nonZeroSkus = _nonZeroItems(summary.skus);
    final visibleItems = nonZeroSkus.take(80).toList();

    return DashboardSection(
      title: tr('dashboard.billing_advanced_title'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionIntro(text: tr('dashboard.billing_advanced_intro')),
          const SizedBox(height: 10),
          Theme(
            data: context.appTheme.copyWith(
              dividerColor: Colors.transparent,
            ),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(top: 8),
              initiallyExpanded: false,
              leading: Container(
                width: 42,
                height: 42,
                decoration: AppDecorations.rounded(
                  color: context.appPrimary.withValues(alpha: 0.10),
                  radius: AppRadii.md,
                ),
                child: Icon(
                  Icons.developer_board_rounded,
                  color: context.appPrimary,
                ),
              ),
              title: Text(
                tr('dashboard.billing_show_skus'),
                style: context.textTheme.titleMedium?.copyWith(
                  color: context.appTextPrimary,
                  fontWeight: FontWeight.w900,
                ),
              ),
              subtitle: Text(
                tr('dashboard.billing_sku_hint'),
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.appTextSecondary,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                ),
              ),
              children: [
                if (visibleItems.isEmpty)
                  _EmptyBillingText(text: tr('dashboard.billing_no_cost_data'))
                else
                  ...visibleItems.map(
                        (item) => _BillingRow(
                      icon: Icons.receipt_long_rounded,
                      title: item.skuName.trim().isEmpty
                          ? tr('dashboard.billing_uncategorized')
                          : item.skuName,
                      subtitle: '${item.serviceName} • ${item.costType}',
                      amount: _money(item.totalCost, summary.currency),
                      amountColor: _amountColor(item.totalCost),
                      credits: item.credits.abs() < _AdminCloudBillingPageState._moneyEpsilon
                          ? null
                          : '${tr('dashboard.billing_credits_label')}: '
                          '${_money(item.credits, summary.currency)}',
                    ),
                  ),
                if (summary.skus.length > visibleItems.length)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      tr(
                        'dashboard.billing_sku_hidden_note',
                        args: [
                          '${visibleItems.length}',
                          '${summary.skus.length}',
                        ],
                      ),
                      style: context.textTheme.bodySmall?.copyWith(
                        color: context.appTextSecondary,
                        height: 1.45,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _billingListSection({
    required String title,
    required String intro,
    required String emptyText,
    required String currency,
    required List<CloudBillingItem> items,
    required IconData Function(CloudBillingItem item) iconOf,
    required String Function(CloudBillingItem item) titleOf,
    required String Function(CloudBillingItem item) subtitleOf,
  }) {
    return DashboardSection(
      title: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionIntro(text: intro),
          const SizedBox(height: 12),
          if (items.isEmpty)
            _EmptyBillingText(text: emptyText)
          else
            ...items.map(
                  (item) => _BillingRow(
                icon: iconOf(item),
                title: titleOf(item),
                subtitle: subtitleOf(item),
                amount: _money(item.totalCost, currency),
                amountColor: _amountColor(item.totalCost),
                credits: item.credits.abs() < _AdminCloudBillingPageState._moneyEpsilon
                    ? null
                    : '${tr('dashboard.billing_credits_label')}: '
                    '${_money(item.credits, currency)}',
              ),
            ),
        ],
      ),
    );
  }

}
