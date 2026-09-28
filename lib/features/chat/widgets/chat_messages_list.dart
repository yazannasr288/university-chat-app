import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../core/permissions/app_role_permissions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../../core/utils/local_file_exists_cache.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_loader.dart';
import '../../../core/widgets/app_motion_widgets.dart';
import '../../../core/widgets/app_shimmer.dart';
import '../../../core/widgets/app_status_chip.dart';
import '../../../data/models/chat_message.dart';
import '../../../data/models/message_receipt_summary.dart';
import '../../../services/chat_audio_player_service.dart';
import '../controllers/chat_controller.dart';
import 'chat_date_separator.dart';
import 'chat_scroll_date_badge.dart';
import 'message_tile.dart';

class ChatMessagesList extends StatefulWidget {
  final ChatController controller;
  final String userRole;
  final String groupAdminId;
  final List<String> groupAdminIds;
  final String? selectedMessageId;
  final VoidCallback? onClearSelection;
  final String searchQuery;
  final void Function(
    ChatMessage message,
    MessageReceiptSummary? receiptSummary,
    bool canDelete,
  )?
  onMessageSelected;

  const ChatMessagesList({
    super.key,
    required this.controller,
    required this.userRole,
    required this.groupAdminId,
    this.groupAdminIds = const <String>[],
    this.selectedMessageId,
    this.onClearSelection,
    this.searchQuery = '',
    this.onMessageSelected,
  });

  @override
  State<ChatMessagesList> createState() => _ChatMessagesListState();
}

class _ChatMessagesListState extends State<ChatMessagesList> {
  static const int _pageSize = 30;
  static const int _searchPageSize = 60;
  static const int _maxAutomaticSearchPages = 10;
  static const double _estimatedMessageExtent = 76;

  final ScrollController _scrollController = ScrollController();
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> _olderDocs = [];
  final Map<String, String> _dateLabelCache = <String, String>{};
  GlobalKey? _replyScrollTargetKey;
  String? _replyScrollTargetMessageId;

  int _olderDocsRevision = 0;
  int? _lastPreparedMessagesRevision;
  int? _lastPreparedOlderDocsRevision;
  bool? _lastPreparedInitialMessagesLoaded;
  String _lastPreparedSearchQuery = '';
  List<ChatMessage> _lastPreparedMessages = const <ChatMessage>[];
  List<ChatMessage>? _lastAudioQueueSourceMessages;
  Map<String, List<ChatAudioPlaybackItem>> _audioPlaybackQueuesById =
      const <String, List<ChatAudioPlaybackItem>>{};

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _latestDocs = [];
  DocumentSnapshot<Map<String, dynamic>>? _currentOldestDoc;

  bool _isLoadingMore = false;
  bool _loadMoreFailed = false;
  bool _hasMore = true;
  bool _isSearchingConversation = false;
  bool _conversationSearchCompleted = false;
  bool _conversationSearchFailed = false;
  int _conversationSearchSerial = 0;
  String _conversationSearchQuery = '';
  Timer? _conversationSearchDebounce;
  DocumentSnapshot<Map<String, dynamic>>? _conversationSearchAfterDoc;
  final Set<String> _conversationSearchScannedIds = <String>{};
  final Map<String, ChatMessage> _conversationSearchMatches =
      <String, ChatMessage>{};
  final ValueNotifier<bool> _showJumpToLatestNotifier =
  ValueNotifier<bool>(false);

  final ValueNotifier<_FloatingDateBadgeState> _floatingDateBadgeNotifier =
  ValueNotifier<_FloatingDateBadgeState>(
    const _FloatingDateBadgeState(label: '', visible: false),
  );
  String? _highlightedMessageId;
  Timer? _floatingDateHideTimer;
  Timer? _highlightTimer;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
  }

  @override
  void didUpdateWidget(covariant ChatMessagesList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _resetConversationSearch();
      _olderDocs.clear();
      _latestDocs = [];
      _currentOldestDoc = null;
      _olderDocsRevision++;
      _hasMore = true;
      _isLoadingMore = false;
      _loadMoreFailed = false;
      _lastPreparedMessagesRevision = null;
      _lastAudioQueueSourceMessages = null;
    } else if (_normalizedSearchText(oldWidget.searchQuery) !=
        _normalizedSearchText(widget.searchQuery)) {
      _handleSearchQueryChanged();
    }
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;

    final position = _scrollController.position;
    final shouldShowJumpToLatest = position.pixels > 360;

    if (_showJumpToLatestNotifier.value != shouldShowJumpToLatest) {
      _showJumpToLatestNotifier.value = shouldShowJumpToLatest;
    }

    if (widget.searchQuery.trim().isNotEmpty || _isLoadingMore || !_hasMore) {
      return;
    }

    if (position.pixels >= position.maxScrollExtent - 180) {
      _loadMore();
    }
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _shouldShowDateSeparator(List<ChatMessage> messages, int index) {
    final current = DateTime.fromMillisecondsSinceEpoch(messages[index].time);

    if (index == messages.length - 1) return true;

    final older = DateTime.fromMillisecondsSinceEpoch(messages[index + 1].time);
    return !_isSameDay(current, older);
  }

  String _dayKey(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${date.year}-${date.month}-${date.day}';
  }

  Key _separatorKeyFor(int timestamp) {
    return ValueKey<String>('date_separator_${_dayKey(timestamp)}');
  }

  String _dateSeparatorLabel(BuildContext context, int timestamp) {
    final locale = context.locale.toString();
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final cacheKey = '$locale:${now.year}-${now.month}-${now.day}:${_dayKey(timestamp)}';

    final cached = _dateLabelCache[cacheKey];
    if (cached != null) return cached;

    final today = DateTime(now.year, now.month, now.day);
    final messageDay = DateTime(date.year, date.month, date.day);
    final diffDays = today.difference(messageDay).inDays;

    final label = switch (diffDays) {
      0 => 'chat.today'.tr(),
      1 => 'chat.yesterday'.tr(),
      > 1 && < 7 => DateFormat.EEEE(locale).format(date),
      _ when date.year == now.year => DateFormat('d MMMM', locale).format(date),
      _ => DateFormat('d MMMM yyyy', locale).format(date),
    };

    _dateLabelCache[cacheKey] = label;
    while (_dateLabelCache.length > 80) {
      _dateLabelCache.remove(_dateLabelCache.keys.first);
    }

    return label;
  }

  String _estimatedFloatingDateLabel(List<ChatMessage> messages) {
    if (messages.isEmpty) return '';

    if (!_scrollController.hasClients) {
      return _dateSeparatorLabel(context, messages.first.time);
    }

    final estimatedIndex = (_scrollController.position.pixels /
            _estimatedMessageExtent)
        .round()
        .clamp(0, messages.length - 1);

    return _dateSeparatorLabel(context, messages[estimatedIndex].time);
  }

  String _visibleSeparatorDateLabel(List<ChatMessage> messages) {
    return _estimatedFloatingDateLabel(messages);
  }

  void _showDateBadgeWhileScrolling(List<ChatMessage> messages) {
    if (messages.isEmpty) return;

    final nextLabel = _visibleSeparatorDateLabel(messages);
    final current = _floatingDateBadgeNotifier.value;

    if (!current.visible || current.label != nextLabel) {
      _floatingDateBadgeNotifier.value = _FloatingDateBadgeState(
        label: nextLabel,
        visible: true,
      );
    }

    _floatingDateHideTimer?.cancel();
    _floatingDateHideTimer = Timer(const Duration(milliseconds: 950), () {
      if (!mounted) return;

      final latest = _floatingDateBadgeNotifier.value;
      if (!latest.visible) return;

      _floatingDateBadgeNotifier.value = latest.copyWith(visible: false);
    });
  }

  bool _handleScrollNotification(
    ScrollNotification notification,
    List<ChatMessage> messages,
  ) {
    if (notification.metrics.axis != Axis.vertical) return false;

    if (notification is ScrollStartNotification ||
        notification is ScrollUpdateNotification ||
        notification is OverscrollNotification) {
      _showDateBadgeWhileScrolling(messages);
    }

    if (notification is ScrollEndNotification) {
      _floatingDateHideTimer?.cancel();
      _floatingDateHideTimer = Timer(const Duration(milliseconds: 650), () {
        if (!mounted) return;

        final latest = _floatingDateBadgeNotifier.value;
        if (!latest.visible) return;

        _floatingDateBadgeNotifier.value = latest.copyWith(visible: false);
      });
    }

    return false;
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _mergeDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> latest,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> older,
  ) {
    final merged = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};

    for (final doc in [...latest, ...older]) {
      merged.putIfAbsent(doc.id, () => doc);
    }

    return merged.values.toList();
  }

  String _normalizedSearchText(String value) => value.trim().toLowerCase();

  String _messageSearchText(ChatMessage message) {
    return [
      message.message,
      message.sender,
      message.type,
      message.fileName ?? '',
      message.pollQuestion,
      ...message.pollOptions,
      message.replyToText ?? '',
      message.replyToSender ?? '',
    ].join(' ').toLowerCase();
  }

  int _docMessageTime(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    return int.tryParse(doc.data()['time']?.toString() ?? '0') ?? 0;
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _sortDocsByTimeDesc(
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final sorted = docs.toList(growable: false);
    sorted.sort((a, b) {
      final byTime = _docMessageTime(b).compareTo(_docMessageTime(a));
      if (byTime != 0) return byTime;
      return b.id.compareTo(a.id);
    });
    return sorted;
  }

  ChatMessage _messageFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    return widget.controller.withLocalAttachmentPreview(
      ChatMessage.fromMap(
        doc.id,
        doc.data(),
        hasPendingWrites: doc.metadata.hasPendingWrites,
      ),
    );
  }

  void _resetConversationSearch() {
    _conversationSearchDebounce?.cancel();
    _conversationSearchSerial++;
    _conversationSearchQuery = '';
    _isSearchingConversation = false;
    _conversationSearchCompleted = false;
    _conversationSearchFailed = false;
    _conversationSearchAfterDoc = null;
    _conversationSearchScannedIds.clear();
    _conversationSearchMatches.clear();
  }

  void _handleSearchQueryChanged() {
    final query = _normalizedSearchText(widget.searchQuery);
    _conversationSearchDebounce?.cancel();

    if (query.isEmpty) {
      setState(_resetConversationSearch);
      return;
    }

    _conversationSearchSerial++;
    _conversationSearchQuery = query;
    _isSearchingConversation = false;
    _conversationSearchCompleted = false;
    _conversationSearchFailed = false;
    _conversationSearchAfterDoc = null;
    _conversationSearchScannedIds.clear();
    _conversationSearchMatches.clear();
    _invalidatePreparedMessagesCache();

    if (mounted) setState(() {});
    _conversationSearchDebounce = Timer(
      const Duration(milliseconds: 260),
      () => _startConversationSearch(query),
    );
  }

  void _scheduleConversationSearch(String query) {
    if (query.isEmpty) return;
    if (_conversationSearchQuery == query &&
        (_isSearchingConversation || _conversationSearchCompleted)) {
      return;
    }

    _handleSearchQueryChanged();
  }

  void _invalidatePreparedMessagesCache() {
    _lastPreparedMessagesRevision = null;
    _lastAudioQueueSourceMessages = null;
  }

  void _scanDocsForSearchMatches(
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    String query,
  ) {
    for (final doc in docs) {
      if (!_conversationSearchScannedIds.add(doc.id)) continue;

      final message = _messageFromDoc(doc);
      if (_messageSearchText(message).contains(query)) {
        _conversationSearchMatches[message.id] = message;
      }
    }
  }

  Future<void> _startConversationSearch(String query) async {
    final serial = _conversationSearchSerial;
    if (!mounted || query != _conversationSearchQuery) return;

    setState(() {
      _isSearchingConversation = true;
      _conversationSearchFailed = false;
    });

    try {
      final knownDocs = _sortDocsByTimeDesc(_mergeDocs(_latestDocs, _olderDocs));
      _scanDocsForSearchMatches(knownDocs, query);

      if (!mounted || serial != _conversationSearchSerial) return;
      _conversationSearchAfterDoc =
          knownDocs.isNotEmpty ? knownDocs.last : _conversationSearchAfterDoc;
      _invalidatePreparedMessagesCache();
      setState(() {});

      var afterDoc = _conversationSearchAfterDoc;
      var loadedSearchPages = 0;

      while (mounted && serial == _conversationSearchSerial) {
        if (loadedSearchPages >= _maxAutomaticSearchPages) {
          _conversationSearchCompleted = true;
          break;
        }

        final snapshot = await widget.controller.loadMessagesPage(
          afterDoc: afterDoc,
          limit: _searchPageSize,
        );

        if (!mounted || serial != _conversationSearchSerial) return;

        loadedSearchPages++;
        final docs = snapshot.docs;
        _scanDocsForSearchMatches(docs, query);
        afterDoc = docs.isNotEmpty ? docs.last : afterDoc;
        _conversationSearchAfterDoc = afterDoc;
        _conversationSearchCompleted = docs.length < _searchPageSize;
        _invalidatePreparedMessagesCache();
        setState(() {});

        if (_conversationSearchCompleted) break;

        // Yield between Firestore pages so long conversations do not monopolize
        // the UI isolate while the user is typing or scrolling.
        await Future<void>.delayed(const Duration(milliseconds: 16));
      }
    } catch (_) {
      if (!mounted || serial != _conversationSearchSerial) return;
      setState(() {
        _conversationSearchFailed = true;
      });
    } finally {
      if (mounted && serial == _conversationSearchSerial) {
        setState(() {
          _isSearchingConversation = false;
        });
      }
    }
  }

  List<ChatMessage> _applySearchFilter(List<ChatMessage> messages) {
    final query = _normalizedSearchText(widget.searchQuery);
    if (query.isEmpty) return messages;

    return messages
        .where((message) => _messageSearchText(message).contains(query))
        .toList();
  }

  List<ChatMessage> _prepareMessages(ChatMessagesUiState state) {
    final normalizedQuery = _normalizedSearchText(widget.searchQuery);

    if (_lastPreparedMessagesRevision == state.revision &&
        _lastPreparedOlderDocsRevision == _olderDocsRevision &&
        _lastPreparedInitialMessagesLoaded == state.initialMessagesLoaded &&
        _lastPreparedSearchQuery == normalizedQuery) {
      return _lastPreparedMessages;
    }

    List<ChatMessage> sourceMessages;

    if (!state.initialMessagesLoaded) {
      sourceMessages = _mergeMessages(
        state.pendingMessages,
        state.cachedMessages,
      );
    } else {
      _latestDocs = state.latestDocs;
      final docs = _mergeDocs(_latestDocs, _olderDocs);
      _currentOldestDoc = docs.isNotEmpty ? docs.last : null;

      final liveMessages = docs.map((doc) {
        return widget.controller.withLocalAttachmentPreview(
          ChatMessage.fromMap(
            doc.id,
            doc.data(),
            hasPendingWrites: doc.metadata.hasPendingWrites,
          ),
        );
      }).toList(growable: false);

      sourceMessages = _mergeMessages(
        state.pendingMessages,
        liveMessages,
      );
    }

    final preparedMessages = normalizedQuery.isEmpty
        ? sourceMessages
        : _mergeMessages(
            state.pendingMessages,
            <ChatMessage>[
              ..._applySearchFilter(sourceMessages),
              ..._conversationSearchMatches.values,
            ],
          );
    _lastPreparedMessagesRevision = state.revision;
    _lastPreparedOlderDocsRevision = _olderDocsRevision;
    _lastPreparedInitialMessagesLoaded = state.initialMessagesLoaded;
    _lastPreparedSearchQuery = normalizedQuery;
    _lastPreparedMessages = preparedMessages;

    return preparedMessages;
  }

  int? _unreadSeparatorIndex(List<ChatMessage> messages) {
    if (widget.searchQuery.trim().isNotEmpty) return null;

    final lastRead = widget.controller.initialLastReadMessageTime;
    if (lastRead <= 0 || messages.isEmpty) return null;

    for (var index = messages.length - 1; index >= 0; index--) {
      final message = messages[index];
      final isIncoming = message.senderId != widget.controller.currentUid;
      final isUnread = message.time > lastRead;
      final isStable = !message.isLocalPending && !message.isFailed;
      if (isIncoming && isUnread && isStable) return index;
    }

    return null;
  }

  Widget _unreadSeparator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: AppStatusChip(
          label: 'chat.unread_messages'.tr(),
          color: context.scheme.secondary,
          backgroundColor: context.scheme.secondary.withValues(alpha: 0.14),
          showBorder: false,
        ),
      ),
    );
  }

  List<ChatMessage> _mergeMessages(
    List<ChatMessage> pending,
    List<ChatMessage> liveOrCached,
  ) {
    final merged = <String, ChatMessage>{};

    for (final message in liveOrCached) {
      merged[message.id] = message;
    }

    final liveIds = liveOrCached.map((message) => message.id).toSet();
    for (final message in pending) {
      if (!liveIds.contains(message.id)) {
        merged[message.id] = message;
      }
    }

    final messages = merged.values.toList();
    messages.sort((a, b) {
      final byTime = b.time.compareTo(a.time);
      if (byTime != 0) return byTime;

      final byId = b.id.compareTo(a.id);
      if (byId != 0) return byId;

      if (a.isLocalPending != b.isLocalPending) {
        return a.isLocalPending ? -1 : 1;
      }

      if (a.isFailed != b.isFailed) {
        return a.isFailed ? -1 : 1;
      }

      return 0;
    });

    return messages;
  }

  MessageReceiptSummary _receiptSummaryFor(ChatMessage message) {
    final states = widget.controller.memberStates;
    final recipientIds =
        states
            .map((state) => state.uid.trim())
            .where((uid) => uid.isNotEmpty && uid != message.senderId)
            .toSet();

    var delivered = 0;
    var read = 0;

    for (final state in states) {
      if (!recipientIds.contains(state.uid)) continue;

      final didRead = state.lastReadMessageTime >= message.time;
      final didDeliver =
          didRead || state.lastDeliveredMessageTime >= message.time;

      if (didDeliver) delivered++;
      if (didRead) read++;
    }

    final recipientCount = recipientIds.length;
    if (delivered > recipientCount) delivered = recipientCount;
    if (read > recipientCount) read = recipientCount;

    return MessageReceiptSummary(
      recipientCount: recipientCount,
      deliveredCount: delivered,
      readCount: read,
    );
  }

  bool _localFileExists(String? path) => LocalFileExistsCache.existsSync(path);

  bool _canRetryFailedMessage(ChatMessage message) {
    return message.isFailed &&
        (message.type == 'text' ||
            message.type == 'poll' ||
            message.type == 'image' ||
            message.type == 'video' ||
            message.type == 'audio' ||
            message.type == 'file');
  }

  Future<void> _selectMessageWithReceipts(
    ChatMessage message,
    bool canDelete,
  ) async {
    var receiptSummary = _receiptSummaryFor(message);
    widget.onMessageSelected?.call(message, receiptSummary, canDelete);

    try {
      await widget.controller.ensureMemberStatesLoaded();
      if (!mounted || widget.selectedMessageId != message.id) return;

      receiptSummary = _receiptSummaryFor(message);
      widget.onMessageSelected?.call(message, receiptSummary, canDelete);
    } catch (_) {
      // Receipt details are optional. Message selection should remain instant.
    }
  }

  String _directAudioSource(ChatMessage message) {
    final localPath = message.localFilePath?.trim() ?? '';
    if (localPath.isNotEmpty && _localFileExists(localPath)) return localPath;

    final audioUrl = message.audioUrl?.trim() ?? '';
    if (audioUrl.isNotEmpty) return audioUrl;

    return '';
  }

  void _prepareAudioPlaybackQueues(List<ChatMessage> messages) {
    if (identical(_lastAudioQueueSourceMessages, messages)) return;

    final queues = <String, List<ChatAudioPlaybackItem>>{};

    for (var index = 0; index < messages.length; index++) {
      final current = messages[index];
      if (current.type != 'audio' || current.isFailed) continue;

      final queue = <ChatAudioPlaybackItem>[];
      for (var i = index; i >= 0 && queue.length < 30; i--) {
        final message = messages[i];
        if (message.type != 'audio' || message.isFailed) break;

        queue.add(
          ChatAudioPlaybackItem(
            id: message.id,
            source: _directAudioSource(message),
            groupId: widget.controller.groupId,
            storagePath: message.storagePath?.trim() ?? '',
          ),
        );
      }

      queues[current.id] = List<ChatAudioPlaybackItem>.unmodifiable(queue);
    }

    _lastAudioQueueSourceMessages = messages;
    _audioPlaybackQueuesById = Map<String, List<ChatAudioPlaybackItem>>.unmodifiable(
      queues,
    );
  }

  List<ChatAudioPlaybackItem> _audioPlaybackQueueFor(String messageId) {
    return _audioPlaybackQueuesById[messageId] ?? const [];
  }

  Key _messageItemKeyFor(String messageId) {
    if (_replyScrollTargetMessageId == messageId) {
      return _replyScrollTargetKey ??= GlobalKey();
    }

    return ValueKey<String>('message_item_$messageId');
  }

  void _prepareReplyScrollTarget(String messageId) {
    if (_replyScrollTargetMessageId == messageId &&
        _replyScrollTargetKey != null) {
      return;
    }

    _replyScrollTargetMessageId = messageId;
    _replyScrollTargetKey = GlobalKey();
    if (mounted) setState(() {});
  }

  void _clearReplyScrollTarget(String messageId) {
    if (_replyScrollTargetMessageId != messageId) return;

    _replyScrollTargetMessageId = null;
    _replyScrollTargetKey = null;
    if (mounted) setState(() {});
  }

  void _highlightMessage(String messageId) {
    _highlightTimer?.cancel();
    if (!mounted) return;
    setState(() => _highlightedMessageId = messageId);
    _highlightTimer = Timer(const Duration(milliseconds: 1500), () {
      if (!mounted || _highlightedMessageId != messageId) return;
      setState(() => _highlightedMessageId = null);
    });
  }

  Future<void> _jumpToLatest() async {
    if (!_scrollController.hasClients) return;
    await _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _scrollToMessage(String messageId) async {
    final cleanMessageId = messageId.trim();
    if (cleanMessageId.isEmpty) return;

    _prepareReplyScrollTarget(cleanMessageId);
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;

    for (var attempt = 0; attempt < 12; attempt++) {
      final targetContext = _replyScrollTargetKey?.currentContext;

      if (targetContext != null) {
        if (!targetContext.mounted) return;

        await Scrollable.ensureVisible(
          targetContext,
          duration: const Duration(milliseconds: 360),
          curve: Curves.easeOutCubic,
          alignment: 0.42,
        );

        if (!mounted) return;

        _highlightMessage(cleanMessageId);
        _clearReplyScrollTarget(cleanMessageId);
        return;
      }

      if (!_hasMore || _isLoadingMore) break;

      await _loadMore();

      if (!mounted) return;

      await Future<void>.delayed(const Duration(milliseconds: 40));

      if (!mounted) return;
    }

    if (!mounted) return;
    _clearReplyScrollTarget(cleanMessageId);
    showAppSnackBar(
      context,
      'chat.reply_target_not_available'.tr(),
      type: SnackType.info,
    );
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    final afterDoc = _currentOldestDoc;
    if (afterDoc == null) return;

    setState(() {
      _isLoadingMore = true;
      _loadMoreFailed = false;
    });

    try {
      final snapshot = await widget.controller.loadOlderMessages(afterDoc);

      if (!mounted) return;

      final knownIds = <String>{
        ..._latestDocs.map((e) => e.id),
        ..._olderDocs.map((e) => e.id),
      };

      final newDocs =
          snapshot.docs.where((doc) => !knownIds.contains(doc.id)).toList();

      setState(() {
        _olderDocs.addAll(newDocs);
        _olderDocsRevision++;
        _hasMore = snapshot.docs.length == _pageSize;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadMoreFailed = true);
    } finally {
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  Widget _buildLoadMoreError() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.pill),
          onTap: _loadMore,
          child: AppStatusChip(
            icon: Icons.refresh_rounded,
            label: 'chat.load_older_failed_retry'.tr(),
            color: context.scheme.error,
            backgroundColor: context.scheme.error.withValues(alpha: 0.10),
          ),
        ),
      ),
    );
  }

  Widget _buildConversationSearchFooter() {
    if (_isSearchingConversation) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Center(
          child: AppStatusChip(
            leading: const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            label: 'chat.searching_full_conversation'.tr(),
            color: context.appPrimary,
          ),
        ),
      );
    }

    if (_conversationSearchFailed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadii.pill),
            onTap: () => _startConversationSearch(_conversationSearchQuery),
            child: AppStatusChip(
              icon: Icons.refresh_rounded,
              label: 'chat.search_full_failed_retry'.tr(),
              color: context.scheme.error,
              backgroundColor: context.scheme.error.withValues(alpha: 0.10),
            ),
          ),
        ),
      );
    }

    return const SizedBox(height: 16);
  }

  @override
  void dispose() {
    _conversationSearchDebounce?.cancel();
    _floatingDateHideTimer?.cancel();
    _highlightTimer?.cancel();
    _showJumpToLatestNotifier.dispose();
    _floatingDateBadgeNotifier.dispose();
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  Widget _buildMessages(List<ChatMessage> messages) {
    if (messages.isEmpty) {
      final searching = widget.searchQuery.trim().isNotEmpty;
      if (searching && _isSearchingConversation) {
        return Center(child: _buildConversationSearchFooter());
      }
      if (searching && _conversationSearchFailed) {
        return Center(child: _buildConversationSearchFooter());
      }

      return Padding(
        padding: const EdgeInsets.only(bottom: 90),
        child: AppEmptyState(
          icon:
              searching
                  ? Icons.search_off_rounded
                  : Icons.chat_bubble_outline_rounded,
          text:
              searching
                  ? 'chat.no_search_results'.tr()
                  : 'chat.no_messages_yet'.tr(),
        ),
      );
    }

    final unreadSeparatorIndex = _unreadSeparatorIndex(messages);
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final bottomPadding = 122.0 + keyboardInset;
    _prepareAudioPlaybackQueues(messages);

    return Stack(
      children: [
        NotificationListener<ScrollNotification>(
          onNotification:
              (notification) =>
                  _handleScrollNotification(notification, messages),
          child: ListView.builder(
            scrollCacheExtent: ScrollCacheExtent.pixels(420),
            controller: _scrollController,
            reverse: true,
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
            padding: EdgeInsets.fromLTRB(8, 14, 8, bottomPadding),
            itemCount: messages.length + 1,
            itemBuilder: (_, index) {
              if (index == messages.length) {
                if (widget.searchQuery.trim().isNotEmpty) {
                  return _buildConversationSearchFooter();
                }

                if (_isLoadingMore) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: AppLoader.inline(size: 22, strokeWidth: 2),
                    ),
                  );
                }

                if (_loadMoreFailed) return _buildLoadMoreError();

                return const SizedBox(height: 16);
              }

              final message = messages[index];
              final sendByMe = message.senderId == widget.controller.currentUid;
              final isGroupManagerRole =
                  AppRolePermissions.canManageRestrictedGroupMessagesRole(
                    widget.userRole,
                  );
              final isGroupAdmin = AppRolePermissions.isGroupAdminUid(
                currentUid: widget.controller.currentUid,
                groupAdminId: widget.groupAdminId,
                groupAdminIds: widget.groupAdminIds,
              );

              final canDelete =
                  !message.isLocalPending &&
                  !message.isFailed &&
                  (sendByMe || isGroupManagerRole || isGroupAdmin);

              final showDateSeparator = _shouldShowDateSeparator(
                messages,
                index,
              );

              return AppStaggeredEntrance(
                key: _messageItemKeyFor(message.id),
                index: index,
                maxDelaySteps: 5,
                duration: AppMotion.fast,
                offsetY: 6,
                scaleBegin: 0.996,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (unreadSeparatorIndex == index) _unreadSeparator(),
                    if (showDateSeparator)
                      ChatDateSeparator(
                        key: _separatorKeyFor(message.time),
                        label: _dateSeparatorLabel(context, message.time),
                      ),
                    MessageTile(
                      key: ValueKey('message_${message.id}'),
                      message: message,
                      sendByMe: sendByMe,
                      canDelete: canDelete,
                      groupId: widget.controller.groupId,
                      currentUid: widget.controller.currentUid,
                      selected: widget.selectedMessageId == message.id,
                      onTap: widget.selectedMessageId == null
                          ? null
                          : () {
                              if (widget.selectedMessageId == message.id) {
                                widget.onClearSelection?.call();
                              } else {
                                unawaited(
                                  _selectMessageWithReceipts(message, canDelete),
                                );
                              }
                            },
                      onSelect: () => unawaited(
                        _selectMessageWithReceipts(message, canDelete),
                      ),
                      onDelete:
                          () => widget.controller.deleteMessage(message.id),
                      onReply:
                          !message.isLocalPending && !message.isFailed
                              ? () => widget.controller.startReply(message)
                              : null,
                      onRetry:
                          _canRetryFailedMessage(message)
                              ? () => widget.controller.retryPendingMessage(
                                message.id,
                              )
                              : null,
                      onDiscard:
                          message.isFailed
                              ? () => widget.controller.discardPendingMessage(
                                message.id,
                              )
                              : null,
                      highlighted: _highlightedMessageId == message.id,
                      onReplyPreviewTap:
                          message.replyToMessageId?.trim().isNotEmpty == true
                              ? () =>
                                  _scrollToMessage(message.replyToMessageId!)
                              : null,
                      audioPlaybackQueue:
                          message.type == 'audio'
                              ? _audioPlaybackQueueFor(message.id)
                              : const [],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        PositionedDirectional(
          end: 16,
          bottom: 92 + keyboardInset,
          child: ValueListenableBuilder<bool>(
            valueListenable: _showJumpToLatestNotifier,
            builder: (context, showJumpToLatest, child) {
              return AnimatedScale(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                scale: showJumpToLatest ? 1 : 0,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 180),
                  opacity: showJumpToLatest ? 1 : 0,
                  child: IgnorePointer(
                    ignoring: !showJumpToLatest,
                    child: child,
                  ),
                ),
              );
            },
            child: FloatingActionButton.small(
              heroTag: 'chat_jump_to_latest_${widget.controller.groupId}',
              tooltip: 'chat.jump_to_latest'.tr(),
              onPressed: _jumpToLatest,
              child: const Icon(Icons.keyboard_arrow_down_rounded),
            ),
          ),
        ),
        Positioned(
          top: 10,
          left: 0,
          right: 0,
          child: ValueListenableBuilder<_FloatingDateBadgeState>(
            valueListenable: _floatingDateBadgeNotifier,
            builder: (context, state, _) {
              return ChatScrollDateBadge(
                label: state.label,
                visible: state.visible,
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ChatMessagesUiState>(
      valueListenable: widget.controller.chatMessagesUiState,
      builder: (context, state, _) {
        final normalizedQuery = _normalizedSearchText(widget.searchQuery);
        if (normalizedQuery.isNotEmpty &&
            _conversationSearchQuery != normalizedQuery &&
            !_isSearchingConversation) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            if (_normalizedSearchText(widget.searchQuery) == normalizedQuery) {
              _scheduleConversationSearch(normalizedQuery);
            }
          });
        }

        final messages = _prepareMessages(state);

        if (!state.initialMessagesLoaded && messages.isEmpty) {
          return AppShimmer(child: AppShimmer.chatSkeleton());
        }

        return _buildMessages(messages);
      },
    );
  }
}
class _FloatingDateBadgeState {
  final String label;
  final bool visible;

  const _FloatingDateBadgeState({
    required this.label,
    required this.visible,
  });

  _FloatingDateBadgeState copyWith({
    String? label,
    bool? visible,
  }) {
    return _FloatingDateBadgeState(
      label: label ?? this.label,
      visible: visible ?? this.visible,
    );
  }
}
