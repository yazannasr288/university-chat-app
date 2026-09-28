import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart' as path_provider;

class ChatAudioPlaybackItem {
  final String id;
  final String source;
  final String groupId;
  final String storagePath;

  const ChatAudioPlaybackItem({
    required this.id,
    required this.source,
    this.groupId = '',
    this.storagePath = '',
  });

  ChatAudioPlaybackItem copyWith({
    String? id,
    String? source,
    String? groupId,
    String? storagePath,
  }) {
    return ChatAudioPlaybackItem(
      id: id ?? this.id,
      source: source ?? this.source,
      groupId: groupId ?? this.groupId,
      storagePath: storagePath ?? this.storagePath,
    );
  }
}

typedef ChatAudioSourceResolver = Future<String> Function(
  ChatAudioPlaybackItem item,
);

class ChatAudioPlaybackState {
  final String id;
  final String source;
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final bool isBuffering;
  final double speed;

  const ChatAudioPlaybackState({
    this.id = '',
    this.source = '',
    this.isPlaying = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.isBuffering = false,
    this.speed = 1.0,
  });

  ChatAudioPlaybackState copyWith({
    String? id,
    String? source,
    bool? isPlaying,
    Duration? position,
    Duration? duration,
    bool? isBuffering,
    double? speed,
  }) {
    return ChatAudioPlaybackState(
      id: id ?? this.id,
      source: source ?? this.source,
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      isBuffering: isBuffering ?? this.isBuffering,
      speed: speed ?? this.speed,
    );
  }
}

class ChatAudioPlayerService {
  ChatAudioPlayerService._();

  static final AudioPlayer _player = AudioPlayer();
  static final ValueNotifier<ChatAudioPlaybackState> _state =
      ValueNotifier<ChatAudioPlaybackState>(const ChatAudioPlaybackState());

  static const List<double> _speedOptions = <double>[1.0, 1.25, 1.5, 2.0];
  static const int _minPlayableBytes = 512;
  static const Duration _cacheMaxAge = Duration(days: 7);
  static const int _cacheMaxBytes = 100 * 1024 * 1024;
  static const int _maxRegisteredSources = 300;

  static bool _initialized = false;
  static bool _cacheCleanupStarted = false;
  static bool _changingSource = false;
  static bool _handlingCompletion = false;
  static int _loadSerial = 0;
  static int _queueIndex = -1;
  static int _speedIndex = 0;
  static String? _currentId;
  static List<ChatAudioPlaybackItem> _queue = const [];
  static ChatAudioSourceResolver? _sourceResolver;

  static final Map<String, String> _registeredSources = <String, String>{};
  static final Map<String, Future<String>> _pendingStorageDownloads =
      <String, Future<String>>{};

  static void _rememberSource(String id, String source) {
    _registeredSources.remove(id);
    _registeredSources[id] = source;
    while (_registeredSources.length > _maxRegisteredSources) {
      _registeredSources.remove(_registeredSources.keys.first);
    }
  }

  static ValueListenable<ChatAudioPlaybackState> get playbackState {
    _ensureInitialized();
    return _state;
  }

  static double get currentSpeed => _speedOptions[_speedIndex];

  static String get currentSpeedLabel => _speedLabel(currentSpeed);

  static String _speedLabel(double value) {
    if (value == 1.0) return '1x';
    if (value == 2.0) return '2x';
    return '${value.toStringAsFixed(2).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '')}x';
  }

  static void _ensureInitialized() {
    if (_initialized) return;
    _initialized = true;

    unawaited(_player.setLoopMode(LoopMode.off));
    unawaited(_player.setSpeed(currentSpeed));
    unawaited(_cleanupVoiceCache());

    _player.playerStateStream.listen((playerState) {
      final processing = playerState.processingState;
      final buffering = processing == ProcessingState.loading ||
          processing == ProcessingState.buffering;

      if (processing == ProcessingState.completed) {
        if (_handlingCompletion) return;
        _handlingCompletion = true;
        unawaited(
          _playNextOrStop().whenComplete(() => _handlingCompletion = false),
        );
        return;
      }

      if (_changingSource) return;

      _state.value = _state.value.copyWith(
        isPlaying: playerState.playing,
        isBuffering: buffering,
        speed: currentSpeed,
      );
    });

    _player.positionStream.listen((position) {
      if (_changingSource) return;
      final duration = _player.duration ?? _state.value.duration;
      _state.value = _state.value.copyWith(
        position: _clampPosition(position, duration),
      );
    });

    _player.durationStream.listen((duration) {
      if (_changingSource || duration == null) return;
      _state.value = _state.value.copyWith(duration: duration);
    });
  }

  static void registerSource({required String id, required String source}) {
    final cleanId = id.trim();
    final cleanSource = source.trim();
    if (cleanId.isEmpty || cleanSource.isEmpty) return;
    _rememberSource(cleanId, cleanSource);
  }

  static bool _isHttpSource(String source) {
    final uri = Uri.tryParse(source.trim());
    return uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
  }

  static String _localPathFromSource(String source) {
    final cleanSource = source.trim();
    final uri = Uri.tryParse(cleanSource);
    if (uri != null && uri.scheme == 'file') return uri.toFilePath();
    return cleanSource;
  }

  static Future<bool> _localSourceAvailable(String source) async {
    final cleanSource = source.trim();
    if (cleanSource.isEmpty || _isHttpSource(cleanSource)) return false;

    final file = File(_localPathFromSource(cleanSource));
    return await file.exists() && await file.length() > _minPlayableBytes;
  }

  static Future<Duration?> _setSource(String source) async {
    final cleanSource = source.trim();
    if (cleanSource.isEmpty) throw ArgumentError('Empty audio source');

    final uri = Uri.tryParse(cleanSource);

    if (uri != null && uri.scheme == 'file') {
      final path = uri.toFilePath();
      final file = File(path);
      if (!await file.exists() || await file.length() <= _minPlayableBytes) {
        throw StateError('Audio file is not available');
      }
      return _player.setFilePath(path);
    }

    if (uri == null || uri.scheme.isEmpty) {
      final file = File(cleanSource);
      if (!await file.exists() || await file.length() <= _minPlayableBytes) {
        throw StateError('Audio file is not available');
      }
      return _player.setFilePath(file.path);
    }

    if (uri.scheme == 'http' || uri.scheme == 'https') {
      return _player.setAudioSource(AudioSource.uri(uri), preload: true);
    }

    throw UnsupportedError('Unsupported audio source: ${uri.scheme}');
  }

  static String _cleanStoragePath(String value) {
    return value.trim().replaceFirst(RegExp(r'^/+'), '');
  }

  static String _storageCacheFileName(String storagePath) {
    final encoded = base64Url.encode(utf8.encode(storagePath)).replaceAll('=', '');
    return 'voice_$encoded.m4a';
  }

  static Future<Directory> _voiceCacheDirectory() async {
    final baseDir = await path_provider.getTemporaryDirectory();
    final dir = Directory(
      '${baseDir.path}${Platform.pathSeparator}chat_voice_playback_cache_v2',
    );
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static Future<File> _voiceCacheFile(String storagePath) async {
    final dir = await _voiceCacheDirectory();
    return File('${dir.path}${Platform.pathSeparator}${_storageCacheFileName(storagePath)}');
  }

  static Future<void> _cleanupVoiceCache() async {
    if (_cacheCleanupStarted) return;
    _cacheCleanupStarted = true;

    try {
      final dir = await _voiceCacheDirectory();
      final now = DateTime.now();
      final files = <FileSystemEntity>[];

      await for (final entity in dir.list(followLinks: false)) {
        if (entity is! File) continue;
        final name = entity.uri.pathSegments.isNotEmpty
            ? entity.uri.pathSegments.last
            : '';
        if (!name.startsWith('voice_') && !name.endsWith('.download')) continue;

        final stat = await entity.stat();
        if (now.difference(stat.modified) > _cacheMaxAge ||
            name.endsWith('.download')) {
          await entity.delete().catchError((_) => entity);
          continue;
        }
        files.add(entity);
      }

      final entries = <({File file, FileStat stat})>[];
      var totalBytes = 0;
      for (final entity in files) {
        final file = File(entity.path);
        final stat = await file.stat();
        totalBytes += stat.size;
        entries.add((file: file, stat: stat));
      }

      if (totalBytes <= _cacheMaxBytes) return;

      entries.sort((a, b) => a.stat.modified.compareTo(b.stat.modified));
      for (final entry in entries) {
        if (totalBytes <= _cacheMaxBytes) break;
        totalBytes -= entry.stat.size;
        await entry.file.delete().catchError((_) => entry.file);
      }
    } catch (error) {
      if (kDebugMode) debugPrint('Voice cache cleanup failed: $error');
    }
  }

  static Future<bool> _isUsableCachedFile(File file) async {
    return await file.exists() && await file.length() > _minPlayableBytes;
  }

  static Future<void> _deleteCacheForStoragePath(String storagePath) async {
    final cleanPath = _cleanStoragePath(storagePath);
    if (cleanPath.isEmpty) return;

    try {
      final file = await _voiceCacheFile(cleanPath);
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Cache cleanup must never break playback or retry.
    }
  }

  static Future<String> _downloadStorageAudioToCache(
    String storagePath, {
    bool forceRefresh = false,
  }) async {
    final cleanPath = _cleanStoragePath(storagePath);
    if (cleanPath.isEmpty) return '';

    final pending = _pendingStorageDownloads[cleanPath];
    if (pending != null) return pending;

    final future = _downloadStorageAudioToCacheOnce(
      cleanPath,
      forceRefresh: forceRefresh,
    );
    _pendingStorageDownloads[cleanPath] = future;

    try {
      return await future;
    } finally {
      if (identical(_pendingStorageDownloads[cleanPath], future)) {
        _pendingStorageDownloads.remove(cleanPath);
      }
    }
  }

  static Future<String> _downloadStorageAudioToCacheOnce(
    String cleanPath, {
    required bool forceRefresh,
  }) async {
    final file = await _voiceCacheFile(cleanPath);
    if (!forceRefresh && await _isUsableCachedFile(file)) return file.path;

    if (forceRefresh && await file.exists()) {
      await file.delete();
    }

    final tempFile = File('${file.path}.download');
    if (await tempFile.exists()) await tempFile.delete();

    final task = FirebaseStorage.instance.ref().child(cleanPath).writeToFile(tempFile);
    await task;

    if (!await _isUsableCachedFile(tempFile)) {
      await tempFile.delete().catchError((_) => tempFile);
      throw StateError('Downloaded audio file is empty');
    }

    if (await file.exists()) await file.delete();
    await tempFile.rename(file.path);
    return file.path;
  }

  static Future<String> _resolveWithCallback(ChatAudioPlaybackItem item) async {
    if (_sourceResolver == null) return '';

    final resolved = (await _sourceResolver!(item)).trim();
    if (resolved.isNotEmpty) {
      _rememberSource(item.id, resolved);
    }
    return resolved;
  }

  static Future<ChatAudioPlaybackItem?> _withPlayableSource(
    ChatAudioPlaybackItem item, {
    bool forceStorageRefresh = false,
  }) async {
    final cleanId = item.id.trim();
    if (cleanId.isEmpty) return null;

    final cleanStoragePath = _cleanStoragePath(item.storagePath);
    final directSource = item.source.trim();

    if (directSource.isNotEmpty && await _localSourceAvailable(directSource)) {
      _rememberSource(cleanId, directSource);
      return item.copyWith(id: cleanId, source: directSource);
    }

    if (cleanStoragePath.isNotEmpty) {
      try {
        final cachedPath = await _downloadStorageAudioToCache(
          cleanStoragePath,
          forceRefresh: forceStorageRefresh,
        );
        if (cachedPath.isNotEmpty) {
          _rememberSource(cleanId, cachedPath);
          return item.copyWith(
            id: cleanId,
            source: cachedPath,
            storagePath: cleanStoragePath,
          );
        }
      } catch (error) {
        if (kDebugMode) {
          debugPrint('Storage audio download failed for $cleanStoragePath: $error');
        }
      }

      if (_isHttpSource(directSource)) {
        return item.copyWith(id: cleanId, source: directSource, storagePath: cleanStoragePath);
      }

      final resolved = await _resolveWithCallback(
        item.copyWith(id: cleanId, source: '', storagePath: cleanStoragePath),
      );
      if (resolved.isNotEmpty) {
        return item.copyWith(id: cleanId, source: resolved, storagePath: cleanStoragePath);
      }

      return null;
    }

    if (_isHttpSource(directSource)) {
      _rememberSource(cleanId, directSource);
      return item.copyWith(id: cleanId, source: directSource);
    }

    final registeredSource = (_registeredSources[cleanId] ?? '').trim();
    if (registeredSource.isNotEmpty) {
      if (_isHttpSource(registeredSource) || await _localSourceAvailable(registeredSource)) {
        return item.copyWith(id: cleanId, source: registeredSource);
      }
      _registeredSources.remove(cleanId);
    }

    final resolved = await _resolveWithCallback(item.copyWith(id: cleanId, source: ''));
    if (resolved.isNotEmpty) {
      return item.copyWith(id: cleanId, source: resolved);
    }

    return null;
  }

  static Duration _clampPosition(Duration position, Duration duration) {
    if (position < Duration.zero) return Duration.zero;
    if (duration > Duration.zero && position > duration) return duration;
    return position;
  }

  static List<ChatAudioPlaybackItem> _cleanQueue(
    List<ChatAudioPlaybackItem> queue,
  ) {
    final seen = <String>{};
    final cleaned = <ChatAudioPlaybackItem>[];

    for (final item in queue) {
      final id = item.id.trim();
      if (id.isEmpty || !seen.add(id)) continue;
      cleaned.add(item.copyWith(id: id));
    }

    return cleaned;
  }

  static void _prepareQueue({
    required String id,
    required String source,
    required List<ChatAudioPlaybackItem> queue,
  }) {
    final cleanId = id.trim();
    final providedSource = source.trim();
    final cleanQueue = _cleanQueue(queue);

    _queue = cleanQueue.isEmpty
        ? [ChatAudioPlaybackItem(id: cleanId, source: providedSource)]
        : cleanQueue;

    _queueIndex = _queue.indexWhere((item) => item.id == cleanId);
    if (_queueIndex < 0) {
      _queue = [
        ChatAudioPlaybackItem(id: cleanId, source: providedSource),
        ..._queue,
      ];
      _queueIndex = 0;
    }
  }

  static void _beginPlayback() {
    unawaited(
      _player.play().catchError((Object error, StackTrace stackTrace) {
        if (kDebugMode) debugPrint('Audio playback failed after start: $error');
        _state.value = _state.value.copyWith(
          isPlaying: false,
          isBuffering: false,
        );
      }),
    );
  }

  static Future<void> _loadAndPlay(
    ChatAudioPlaybackItem item, {
    Duration initialPosition = Duration.zero,
    bool forceStorageRefresh = false,
    bool allowRetry = true,
  }) async {
    _ensureInitialized();

    final loadId = ++_loadSerial;
    final playable = await _withPlayableSource(
      item,
      forceStorageRefresh: forceStorageRefresh,
    );
    if (loadId != _loadSerial) return;

    if (playable == null) {
      _state.value = ChatAudioPlaybackState(speed: currentSpeed);
      throw StateError('No playable audio source');
    }

    final cleanSource = playable.source.trim();
    _changingSource = true;
    _currentId = playable.id;
    _state.value = ChatAudioPlaybackState(
      id: playable.id,
      source: cleanSource,
      isBuffering: true,
      speed: currentSpeed,
    );

    try {
      await _player.stop();
      if (loadId != _loadSerial) return;

      final duration = await _setSource(cleanSource) ?? Duration.zero;
      if (loadId != _loadSerial) return;

      await _player.setSpeed(currentSpeed);
      if (loadId != _loadSerial) return;

      final startAt = _clampPosition(initialPosition, duration);
      if (startAt > Duration.zero) {
        await _player.seek(startAt);
        if (loadId != _loadSerial) return;
      }

      _changingSource = false;
      _state.value = _state.value.copyWith(
        duration: duration,
        position: startAt,
        isBuffering: false,
        isPlaying: true,
        speed: currentSpeed,
      );
      _beginPlayback();
    } catch (error) {
      if (kDebugMode) debugPrint('Voice note source failed: $error');

      if (loadId != _loadSerial) {
        _changingSource = false;
        return;
      }

      _changingSource = false;

      if (allowRetry && playable.storagePath.trim().isNotEmpty) {
        await _deleteCacheForStoragePath(playable.storagePath);
        await _loadAndPlay(
          playable.copyWith(source: ''),
          initialPosition: initialPosition,
          forceStorageRefresh: true,
          allowRetry: false,
        );
        return;
      }

      _currentId = null;
      _state.value = ChatAudioPlaybackState(speed: currentSpeed);
      rethrow;
    }
  }

  static Future<void> playOrPause(
    String source, {
    String? id,
    List<ChatAudioPlaybackItem> queue = const [],
    ChatAudioSourceResolver? resolveSource,
  }) async {
    final providedSource = source.trim();
    final cleanId = id?.trim().isNotEmpty == true ? id!.trim() : providedSource;
    if (cleanId.isEmpty) return;

    _ensureInitialized();
    _sourceResolver = resolveSource;

    if (_currentId == cleanId) {
      if (_player.playing) {
        await pause();
        return;
      }

      final duration = _player.duration ?? _state.value.duration;
      if (duration > Duration.zero && _player.position >= duration) {
        await _player.seek(Duration.zero);
        _state.value = _state.value.copyWith(position: Duration.zero);
      }

      await _player.setSpeed(currentSpeed);
      _state.value = _state.value.copyWith(
        isPlaying: true,
        isBuffering: false,
        speed: currentSpeed,
      );
      _beginPlayback();
      return;
    }

    _prepareQueue(id: cleanId, source: providedSource, queue: queue);
    await _loadAndPlay(_queue[_queueIndex]);
  }

  static Future<void> seekToPosition(
    Duration position, {
    required String id,
    String source = '',
    List<ChatAudioPlaybackItem> queue = const [],
    ChatAudioSourceResolver? resolveSource,
  }) async {
    final cleanId = id.trim();
    if (cleanId.isEmpty) return;

    _ensureInitialized();
    _sourceResolver = resolveSource;

    var target = position < Duration.zero ? Duration.zero : position;

    if (_currentId != cleanId) {
      _prepareQueue(id: cleanId, source: source.trim(), queue: queue);
      await _loadAndPlay(_queue[_queueIndex], initialPosition: target);
      return;
    }

    final duration = _player.duration ?? _state.value.duration;
    target = _clampPosition(target, duration);
    await _player.seek(target);
    _state.value = _state.value.copyWith(position: target);
  }

  static Future<void> cycleSpeed() async {
    _ensureInitialized();

    _speedIndex = (_speedIndex + 1) % _speedOptions.length;
    final nextSpeed = currentSpeed;
    await _player.setSpeed(nextSpeed);
    _state.value = _state.value.copyWith(speed: nextSpeed);
  }

  static Future<void> pause() async {
    _ensureInitialized();

    await _player.pause();
    _state.value = _state.value.copyWith(
      isPlaying: false,
      isBuffering: false,
    );
  }

  static Future<void> _playNextOrStop() async {
    if (_changingSource) return;

    var nextIndex = _queueIndex + 1;
    while (nextIndex >= 0 && nextIndex < _queue.length) {
      try {
        final nextItem = await _withPlayableSource(_queue[nextIndex]);
        if (nextItem != null) {
          _queueIndex = nextIndex;
          await _loadAndPlay(nextItem);
          return;
        }
      } catch (error) {
        if (kDebugMode) {
          debugPrint('Skipping failed voice note at queue index $nextIndex: $error');
        }
      }
      nextIndex++;
    }

    final finishedState = _state.value;
    final finishedDuration = _player.duration ?? finishedState.duration;
    _loadSerial++;

    await _player.stop();
    _currentId = null;
    _queue = const [];
    _queueIndex = -1;

    _state.value = finishedState.copyWith(
      isPlaying: false,
      isBuffering: false,
      position: finishedDuration > Duration.zero
          ? finishedDuration
          : finishedState.position,
      duration: finishedDuration,
      speed: currentSpeed,
    );
  }

  static Future<void> stop() async {
    _ensureInitialized();
    _loadSerial++;

    await _player.stop();
    _currentId = null;
    _queue = const [];
    _queueIndex = -1;
    _state.value = ChatAudioPlaybackState(speed: currentSpeed);
  }
}
