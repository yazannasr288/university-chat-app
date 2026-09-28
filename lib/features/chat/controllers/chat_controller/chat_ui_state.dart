part of '../chat_controller.dart';

@immutable
class ChatRecordingUiState {
  final bool isRecording;
  final bool isCancelled;
  final Duration duration;
  final double level;

  const ChatRecordingUiState({
    this.isRecording = false,
    this.isCancelled = false,
    this.duration = Duration.zero,
    this.level = 0.08,
  });

  static const idle = ChatRecordingUiState();

  ChatRecordingUiState copyWith({
    bool? isRecording,
    bool? isCancelled,
    Duration? duration,
    double? level,
  }) {
    return ChatRecordingUiState(
      isRecording: isRecording ?? this.isRecording,
      isCancelled: isCancelled ?? this.isCancelled,
      duration: duration ?? this.duration,
      level: level ?? this.level,
    );
  }
}

@immutable
class ChatShellUiState {
  final bool initialGroupLoaded;
  final GroupModel? group;
  final String? errorMessage;
  final String? warningMessage;

  const ChatShellUiState({
    this.initialGroupLoaded = false,
    this.group,
    this.errorMessage,
    this.warningMessage,
  });
}

@immutable
class ChatMessagesUiState {
  final int revision;
  final bool initialMessagesLoaded;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> latestDocs;
  final List<ChatMessage> pendingMessages;
  final List<ChatMessage> cachedMessages;
  final int initialLastReadMessageTime;

  const ChatMessagesUiState({
    this.revision = 0,
    this.initialMessagesLoaded = false,
    this.latestDocs = const <QueryDocumentSnapshot<Map<String, dynamic>>>[],
    this.pendingMessages = const <ChatMessage>[],
    this.cachedMessages = const <ChatMessage>[],
    this.initialLastReadMessageTime = 0,
  });

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ChatMessagesUiState &&
            other.revision == revision &&
            other.initialMessagesLoaded == initialMessagesLoaded &&
            other.initialLastReadMessageTime == initialLastReadMessageTime;
  }

  @override
  int get hashCode => Object.hash(
        revision,
        initialMessagesLoaded,
        initialLastReadMessageTime,
      );
}

@immutable
class ChatComposerUiState {
  final ChatMessage? replyingToMessage;

  const ChatComposerUiState({this.replyingToMessage});

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ChatComposerUiState &&
            other.replyingToMessage?.id == replyingToMessage?.id;
  }

  @override
  int get hashCode => replyingToMessage?.id.hashCode ?? 0;
}
