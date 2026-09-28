part of '../admin_cloud_billing_page.dart';

extension on _AdminCloudBillingPageState {
  List<CloudBillingItem> _nonZeroItems(List<CloudBillingItem> items) {
    return items.where((item) {
      return item.grossCost.abs() >= _AdminCloudBillingPageState._moneyEpsilon ||
          item.credits.abs() >= _AdminCloudBillingPageState._moneyEpsilon ||
          item.totalCost.abs() >= _AdminCloudBillingPageState._moneyEpsilon;
    }).toList();
  }

  String _money(double value, String currency) {
    final symbol = currency.toUpperCase() == 'USD' ? r'$' : '$currency ';

    return NumberFormat.currency(
      locale: context.locale.toString(),
      symbol: symbol,
      decimalDigits: 2,
    ).format(value);
  }

  String _dateTime(String iso) {
    if (iso.trim().isEmpty) {
      return tr('dashboard.billing_not_available');
    }

    final parsed = DateTime.tryParse(iso);
    if (parsed == null) return iso;

    return DateFormat.yMd(context.locale.toString())
        .add_Hm()
        .format(parsed.toLocal());
  }

  Color _amountColor(double value) {
    if (value < -_AdminCloudBillingPageState._moneyEpsilon) return AppColors.success;
    if (value.abs() < _AdminCloudBillingPageState._moneyEpsilon) return context.appTextMuted;
    return context.appTextPrimary;
  }

}
