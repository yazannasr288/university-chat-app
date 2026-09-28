part of '../chat_controller.dart';

extension ChatMessageActions on ChatController {
  Future<void> loadCachedMessages() async {
    try {
      _cachedMessages = await _chatCacheRepository.loadMessages(groupId);
      _notifyMessagesChanged();
    } catch (error) {
      if (kDebugMode) debugPrint('Chat message cache load failed: $error');
    }
  }

  Future<void> cacheMessages(List<ChatMessage> messages) {
    return _chatCacheRepository.saveMessages(groupId, messages);
  }

  Future<bool> markGroupRead({int? lastReadMessageTime}) async {
    if (lastReadMessageTime == null && _currentGroup != null) {
      _currentGroup = _currentGroup!.copyWith(unreadCount: 0);
      _syncChatShellUi();
    }

    try {
      await _groupRepository.markGroupRead(
        groupId,
        lastReadMessageTime: lastReadMessageTime,
      );
      return true;
    } catch (error) {
      if (kDebugMode) debugPrint('Mark group read failed: $error');
      // Keep the conversation accessible if the read counter reset fails temporarily.
      return false;
    }
  }

  void markVisibleMessagesRead(List<ChatMessage> messages) {
    if (messages.isEmpty) return;

    final latestTime = messages
        .map((message) => message.time)
        .fold<int>(0, (previous, value) => value > previous ? value : previous);

    if (latestTime <= 0 || latestTime <= _lastMarkedReadMessageTime) return;

    if (latestTime > _pendingReadMessageTime) {
      _pendingReadMessageTime = latestTime;
    }
    _scheduleReadReceipt();
  }

  void _scheduleReadReceipt() {
    if (_disposed || _readReceiptInFlight) return;
    if (_pendingReadMessageTime <= _lastMarkedReadMessageTime) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final elapsed = now - _lastReadUpdateTimestamp;
    final throttleDelay = 2000 - elapsed;
    final retryDelay = _readReceiptRetryNotBefore - now;
    final delayMilliseconds = throttleDelay > retryDelay
        ? throttleDelay
        : retryDelay;

    _readReceiptTimer?.cancel();
    if (delayMilliseconds <= 0) {
      unawaited(_flushReadReceipt());
      return;
    }

    _readReceiptTimer = Timer(
      Duration(milliseconds: delayMilliseconds),
      _flushReadReceipt,
    );
  }

  Future<void> _flushReadReceipt() async {
    _readReceiptTimer?.cancel();
    _readReceiptTimer = null;
    if (_disposed || _readReceiptInFlight) return;

    final latestTime = _pendingReadMessageTime;
    if (latestTime <= _lastMarkedReadMessageTime) return;

    _readReceiptInFlight = true;
    final succeeded = await markGroupRead(lastReadMessageTime: latestTime);
    _readReceiptInFlight = false;
    if (_disposed) return;

    if (succeeded) {
      _lastMarkedReadMessageTime = latestTime;
      _lastReadUpdateTimestamp = DateTime.now().millisecondsSinceEpoch;
      _readReceiptRetryNotBefore = 0;
    } else {
      _readReceiptRetryNotBefore =
          DateTime.now().add(const Duration(seconds: 10)).millisecondsSinceEpoch;
    }

    if (_pendingReadMessageTime > _lastMarkedReadMessageTime) {
      _scheduleReadReceipt();
    }
  }

  Future<void> sendText() async {
    final text = messageController.text.trim();
    if (text.isEmpty) return;
    if (text.length > 4000) {
      throw Exception('chat.errors.message_too_long');
    }

    final now = _nextClientMessageTime();
    final pendingId = 'local_text_${now}_${DateTime.now().microsecondsSinceEpoch}';
    final reply = replyingToMessage;
    final replyText = reply == null ? '' : replyPreviewFor(reply).trim();

    final pendingMessage = ChatMessage(
      id: pendingId,
      type: 'text',
      message: text,
      sender: userName,
      senderId: currentUid,
      time: now,
      replyToMessageId: reply?.id,
      replyToText: replyText.isEmpty
          ? null
          : (replyText.length > 180 ? '${replyText.substring(0, 180)}…' : replyText),
      replyToSender: reply?.sender,
      replyToType: reply?.type,
      isLocalPending: true,
      nextRetryAt: DateTime.now().millisecondsSinceEpoch,
    );

    messageController.clear();
    clearReply();
    _upsertPending(pendingMessage);
    unawaited(_processPendingMessage(pendingId));
  }

  Future<void> sendPoll({
    required String question,
    required List<String> options,
    required int expiresAt,
  }) async {
    final cleanQuestion = question.trim();
    final cleanOptions = options.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

    if (cleanQuestion.isEmpty || cleanQuestion.length > 120) {
      throw Exception('chat.errors.poll_question_too_long');
    }
    if (cleanOptions.length < 2 || cleanOptions.length > 6) {
      throw Exception('chat.errors.poll_options_range');
    }
    if (cleanOptions.any((option) => option.length > 80)) {
      throw Exception('chat.errors.poll_option_too_long');
    }

    final now = _nextClientMessageTime();
    final pendingId = 'local_poll_${now}_${DateTime.now().microsecondsSinceEpoch}';
    final reply = replyingToMessage;
    final replyText = reply == null ? '' : replyPreviewFor(reply).trim();

    final pendingMessage = ChatMessage(
      id: pendingId,
      type: 'poll',
      message: cleanQuestion,
      sender: userName,
      senderId: currentUid,
      time: now,
      pollQuestion: cleanQuestion,
      pollOptions: cleanOptions,
      pollExpiresAt: expiresAt,
      pollIsClosed: false,
      replyToMessageId: reply?.id,
      replyToText: replyText.isEmpty
          ? null
          : (replyText.length > 180 ? '${replyText.substring(0, 180)}…' : replyText),
      replyToSender: reply?.sender,
      replyToType: reply?.type,
      isLocalPending: true,
      nextRetryAt: DateTime.now().millisecondsSinceEpoch,
    );

    clearReply();
    _upsertPending(pendingMessage);
    unawaited(_processPendingMessage(pendingId));
  }

  Future<void> _processPendingMessage(String id) async {
    var message = _pendingById(id);
    if (message == null || message.isFailed || _pendingSendInFlight.contains(id)) {
      return;
    }

    _pendingSendInFlight.add(id);

    try {
      message = _withFreshSendTimeIfNeeded(message);
      final current = _pendingById(id);
      if (current == null || current.isFailed) return;
      if (message.time != current.time) {
        _upsertPending(current.copyWith(time: message.time));
      }

      switch (message.type) {
        case 'text':
          await _submitPendingText(message);
          break;
        case 'poll':
          await _submitPendingPoll(message);
          break;
        case 'image':
        case 'video':
        case 'audio':
        case 'file':
          await _submitPendingAttachment(message);
          break;
        default:
          throw ChatOperationException(
            'chat.errors.retry_unsupported_type',
            code: 'unsupported-type',
            retryable: false,
          );
      }

      final sentPending = _pendingById(id);
      if (sentPending != null && !sentPending.isFailed) {
        _upsertPending(
          sentPending.copyWith(
            isLocalPending: false,
            hasPendingWrites: true,
            isFailed: false,
            uploadProgress: sentPending.uploadProgress >= 1 ? sentPending.uploadProgress : 1,
            retryAttempt: 0,
            nextRetryAt: 0,
          ),
        );
      }
    } catch (error) {
      if (kDebugMode) debugPrint('Pending message send failed ($id): $error');
      _markPendingForAutoRetry(id, error);
    } finally {
      _pendingSendInFlight.remove(id);
      _schedulePendingRetrySweep();
    }
  }

  Future<void> _submitPendingText(ChatMessage message) async {
    await _groupRepository.sendMessage(
      groupId: groupId,
      messageId: message.id,
      data: {
        ..._basePayloadFromPending(message),
        'message': message.message.trim(),
        'type': 'text',
      },
    );
  }

  Future<void> _submitPendingPoll(ChatMessage message) async {
    await _groupRepository.sendMessage(
      groupId: groupId,
      messageId: message.id,
      data: {
        ..._basePayloadFromPending(message),
        'message': message.pollQuestion.trim().isNotEmpty
            ? message.pollQuestion.trim()
            : message.message.trim(),
        'type': 'poll',
        'pollQuestion': message.pollQuestion.trim().isNotEmpty
            ? message.pollQuestion.trim()
            : message.message.trim(),
        'pollOptions': message.pollOptions,
        'pollExpiresAt': message.pollExpiresAt,
        'pollIsClosed': message.pollIsClosed,
        'pollTotalVotes': 0,
      },
    );
  }

  void dropSyncedPendingMessages(List<ChatMessage> liveMessages) {
    if (_pendingMessages.isEmpty || liveMessages.isEmpty) return;

    final liveIds = liveMessages.map((message) => message.id).toSet();
    final before = _pendingMessages.length;

    // If Firestore already contains the same message id, the local pending
    // bubble must disappear even if a previous retry marked it as failed.
    // This avoids the confusing state where a voice note appears sent and
    // failed at the same time.
    _pendingMessages.removeWhere((message) {
      final shouldRemove = liveIds.contains(message.id);
      if (shouldRemove) _pendingSendInFlight.remove(message.id);
      return shouldRemove;
    });

    if (_pendingMessages.length != before) {
      _persistPendingMessagesDebounced();
      _notifyMessagesChanged();
    }
  }

  Future<void> retryPendingMessage(String id) async {
    final message = _pendingById(id);
    if (message == null || !message.isFailed) return;

    _upsertPending(
      message.copyWith(
        isFailed: false,
        isLocalPending: true,
        hasPendingWrites: false,
        retryAttempt: 0,
        nextRetryAt: DateTime.now().millisecondsSinceEpoch,
        uploadProgress: _isAttachmentMessage(message) &&
                message.storagePath?.trim().isNotEmpty != true
            ? 0
            : message.uploadProgress,
      ),
    );

    await _processPendingMessage(id);
  }

  Future<void> discardPendingMessage(String id) async {
    final message = _pendingById(id);
    if (message == null) return;

    _removePending(id);
    _forgetLocalAttachmentPreview(id);

    if (_isAttachmentMessage(message)) {
      final storagePath = message.storagePath?.trim();
      if (storagePath != null && storagePath.isNotEmpty) {
        unawaited(_groupRepository.deleteStorageFile(storagePath, groupId: groupId));
      }
    }

    if (message.type == ChatAttachmentType.audio.value) {
      final path = message.localFilePath?.trim();
      if (path != null && path.isNotEmpty) {
        await _deleteLocalFileQuietly(File(path));
      }
    }
  }

  Future<QuerySnapshot<Map<String, dynamic>>> loadOlderMessages(
    DocumentSnapshot<Map<String, dynamic>> afterDoc,
  ) {
    return _groupRepository.loadOlderMessages(
      groupId: groupId,
      afterDoc: afterDoc,
    );
  }

  Future<QuerySnapshot<Map<String, dynamic>>> loadMessagesPage({
    DocumentSnapshot<Map<String, dynamic>>? afterDoc,
    int limit = 30,
  }) {
    return _groupRepository.loadMessagesPage(
      groupId: groupId,
      afterDoc: afterDoc,
      limit: limit,
    );
  }

  Future<void> deleteMessage(String messageId) async {
    await _groupRepository.deleteMessage(
      groupId: groupId,
      messageId: messageId,
    );
  }

  Future<List<GroupModel>> forwardableGroups({
    required String userRole,
    required String accountType,
    String currentDepartment = '',
  }) {
    return _groupRepository.listForwardableGroups(
      uid: currentUid,
      role: userRole,
      accountType: accountType,
      currentGroupId: groupId,
      currentDepartment: currentDepartment,
    );
  }

  Future<void> forwardMessage({
    required ChatMessage message,
    required GroupModel targetGroup,
  }) async {
    if (message.isLocalPending || message.isFailed || message.id.trim().isEmpty) {
      throw Exception('chat.errors.forward_unavailable');
    }

    await _groupRepository.forwardMessage(
      sourceGroupId: groupId,
      targetGroupId: targetGroup.groupId,
      messageId: message.id,
    );
  }

  Future<void> saveMessage(ChatMessage message) async {
    if (message.isLocalPending || message.isFailed || message.id.trim().isEmpty) {
      throw Exception('chat.errors.save_unavailable');
    }

    final groupName = _currentGroup?.groupName.trim().isNotEmpty == true
        ? _currentGroup!.groupName.trim()
        : groupId;

    await _groupRepository.saveMessage(
      groupId: groupId,
      groupName: groupName,
      message: message,
    );
  }

  bool canSend(
    GroupModel group,
    String userRole, {
    required String accountType,
    String currentDepartment = '',
  }) {
    if (!group.isActive) return false;

    final groupName = group.groupName.trim();
    if (groupName == 'main_wpu') {
      return AppRolePermissions.isSystemAdminRole(userRole);
    }
    if (!AppGroupAudiences.canAccess(
      audience: group.audience,
      role: userRole,
      accountType: accountType,
      userDepartment: currentDepartment,
      groupDepartment: group.department,
    )) {
      return false;
    }
    if (AppGroupAudiences.isMemberCollaboration(group.audience)) {
      if (AppGroupWritePermissions.isOpen(group.writePermission)) return true;

      return AppGroupWritePermissions.isAdminsOnly(group.writePermission) &&
          AppRolePermissions.canSendToRestrictedGroup(
            currentUid: currentUid,
            groupAdminId: group.adminId,
            groupAdminIds: group.adminIds,
            role: userRole,
          );
    }
    if (groupName.startsWith('main_')) {
      return AppRolePermissions.isSystemAdminRole(userRole) ||
          ((AppRolePermissions.isDeanRole(userRole) ||
                  AppRolePermissions.isDepartmentStaffRole(userRole)) &&
              currentDepartment.trim().isNotEmpty &&
              currentDepartment.trim() == group.department.trim());
    }

    if (AppGroupWritePermissions.isOpen(group.writePermission)) return true;

    return AppGroupWritePermissions.isAdminsOnly(group.writePermission) &&
        AppRolePermissions.canSendToRestrictedGroup(
          currentUid: currentUid,
          groupAdminId: group.adminId,
          groupAdminIds: group.adminIds,
          role: userRole,
        );
  }
}
