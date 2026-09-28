import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_confirm_dialog.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../../core/utils/bidi_text.dart';
import '../../../core/utils/error_message.dart';
import '../../../data/models/chat_message.dart';
import '../../../services/chat_audio_player_service.dart';
import 'message_content.dart';

class MessageTile extends StatelessWidget {
  final ChatMessage message;
  final bool sendByMe;
  final bool canDelete;
  final Future<void> Function()? onDelete;
  final Future<void> Function()? onRetry;
  final Future<void> Function()? onDiscard;
  final String groupId;
  final String currentUid;
  final bool selected;
  final bool highlighted;
  final VoidCallback? onSelect;
  final VoidCallback? onTap;
  final VoidCallback? onReply;
  final VoidCallback? onReplyPreviewTap;
  final List<ChatAudioPlaybackItem> audioPlaybackQueue;

  const MessageTile({
    super.key,
    required this.message,
    required this.sendByMe,
    required this.canDelete,
    required this.groupId,
    required this.currentUid,
    this.selected = false,
    this.highlighted = false,
    this.onSelect,
    this.onTap,
    this.onReply,
    this.onReplyPreviewTap,
    this.audioPlaybackQueue = const [],
    this.onDelete,
    this.onRetry,
    this.onDiscard,
  });

  bool get _isMedia => message.type == 'image' || message.type == 'video';

  bool get _isCompactContent =>
      message.type == 'audio' || message.type == 'file' || message.type == 'event' || message.type == 'poll';

  double _maxBubbleWidth(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    if (_isMedia) return math.min(screenWidth * 0.82, 370);
    if (message.type == 'audio') return math.min(screenWidth * 0.76, 330);
    if (_isCompactContent) return math.min(screenWidth * 0.82, 380);
    return math.min(screenWidth * 0.80, 380);
  }

  EdgeInsetsGeometry get _bubblePadding {
    if (_isMedia) return const EdgeInsets.all(4);
    if (message.type == 'audio') return const EdgeInsets.all(6);
    if (_isCompactContent) return const EdgeInsets.all(9);
    return const EdgeInsets.symmetric(horizontal: 13, vertical: 8);
  }

  Future<void> _confirmDelete(BuildContext context) async {
    if (!canDelete || onDelete == null) return;

    final confirm = await showAppConfirmDialog(
      context: context,
      title: 'chat.delete_confirm_title'.tr(),
      message: 'chat.delete_message_for_everyone_question'.tr(),
      cancelText: 'common.cancel'.tr(),
      confirmText: 'common.delete'.tr(),
    );

    if (confirm) {
      try {
        await onDelete!();
      } catch (e) {
        if (!context.mounted) return;
        showAppSnackBar(
          context,
          cleanErrorMessage(e),
          type: SnackType.error,
        );
      }
    }
  }

  Future<void> _retry(BuildContext context) async {
    if (onRetry == null) return;

    try {
      await onRetry!();
    } catch (e) {
      if (!context.mounted) return;
      showAppSnackBar(
        context,
        cleanErrorMessage(e),
        type: SnackType.error,
      );
    }
  }

  Future<void> _discard(BuildContext context) async {
    if (onDiscard == null) return;

    try {
      await onDiscard!();
    } catch (e) {
      if (!context.mounted) return;
      showAppSnackBar(
        context,
        cleanErrorMessage(e),
        type: SnackType.error,
      );
    }
  }

  ButtonStyle _failedActionStyle(BuildContext context) {
    return TextButton.styleFrom(
      foregroundColor: Colors.white,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      minimumSize: const Size(0, 32),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      backgroundColor: Colors.white.withValues(alpha: 0.10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      textStyle: context.textTheme.bodySmall?.copyWith(
        fontWeight: FontWeight.w900,
        fontSize: 11,
      ),
    );
  }



  Widget _buildReplyPreview(BuildContext context) {
    final replyId = message.replyToMessageId?.trim() ?? '';
    final replyText = message.replyToText?.trim() ?? '';
    if (replyId.isEmpty && replyText.isEmpty) return const SizedBox.shrink();

    final sender = message.replyToSender?.trim().isNotEmpty == true
        ? message.replyToSender!.trim()
        : 'chat.unknown_sender'.tr();
    final text = replyText.isNotEmpty ? replyText : 'chat.attachment.generic'.tr();

    final bgColor = sendByMe
        ? Colors.white.withValues(alpha: 0.14)
        : context.appSurfaceSoft;
    final borderColor = sendByMe
        ? Colors.white.withValues(alpha: 0.42)
        : context.appPrimary.withValues(alpha: 0.35);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: replyId.isNotEmpty ? onReplyPreviewTap : null,
      child: Container(
        width: double.infinity,
        margin: EdgeInsets.only(bottom: _isMedia ? 4 : 7),
        padding: const EdgeInsetsDirectional.fromSTEB(9, 7, 8, 7),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(AppRadii.md),
          border: BorderDirectional(
            start: BorderSide(color: borderColor, width: 3.5),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    sender,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textTheme.labelMedium?.copyWith(
                      color: sendByMe ? Colors.white : context.appPrimary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (replyId.isNotEmpty && onReplyPreviewTap != null)
                  Icon(
                    Icons.keyboard_arrow_up_rounded,
                    size: 17,
                    color: sendByMe
                        ? Colors.white.withValues(alpha: 0.78)
                        : context.appTextSecondary,
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textDirection: chatTextDirectionFor(text),
              style: context.textTheme.bodySmall?.copyWith(
                color: sendByMe
                    ? Colors.white.withValues(alpha: 0.82)
                    : context.appTextSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingStatus(BuildContext context) {
    final statusColor = Colors.white.withValues(alpha: 0.90);
    final iconColor = message.isFailed
        ? AppColors.errorSoft
        : Colors.white.withValues(alpha: 0.82);

    return Padding(
      padding: const EdgeInsets.only(top: 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                message.isFailed
                    ? Icons.error_outline_rounded
                    : Icons.schedule_rounded,
                size: 13,
                color: iconColor,
              ),
              const SizedBox(width: 4),
              Text(
                message.isFailed
                    ? 'chat.message_status.not_sent'.tr()
                    : message.isLocalPending
                        ? 'chat.message_status.sending'.tr()
                        : 'chat.message_status.waiting_network'.tr(),
                style: context.textTheme.bodySmall?.copyWith(
                  color: statusColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          if (message.isFailed && (onRetry != null || onDiscard != null)) ...[
            const SizedBox(height: 7),
            Wrap(
              spacing: 6,
              runSpacing: 5,
              children: [
                if (onRetry != null)
                  TextButton.icon(
                    onPressed: () => _retry(context),
                    style: _failedActionStyle(context),
                    icon: const Icon(Icons.refresh_rounded, size: 15),
                    label: Text('chat.resend'.tr()),
                  ),
                if (onDiscard != null)
                  TextButton.icon(
                    onPressed: () => _discard(context),
                    style: _failedActionStyle(context),
                    icon: const Icon(Icons.close_rounded, size: 15),
                    label: Text('chat.remove'.tr()),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTime(BuildContext context) {
    final date = DateTime.fromMillisecondsSinceEpoch(message.time);
    final locale = context.locale.toString();
    final use24Hour = MediaQuery.alwaysUse24HourFormatOf(context);

    final timeStr = DateFormat(
      use24Hour ? 'HH:mm' : 'h:mm a',
      locale,
    ).format(date);

    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 5, end: 3, top: 1),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            timeStr,
            textDirection: ui.TextDirection.ltr,
            style: context.textTheme.bodySmall?.copyWith(
              color: sendByMe
                  ? context.appMessageMineMeta
                  : context.appMessageOtherMeta,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.05,
            ),
          ),
          if (sendByMe && !message.isLocalPending && !message.isFailed) ...[
            const SizedBox(width: 4),
            Icon(
              Icons.done_all_rounded,
              size: 14,
              color: context.appMessageMineMeta,
            ),
          ],
        ],
      ),
    );
  }

  BorderRadius get _bubbleRadius {
    const large = Radius.circular(24);
    const tail = Radius.circular(7);

    return sendByMe
        ? const BorderRadius.only(
            topLeft: large,
            topRight: large,
            bottomLeft: large,
            bottomRight: tail,
          )
        : const BorderRadius.only(
            topLeft: large,
            topRight: large,
            bottomLeft: tail,
            bottomRight: large,
          );
  }

  @override
  Widget build(BuildContext context) {
    final isPendingOrFailed =
        message.isLocalPending || message.hasPendingWrites || message.isFailed;

    final shouldAnimateTile = selected || highlighted || isPendingOrFailed;

    final bubbleDecoration = BoxDecoration(
      gradient: sendByMe ? context.appMessageMineGradient : null,
      color: sendByMe ? null : context.appBubbleOther,
      borderRadius: _bubbleRadius,
      border: highlighted
          ? Border.all(color: context.scheme.tertiary, width: 2.2)
          : selected
              ? Border.all(color: context.scheme.secondary, width: 2)
              : message.isFailed
              ? Border.all(color: AppColors.errorSoft.withValues(alpha: 0.88))
              : sendByMe
                  ? Border.all(color: Colors.white.withValues(alpha: 0.10))
                  : Border.all(color: context.appBubbleOtherBorder, width: 0.9),
      boxShadow: [
        if (!context.isDark)
          BoxShadow(
            color: AppColors.primaryDark.withValues(
              alpha: selected ? 0.13 : 0.065,
            ),
            blurRadius: selected ? 22 : 15,
            offset: const Offset(0, 8),
            spreadRadius: -5,
          )
        else if (selected)
          BoxShadow(
            color: context.scheme.secondary.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
      ],
    );

    return _SwipeReplyGesture(
      enabled: onReply != null && !isPendingOrFailed,
      onReply: onReply,
      onTap: onTap,
      onLongPress: onSelect ?? (canDelete ? () => _confirmDelete(context) : null),
      child: AnimatedContainer(
        duration: shouldAnimateTile
            ? AppMotion.resolve(context, AppMotion.fast)
            : Duration.zero,
        curve: AppMotion.standard,
        decoration: BoxDecoration(
          color: highlighted
              ? context.scheme.tertiary.withValues(
                  alpha: context.isDark ? 0.16 : 0.10,
                )
              : selected
                  ? context.scheme.secondary.withValues(
                      alpha: context.isDark ? 0.12 : 0.08,
                    )
                  : Colors.transparent,
        ),
        padding: EdgeInsets.only(
          top: 6,
          right: sendByMe ? 10 : 46,
          left: sendByMe ? 46 : 10,
        ),
        alignment: sendByMe ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: _maxBubbleWidth(context)),
          child: AnimatedScale(
            duration: shouldAnimateTile
                ? AppMotion.resolve(context, AppMotion.fast)
                : Duration.zero,
            curve: AppMotion.standard,
            scale: selected ? 0.975 : 1,
            child: DecoratedBox(
              decoration: bubbleDecoration,
              child: Padding(
                padding: _bubblePadding,
                child: Column(
                  crossAxisAlignment:
                  sendByMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!sendByMe)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(
                          start: 5,
                          end: 5,
                          bottom: 1,
                        ),
                        child: Text(
                          message.sender,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.textTheme.labelMedium?.copyWith(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: context.isDark
                                ? context.scheme.secondary
                                : context.scheme.primary,
                          ),
                        ),
                      ),

                    _buildReplyPreview(context),

                    RepaintBoundary(
                      child: MessageContent(
                        key: ValueKey('message_content_${message.id}'),
                        message: message,
                        sendByMe: sendByMe,
                        groupId: groupId,
                        currentUid: currentUid,
                        audioPlaybackQueue: audioPlaybackQueue,
                      ),
                    ),

                    if (!_isMedia) const SizedBox(height: 2),

                    if (sendByMe && isPendingOrFailed)
                      _buildPendingStatus(context)
                    else
                      Align(
                        widthFactor: 1,
                        heightFactor: 1,
                        alignment: sendByMe ? Alignment.bottomRight : Alignment.bottomLeft,
                        child: _buildTime(context),
                      ),
                  ],
                )
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SwipeReplyGesture extends StatefulWidget {
  final Widget child;
  final bool enabled;
  final VoidCallback? onReply;
  final VoidCallback? onLongPress;
  final VoidCallback? onTap;

  const _SwipeReplyGesture({
    required this.child,
    required this.enabled,
    this.onReply,
    this.onLongPress,
    this.onTap,
  });

  @override
  State<_SwipeReplyGesture> createState() => _SwipeReplyGestureState();
}

class _SwipeReplyGestureState extends State<_SwipeReplyGesture> {
  static const double _triggerDistance = 48;
  static const double _maxDragDistance = 74;

  double _dragOffset = 0;
  bool _isDragging = false;
  bool _hapticTriggered = false;

  void _resetDrag() {
    if (!mounted) return;
    setState(() {
      _dragOffset = 0;
      _isDragging = false;
      _hapticTriggered = false;
    });
  }

  void _handleDragStart(DragStartDetails _) {
    if (!widget.enabled) return;
    setState(() {
      _isDragging = true;
      _dragOffset = 0;
      _hapticTriggered = false;
    });
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (!widget.enabled) return;

    final delta = details.primaryDelta ?? 0;
    final nextOffset = (_dragOffset + delta)
        .clamp(0.0, _maxDragDistance)
        .toDouble();

    if (nextOffset >= _triggerDistance && !_hapticTriggered) {
      _hapticTriggered = true;
      HapticFeedback.selectionClick();
    }

    setState(() => _dragOffset = nextOffset);
  }

  void _handleDragEnd(DragEndDetails _) {
    if (!widget.enabled) return;

    final shouldReply = _dragOffset >= _triggerDistance;
    _resetDrag();

    if (shouldReply) {
      HapticFeedback.lightImpact();
      widget.onReply?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_dragOffset / _triggerDistance).clamp(0.0, 1.0).toDouble();

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      onHorizontalDragStart: widget.enabled ? _handleDragStart : null,
      onHorizontalDragUpdate: widget.enabled ? _handleDragUpdate : null,
      onHorizontalDragEnd: widget.enabled ? _handleDragEnd : null,
      onHorizontalDragCancel: widget.enabled ? _resetDrag : null,
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          if (widget.enabled && (_dragOffset > 0 || _isDragging))
            Positioned(
              left: 22,
              child: Opacity(
                opacity: progress,
                child: Transform.scale(
                  scale: 0.82 + (progress * 0.18),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: context.scheme.secondary.withValues(alpha: 0.16),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.reply_rounded,
                      color: context.scheme.secondary,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),
          AnimatedSlide(
            duration: _isDragging
                ? Duration.zero
                : AppMotion.resolve(context, AppMotion.fast),
            curve: AppMotion.standard,
            offset: Offset(_dragOffset / MediaQuery.sizeOf(context).width, 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}
