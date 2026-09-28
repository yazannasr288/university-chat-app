part of '../chat_controller.dart';

extension ChatPendingMessageHelpers on ChatController {
  static const Duration _minAutoRetryDelay = Duration(seconds: 2);
  static const Duration _maxAutoRetryDelay = Duration(minutes: 2);

  bool _isAttachmentMessage(ChatMessage message) {
    return message.type == ChatAttachmentType.image.value ||
        message.type == ChatAttachmentType.video.value ||
        message.type == ChatAttachmentType.audio.value ||
        message.type == ChatAttachmentType.file.value;
  }

  void _rememberLocalAttachmentPreview(ChatMessage message) {
    if (!_isAttachmentMessage(message)) return;
    if (message.localFilePath?.trim().isNotEmpty != true &&
        message.localThumbnailPath?.trim().isNotEmpty != true) {
      return;
    }

    _localAttachmentPreviews.remove(message.id);
    _localAttachmentPreviews[message.id] = message;

    while (_localAttachmentPreviews.length >
        ChatController._maxLocalAttachmentPreviews) {
      _localAttachmentPreviews.remove(_localAttachmentPreviews.keys.first);
    }
  }

  void _forgetLocalAttachmentPreview(String id) {
    _localAttachmentPreviews.remove(id);
  }

  ChatMessage withLocalAttachmentPreview(ChatMessage message) {
    final preview = _localAttachmentPreviews[message.id];
    if (preview == null || !_isAttachmentMessage(message)) return message;

    final previewFilePath = preview.localFilePath?.trim();
    final previewThumbnailPath = preview.localThumbnailPath?.trim();

    return message.copyWith(
      localFilePath:
          message.localFilePath?.trim().isNotEmpty == true
              ? message.localFilePath
              : previewFilePath,
      localThumbnailPath:
          message.localThumbnailPath?.trim().isNotEmpty == true
              ? message.localThumbnailPath
              : previewThumbnailPath,
      audioDurationMs: message.audioDurationMs ?? preview.audioDurationMs,
    );
  }

  int _nextClientMessageTime([int? requestedTime]) {
    final safeTime = _safeClientMessageTime(
      requestedTime ?? DateTime.now().millisecondsSinceEpoch,
    );

    final nextTime =
        safeTime <= _lastGeneratedMessageTime
            ? _lastGeneratedMessageTime + 1
            : safeTime;
    _lastGeneratedMessageTime = nextTime;
    return nextTime;
  }

  Map<String, dynamic> _basePayloadFromPending(ChatMessage message) {
    final replyText = message.replyToText?.trim() ?? '';

    return {
      'sender':
          message.sender.trim().isNotEmpty ? message.sender.trim() : userName,
      'senderId':
          message.senderId.trim().isNotEmpty
              ? message.senderId.trim()
              : currentUid,
      'time': message.time,
      'createdAt': FieldValue.serverTimestamp(),
      if (message.replyToMessageId?.trim().isNotEmpty == true) ...{
        'replyToMessageId': message.replyToMessageId!.trim(),
        if (replyText.isNotEmpty) 'replyToText': replyText,
        'replyToSender':
            message.replyToSender?.trim().isNotEmpty == true
                ? message.replyToSender!.trim()
                : tr('chat.unknown_sender'),
        'replyToType':
            message.replyToType?.trim().isNotEmpty == true
                ? message.replyToType!.trim()
                : 'text',
      },
    };
  }

  ChatMessage _withFreshSendTimeIfNeeded(ChatMessage message) {
    final safe = _safeClientMessageTime(message.time);
    if (safe == message.time) return message;
    return message.copyWith(time: _nextClientMessageTime(safe));
  }

  void _persistPendingMessagesDebounced() {
    _pendingPersistTimer?.cancel();
    _pendingPersistTimer = Timer(const Duration(milliseconds: 180), () {
      if (_disposed) return;
      unawaited(
        _chatCacheRepository
            .savePendingMessages(groupId, _pendingMessages)
            .catchError((Object error) {}),
      );
    });
  }

  Future<void> _persistPendingMessagesNow() {
    _pendingPersistTimer?.cancel();
    return _chatCacheRepository.savePendingMessages(groupId, _pendingMessages);
  }

  void _upsertPending(ChatMessage message) {
    final index = _pendingMessages.indexWhere((e) => e.id == message.id);
    if (index == -1) {
      _pendingMessages.insert(0, message);
    } else {
      _pendingMessages[index] = message;
    }
    _persistPendingMessagesDebounced();
    _notifyMessagesChanged();
  }

  void _removePending(String id) {
    _pendingMessages.removeWhere((e) => e.id == id);
    _pendingSendInFlight.remove(id);
    _persistPendingMessagesDebounced();
    _notifyMessagesChanged();
  }

  ChatMessage? _pendingById(String id) {
    final index = _pendingMessages.indexWhere((e) => e.id == id);
    return index == -1 ? null : _pendingMessages[index];
  }

  bool _isPermanentFirebaseSendError(String code) {
    return code == 'permission-denied' ||
        code == 'unauthorized' ||
        code == 'unauthenticated' ||
        code == 'invalid-argument' ||
        code == 'failed-precondition' ||
        code == 'not-found';
  }

  bool _isRetryableSendError(Object error) {
    if (error is ChatOperationException) return error.retryable;

    if (error is FirebaseException) {
      return !_isPermanentFirebaseSendError(error.code);
    }

    if (error is FirebaseFunctionsException) {
      return !_isPermanentFirebaseSendError(error.code);
    }

    if (error is FileSystemException || error is StateError) return false;

    return true;
  }

  Duration _retryDelayForAttempt(int attempt) {
    final seconds = switch (attempt) {
      <= 0 => 2,
      1 => 4,
      2 => 8,
      3 => 15,
      4 => 30,
      _ => 60,
    };

    final baseDelay = Duration(seconds: seconds);
    if (baseDelay < _minAutoRetryDelay) return _minAutoRetryDelay;
    if (baseDelay > _maxAutoRetryDelay) return _maxAutoRetryDelay;
    return baseDelay;
  }

  void _schedulePendingRetrySweep() {
    if (_disposed || _pendingMessages.isEmpty) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    int? earliest;

    for (final message in _pendingMessages) {
      if (message.isFailed) continue;
      if (_pendingSendInFlight.contains(message.id)) continue;
      if (!message.isLocalPending) continue;

      final nextRetryAt = message.nextRetryAt > 0 ? message.nextRetryAt : now;
      earliest =
          earliest == null || nextRetryAt < earliest ? nextRetryAt : earliest;
    }

    if (earliest == null) return;

    final delayMs =
        (earliest - now).clamp(0, _maxAutoRetryDelay.inMilliseconds).toInt();
    final delay = Duration(milliseconds: delayMs);

    _pendingRetryTimer?.cancel();
    _pendingRetryTimer = Timer(delay, _retryDuePendingMessages);
  }

  void _retryDuePendingMessages() {
    if (_disposed) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    for (final message in List<ChatMessage>.from(_pendingMessages)) {
      if (message.isFailed) continue;
      if (_pendingSendInFlight.contains(message.id)) continue;
      if (!message.isLocalPending) continue;
      if (message.nextRetryAt > now) continue;

      unawaited(_processPendingMessage(message.id));
    }

    _schedulePendingRetrySweep();
  }

  void _markPendingForAutoRetry(String id, Object error) {
    final current = _pendingById(id);
    if (current == null || current.isFailed) return;

    final retryable = _isRetryableSendError(error);
    if (!retryable) {
      _upsertPending(
        current.copyWith(
          isFailed: true,
          isLocalPending: false,
          hasPendingWrites: false,
          uploadProgress: 0,
        ),
      );
      return;
    }

    final attempt = current.retryAttempt + 1;
    final nextRetryAt =
        DateTime.now()
            .add(_retryDelayForAttempt(attempt))
            .millisecondsSinceEpoch;

    _upsertPending(
      current.copyWith(
        isFailed: false,
        isLocalPending: true,
        hasPendingWrites: false,
        retryAttempt: attempt,
        nextRetryAt: nextRetryAt,
      ),
    );
    _schedulePendingRetrySweep();
  }

  Future<void> _restorePendingMessages() async {
    try {
      final restored = await _chatCacheRepository.loadPendingMessages(groupId);
      if (_disposed || restored.isEmpty) return;

      var changed = false;
      final now = DateTime.now().millisecondsSinceEpoch;
      for (final message in restored) {
        if (_pendingById(message.id) != null) continue;

        var pending = message;
        if (pending.isFailed) {
          // Keep explicit final failures as-is so the user can decide whether to retry or remove.
        } else {
          final type = _attachmentTypeFromValue(pending.type);
          final hasStoragePath = pending.storagePath?.trim().isNotEmpty == true;
          final localPath = pending.localFilePath?.trim() ?? '';
          if (type != null && !hasStoragePath) {
            final file = localPath.isNotEmpty ? File(localPath) : null;
            if (file == null ||
                !await file.exists() ||
                await file.length() == 0) {
              pending = pending.copyWith(
                isFailed: true,
                isLocalPending: false,
                hasPendingWrites: false,
                uploadProgress: 0,
              );
            }
          }
        }

        if (!pending.isFailed) {
          pending = pending.copyWith(
            isLocalPending: true,
            hasPendingWrites: false,
            nextRetryAt: pending.nextRetryAt > 0 ? pending.nextRetryAt : now,
          );
        }

        _pendingMessages.add(pending);
        changed = true;
      }

      if (!changed) return;
      _pendingMessages.sort((a, b) => b.time.compareTo(a.time));
      _persistPendingMessagesDebounced();
      _notifyMessagesChanged();
      _schedulePendingRetrySweep();
    } catch (error) {
      if (kDebugMode) debugPrint('Pending message restore failed: $error');
    }
  }
}
