part of '../message_content.dart';

extension _MessageContentAudioContent on _MessageContentState {
  String _formatAudioDuration(Duration duration) {
    final totalSeconds = duration.inSeconds.clamp(0, 24 * 60 * 60);
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  String _formatAudioRemaining(Duration duration, Duration position) {
    if (duration <= Duration.zero) return '--:--';
    final remaining = duration - position;
    return '-${_formatAudioDuration(
      remaining < Duration.zero ? Duration.zero : remaining,
    )}';
  }

  String _formatPlaybackSpeed(double speed) {
    if ((speed - 1.0).abs() < 0.001) return '1x';
    if ((speed - 2.0).abs() < 0.001) return '2x';
    return '${speed.toStringAsFixed(2).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '')}x';
  }

  Duration _audioDisplayDuration({
    required ChatMessage message,
    required ChatAudioPlaybackState playback,
    required String audioUrl,
  }) {
    if (playback.id == message.id && playback.duration > Duration.zero) {
      return playback.duration;
    }

    final storedDurationMs = message.audioDurationMs;
    if (storedDurationMs != null && storedDurationMs > 0) {
      return Duration(milliseconds: storedDurationMs);
    }

    return Duration.zero;
  }

  String _audioPlayableSource(ChatMessage message) {
    final localPath = message.localFilePath?.trim() ?? '';
    if (localPath.isNotEmpty && _localFileExists(localPath)) return localPath;

    final directUrl = message.audioUrl?.trim() ?? '';
    if (directUrl.isNotEmpty) return directUrl;

    return '';
  }

  bool _hasResolvableAudioSource(ChatMessage message) {
    if (_audioPlayableSource(message).isNotEmpty) return true;
    return _MessageContentState._cleanStoragePath(message.storagePath).isNotEmpty;
  }

  Future<String> _resolveAudioPlaybackItem(ChatAudioPlaybackItem item) async {
    final directSource = item.source.trim();
    if (directSource.isNotEmpty) return directSource;

    final cleanPath = _MessageContentState._cleanStoragePath(
      item.storagePath.isNotEmpty ? item.storagePath : widget.message.storagePath,
    );
    if (cleanPath.isEmpty) return '';

    final groupId = item.groupId.trim().isNotEmpty ? item.groupId.trim() : widget.groupId;
    final key = _MessageContentState._cacheKey(
      groupId: groupId,
      directUrl: null,
      storagePath: cleanPath,
    );

    final cached = _MessageContentState._resolvedAttachmentUrls[key];
    if (cached != null && cached.isNotEmpty) return cached;

    if (mounted && item.id == widget.message.id) {
      _applyState(() {
        _audioIsResolving = true;
        _audioResolveFailed = false;
      });
    }

    try {
      final resolvedUrl = await _resolveStoragePathUrl(
        key: key,
        storagePath: cleanPath,
      );

      final cleanUrl = resolvedUrl.trim();
      if (cleanUrl.isNotEmpty) {
        ChatAudioPlayerService.registerSource(id: item.id, source: cleanUrl);
      }

      if (mounted && item.id == widget.message.id) {
        _applyState(() {
          _audioDisplayUrl = cleanUrl;
          _audioResolveFailed = cleanUrl.isEmpty;
          _audioIsResolving = false;
        });
      }

      return cleanUrl;
    } catch (_) {
      if (mounted && item.id == widget.message.id) {
        _applyState(() {
          _audioResolveFailed = true;
          _audioIsResolving = false;
        });
      }
      rethrow;
    }
  }


  Widget _buildAudioMessage(ChatMessage message) {
    final audioSource = _audioPlayableSource(message);
    if (audioSource.isNotEmpty) {
      ChatAudioPlayerService.registerSource(id: message.id, source: audioSource);
    }

    final hasResolvableSource = _hasResolvableAudioSource(message);
    final localAudioPath = message.localFilePath?.trim() ?? '';
    final hasPlayableLocalAudio =
        localAudioPath.isNotEmpty && _localFileExists(localAudioPath);
    final canPlay = hasResolvableSource && (!_isUnavailable || hasPlayableLocalAudio);
    final hasAudioError =
        _audioPlaybackFailed || (_audioResolveFailed && !hasPlayableLocalAudio);
    final width = _contentWidth(max: 282, factor: 0.72);
    final textColor = widget.sendByMe ? Colors.white : context.appTextPrimary;
    final metaColor = widget.sendByMe
        ? Colors.white.withValues(alpha: 0.74)
        : context.appTextSecondary;
    final activeBarColor = widget.sendByMe ? Colors.white : context.appPrimary;
    final trackBarColor = widget.sendByMe
        ? Colors.white.withValues(alpha: 0.28)
        : context.appBorder.withValues(alpha: 0.72);
    final borderColor = widget.sendByMe
        ? Colors.white.withValues(alpha: 0.14)
        : context.appBorder.withValues(alpha: 0.70);

    Future<void> toggleAudio() async {
      if (!canPlay) {
        if (_audioResolveFailed) _retryAudioResolve(message);
        return;
      }

      try {
        if ((_audioPlaybackFailed || _audioResolveFailed) && mounted) {
          _applyState(() {
            _audioPlaybackFailed = false;
            _audioResolveFailed = false;
          });
        }
        await ChatAudioPlayerService.playOrPause(
          audioSource,
          id: message.id,
          queue: widget.audioPlaybackQueue,
          resolveSource: _resolveAudioPlaybackItem,
        );
      } catch (error) {
        if (!mounted) return;
        if (error is StateError || error is ArgumentError || error is UnsupportedError) {
          _applyState(() => _audioPlaybackFailed = true);
        } else {
          _applyState(() => _audioResolveFailed = true);
        }
      }
    }

    Future<void> seekAudio(double fraction, Duration duration) async {
      if (!canPlay || duration <= Duration.zero) return;

      final safeFraction = fraction.clamp(0.0, 1.0).toDouble();
      final target = Duration(
        milliseconds: (duration.inMilliseconds * safeFraction).round(),
      );

      try {
        if ((_audioPlaybackFailed || _audioResolveFailed) && mounted) {
          _applyState(() {
            _audioPlaybackFailed = false;
            _audioResolveFailed = false;
          });
        }
        await ChatAudioPlayerService.seekToPosition(
          target,
          id: message.id,
          source: audioSource,
          queue: widget.audioPlaybackQueue,
          resolveSource: _resolveAudioPlaybackItem,
        );
      } catch (error) {
        if (!mounted) return;
        if (error is StateError || error is ArgumentError || error is UnsupportedError) {
          _applyState(() => _audioPlaybackFailed = true);
        } else {
          _applyState(() => _audioResolveFailed = true);
        }
      }
    }

    Future<void> retryAudio() async => toggleAudio();

    return SizedBox(
      width: width,
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            decoration: AppDecorations.rounded(
              color: widget.sendByMe
                  ? Colors.white.withValues(alpha: 0.11)
                  : context.appSurfaceSoft,
              borderColor: borderColor,
            ),
            child: ValueListenableBuilder<ChatAudioPlaybackState>(
              valueListenable: ChatAudioPlayerService.playbackState,
              builder: (context, playback, _) {
                final isCurrent = playback.id == message.id;
                final isPlaying = canPlay && isCurrent && playback.isPlaying;
                final isBuffering = _audioIsResolving ||
                    (canPlay && isCurrent && playback.isBuffering);
                final displayDuration = _audioDisplayDuration(
                  message: message,
                  playback: playback,
                  audioUrl: audioSource,
                );
                final rawPosition = isCurrent ? playback.position : Duration.zero;
                final position = displayDuration > Duration.zero &&
                        rawPosition > displayDuration
                    ? displayDuration
                    : rawPosition;
                final progress = displayDuration > Duration.zero
                    ? (position.inMilliseconds / displayDuration.inMilliseconds)
                        .clamp(0.0, 1.0)
                        .toDouble()
                    : 0.0;
                final durationLabel = displayDuration > Duration.zero
                    ? _formatAudioDuration(displayDuration)
                    : '--:--';
                final positionLabel = isCurrent && position > Duration.zero
                    ? _formatAudioDuration(position)
                    : '00:00';
                final remainingLabel = _formatAudioRemaining(
                  displayDuration,
                  position,
                );
                final speedLabel = _formatPlaybackSpeed(playback.speed);
                final actionEnabled = canPlay || _audioResolveFailed;
                final actionIcon = hasAudioError
                    ? Icons.refresh_rounded
                    : isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded;

                final statusText = _audioIsResolving || _isWaiting
                    ? tr('chat.attachment.preparing')
                    : _isUnavailable && hasPlayableLocalAudio
                        ? tr('chat.attachment.not_sent')
                        : hasAudioError
                            ? tr('chat.attachment.audio_play_failed')
                            : canPlay
                                ? (isPlaying
                                    ? tr('chat.attachment.audio_playing')
                                    : tr('chat.attachment.audio_tap_to_play'))
                                : tr('chat.attachment.audio_play_failed');

                return Row(
                  children: [
                    Material(
                      color: actionEnabled
                          ? (hasAudioError
                              ? AppColors.error
                              : AppColors.supportEmerald)
                          : AppColors.supportEmerald.withValues(alpha: 0.44),
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: actionEnabled ? retryAudio : null,
                        child: SizedBox(
                          width: 36,
                          height: 36,
                          child: isBuffering
                              ? const AppLoader.inline(
                                  size: 18,
                                  strokeWidth: 2.1,
                                  color: Colors.white,
                                )
                              : Icon(
                                  actionIcon,
                                  color: Colors.white,
                                  size: hasAudioError
                                      ? 20
                                      : isPlaying
                                          ? 21
                                          : 27,
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  tr('chat.attachment.voice_message'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: context.textTheme.bodyMedium?.copyWith(
                                    color: textColor,
                                    fontSize: 12.2,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(AppRadii.pill),
                                  onTap: canPlay
                                      ? () async {
                                          await ChatAudioPlayerService.cycleSpeed();
                                        }
                                      : null,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 2.5,
                                    ),
                                    decoration: AppDecorations.pill(
                                      color: widget.sendByMe
                                          ? Colors.white.withValues(alpha: 0.16)
                                          : context.appPrimary.withValues(alpha: 0.10),
                                      borderColor: widget.sendByMe
                                          ? Colors.white.withValues(alpha: 0.18)
                                          : context.appPrimary.withValues(alpha: 0.16),
                                    ),
                                    child: Text(
                                      speedLabel,
                                      style: context.textTheme.labelSmall?.copyWith(
                                        color: widget.sendByMe
                                            ? Colors.white
                                            : context.appPrimary,
                                        fontSize: 10.3,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              if (_canShowSaveButton(message)) ...[
                                const SizedBox(width: 4),
                                AttachmentSaveButton(
                                  attachment: _downloadableAttachment(message),
                                  compact: true,
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 6),
                          _AudioProgressBar(
                            progress: progress,
                            enabled: canPlay && displayDuration > Duration.zero,
                            activeColor: activeBarColor,
                            trackColor: trackBarColor,
                            onSeekFraction: (fraction) => seekAudio(
                              fraction,
                              displayDuration,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                positionLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.textTheme.labelSmall?.copyWith(
                                  color: metaColor,
                                  fontSize: 10.1,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                displayDuration > Duration.zero
                                    ? '$remainingLabel / $durationLabel'
                                    : durationLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.textTheme.labelSmall?.copyWith(
                                  color: metaColor,
                                  fontSize: 10.1,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                          if (_audioIsResolving || _isWaiting || hasAudioError || !canPlay) ...[
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    statusText,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: context.textTheme.bodySmall?.copyWith(
                                      color: hasAudioError
                                          ? (widget.sendByMe
                                              ? AppColors.errorSoft
                                              : AppColors.error)
                                          : metaColor,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                if (hasAudioError) ...[
                                  const SizedBox(width: 4),
                                  InkWell(
                                    borderRadius: BorderRadius.circular(AppRadii.pill),
                                    onTap: retryAudio,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      child: Text(
                                        'chat.attachment.retry',
                                        maxLines: 1,
                                        style: context.textTheme.bodySmall?.copyWith(
                                          color: widget.sendByMe
                                              ? Colors.white
                                              : context.appPrimary,
                                          fontSize: 9.8,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          if (_isUnavailable && !hasPlayableLocalAudio)
            _statusOverlay(label: tr('chat.attachment.load_failed')),
        ],
      ),
    );
  }

}
