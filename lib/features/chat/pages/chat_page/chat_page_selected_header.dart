part of '../chat_page.dart';

extension on _ChatPageState {
  PreferredSizeWidget _buildSelectedMessageHeader() {
    final canDelete = _selectedCanDelete;
    final width = MediaQuery.sizeOf(context).width;
    final isCompact = width < 380;
    final actionSize = isCompact ? 34.0 : 45.0;
    final iconSize = isCompact ? 18.5 : 22.5;
    final iconGap = isCompact ? 16.0 : 20.0;

    Widget circularHeaderButton({
      required IconData icon,
      required String tooltip,
      required VoidCallback onPressed,
      bool destructive = false,
    }) {
      final fillColor =
      destructive
          ? AppColors.error.withValues(alpha: 0.96)
          : Colors.white.withValues(alpha: 0.14);

      final borderColor =
      destructive
          ? Colors.white.withValues(alpha: 0.24)
          : Colors.white.withValues(alpha: 0.18);

      return Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: Ink(
            width: actionSize,
            height: actionSize,
            decoration: BoxDecoration(
              color: fillColor,
              shape: BoxShape.circle,
              border: Border.all(color: borderColor),
              boxShadow:
              destructive
                  ? [
                BoxShadow(
                  color: AppColors.error.withValues(alpha: 0.24),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ]
                  : null,
            ),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onPressed,
              child: Icon(icon, color: Colors.white, size: iconSize),
            ),
          ),
        ),
      );
    }

    Widget closeButton() {
      return Center(
        child: Tooltip(
          message: 'common.cancel'.tr(),
          child: Material(
            color: Colors.white.withValues(alpha: 0.14),
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _clearSelectedMessage,
              child: SizedBox(
                width: actionSize - 4,
                height: actionSize,
                child: Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: iconSize + 1,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return AppBar(
      key: const ValueKey('selected_message_header'),
      toolbarHeight: 60,
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      flexibleSpace: Container(
        decoration: const BoxDecoration(gradient: AppGradients.appBar),
      ),
      leadingWidth: isCompact ? 44 : 50,
      leading: Padding(
        padding: EdgeInsetsDirectional.only(
          start: isCompact ? 6 : AppSpacing.xs,
        ),
        child: closeButton(),
      ),

      // المسافة بين زر إلغاء التحديد وباقي الأيقونات
      titleSpacing: isCompact ? 8 : 10,

      iconTheme: const IconThemeData(color: Colors.white),

      title: Align(
        alignment: AlignmentDirectional.centerEnd,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              circularHeaderButton(
                icon: Icons.bookmark_add_rounded,
                tooltip: 'chat.save_message'.tr(),
                onPressed: _saveSelectedMessage,
              ),
              SizedBox(width: iconGap),

              circularHeaderButton(
                icon: Icons.analytics_outlined,
                tooltip: 'chat.delivery_read_summary'.tr(),
                onPressed: _showReceiptSummary,
              ),
              SizedBox(width: iconGap),

              circularHeaderButton(
                icon: Icons.copy_rounded,
                tooltip: 'chat.copy'.tr(),
                onPressed: _copySelectedMessage,
              ),
              SizedBox(width: iconGap),

              circularHeaderButton(
                icon: Icons.forward_rounded,
                tooltip: 'chat.forward'.tr(),
                onPressed: _showForwardMessageSheet,
              ),

              if (canDelete) ...[
                SizedBox(width: iconGap),
                circularHeaderButton(
                  icon: Icons.delete_outline_rounded,
                  tooltip: 'common.delete'.tr(),
                  onPressed: _deleteSelectedMessage,
                  destructive: true,
                ),
              ],
            ],
          ),
        ),
      ),

      actions: const [],
    );
  }
}
