part of '../chat_page.dart';

extension on _ChatPageState {
  void _showReceiptSummary() {
    final summary = _selectedReceiptSummary;
    final message = _selectedMessage;
    if (message == null) return;

    _clearSelectedMessage();

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        Widget summaryCard({
          required IconData icon,
          required String label,
          required int value,
          required Color color,
        }) {
          return Container(
            width: 108,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
            decoration: BoxDecoration(
              color: color.withValues(alpha: context.isDark ? 0.16 : 0.10),
              borderRadius: BorderRadius.circular(AppRadii.lg),
              border: Border.all(color: color.withValues(alpha: 0.28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(height: 8),
                Text(
                  value.toString(),
                  style: context.textTheme.titleLarge?.copyWith(
                    color: context.appTextPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label.tr(),
                  textAlign: TextAlign.center,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.appTextSecondary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          );
        }

        final recipientCount = summary?.recipientCount ?? 0;
        final deliveredCount = summary?.deliveredCount ?? 0;
        final readCount = summary?.readCount ?? 0;
        final notDeliveredCount = summary?.notDeliveredCount ?? recipientCount;

        return AlertDialog(
          backgroundColor: context.appCardColorStrong,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.lg),
            side: BorderSide(color: context.appBorder),
          ),
          title: Text(
            'chat.receipts.message_summary'.tr(),
            style: context.textTheme.titleMedium?.copyWith(
              color: context.appTextPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  summaryCard(
                    icon: Icons.done_all_rounded,
                    label: 'chat.receipts.read',
                    value: readCount,
                    color: AppColors.supportEmerald,
                  ),
                  summaryCard(
                    icon: Icons.mark_email_read_rounded,
                    label: 'chat.receipts.delivered',
                    value: deliveredCount,
                    color: AppColors.primary,
                  ),
                  summaryCard(
                    icon: Icons.schedule_rounded,
                    label: 'chat.receipts.not_delivered',
                    value: notDeliveredCount,
                    color: AppColors.accent,
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text('common.close'.tr()),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showForwardMessageSheet() async {
    final message = _selectedMessage;
    if (message == null) return;

    _clearSelectedMessage();

    final forwarded = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (_) => ChatForwardSheet(
            loadGroups:
                () => controller.forwardableGroups(
                  userRole: userRole,
                  accountType: AppPrefs.userAccountType,
                  currentDepartment: AppPrefs.userDepartment,
                ),
            onForward:
                (group) => controller.forwardMessage(
                  message: message,
                  targetGroup: group,
                ),
          ),
    );

    if (!mounted || forwarded != true) return;
    showAppSnackBar(
      context,
      'chat.message_forwarded'.tr(),
      type: SnackType.success,
    );
  }

}
