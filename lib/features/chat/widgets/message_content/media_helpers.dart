part of '../message_content.dart';

extension _MessageContentMediaHelpers on _MessageContentState {
  double _contentWidth({double max = 312, double factor = 0.70}) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    return math.min(screenWidth * factor, max);
  }

  DownloadableAttachment _downloadableAttachment(ChatMessage message) {
    return DownloadableAttachment(
      groupId: widget.groupId,
      messageId: message.id,
      type: message.type,
      storagePath: message.storagePath ?? '',
      directUrl: switch (message.type) {
        'image' => _imageDisplayUrl.isNotEmpty ? _imageDisplayUrl : message.imageUrl,
        'video' => _videoDisplayUrl.isNotEmpty ? _videoDisplayUrl : message.videoUrl,
        'audio' => _audioDisplayUrl.isNotEmpty ? _audioDisplayUrl : message.audioUrl,
        'file' => _fileDisplayUrl.isNotEmpty ? _fileDisplayUrl : message.fileUrl,
        _ => null,
      },
      localFilePath: message.localFilePath,
      fileName: message.fileName,
      thumbnailStoragePath: message.type == 'video' ? message.videoThumbnailPath : null,
      thumbnailDirectUrl: message.type == 'video'
          ? (_videoThumbnailDisplayUrl.isNotEmpty
              ? _videoThumbnailDisplayUrl
              : message.videoThumbnailUrl)
          : null,
      localThumbnailPath: message.type == 'video' ? message.localThumbnailPath : null,
    );
  }

  bool _canShowSaveButton(ChatMessage message) {
    if (_isWaiting || _isUnavailable) return false;
    return _downloadableAttachment(message).canSave;
  }

  String _fileExtension(String? fileName) {
    final extension = AppFileMetadata.extensionFromName(fileName);
    return extension.isEmpty ? 'FILE' : extension.toUpperCase();
  }

  IconData _fileIcon(String? fileName) {
    switch (_fileExtension(fileName).toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'doc':
      case 'docx':
        return Icons.description_rounded;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart_rounded;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow_rounded;
      case 'txt':
        return Icons.notes_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  String _fileTitle(ChatMessage message) {
    final fileName = message.fileName?.trim();
    if (fileName != null && fileName.isNotEmpty) return fileName;

    final messageText = message.message.trim();
    if (messageText.isNotEmpty) return messageText;

    return tr('chat.attachment.generic_file');
  }

  Widget _statusOverlay({String? label, bool forceLoading = false}) {
    if (_isUnavailable) {
      return Positioned.fill(
        child: DecoratedBox(
          decoration: AppDecorations.rounded(
            color: AppColors.black.withValues(alpha: 0.46),
          ),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: AppDecorations.pill(
                color: AppColors.error.withValues(alpha: 0.94),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    tr('chat.attachment.send_failed'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (!_isWaiting && !forceLoading) return const SizedBox.shrink();

    final percent = (widget.message.uploadProgress * 100).round();
    final progressLabel = percent > 0 && percent < 100 ? '$percent%' : null;

    return Positioned.fill(
      child: DecoratedBox(
        decoration: AppDecorations.rounded(
          color: AppColors.black.withValues(alpha: 0.38),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppLoader.inline(
                size: 26,
                strokeWidth: 2.4,
                color: Colors.white,
              ),
              const SizedBox(height: 8),
              Text(
                progressLabel ?? label ?? tr('chat.attachment.loading'),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _typeBadge({
    required String label,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: AppDecorations.pill(
        color: AppColors.black.withValues(alpha: 0.50),
        borderColor: Colors.white.withValues(alpha: 0.12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 5),
          Text(
            label.tr(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _mediaShell({
    required Widget child,
    required String label,
    required IconData icon,
    required double width,
    required double height,
    Widget? centerOverlay,
    Widget? topEndOverlay,
    bool showLoading = false,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: AppDecorations.rounded(
                color: context.isDark
                    ? const Color(0xFF091421)
                    : AppColors.primaryDark,
              ),
              child: child,
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 82,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        AppColors.black.withValues(alpha: 0.50),
                        AppColors.black.withValues(alpha: 0.00),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (centerOverlay != null) Center(child: centerOverlay),
            PositionedDirectional(
              top: 10,
              start: 10,
              child: _typeBadge(label: label, icon: icon),
            ),
            if (topEndOverlay != null)
              PositionedDirectional(
                top: 8,
                end: 8,
                child: topEndOverlay,
              ),
            _statusOverlay(label: tr('chat.attachment.loading'), forceLoading: showLoading),
          ],
        ),
      ),
    );
  }

  Widget _placeholder({
    required IconData icon,
    required String label,
    Gradient? gradient,
  }) {
    return Container(
      decoration: AppDecorations.rounded(
        gradient: gradient,
        color: context.isDark ? const Color(0xFF101E30) : AppColors.primaryDark,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 42),
          const SizedBox(height: 8),
          Text(
            label.tr(),
            textAlign: TextAlign.center,
            style: context.textTheme.titleSmall?.copyWith(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _videoFallback() {
    return Container(
      decoration: AppDecorations.rounded(
        gradient: AppGradients.video,
        color: AppColors.primaryDark,
      ),
    );
  }

  Widget _playButton({required bool enabled}) {
    return AnimatedContainer(
      duration: AppMotion.fast,
      width: 58,
      height: 58,
      decoration: AppDecorations.circle(
        color: AppColors.black.withValues(alpha: enabled ? 0.56 : 0.40),
        borderColor: Colors.white70,
        borderWidth: 1.2,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Icon(
        enabled ? Icons.play_arrow_rounded : Icons.videocam_rounded,
        color: Colors.white,
        size: enabled ? 42 : 30,
      ),
    );
  }

  Widget _mediaSaveButton(ChatMessage message) {
    if (!_canShowSaveButton(message)) return const SizedBox.shrink();
    return AttachmentSaveButton(
      attachment: _downloadableAttachment(message),
      compact: true,
      overlayStyle: true,
    );
  }

}
