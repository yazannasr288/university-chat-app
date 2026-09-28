part of '../admin_cloud_billing_page.dart';

extension on _AdminCloudBillingPageState {
  Widget _monthSelector() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: context.appCardColorStrong,
        borderRadius: BorderRadius.circular(AppRadii.xl),
        border: Border.all(color: context.appBorder),
        boxShadow: AppShadows.subtle,
      ),
      child: Row(
        children: [
          IconButton.filledTonal(
            onPressed: controller.isLoading ? null : _previousMonth,
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  tr('dashboard.billing_period'),
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.appTextSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat.yMMMM(context.locale.toString()).format(
                    controller.selectedMonth,
                  ),
                  textAlign: TextAlign.center,
                  style: context.textTheme.titleMedium?.copyWith(
                    color: context.appTextPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          IconButton.filledTonal(
            onPressed: controller.isLoading || !controller.canGoNext
                ? null
                : _nextMonth,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }

  Widget _heroCard(CloudBillingSummary summary) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: AppGradients.primary,
        borderRadius: BorderRadius.circular(AppRadii.xl),
        boxShadow: AppShadows.floating,
      ),
      child: Stack(
        children: [
          PositionedDirectional(
            end: -24,
            top: -28,
            child: Icon(
              Icons.receipt_long_rounded,
              size: 118,
              color: Colors.white.withValues(alpha: 0.10),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr('dashboard.billing_total_invoice'),
                style: context.textTheme.titleMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.88),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _money(summary.totalCost, summary.currency),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 34,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _HeroChip(
                    icon: Icons.calendar_month_rounded,
                    label: summary.invoiceMonth,
                  ),
                  _HeroChip(
                    icon: Icons.sort_rounded,
                    label: tr('dashboard.billing_sorted_by_cost'),
                  ),
                  _HeroChip(
                    icon: Icons.account_tree_rounded,
                    label: summary.scope == 'billing_account'
                        ? tr('dashboard.billing_scope_billing_account')
                        : tr('dashboard.billing_scope_project'),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryCards(CloudBillingSummary summary) {
    return Center(
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          DashboardStatCard(
            title: tr('dashboard.billing_gross_cost'),
            value: _money(summary.grossCost, summary.currency),
            icon: Icons.payments_rounded,
          ),
          DashboardStatCard(
            title: tr('dashboard.billing_credits'),
            value: _money(summary.credits, summary.currency),
            icon: Icons.discount_rounded,
          ),
          DashboardStatCard(
            title: tr('dashboard.billing_net_after_credits'),
            value: _money(summary.totalCost, summary.currency),
            icon: Icons.calculate_rounded,
          ),
          DashboardStatCard(
            title: tr('dashboard.billing_line_count'),
            value: '${summary.lineCount}',
            icon: Icons.list_alt_rounded,
          ),
        ],
      ),
    );
  }

  Widget _notice() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.isDark
            ? AppColors.accent.withValues(alpha: 0.08)
            : AppColors.accentSoft,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(
          color: AppColors.accent.withValues(
            alpha: context.isDark ? 0.28 : 0.45,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: context.isDark ? AppColors.accent : AppColors.primaryDark,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              tr('dashboard.billing_note_clear'),
              style: context.textTheme.bodySmall?.copyWith(
                color: context.appTextSecondary,
                height: 1.6,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

}
