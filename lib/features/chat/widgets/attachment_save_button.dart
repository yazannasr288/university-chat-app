import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../../core/utils/error_message.dart';
import '../../../services/attachment_download_service.dart';

class AttachmentSaveButton extends StatefulWidget {
  final DownloadableAttachment attachment;
  final bool compact;
  final bool overlayStyle;

  const AttachmentSaveButton({
    super.key,
    required this.attachment,
    this.compact = false,
    this.overlayStyle = false,
  });

  @override
  State<AttachmentSaveButton> createState() => _AttachmentSaveButtonState();
}

class _AttachmentSaveButtonState extends State<AttachmentSaveButton> {
  final AttachmentDownloadService _downloadService = AttachmentDownloadService.instance;

  @override
  void initState() {
    super.initState();
    _downloadService.refreshSavedState(widget.attachment);
  }

  @override
  void didUpdateWidget(covariant AttachmentSaveButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.attachment.key != widget.attachment.key) {
      _downloadService.refreshSavedState(widget.attachment);
    }
  }

  Future<void> _save() async {
    try {
      await _downloadService.save(widget.attachment);
      if (!mounted) return;
      showAppSnackBar(
        context,
        'attachments.saved_to_device'.tr(),
        type: SnackType.success,
      );
      await _downloadService.refreshSavedState(widget.attachment);
    } catch (error) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        cleanErrorMessage(error),
        type: SnackType.error,
      );
    }
  }

  Future<void> _open(String path) async {
    final result = await OpenFilex.open(path);
    if (!mounted) return;
    if (result.type != ResultType.done) {
      showAppSnackBar(
        context,
        'chat.could_not_open_saved_file'.tr(),
        type: SnackType.error,
      );
    }
  }

  String _formatRemaining(Duration? duration) {
    if (duration == null) return '';
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');

    if (duration.inHours > 0) {
      return '${duration.inHours}:$minutes:$seconds';
    }
    if (duration.inMinutes > 0) {
      return '${duration.inMinutes}:$seconds';
    }
    return '${duration.inSeconds.clamp(1, 59)} ${'chat.s'.tr()}';
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.attachment.canSave) return const SizedBox.shrink();

    return StreamBuilder<AttachmentDownloadSnapshot>(
      stream: _downloadService.watch(widget.attachment),
      initialData: _downloadService.snapshotOf(widget.attachment),
      builder: (context, snapshot) {
        final state = snapshot.data ?? const AttachmentDownloadSnapshot.idle();

        if (widget.compact) {
          return _CompactSaveButton(
            state: state,
            overlayStyle: widget.overlayStyle,
            onSave: state.isDownloading ? null : _save,
            onOpen: state.savedPath == null ? null : () => _open(state.savedPath!),
          );
        }

        return _InlineSaveButton(
          state: state,
          remainingLabel: _formatRemaining(state.remaining),
          onSave: state.isDownloading ? null : _save,
          onOpen: state.savedPath == null ? null : () => _open(state.savedPath!),
        );
      },
    );
  }
}

class _CompactSaveButton extends StatelessWidget {
  final AttachmentDownloadSnapshot state;
  final bool overlayStyle;
  final VoidCallback? onSave;
  final VoidCallback? onOpen;

  const _CompactSaveButton({
    required this.state,
    required this.overlayStyle,
    required this.onSave,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final backgroundColor = overlayStyle
        ? Colors.black.withValues(alpha: 0.50)
        : context.appPrimary.withValues(alpha: context.isDark ? 0.18 : 0.10);
    final foregroundColor = overlayStyle ? Colors.white : context.appMessageMineMeta;

    IconData icon;
    VoidCallback? onPressed;
    String tooltip;

    if (state.isDownloading) {
      icon = Icons.downloading_rounded;
      onPressed = null;
      tooltip = 'common.saving'.tr();
    } else if (state.isSaved) {
      icon = Icons.download_done_rounded;
      onPressed = state.savedPath == null ? null : onOpen;
      tooltip = 'attachments.saved_to_device'.tr();
    } else if (state.hasFailed) {
      icon = Icons.refresh_rounded;
      onPressed = onSave;
      tooltip = 'chat.could_not_save_try_again'.tr();
    } else {
      icon = Icons.file_download_outlined;
      onPressed = onSave;
      tooltip = 'chat.save_device'.tr();
    }

    return Tooltip(
      message: tooltip,
      child: Material(
        color: backgroundColor,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: overlayStyle ? 42 : 38,
            height: overlayStyle ? 42 : 38,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (state.isDownloading)
                  SizedBox(
                    width: overlayStyle ? 31 : 28,
                    height: overlayStyle ? 31 : 28,
                    child: CircularProgressIndicator(
                      value: state.progress > 0 ? state.progress : null,
                      strokeWidth: 2.4,
                      color: foregroundColor,
                      backgroundColor: foregroundColor.withValues(alpha: 0.18),
                    ),
                  ),
                Icon(icon, color: foregroundColor, size: overlayStyle ? 22 : 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InlineSaveButton extends StatelessWidget {
  final AttachmentDownloadSnapshot state;
  final String remainingLabel;
  final VoidCallback? onSave;
  final VoidCallback? onOpen;

  const _InlineSaveButton({
    required this.state,
    required this.remainingLabel,
    required this.onSave,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final percent = (state.progress * 100).clamp(0, 100).round();

    String label;
    IconData icon;
    VoidCallback? action;

    if (state.isDownloading) {
      label = remainingLabel.isEmpty
          ? '${'common.saving'.tr()} $percent%'
          : '${'common.saving'.tr()} $percent% • ${'chat.remaining'.tr()} $remainingLabel';
      icon = Icons.downloading_rounded;
      action = null;
    } else if (state.isSaved) {
      label = 'attachments.saved_to_device'.tr();
      icon = Icons.download_done_rounded;
      action = onOpen;
    } else if (state.hasFailed) {
      label = 'chat.could_not_save_try_again'.tr();
      icon = Icons.refresh_rounded;
      action = onSave;
    } else {
      label = 'chat.save_device'.tr();
      icon = Icons.file_download_outlined;
      action = onSave;
    }

    final foreground = context.appPrimary;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: foreground.withValues(alpha: context.isDark ? 0.16 : 0.08),
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: foreground.withValues(alpha: 0.20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: action,
            borderRadius: BorderRadius.circular(AppRadii.md),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: foreground, size: 17),
                  const SizedBox(width: 7),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.textTheme.bodySmall?.copyWith(
                        color: context.appTextPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (state.isDownloading)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(AppRadii.md),
              ),
              child: LinearProgressIndicator(
                value: state.progress > 0 ? state.progress : null,
                minHeight: 3,
                color: foreground,
                backgroundColor: foreground.withValues(alpha: 0.14),
              ),
            ),
        ],
      ),
    );
  }
}
