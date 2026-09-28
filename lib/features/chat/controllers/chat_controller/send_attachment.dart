part of '../chat_controller.dart';

extension ChatControllerSendAttachment on ChatController {
  Future<void> sendAttachment({
    required File file,
    required ChatAttachmentType type,
    String? fileName,
    int? messageTime,
    String? messageId,
    int? audioDurationMs,
  }) async {
    final now = _nextClientMessageTime(messageTime);
    final pendingId = messageId?.trim().isNotEmpty == true
        ? messageId!.trim()
        : 'local_${type.value}_${now}_${DateTime.now().microsecondsSinceEpoch}';
    final cleanFileName = fileName?.trim();

    if (type == ChatAttachmentType.audio &&
        !await _waitForStableLocalFile(file)) {
      throw Exception('chat.errors.voice_prepare_failed');
    }

    final reply = replyingToMessage;
    final replyText = reply == null ? '' : replyPreviewFor(reply).trim();

    final pendingMessage = ChatMessage(
      id: pendingId,
      type: type.value,
      message: type.fallbackMessage(cleanFileName),
      sender: userName,
      senderId: currentUid,
      time: now,
      fileName: cleanFileName,
      localFilePath: file.path,
      audioDurationMs: type == ChatAttachmentType.audio ? audioDurationMs : null,
      replyToMessageId: reply?.id,
      replyToText: replyText.isEmpty
          ? null
          : (replyText.length > 180 ? '${replyText.substring(0, 180)}…' : replyText),
      replyToSender: reply?.sender,
      replyToType: reply?.type,
      isLocalPending: true,
      uploadProgress: 0,
      nextRetryAt: DateTime.now().millisecondsSinceEpoch,
    );

    clearReply();
    _rememberLocalAttachmentPreview(pendingMessage);
    _upsertPending(pendingMessage);
    unawaited(_processPendingMessage(pendingId));
  }

  Future<void> _submitPendingAttachment(ChatMessage originalMessage) async {
    final type = _attachmentTypeFromValue(originalMessage.type);
    if (type == null) {
      throw ChatOperationException(
        'chat.errors.retry_unsupported_type',
        code: 'unsupported-type',
        retryable: false,
      );
    }

    var message = _pendingById(originalMessage.id) ?? originalMessage;
    final cleanFileName = message.fileName?.trim();
    String? uploadFileName = cleanFileName;
    if (type == ChatAttachmentType.audio &&
        (uploadFileName == null || uploadFileName.isEmpty)) {
      uploadFileName = 'voice_${message.time}.m4a';
    }

    if (type == ChatAttachmentType.image &&
        (uploadFileName == null || uploadFileName.isEmpty)) {
      uploadFileName = 'image_${message.time}.jpg';
    }

    File? localFile;
    final localPath = message.localFilePath?.trim() ?? '';
    final hasUploadedMain = message.storagePath?.trim().isNotEmpty == true;

    if (!hasUploadedMain) {
      if (localPath.isEmpty) {
        throw ChatOperationException(
          'chat.errors.retry_missing_local_file',
          code: 'missing-local-file',
          retryable: false,
        );
      }

      localFile = File(localPath);
      if (!await localFile.exists() || await localFile.length() == 0) {
        throw ChatOperationException(
          'chat.errors.retry_local_file_not_found',
          code: 'local-file-not-found',
          retryable: false,
        );
      }

      if (type == ChatAttachmentType.audio &&
          !await _waitForStableLocalFile(localFile)) {
        throw ChatOperationException(
          'chat.errors.voice_prepare_failed',
          code: 'voice-prepare-failed',
          retryable: false,
        );
      }
    }

    File? videoThumbnailFile;
    UploadedFileInfo? uploadedThumbnail;
    UploadedFileInfo? uploadedMain;
    var lastProgressValue = message.uploadProgress <= 0 ? -1.0 : message.uploadProgress;
    var lastProgressEmitMs = 0;

    void emitUploadProgress(double progress, {bool force = false}) {
      final clamped = progress.clamp(0, 1).toDouble();
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final changedEnough =
          lastProgressValue < 0 || (clamped - lastProgressValue).abs() >= 0.02;
      final waitedEnough = nowMs - lastProgressEmitMs >= 100;

      if (!force && !changedEnough && !waitedEnough) return;

      final current = _pendingById(message.id);
      if (current == null || current.isFailed) return;

      lastProgressValue = clamped;
      lastProgressEmitMs = nowMs;
      _upsertPending(current.copyWith(uploadProgress: clamped));
    }

    try {
      if (!hasUploadedMain) {
        if (type == ChatAttachmentType.video) {
          final hasUploadedThumbnail = message.videoThumbnailPath?.trim().isNotEmpty == true;
          if (!hasUploadedThumbnail && localFile != null) {
            videoThumbnailFile = await _createVideoThumbnail(localFile);
            final current = _pendingById(message.id);
            if (videoThumbnailFile != null && current != null && !current.isFailed) {
              final updated = current.copyWith(
                localThumbnailPath: videoThumbnailFile.path,
              );
              _rememberLocalAttachmentPreview(updated);
              _upsertPending(updated);
              message = updated;
            }
          }
        }

        if (videoThumbnailFile != null) {
          try {
            uploadedThumbnail = await _groupRepository.uploadFile(
              groupId: groupId,
              file: videoThumbnailFile,
              folder: AppStorageFolders.chatVideoThumbnails,
              fileName: 'thumbnail.jpg',
              createDownloadUrl: false,
              onProgress: (progress) => emitUploadProgress(progress * 0.2),
            );
            emitUploadProgress(0.2, force: true);
          } catch (error) {
            if (kDebugMode) {
              debugPrint('Video thumbnail upload failed: $error');
            }
            uploadedThumbnail = null;
          }
        }

        uploadedMain = await _groupRepository.uploadFile(
          groupId: groupId,
          file: localFile!,
          folder: type.folder,
          fileName: uploadFileName,
          createDownloadUrl: false,
          onProgress: (progress) {
            final normalizedProgress =
                type == ChatAttachmentType.video && uploadedThumbnail != null
                    ? 0.2 + (progress * 0.8)
                    : progress;

            emitUploadProgress(normalizedProgress);
          },
        );
        emitUploadProgress(1, force: true);

        final uploadedPending = _pendingById(message.id);
        if (uploadedPending != null && !uploadedPending.isFailed) {
          final updatedPending = uploadedPending.copyWith(
            storagePath: uploadedMain.storagePath,
            videoThumbnailPath: uploadedThumbnail?.storagePath,
            audioDurationMs: type == ChatAttachmentType.audio
                ? originalMessage.audioDurationMs ?? uploadedPending.audioDurationMs
                : uploadedPending.audioDurationMs,
            uploadProgress: 1,
          );
          _rememberLocalAttachmentPreview(updatedPending);
          _upsertPending(updatedPending);
          message = updatedPending;
        }
      }

      var currentForSend = _pendingById(message.id) ?? message;
      final freshForSend = _withFreshSendTimeIfNeeded(currentForSend);
      if (freshForSend.time != currentForSend.time) {
        currentForSend = currentForSend.copyWith(time: freshForSend.time);
        _upsertPending(currentForSend);
      }

      final storagePath = currentForSend.storagePath?.trim() ?? '';
      if (storagePath.isEmpty) {
        throw ChatOperationException(
          'attachments.upload_failed',
          code: 'missing-storage-path',
          retryable: true,
        );
      }

      await _groupRepository.sendMessage(
        groupId: groupId,
        messageId: currentForSend.id,
        data: {
          ..._basePayloadFromPending(currentForSend),
          'message': type.fallbackMessage(cleanFileName),
          'type': type.value,
          'storagePath': storagePath,
          if (currentForSend.videoThumbnailPath?.trim().isNotEmpty == true)
            'videoThumbnailPath': currentForSend.videoThumbnailPath!.trim(),
          if (cleanFileName != null && cleanFileName.isNotEmpty)
            'fileName': cleanFileName,
          if (type == ChatAttachmentType.audio &&
              currentForSend.audioDurationMs != null)
            'audioDurationMs': currentForSend.audioDurationMs,
        },
      );
    } catch (error) {
      if (!_isRetryableSendError(error)) {
        final current = _pendingById(message.id);
        if (current != null) {
          final failed = current.copyWith(
            isFailed: true,
            isLocalPending: false,
            hasPendingWrites: false,
            uploadProgress: 0,
          );
          _rememberLocalAttachmentPreview(failed);
          _upsertPending(failed);
        }
      }

      rethrow;
    } finally {
      final thumbnailToDelete = videoThumbnailFile;
      if (thumbnailToDelete != null) {
        // Keep the local thumbnail briefly after the Firestore message replaces
        // the local pending bubble. This prevents video bubbles from flashing to
        // an empty placeholder while the storagePath URL is being resolved.
        unawaited(
          Future<void>.delayed(const Duration(minutes: 5)).then(
            (_) => _deleteLocalFileQuietly(thumbnailToDelete),
          ),
        );
      }
    }
  }
}
