class ChatOperationException implements Exception {
  final String messageKey;
  final String code;
  final bool retryable;

  const ChatOperationException(
    this.messageKey, {
    this.code = 'unknown',
    this.retryable = false,
  });

  @override
  String toString() => messageKey;
}
