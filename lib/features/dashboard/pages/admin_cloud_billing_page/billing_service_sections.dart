part of '../admin_cloud_billing_page.dart';

extension on _AdminCloudBillingPageState {
  Widget _billableServicesSection(CloudBillingSummary summary) {
    final items = _nonZeroItems(summary.services);

    return _billingListSection(
      title: tr('dashboard.billing_billable_services'),
      intro: tr('dashboard.billing_billable_services_intro'),
      emptyText: tr('dashboard.billing_no_cost_data'),
      currency: summary.currency,
      items: items,
      iconOf: (item) => _serviceIcon(item.name),
      titleOf: (item) => item.name,
      subtitleOf: (item) {
        final lines = tr(
          'dashboard.billing_lines_count',
          args: ['${item.lineCount}'],
        );

        return '${_serviceDescription(item.name)} • $lines';
      },
    );
  }

  Widget _invoicePartsSection(CloudBillingSummary summary) {
    final items = _nonZeroItems(summary.costTypes);

    return _billingListSection(
      title: tr('dashboard.billing_invoice_parts'),
      intro: tr('dashboard.billing_invoice_parts_intro'),
      emptyText: tr('dashboard.billing_no_cost_data'),
      currency: summary.currency,
      items: items,
      iconOf: (item) {
        final lower = item.name.toLowerCase();
        if (lower == 'tax') return Icons.request_quote_rounded;
        if (lower == 'adjustment') return Icons.tune_rounded;
        if (lower == 'rounding_error') return Icons.exposure_rounded;
        return Icons.receipt_rounded;
      },
      titleOf: (item) => _costTypeLabel(item.name),
      subtitleOf: (item) {
        final lines = tr(
          'dashboard.billing_lines_count',
          args: ['${item.lineCount}'],
        );

        return '${_costTypeDescription(item.name)} • $lines';
      },
    );
  }

  Widget _sourceSection(CloudBillingSummary summary) {
    final scopeLabel = summary.scope == 'billing_account'
        ? tr('dashboard.billing_scope_billing_account')
        : tr('dashboard.billing_scope_project');

    return DashboardSection(
      title: tr('dashboard.billing_source'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionIntro(text: tr('dashboard.billing_source_intro')),
          const SizedBox(height: 12),
          _InfoLine(
            icon: Icons.calendar_month_rounded,
            label: tr('dashboard.billing_invoice_month'),
            value: summary.invoiceMonth,
          ),
          _InfoLine(
            icon: Icons.account_tree_rounded,
            label: tr('dashboard.billing_scope'),
            value: scopeLabel,
          ),
          if (summary.scope == 'project')
            _InfoLine(
              icon: Icons.apps_rounded,
              label: tr('dashboard.billing_project_id'),
              value: summary.appProjectId,
            ),
          _InfoLine(
            icon: Icons.sync_rounded,
            label: tr('dashboard.billing_last_export'),
            value: _dateTime(summary.lastExportTime),
          ),
        ],
      ),
    );
  }

}
