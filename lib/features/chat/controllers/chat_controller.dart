import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart' as path_provider;

import '../../../core/permissions/app_role_permissions.dart';
import '../../../core/constants/app_group_write_permissions.dart';
import '../../../core/constants/app_group_audiences.dart';
import '../../../core/constants/app_storage_folders.dart';
import '../../../core/utils/chat_operation_exception.dart';
import '../../../data/models/chat_message.dart';
import '../../../data/models/group_model.dart';
import '../../../data/models/group_member_state.dart';
import '../../../data/repositories/chat_cache_repository.dart';
import '../../../data/repositories/group_repository.dart';

part 'chat_controller/chat_attachment_type.dart';
part 'chat_controller/chat_ui_state.dart';
part 'chat_controller/pending_message_helpers.dart';
part 'chat_controller/attachment_helpers.dart';
part 'chat_controller/recording_helpers.dart';
part 'chat_controller/send_attachment.dart';
part 'chat_controller/ui_state_sync.dart';
part 'chat_controller/message_actions.dart';
part 'chat_controller/recording_actions.dart';

class ChatController extends ChangeNotifier {
  final String groupId;
  final String userName;
  final GroupRepository _groupRepository;
  final ChatCacheRepository _chatCacheRepository;

  final TextEditingController messageController = TextEditingController();
  final AudioRecorder recorder = AudioRecorder();

  StreamSubscription? _messagesSub;
  StreamSubscription? _memberStatesSub;
  StreamSubscription? _groupSub;
  late final Future<void> _initialReadStateFuture;
  Completer<void>? _memberStatesFirstLoadCompleter;

  List<ChatMessage> _liveMessages = [];
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _latestDocs = [];
  List<GroupMemberState> _memberStates = [];
  GroupModel? _currentGroup;

  bool _initialMessagesLoaded = false;
  bool _initialGroupLoaded = false;

  List<ChatMessage> get liveMessages => _liveMessages;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> get latestDocs =>
      _latestDocs;
  List<GroupMemberState> get memberStates => _memberStates;
  GroupModel? get currentGroup => _currentGroup;
  bool get initialMessagesLoaded => _initialMessagesLoaded;
  bool get initialGroupLoaded => _initialGroupLoaded;

  bool isRecording = false;
  bool isCancelled = false;
  Duration recordingDuration = Duration.zero;
  double recordingLevel = 0.08;
  final ValueNotifier<ChatRecordingUiState> recordingUiState =
      ValueNotifier<ChatRecordingUiState>(ChatRecordingUiState.idle);
  final ValueNotifier<ChatShellUiState> chatShellUiState =
      ValueNotifier<ChatShellUiState>(const ChatShellUiState());
  final ValueNotifier<ChatMessagesUiState> chatMessagesUiState =
      ValueNotifier<ChatMessagesUiState>(const ChatMessagesUiState());
  final ValueNotifier<ChatComposerUiState> chatComposerUiState =
      ValueNotifier<ChatComposerUiState>(const ChatComposerUiState());
  bool _hasActiveRecording = false;
  String? _activeRecordingPath;
  Offset? _startDragPosition;
  PermissionStatus? _microphonePermissionStatus;
  DateTime? _recordingStartedAt;
  Timer? _recordingTimer;
  StreamSubscription<Amplitude>? _amplitudeSub;
  int _lastCompletedRecordingDurationMs = 0;

  int get lastCompletedRecordingDurationMs => _lastCompletedRecordingDurationMs;

  static const int _maxLocalAttachmentPreviews = 80;

  final List<ChatMessage> _pendingMessages = [];
  final Map<String, ChatMessage> _localAttachmentPreviews = {};
  List<ChatMessage> _cachedMessages = const [];
  ChatMessage? _replyingToMessage;
  int _initialLastReadMessageTime = 0;
  int _lastMarkedReadMessageTime = 0;
  int _lastReadUpdateTimestamp = 0;
  int _lastGeneratedMessageTime = 0;
  bool _disposed = false;
  int _messagesRevision = 0;
  String? _chatStreamErrorMessage;
  String? _chatStreamWarningMessage;
  Timer? _pendingRetryTimer;
  Timer? _pendingPersistTimer;
  Timer? _readReceiptTimer;
  int _pendingReadMessageTime = 0;
  int _readReceiptRetryNotBefore = 0;
  bool _readReceiptInFlight = false;
  final Set<String> _pendingSendInFlight = <String>{};
  Future<void> _messageCacheWriteQueue = Future<void>.value();

  String? get chatStreamErrorMessage => _chatStreamErrorMessage;
  ChatMessage? get replyingToMessage => _replyingToMessage;
  int get initialLastReadMessageTime => _initialLastReadMessageTime;

  bool _isTransientChatStreamError(Object error) {
    if (error is FirebaseException || error is FirebaseFunctionsException) {
      final code =
          error is FirebaseException
              ? error.code
              : (error as FirebaseFunctionsException).code;
      return code == 'unavailable' ||
          code == 'deadline-exceeded' ||
          code == 'aborted' ||
          code == 'cancelled' ||
          code == 'resource-exhausted' ||
          code == 'internal' ||
          code == 'unknown';
    }

    return false;
  }

  String _mapChatStreamError(Object error) {
    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return tr('chat.errors.access_lost');
        case 'unavailable':
        case 'deadline-exceeded':
          return tr('chat.errors.connection_failed');
      }
    }

    return tr('chat.errors.load_failed');
  }

  void _handleChatStreamError(
    Object error,
    StackTrace stackTrace, {
    bool markGroupLoaded = false,
    bool markMessagesLoaded = false,
  }) {
    if (kDebugMode) {
      debugPrint('Chat stream error: $error');
      debugPrintStack(stackTrace: stackTrace);
    }

    final mappedMessage = _mapChatStreamError(error);
    final transient = _isTransientChatStreamError(error);
    final hasUsableState =
        _currentGroup != null ||
        _initialGroupLoaded ||
        _initialMessagesLoaded ||
        _cachedMessages.isNotEmpty ||
        _liveMessages.isNotEmpty;

    if (transient && hasUsableState) {
      _chatStreamWarningMessage = mappedMessage;
    } else {
      _chatStreamErrorMessage = mappedMessage;
      _chatStreamWarningMessage = null;
    }

    if (markGroupLoaded) _initialGroupLoaded = true;
    if (markMessagesLoaded) _initialMessagesLoaded = true;

    _syncChatShellUi();
    if (markMessagesLoaded) {
      _notifyMessagesChanged();
    } else {
      _notifyListeners();
    }
  }

  ChatController({
    required this.groupId,
    required this.userName,
    GroupRepository? repo,
    ChatCacheRepository? chatCacheRepository,
  }) : _groupRepository = repo ?? GroupRepository(),
       _chatCacheRepository = chatCacheRepository ?? ChatCacheRepository() {
    _initialReadStateFuture = _loadInitialReadState();

    _groupSub = _groupRepository
        .groupStream(groupId)
        .listen(
          (snapshot) {
            final data = snapshot.data();
            if (data != null) {
              _currentGroup = GroupModel.fromMap(data);
            }

            _chatStreamErrorMessage = null;
            _chatStreamWarningMessage = null;
            _initialGroupLoaded = true;
            _syncChatShellUi();
          },
          onError: (Object error, StackTrace stackTrace) {
            _handleChatStreamError(error, stackTrace, markGroupLoaded: true);
          },
        );

    _messagesSub = _groupRepository
        .messagesStream(groupId)
        .listen(
          (snapshot) {
            _latestDocs = snapshot.docs;
            _liveMessages =
                snapshot.docs.map((doc) {
                  return withLocalAttachmentPreview(
                    ChatMessage.fromMap(
                      doc.id,
                      doc.data(),
                      hasPendingWrites: doc.metadata.hasPendingWrites,
                    ),
                  );
                }).toList();
            _chatStreamErrorMessage = null;
            _chatStreamWarningMessage = null;
            _initialMessagesLoaded = true;
            unawaited(_applyLiveMessageSideEffects(_liveMessages));
            _notifyMessagesChanged();
          },
          onError: (Object error, StackTrace stackTrace) {
            _handleChatStreamError(error, stackTrace, markMessagesLoaded: true);
          },
        );

    unawaited(_restorePendingMessages());
  }

  String get currentUid {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('chat.errors.no_signed_in_user');
    }
    return user.uid;
  }

  Future<void> _loadInitialReadState() async {
    try {
      final snapshot = await _groupRepository.userGroupSummary(
        uid: currentUid,
        groupId: groupId,
      );
      final data = snapshot.data();
      final readTime =
          int.tryParse(data?['lastReadMessageTime']?.toString() ?? '0') ?? 0;
      var changed = false;
      if (readTime > _initialLastReadMessageTime) {
        _initialLastReadMessageTime = readTime;
        changed = true;
      }
      _lastMarkedReadMessageTime = _initialLastReadMessageTime;
      if (changed) _notifyMessagesChanged();
    } catch (error) {
      if (kDebugMode) debugPrint('Initial chat read state load failed: $error');
      // If the summary is temporarily unavailable, the chat remains usable.
    }
  }

  Future<void> _applyLiveMessageSideEffects(List<ChatMessage> messages) async {
    if (messages.isEmpty) return;

    _messageCacheWriteQueue = _messageCacheWriteQueue
        .then((_) => cacheMessages(messages))
        .catchError((Object error) {
          if (kDebugMode) debugPrint('Chat message cache save failed: $error');
        });
    dropSyncedPendingMessages(messages);

    await _initialReadStateFuture;
    if (_disposed) return;

    markVisibleMessagesRead(messages);
  }

  void startReply(ChatMessage message) {
    if (message.isLocalPending || message.isFailed) return;
    _replyingToMessage = message;
    _notifyComposerListeners();
  }

  void clearReply() {
    if (_replyingToMessage == null) return;
    _replyingToMessage = null;
    _notifyComposerListeners();
  }

  String replyPreviewFor(ChatMessage message) {
    final text = message.message.trim();
    switch (message.type) {
      case 'text':
        return text;
      case 'poll':
        return message.pollQuestion.trim().isNotEmpty
            ? message.pollQuestion.trim()
            : text;
      case 'image':
        return text.isNotEmpty ? text : tr('chat.attachment.image');
      case 'video':
        return text.isNotEmpty ? text : tr('chat.attachment.video');
      case 'audio':
        return text.isNotEmpty ? text : tr('chat.attachment.voice_message');
      case 'file':
        return message.fileName?.trim().isNotEmpty == true
            ? message.fileName!.trim()
            : (text.isNotEmpty ? text : tr('chat.attachment.file'));
      case 'event':
        return text.isNotEmpty ? text : tr('events.title');
      default:
        return text.isNotEmpty ? text : tr('chat.attachment.message');
    }
  }

  List<ChatMessage> get pendingMessages => List.unmodifiable(_pendingMessages);
  List<ChatMessage> get cachedMessages => _cachedMessages;

  Future<void> ensureMemberStatesLoaded() {
    if (_memberStatesSub != null) {
      return _memberStatesFirstLoadCompleter?.future ?? Future<void>.value();
    }

    final completer = Completer<void>();
    _memberStatesFirstLoadCompleter = completer;

    _memberStatesSub = _groupRepository
        .memberStatesStream(groupId)
        .listen(
          (snapshot) {
            _memberStates = snapshot.docs
                .map((doc) {
                  return GroupMemberState.fromMap(doc.id, doc.data());
                })
                .toList(growable: false);

            if (!completer.isCompleted) completer.complete();
          },
          onError: (Object error, StackTrace stackTrace) {
            if (kDebugMode) {
              debugPrint('Chat member states stream error: $error');
              debugPrintStack(stackTrace: stackTrace);
            }
            if (!completer.isCompleted) {
              completer.completeError(error, stackTrace);
            }
            _memberStatesFirstLoadCompleter = null;
          },
        );

    return completer.future;
  }

  void releaseMemberStatesSubscription() {
    _memberStatesSub?.cancel();
    _memberStatesSub = null;
    _memberStatesFirstLoadCompleter = null;
  }

  void _notifyMessagesChanged() {
    if (_disposed) return;
    _messagesRevision++;
    _syncChatMessagesUi();
    notifyListeners();
  }

  void _notifyComposerListeners() {
    if (_disposed) return;
    _syncComposerUi();
    notifyListeners();
  }

  void _notifyListeners() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    unawaited(
      _persistPendingMessagesNow().catchError((Object error) {
        if (kDebugMode) {
          debugPrint('Pending message cache final save failed: $error');
        }
      }),
    );
    _disposed = true;
    _messagesSub?.cancel();
    _pendingRetryTimer?.cancel();
    _pendingPersistTimer?.cancel();
    _readReceiptTimer?.cancel();
    _memberStatesSub?.cancel();
    _groupSub?.cancel();
    _stopRecordingMeters();
    messageController.dispose();
    recorder.dispose();
    recordingUiState.dispose();
    chatShellUiState.dispose();
    chatMessagesUiState.dispose();
    chatComposerUiState.dispose();
    super.dispose();
  }
}
