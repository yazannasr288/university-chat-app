part of '../message_content.dart';

extension _MessageContentFileContent on _MessageContentState {
  Widget _buildFileMessage(ChatMessage message) {
    final fileUrl = _fileDisplayUrl.trim();
    final localPath = message.localFilePath?.trim() ?? '';
    final hasLocalFile = _localFileExists(localPath);
    final canOpenLocal = hasLocalFile && !_isUnavailable;
    final hasRemoteSource = (message.fileUrl?.trim().isNotEmpty == true) ||
        _MessageContentState._cleanStoragePath(message.storagePath).isNotEmpty;
    final canOpenRemote = hasRemoteSource && !_isWaiting && !_isUnavailable && !_fileIsOpening;
    final canOpen = canOpenLocal || canOpenRemote;
    final isResolving = _fileIsOpening;
    final width = _contentWidth(max: 314, factor: 0.72);
    final textColor = widget.sendByMe ? Colors.white : context.appTextPrimary;
    final metaColor = widget.sendByMe
        ? Colors.white.withValues(alpha: 0.74)
        : context.appTextSecondary;
    final fileAccent = widget.sendByMe ? AppColors.accent : context.appPrimary;

    return GestureDetector(
      onTap: canOpen
          ? () async {
              if (canOpenLocal) {
                final result = await OpenFilex.open(localPath);
                if (!mounted || result.type == ResultType.done) return;
                showAppSnackBar(
                  context,
                  tr('chat.attachment.open_file_failed'),
                  type: SnackType.error,
                );
                return;
              }

              _applyState(() {
                _fileIsOpening = true;
              });

              try {
                final resolvedUrl = await _resolveAttachmentUrlForOpen(
                  directUrl: fileUrl.isNotEmpty ? fileUrl : message.fileUrl,
                  storagePath: message.storagePath,
                );

                if (!mounted) return;
                _applyState(() {
                  _fileDisplayUrl = resolvedUrl.trim();
                  _fileIsOpening = false;
                });

                if (resolvedUrl.trim().isEmpty) {
                  showAppSnackBar(
                    context,
                    tr('chat.attachment.open_file_failed'),
                    type: SnackType.error,
                  );
                  return;
                }

                final uri = Uri.parse(resolvedUrl.trim());
                final opened = await launchUrl(
                  uri,
                  mode: LaunchMode.externalApplication,
                );
                if (!opened) {
                  if (!mounted) return;
                  showAppSnackBar(
                    context,
                    tr('chat.attachment.open_file_failed'),
                    type: SnackType.error,
                  );
                }
              } catch (_) {
                if (!mounted) return;
                _applyState(() {
                  _fileIsOpening = false;
                });
                showAppSnackBar(
                  context,
                  tr('chat.attachment.open_file_failed'),
                  type: SnackType.error,
                );
              }
            }
          : null,
      child: SizedBox(
        width: width,
        child: Stack(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: AppDecorations.rounded(
                color: widget.sendByMe
                    ? Colors.white.withValues(alpha: 0.11)
                    : context.appSurfaceSoft,
                borderColor: widget.sendByMe
                    ? Colors.white.withValues(alpha: 0.15)
                    : context.appBorder.withValues(alpha: 0.72),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: AppDecorations.rounded(
                      color: fileAccent.withValues(alpha: widget.sendByMe ? 0.22 : 0.12),
                      radius: 15,
                      borderColor: fileAccent.withValues(alpha: 0.20),
                    ),
                    child: Icon(
                      _fileIcon(message.fileName),
                      color: fileAccent,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _fileTitle(message),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: context.textTheme.titleSmall?.copyWith(
                            color: textColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: AppDecorations.pill(
                                color: fileAccent.withValues(alpha: widget.sendByMe ? 0.18 : 0.10),
                              ),
                              child: Text(
                                _fileExtension(message.fileName),
                                style: context.textTheme.bodySmall?.copyWith(
                                  color: fileAccent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              canOpen
                                  ? Icons.open_in_new_rounded
                                  : Icons.lock_clock_rounded,
                              color: metaColor,
                              size: 15,
                            ),
                            const Spacer(),
                            if (_canShowSaveButton(message))
                              AttachmentSaveButton(
                                attachment: _downloadableAttachment(message),
                                compact: true,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (_isWaiting || isResolving || _isUnavailable)
              _statusOverlay(
                label: tr('chat.attachment.loading'),
                forceLoading: isResolving,
              ),
          ],
        ),
      ),
    );
  }

}
