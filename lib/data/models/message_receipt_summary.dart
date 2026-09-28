class MessageReceiptSummary {
  final int recipientCount;
  final int deliveredCount;
  final int readCount;

  const MessageReceiptSummary({
    required this.recipientCount,
    required this.deliveredCount,
    required this.readCount,
  });

  int get notDeliveredCount {
    final value = recipientCount - deliveredCount;
    return value < 0 ? 0 : value;
  }

  bool get hasRecipients => recipientCount > 0;
}
