class CloudBillingItem {
  final String name;
  final String serviceName;
  final String skuName;
  final String costType;
  final double grossCost;
  final double credits;
  final double totalCost;
  final int lineCount;

  const CloudBillingItem({
    required this.name,
    required this.serviceName,
    required this.skuName,
    required this.costType,
    required this.grossCost,
    required this.credits,
    required this.totalCost,
    required this.lineCount,
  });

  factory CloudBillingItem.fromMap(Map<String, dynamic> map) {
    double readDouble(String key) =>
        double.tryParse('${map[key] ?? 0}') ?? 0;

    int readInt(String key) =>
        int.tryParse('${map[key] ?? 0}') ?? 0;

    return CloudBillingItem(
      name: (map['name'] ?? '').toString(),
      serviceName: (map['serviceName'] ?? '').toString(),
      skuName: (map['skuName'] ?? '').toString(),
      costType: (map['costType'] ?? '').toString(),
      grossCost: readDouble('grossCost'),
      credits: readDouble('credits'),
      totalCost: readDouble('totalCost'),
      lineCount: readInt('lineCount'),
    );
  }
}

class CloudBillingCategory {
  final String key;
  final double grossCost;
  final double credits;
  final double totalCost;
  final int lineCount;
  final int skuCount;
  final List<String> services;

  const CloudBillingCategory({
    required this.key,
    required this.grossCost,
    required this.credits,
    required this.totalCost,
    required this.lineCount,
    required this.skuCount,
    required this.services,
  });

  factory CloudBillingCategory.fromMap(Map<String, dynamic> map) {
    double readDouble(String key) =>
        double.tryParse('${map[key] ?? 0}') ?? 0;

    int readInt(String key) =>
        int.tryParse('${map[key] ?? 0}') ?? 0;

    final rawServices = map['services'];

    return CloudBillingCategory(
      key: (map['key'] ?? 'other').toString(),
      grossCost: readDouble('grossCost'),
      credits: readDouble('credits'),
      totalCost: readDouble('totalCost'),
      lineCount: readInt('lineCount'),
      skuCount: readInt('skuCount'),
      services: rawServices is List
          ? rawServices.map((e) => e.toString()).toList()
          : const [],
    );
  }
}

class CloudBillingSummary {
  final List<CloudBillingCategory> categories;
  final int year;
  final int month;
  final String invoiceMonth;
  final String scope;
  final String appProjectId;
  final String currency;

  final double grossCost;
  final double credits;
  final double totalCost;

  final int lineCount;
  final String lastExportTime;
  final int generatedAtMs;

  final List<CloudBillingItem> services;
  final List<CloudBillingItem> costTypes;
  final List<CloudBillingItem> skus;

  const CloudBillingSummary({
    required this.categories,
    required this.year,
    required this.month,
    required this.invoiceMonth,
    required this.scope,
    required this.appProjectId,
    required this.currency,
    required this.grossCost,
    required this.credits,
    required this.totalCost,
    required this.lineCount,
    required this.lastExportTime,
    required this.generatedAtMs,
    required this.services,
    required this.costTypes,
    required this.skus,
  });

  factory CloudBillingSummary.fromMap(Map<String, dynamic> map) {
    List<CloudBillingCategory> readCategories(String key) {
      final raw = map[key];

      if (raw is! List) return const [];

      return raw
          .map((e) => CloudBillingCategory.fromMap(
        Map<String, dynamic>.from(e as Map),
      ))
          .toList();
    }
    int readInt(String key) =>
        int.tryParse('${map[key] ?? 0}') ?? 0;

    double readDouble(String key) =>
        double.tryParse('${map[key] ?? 0}') ?? 0;

    List<CloudBillingItem> readItems(String key) {
      final raw = map[key];

      if (raw is! List) return const [];

      return raw
          .map((e) => CloudBillingItem.fromMap(
        Map<String, dynamic>.from(e as Map),
      ))
          .toList();
    }



    return CloudBillingSummary(
      categories: readCategories('categories'),
      year: readInt('year'),
      month: readInt('month'),
      invoiceMonth: (map['invoiceMonth'] ?? '').toString(),
      scope: (map['scope'] ?? 'project').toString(),
      appProjectId: (map['appProjectId'] ?? '').toString(),
      currency: (map['currency'] ?? 'USD').toString(),
      grossCost: readDouble('grossCost'),
      credits: readDouble('credits'),
      totalCost: readDouble('totalCost'),
      lineCount: readInt('lineCount'),
      lastExportTime: (map['lastExportTime'] ?? '').toString(),
      generatedAtMs: readInt('generatedAtMs'),
      services: readItems('services'),
      costTypes: readItems('costTypes'),
      skus: readItems('skus'),
    );
  }
}
