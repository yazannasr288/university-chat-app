part of '../chat_page.dart';

extension on _ChatPageState {
  void _selectMessage(
    ChatMessage message,
    MessageReceiptSummary? receiptSummary,
    bool canDelete,
  ) {
    if (message.isLocalPending || message.isFailed) return;

    HapticFeedback.selectionClick();
    _safeSetState(() {
      _selectedMessage = message;
      _selectedReceiptSummary = receiptSummary;
      _selectedCanDelete = canDelete;
    });
  }

  void _clearSelectedMessage() {
    if (_selectedMessage == null) return;
    controller.releaseMemberStatesSubscription();
    _safeSetState(() {
      _selectedMessage = null;
      _selectedReceiptSummary = null;
      _selectedCanDelete = false;
    });
  }

  String _copyableMessageText(ChatMessage message) {
    final text = message.message.trim();

    switch (message.type) {
      case 'text':
        return text;
      case 'poll':
        final options = message.pollOptions
            .asMap()
            .entries
            .map((entry) => '${entry.key + 1}. ${entry.value}')
            .join('\n');
        return [
          message.pollQuestion.trim().isNotEmpty
              ? message.pollQuestion.trim()
              : text,
          if (options.isNotEmpty) options,
        ].where((value) => value.trim().isNotEmpty).join('\n');
      case 'file':
        return message.fileName?.trim().isNotEmpty == true
            ? message.fileName!.trim()
            : (text.isNotEmpty ? text : 'chat.attachment.file'.tr());
      case 'image':
        return text.isNotEmpty ? text : 'chat.attachment.image'.tr();
      case 'video':
        return text.isNotEmpty ? text : 'chat.attachment.video'.tr();
      case 'audio':
        return text.isNotEmpty ? text : 'chat.attachment.voice_message'.tr();
      default:
        return text.isNotEmpty ? text : 'chat.attachment.message'.tr();
    }
  }

  Future<void> _copySelectedMessage() async {
    final message = _selectedMessage;
    if (message == null) return;

    final text = _copyableMessageText(message);
    _clearSelectedMessage();
    if (text.trim().isEmpty) return;

    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    showAppSnackBar(context, 'chat.message_copied'.tr(), type: SnackType.success);
  }



  Future<void> _saveSelectedMessage() async {
    final message = _selectedMessage;
    if (message == null) return;

    _clearSelectedMessage();

    try {
      await controller.saveMessage(message);
      if (!mounted) return;
      showAppSnackBar(
        context,
        'chat.message_saved'.tr(),
        type: SnackType.success,
      );
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, cleanErrorMessage(e), type: SnackType.error);
    }
  }

  Future<void> _deleteSelectedMessage() async {
    final message = _selectedMessage;
    final canDelete = _selectedCanDelete;
    if (message == null || !canDelete) return;

    _clearSelectedMessage();

    final confirm = await showAppConfirmDialog(
      context: context,
      title: 'chat.delete_confirm_title'.tr(),
      message: 'chat.delete_message_for_everyone_question'.tr(),
      cancelText: 'common.cancel'.tr(),
      confirmText: 'common.delete'.tr(),
    );

    if (!confirm) return;

    try {
      await controller.deleteMessage(message.id);
      if (!mounted) return;
      showAppSnackBar(context, 'chat.message_deleted'.tr(), type: SnackType.success);
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, cleanErrorMessage(e), type: SnackType.error);
    }
  }

}
