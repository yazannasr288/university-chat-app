part of '../chat_controller.dart';

extension ChatUiStateSync on ChatController {
  void _syncRecordingUi() {
    if (_disposed) return;

    recordingUiState.value = ChatRecordingUiState(
      isRecording: isRecording,
      isCancelled: isCancelled,
      duration: recordingDuration,
      level: recordingLevel,
    );
  }

  bool _sameStringList(List<String> a, List<String> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;

    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }

    return true;
  }

  bool _sameChatShellGroup(GroupModel? a, GroupModel? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null) return false;

    return a.groupId == b.groupId &&
        a.groupName == b.groupName &&
        a.groupIcon == b.groupIcon &&
        a.adminId == b.adminId &&
        a.adminName == b.adminName &&
        a.department == b.department &&
        a.audience == b.audience &&
        a.writePermission == b.writePermission &&
        a.isActive == b.isActive &&
        _sameStringList(a.adminIds, b.adminIds) &&
        _sameStringList(a.memberIds, b.memberIds);
  }

  void _syncChatShellUi() {
    if (_disposed) return;

    final previous = chatShellUiState.value;
    final next = ChatShellUiState(
      initialGroupLoaded: _initialGroupLoaded,
      group: _currentGroup,
      errorMessage: _chatStreamErrorMessage,
      warningMessage: _chatStreamWarningMessage,
    );

    if (previous.initialGroupLoaded == next.initialGroupLoaded &&
        previous.errorMessage == next.errorMessage &&
        previous.warningMessage == next.warningMessage &&
        _sameChatShellGroup(previous.group, next.group)) {
      return;
    }

    chatShellUiState.value = next;
  }

  void _syncChatMessagesUi() {
    if (_disposed) return;

    chatMessagesUiState.value = ChatMessagesUiState(
      revision: _messagesRevision,
      initialMessagesLoaded: _initialMessagesLoaded,
      latestDocs: List<QueryDocumentSnapshot<Map<String, dynamic>>>.unmodifiable(
        _latestDocs,
      ),
      pendingMessages: List<ChatMessage>.unmodifiable(_pendingMessages),
      cachedMessages: List<ChatMessage>.unmodifiable(_cachedMessages),
      initialLastReadMessageTime: _initialLastReadMessageTime,
    );
  }

  void _syncComposerUi() {
    if (_disposed) return;

    chatComposerUiState.value = ChatComposerUiState(
      replyingToMessage: _replyingToMessage,
    );
  }
}
