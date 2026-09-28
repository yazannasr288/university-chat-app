part of '../message_content.dart';

extension _MessageContentImageVideoContent on _MessageContentState {
  Widget _buildImageMessage(ChatMessage message) {
    final remoteUrl = _imageDisplayUrl.trim();
    final hasLocal = _localFileExists(message.localFilePath);
    final hasRemote = remoteUrl.isNotEmpty;
    final hasStoragePath =
        _MessageContentState._cleanStoragePath(message.storagePath).isNotEmpty;
    final isResolving =
        !hasLocal &&
        !hasRemote &&
        hasStoragePath &&
        !_imageResolveFailed &&
        !_isUnavailable;
    final failedToResolve = _imageResolveFailed && !hasLocal && !hasRemote;
    final width = _contentWidth(max: 314, factor: 0.70);
    final height = math.min(width * 1.16, 354.0);
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    final cacheWidth = (width * pixelRatio).ceil().clamp(64, 3072).toInt();
    final cacheHeight = (height * pixelRatio).ceil().clamp(64, 3072).toInt();

    Widget imageChild;
    if (hasLocal) {
      imageChild = Image.file(
        File(message.localFilePath!.trim()),
        fit: BoxFit.cover,
        gaplessPlayback: true,
        cacheWidth: cacheWidth,
        cacheHeight: cacheHeight,
        errorBuilder:
            (_, _, _) => _placeholder(
              icon: Icons.broken_image_rounded,
              label: 'chat.attachment.image_display_failed',
            ),
      );
    } else if (hasRemote) {
      imageChild = SafeNetworkImage(
        url: remoteUrl,
        fit: BoxFit.cover,
        placeholderBuilder:
            (_) => _placeholder(
              icon: Icons.image_rounded,
              label: 'chat.attachment.image_loading',
            ),
        errorBuilder:
            (_) => _placeholder(
              icon: Icons.broken_image_rounded,
              label: 'chat.attachment.image_load_failed',
            ),
      );
    } else {
      imageChild = _placeholder(
        icon:
            failedToResolve ? Icons.broken_image_rounded : Icons.image_rounded,
        label:
            failedToResolve
                ? 'chat.attachment.image_load_failed'
                : 'chat.attachment.image',
      );
    }

    final canOpenLocal = hasLocal && !_isUnavailable;
    final canOpenRemote = hasRemote && !_isWaiting && !_isUnavailable;

    return GestureDetector(
      onTap:
          canOpenLocal || canOpenRemote
              ? () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (_) => FullScreenImagePage(
                          url: canOpenRemote ? remoteUrl : '',
                          localPath:
                              canOpenLocal
                                  ? message.localFilePath!.trim()
                                  : null,
                          attachment: _downloadableAttachment(message),
                        ),
                  ),
                );
              }
              : null,
      child: _mediaShell(
        label: 'chat.attachment.image',
        icon: Icons.image_rounded,
        width: width,
        height: height,
        child: imageChild,
        topEndOverlay: _mediaSaveButton(message),
        showLoading: isResolving,
      ),
    );
  }

  Widget _buildVideoMessage(ChatMessage message) {
    final videoUrl = _videoDisplayUrl.trim();
    final thumbnailUrl = _videoThumbnailDisplayUrl.trim();
    final localVideoPath = message.localFilePath?.trim() ?? '';
    final hasLocalVideo = _localFileExists(localVideoPath);
    final canOpenLocal = hasLocalVideo && !_isUnavailable;
    final hasRemoteSource =
        (message.videoUrl?.trim().isNotEmpty == true) ||
        _MessageContentState._cleanStoragePath(message.storagePath).isNotEmpty;
    final canOpenRemote =
        hasRemoteSource && !_isWaiting && !_isUnavailable && !_videoIsOpening;
    final canOpen = canOpenLocal || canOpenRemote;
    final isResolving = _videoIsOpening;
    final width = _contentWidth(max: 316, factor: 0.70);
    final height = math.max(154.0, width * 9 / 16);
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    final cacheWidth = (width * pixelRatio).ceil().clamp(64, 3072).toInt();
    final cacheHeight = (height * pixelRatio).ceil().clamp(64, 3072).toInt();

    final hasLocalThumbnail = _localFileExists(message.localThumbnailPath);
    final hasRemoteThumbnail = thumbnailUrl.isNotEmpty;

    Widget thumbnailChild;
    if (hasLocalThumbnail) {
      thumbnailChild = Image.file(
        File(message.localThumbnailPath!.trim()),
        fit: BoxFit.cover,
        gaplessPlayback: true,
        cacheWidth: cacheWidth,
        cacheHeight: cacheHeight,
        errorBuilder: (_, _, _) => _videoFallback(),
      );
    } else if (hasRemoteThumbnail) {
      thumbnailChild = SafeNetworkImage(
        url: thumbnailUrl,
        fit: BoxFit.cover,
        placeholderBuilder: (_) => _videoFallback(),
        errorBuilder: (_) => _videoFallback(),
      );
    } else {
      thumbnailChild = _videoFallback();
    }

    return GestureDetector(
      onTap:
          canOpen
              ? () async {
                if (canOpenLocal) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (_) => VideoPlayerPage(
                            url: '',
                            localPath: localVideoPath,
                          ),
                    ),
                  );
                  return;
                }

                _applyState(() {
                  _videoIsOpening = true;
                });

                try {
                  final resolvedUrl = await _resolveAttachmentUrlForOpen(
                    directUrl:
                        videoUrl.isNotEmpty ? videoUrl : message.videoUrl,
                    storagePath: message.storagePath,
                  );

                  if (!mounted) return;
                  _applyState(() {
                    _videoDisplayUrl = resolvedUrl.trim();
                    _videoIsOpening = false;
                  });

                  if (resolvedUrl.trim().isEmpty) {
                    showAppSnackBar(
                      context,
                      tr('common.could_not_play_video'),
                      type: SnackType.error,
                    );
                    return;
                  }

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => VideoPlayerPage(url: resolvedUrl.trim()),
                    ),
                  );
                } catch (_) {
                  if (!mounted) return;
                  _applyState(() {
                    _videoIsOpening = false;
                  });
                  showAppSnackBar(
                    context,
                    tr('common.could_not_play_video'),
                    type: SnackType.error,
                  );
                }
              }
              : null,
      child: _mediaShell(
        label: 'chat.attachment.video',
        icon: Icons.videocam_rounded,
        width: width,
        height: height,
        child: thumbnailChild,
        centerOverlay: _playButton(enabled: canOpen),
        topEndOverlay: _mediaSaveButton(message),
        showLoading: isResolving && !_videoThumbnailResolveFailed,
      ),
    );
  }
}
