import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/services/storage_download_url_cache.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_file_metadata.dart';
import '../../../core/utils/bidi_text.dart';
import '../../../core/utils/local_file_exists_cache.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../../core/widgets/app_loader.dart';
import '../../../core/widgets/safe_network_image.dart';
import '../../../data/models/chat_message.dart';
import '../../../services/attachment_download_service.dart';
import '../../../services/chat_audio_player_service.dart';
import '../../pages/media_viewer_page.dart';
import 'attachment_save_button.dart';
import 'chat_event_card.dart';
import 'poll_message_card.dart';

part 'message_content/audio_progress_bar.dart';
part 'message_content/media_helpers.dart';
part 'message_content/image_video_message_content.dart';
part 'message_content/audio_message_content.dart';
part 'message_content/file_message_content.dart';

class MessageContent extends StatefulWidget {
  final ChatMessage message;
  final bool sendByMe;
  final String groupId;
  final String currentUid;
  final List<ChatAudioPlaybackItem> audioPlaybackQueue;

  const MessageContent({
    super.key,
    required this.message,
    required this.sendByMe,
    required this.groupId,
    required this.currentUid,
    this.audioPlaybackQueue = const [],
  });

  @override
  State<MessageContent> createState() => _MessageContentState();
}

class _MessageContentState extends State<MessageContent>
    with AutomaticKeepAliveClientMixin<MessageContent> {
  static const int _maxCachedAttachmentUrls = 500;

  static final Map<String, String> _resolvedAttachmentUrls = {};
  static final Map<String, Future<String>> _attachmentUrlFutures = {};

  String _imageRequestKey = '';
  String _videoRequestKey = '';
  String _videoThumbnailRequestKey = '';
  String _audioRequestKey = '';
  String _fileRequestKey = '';

  String _imageDisplayUrl = '';
  String _videoDisplayUrl = '';
  String _videoThumbnailDisplayUrl = '';
  String _audioDisplayUrl = '';
  String _fileDisplayUrl = '';

  bool _imageResolveFailed = false;
  bool _videoThumbnailResolveFailed = false;
  bool _audioResolveFailed = false;
  bool _audioPlaybackFailed = false;
  bool _audioIsResolving = false;
  bool _videoIsOpening = false;
  bool _fileIsOpening = false;
  bool _listeningToPlaybackState = false;

  @override
  bool get wantKeepAlive {
    final message = widget.message;

    if (message.isLocalPending || message.hasPendingWrites || message.isFailed) {
      return true;
    }

    if (message.localFilePath?.trim().isNotEmpty == true ||
        message.localThumbnailPath?.trim().isNotEmpty == true) {
      return true;
    }

    if (message.type == 'audio') {
      final playback = ChatAudioPlayerService.playbackState.value;
      return playback.id == message.id &&
          (playback.isPlaying || playback.isBuffering);
    }

    return false;
  }

  bool get _isWaiting =>
      widget.message.isLocalPending || widget.message.hasPendingWrites;

  bool get _isUnavailable => widget.message.isFailed;

  @override
  void initState() {
    super.initState();
    _syncPlaybackKeepAliveListener();
    _syncResolvedUrls();
  }

  @override
  void didUpdateWidget(covariant MessageContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.message.id != widget.message.id) {
      _audioPlaybackFailed = false;
      _audioIsResolving = false;
    }
    _syncPlaybackKeepAliveListener();
    _syncResolvedUrls();
  }

  @override
  void dispose() {
    if (_listeningToPlaybackState) {
      ChatAudioPlayerService.playbackState.removeListener(_handlePlaybackStateChanged);
    }
    super.dispose();
  }

  void _syncPlaybackKeepAliveListener() {
    final shouldListen = widget.message.type == 'audio';
    if (shouldListen == _listeningToPlaybackState) return;

    if (shouldListen) {
      ChatAudioPlayerService.playbackState.addListener(_handlePlaybackStateChanged);
    } else {
      ChatAudioPlayerService.playbackState.removeListener(_handlePlaybackStateChanged);
    }

    _listeningToPlaybackState = shouldListen;
  }

  void _handlePlaybackStateChanged() {
    updateKeepAlive();
  }

  static String _cleanStoragePath(String? value) {
    return (value ?? '').trim().replaceFirst(RegExp(r'^/+'), '');
  }

  static String _cleanDirectUrl(String? value) => (value ?? '').trim();

  static String _cacheKey({
    required String groupId,
    required String? directUrl,
    required String? storagePath,
  }) {
    final cleanUrl = _cleanDirectUrl(directUrl);
    if (cleanUrl.isNotEmpty) return 'url:$cleanUrl';

    final cleanPath = _cleanStoragePath(storagePath);
    if (cleanPath.isEmpty) return '';

    return 'path:$groupId:$cleanPath';
  }

  static bool _isPathKey(String key) => key.startsWith('path:');

  static void _rememberResolvedUrl(String key, String url) {
    final cleanUrl = url.trim();
    if (key.isEmpty || cleanUrl.isEmpty) return;

    _resolvedAttachmentUrls.remove(key);
    _resolvedAttachmentUrls[key] = cleanUrl;

    while (_resolvedAttachmentUrls.length > _maxCachedAttachmentUrls) {
      final oldestKey = _resolvedAttachmentUrls.keys.first;
      _resolvedAttachmentUrls.remove(oldestKey);
      _attachmentUrlFutures.remove(oldestKey);
    }
  }

  Future<String> _resolveStoragePathUrl({
    required String key,
    required String storagePath,
  }) {
    final cached = _resolvedAttachmentUrls[key];
    if (cached != null && cached.isNotEmpty) return Future.value(cached);

    final cachedStorageUrl = StorageDownloadUrlCache.peek(storagePath);
    if (cachedStorageUrl != null && cachedStorageUrl.isNotEmpty) {
      _rememberResolvedUrl(key, cachedStorageUrl);
      return Future.value(cachedStorageUrl);
    }

    return _attachmentUrlFutures.putIfAbsent(
      key,
      () async {
        final resolvedUrl = await StorageDownloadUrlCache.resolve(storagePath);
        _rememberResolvedUrl(key, resolvedUrl);
        return resolvedUrl.trim();
      },
    );
  }

  void _syncAttachmentSlot({
    required String? directUrl,
    required String? storagePath,
    required String Function() getRequestKey,
    required void Function(String value) setRequestKey,
    required void Function(String value) setDisplayUrl,
    required void Function(bool value) setFailed,
  }) {
    final key = _cacheKey(
      groupId: widget.groupId,
      directUrl: directUrl,
      storagePath: storagePath,
    );

    if (key == getRequestKey()) return;

    setRequestKey(key);
    setFailed(false);

    final cleanUrl = _cleanDirectUrl(directUrl);
    if (cleanUrl.isNotEmpty) {
      _rememberResolvedUrl(key, cleanUrl);
      setDisplayUrl(cleanUrl);
      return;
    }

    final cachedUrl = _resolvedAttachmentUrls[key];
    if (cachedUrl != null && cachedUrl.isNotEmpty) {
      setDisplayUrl(cachedUrl);
      return;
    }

    setDisplayUrl('');

    final cleanPath = _cleanStoragePath(storagePath);
    if (key.isEmpty || cleanPath.isEmpty || !_isPathKey(key)) return;

    _resolveStoragePathUrl(key: key, storagePath: cleanPath).then((url) {
      if (!mounted || getRequestKey() != key) return;
      setState(() {
        setDisplayUrl(url.trim());
        setFailed(url.trim().isEmpty);
      });
    }).catchError((_) {
      _attachmentUrlFutures.remove(key);
      if (!mounted || getRequestKey() != key) return;
      setState(() {
        setDisplayUrl('');
        setFailed(true);
      });
    });
  }

  void _syncAudioSlot(ChatMessage message) {
    final key = _cacheKey(
      groupId: widget.groupId,
      directUrl: message.audioUrl,
      storagePath: message.type == 'audio' ? message.storagePath : null,
    );

    if (key == _audioRequestKey) return;

    _audioRequestKey = key;
    _audioResolveFailed = false;
    _audioPlaybackFailed = false;
    _audioIsResolving = false;
    _audioDisplayUrl = '';

    // Voice playback now uses Firebase Storage SDK download-to-cache inside
    // ChatAudioPlayerService when a storagePath exists. Do not generate or cache
    // short-lived signed URLs for voice notes during widget build; stale signed
    // URLs were the main reason playback failed after reopening the app.
    final cleanUrl = _cleanDirectUrl(message.audioUrl);
    if (cleanUrl.isNotEmpty) {
      _rememberResolvedUrl(key, cleanUrl);
      _audioDisplayUrl = cleanUrl;
      ChatAudioPlayerService.registerSource(id: message.id, source: cleanUrl);
    }
  }

  void _syncResolvedUrls() {
    final message = widget.message;

    _syncAttachmentSlot(
      directUrl: message.imageUrl,
      storagePath: message.type == 'image' ? message.storagePath : null,
      getRequestKey: () => _imageRequestKey,
      setRequestKey: (value) => _imageRequestKey = value,
      setDisplayUrl: (value) => _imageDisplayUrl = value,
      setFailed: (value) => _imageResolveFailed = value,
    );

    final videoKey = _cacheKey(
      groupId: widget.groupId,
      directUrl: message.videoUrl,
      storagePath: message.type == 'video' ? message.storagePath : null,
    );
    if (videoKey != _videoRequestKey) {
      _videoRequestKey = videoKey;
      _videoDisplayUrl = '';
      _videoIsOpening = false;
      final directVideoUrl = _cleanDirectUrl(message.videoUrl);
      if (directVideoUrl.isNotEmpty) {
        _rememberResolvedUrl(videoKey, directVideoUrl);
      }
    }

    _syncAttachmentSlot(
      directUrl: message.videoThumbnailUrl,
      storagePath: message.type == 'video' ? message.videoThumbnailPath : null,
      getRequestKey: () => _videoThumbnailRequestKey,
      setRequestKey: (value) => _videoThumbnailRequestKey = value,
      setDisplayUrl: (value) => _videoThumbnailDisplayUrl = value,
      setFailed: (value) => _videoThumbnailResolveFailed = value,
    );

    _syncAudioSlot(message);

    final fileKey = _cacheKey(
      groupId: widget.groupId,
      directUrl: message.fileUrl,
      storagePath: message.type == 'file' ? message.storagePath : null,
    );
    if (fileKey != _fileRequestKey) {
      _fileRequestKey = fileKey;
      _fileDisplayUrl = '';
      _fileIsOpening = false;
      final directFileUrl = _cleanDirectUrl(message.fileUrl);
      if (directFileUrl.isNotEmpty) {
        _rememberResolvedUrl(fileKey, directFileUrl);
      }
    }
  }


  Future<String> _resolveAttachmentUrlForOpen({
    required String? directUrl,
    required String? storagePath,
  }) async {
    final cleanUrl = _cleanDirectUrl(directUrl);
    final cleanPath = _cleanStoragePath(storagePath);
    final key = _cacheKey(
      groupId: widget.groupId,
      directUrl: cleanUrl,
      storagePath: cleanPath,
    );

    if (cleanUrl.isNotEmpty) {
      _rememberResolvedUrl(key, cleanUrl);
      return cleanUrl;
    }

    if (key.isEmpty || cleanPath.isEmpty || !_isPathKey(key)) return '';

    final cached = _resolvedAttachmentUrls[key];
    if (cached != null && cached.isNotEmpty) return cached;

    return _resolveStoragePathUrl(key: key, storagePath: cleanPath);
  }

  void _retryAudioResolve(ChatMessage message) {
    final key = _cacheKey(
      groupId: widget.groupId,
      directUrl: message.audioUrl,
      storagePath: message.type == 'audio' ? message.storagePath : null,
    );

    if (key.isNotEmpty) {
      _attachmentUrlFutures.remove(key);
      _resolvedAttachmentUrls.remove(key);
    }

    setState(() {
      _audioRequestKey = '';
      _audioDisplayUrl = '';
      _audioResolveFailed = false;
      _audioPlaybackFailed = false;
      _audioIsResolving = false;
    });
    _syncResolvedUrls();
  }

  bool _localFileExists(String? path) => LocalFileExistsCache.existsSync(path);

  void _applyState(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final message = widget.message;

    if (message.type == 'text') {
      return Text(
        message.message,
        textAlign: TextAlign.start,
        textDirection: chatTextDirectionFor(message.message),
        style: context.textTheme.bodyLarge?.copyWith(
          fontSize: 15,
          height: 1.52,
          color: widget.sendByMe
              ? context.appMessageMineText
              : context.appMessageOtherText,
          fontWeight: FontWeight.w500,
          letterSpacing: 0,
        ),
      );
    }

    if (message.type == 'poll') {
      return PollMessageCard(
        groupId: widget.groupId,
        messageId: message.id,
        currentUid: widget.currentUid,
        pollQuestion: message.pollQuestion,
        pollOptions: message.pollOptions,
        pollExpiresAt: message.pollExpiresAt,
        pollIsClosed: message.pollIsClosed,
        sendByMe: widget.sendByMe,
      );
    }

    if (message.type == 'event' && message.eventId != null) {
      return ChatEventCard(
        eventId: message.eventId!,
        currentUid: widget.currentUid,
        sendByMe: widget.sendByMe,
      );
    }

    switch (message.type) {
      case 'image':
        return _buildImageMessage(message);
      case 'video':
        return _buildVideoMessage(message);
      case 'audio':
        return _buildAudioMessage(message);
      case 'file':
        return _buildFileMessage(message);
      default:
        return _placeholder(
          icon: Icons.chat_bubble_outline_rounded,
          label: 'chat.attachment.message',
        );
    }
  }
}
