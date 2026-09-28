import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:firebase_storage/firebase_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DownloadableAttachment {
  final String groupId;
  final String messageId;
  final String type;
  final String storagePath;
  final String? directUrl;
  final String? localFilePath;
  final String? fileName;
  final String? thumbnailStoragePath;
  final String? thumbnailDirectUrl;
  final String? localThumbnailPath;

  const DownloadableAttachment({
    required this.groupId,
    required this.messageId,
    required this.type,
    required this.storagePath,
    this.directUrl,
    this.localFilePath,
    this.fileName,
    this.thumbnailStoragePath,
    this.thumbnailDirectUrl,
    this.localThumbnailPath,
  });

  String get cleanStoragePath =>
      storagePath.trim().replaceFirst(RegExp(r'^/+'), '');

  String get cleanThumbnailStoragePath =>
      (thumbnailStoragePath ?? '').trim().replaceFirst(RegExp(r'^/+'), '');

  String get key {
    final pathKey =
        cleanStoragePath.isNotEmpty
            ? cleanStoragePath
            : (directUrl ?? localFilePath ?? messageId).trim();
    return '$groupId|$messageId|$pathKey';
  }

  bool get canSave =>
      cleanStoragePath.isNotEmpty ||
      (directUrl?.trim().isNotEmpty ?? false) ||
      (localFilePath?.trim().isNotEmpty ?? false);

  String get safeDisplayName {
    final fromFileName = fileName?.trim();
    if (fromFileName != null && fromFileName.isNotEmpty) return fromFileName;

    final pathSource =
        cleanStoragePath.isNotEmpty ? cleanStoragePath : (directUrl ?? '');
    final uriSegments =
        Uri.tryParse(pathSource)?.pathSegments ?? const <String>[];
    final nonEmptyUriSegments =
        uriSegments.where((part) => part.trim().isNotEmpty).toList();
    final nonEmptyPathSegments =
        pathSource.split('/').where((part) => part.trim().isNotEmpty).toList();
    final lastSegment =
        nonEmptyUriSegments.isNotEmpty
            ? nonEmptyUriSegments.last
            : nonEmptyPathSegments.isNotEmpty
            ? nonEmptyPathSegments.last
            : '';

    if (lastSegment.trim().isNotEmpty) {
      return lastSegment.trim();
    }

    switch (type) {
      case 'image':
        return 'image_$messageId.jpg';
      case 'video':
        return 'video_$messageId.mp4';
      case 'audio':
        return 'audio_$messageId.m4a';
      default:
        return 'file_$messageId';
    }
  }
}

class SavedAttachmentRecord {
  final String key;
  final String groupId;
  final String messageId;
  final String type;
  final String fileName;
  final String path;
  final String thumbnailPath;
  final String thumbnailUrl;
  final String thumbnailStoragePath;
  final int savedAt;
  final int sizeBytes;

  const SavedAttachmentRecord({
    required this.key,
    required this.groupId,
    required this.messageId,
    required this.type,
    required this.fileName,
    required this.path,
    this.thumbnailPath = '',
    this.thumbnailUrl = '',
    this.thumbnailStoragePath = '',
    required this.savedAt,
    required this.sizeBytes,
  });

  factory SavedAttachmentRecord.fromMap(Map<String, dynamic> map) {
    return SavedAttachmentRecord(
      key: map['key']?.toString() ?? '',
      groupId: map['groupId']?.toString() ?? '',
      messageId: map['messageId']?.toString() ?? '',
      type: map['type']?.toString() ?? 'file',
      fileName: map['fileName']?.toString() ?? '',
      path: map['path']?.toString() ?? '',
      thumbnailPath: map['thumbnailPath']?.toString() ?? '',
      thumbnailUrl: map['thumbnailUrl']?.toString() ?? '',
      thumbnailStoragePath: map['thumbnailStoragePath']?.toString() ?? '',
      savedAt: int.tryParse(map['savedAt']?.toString() ?? '0') ?? 0,
      sizeBytes: int.tryParse(map['sizeBytes']?.toString() ?? '0') ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
    'key': key,
    'groupId': groupId,
    'messageId': messageId,
    'type': type,
    'fileName': fileName,
    'path': path,
    if (thumbnailPath.trim().isNotEmpty) 'thumbnailPath': thumbnailPath,
    if (thumbnailUrl.trim().isNotEmpty) 'thumbnailUrl': thumbnailUrl,
    if (thumbnailStoragePath.trim().isNotEmpty)
      'thumbnailStoragePath': thumbnailStoragePath,
    'savedAt': savedAt,
    'sizeBytes': sizeBytes,
  };
}

class AttachmentDownloadSnapshot {
  final bool isDownloading;
  final bool isSaved;
  final bool hasFailed;
  final double progress;
  final Duration? remaining;
  final String? savedPath;
  final String? errorMessage;

  const AttachmentDownloadSnapshot({
    required this.isDownloading,
    required this.isSaved,
    required this.hasFailed,
    required this.progress,
    this.remaining,
    this.savedPath,
    this.errorMessage,
  });

  const AttachmentDownloadSnapshot.idle()
    : isDownloading = false,
      isSaved = false,
      hasFailed = false,
      progress = 0,
      remaining = null,
      savedPath = null,
      errorMessage = null;

  AttachmentDownloadSnapshot copyWith({
    bool? isDownloading,
    bool? isSaved,
    bool? hasFailed,
    double? progress,
    Duration? remaining,
    String? savedPath,
    String? errorMessage,
  }) {
    return AttachmentDownloadSnapshot(
      isDownloading: isDownloading ?? this.isDownloading,
      isSaved: isSaved ?? this.isSaved,
      hasFailed: hasFailed ?? this.hasFailed,
      progress: progress ?? this.progress,
      remaining: remaining ?? this.remaining,
      savedPath: savedPath ?? this.savedPath,
      errorMessage: errorMessage,
    );
  }
}

class AttachmentDownloadService {
  static final AttachmentDownloadService instance =
      AttachmentDownloadService._();

  AttachmentDownloadService._();

  static const String _prefsPrefix = 'saved_attachment_path_v1:';
  static const String _recordsPrefsKey = 'saved_attachment_records_v1';
  static const int _maxFileNameLength = 110;
  static const int _maxSavedRecords = 250;
  static const int _maxTrackedAttachments = 300;

  final FirebaseStorage _storage = FirebaseStorage.instance;
  final Map<String, AttachmentDownloadSnapshot> _snapshots = {};
  final Map<String, StreamController<AttachmentDownloadSnapshot>> _controllers =
      {};
  final Set<String> _activeDownloads = {};
  Future<Directory>? _saveRootDirectoryFuture;
  Future<void> _recordsWriteQueue = Future<void>.value();

  AttachmentDownloadSnapshot snapshotOf(DownloadableAttachment attachment) {
    return _snapshots[attachment.key] ??
        const AttachmentDownloadSnapshot.idle();
  }

  Stream<AttachmentDownloadSnapshot> watch(DownloadableAttachment attachment) {
    final controller = _controllerFor(attachment.key);
    _trimTrackedAttachments(keepKey: attachment.key);
    return controller.stream;
  }

  Future<void> refreshSavedState(DownloadableAttachment attachment) async {
    final savedPath = await savedPathFor(attachment);
    if (savedPath == null) {
      final current = snapshotOf(attachment);
      if (current.isSaved) {
        _emit(attachment.key, const AttachmentDownloadSnapshot.idle());
      }
      return;
    }

    _emit(
      attachment.key,
      AttachmentDownloadSnapshot(
        isDownloading: false,
        isSaved: true,
        hasFailed: false,
        progress: 1,
        savedPath: savedPath,
      ),
    );
  }

  Future<String?> savedPathFor(DownloadableAttachment attachment) async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString('$_prefsPrefix${attachment.key}')?.trim();
    if (path == null || path.isEmpty) return null;

    final file = File(path);
    if (await file.exists()) return path;

    await prefs.remove('$_prefsPrefix${attachment.key}');
    await _removeRecord(attachment.key);
    return null;
  }

  Future<List<SavedAttachmentRecord>> savedAttachments() {
    return _withRecordsLock(() async {
      final records = await _readRecords();
      final checkedRecords = await Future.wait(
        records.map((record) async {
          if (record.path.trim().isEmpty || !await File(record.path).exists()) {
            return null;
          }
          return record;
        }),
      );
      final validRecords = checkedRecords
          .whereType<SavedAttachmentRecord>()
          .toList(growable: false)
        ..sort((a, b) => b.savedAt.compareTo(a.savedAt));

      if (validRecords.length != records.length) {
        await _writeRecordsUnlocked(validRecords);
      }
      return validRecords;
    });
  }

  Future<void> removeSavedAttachment(
    SavedAttachmentRecord record, {
    bool deleteFile = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefsPrefix${record.key}');
    await _removeRecord(record.key);

    if (deleteFile) {
      final file = File(record.path);
      if (await file.exists()) await file.delete();

      final thumbnailPath = record.thumbnailPath.trim();
      if (thumbnailPath.isNotEmpty && thumbnailPath != record.path.trim()) {
        final thumbnailFile = File(thumbnailPath);
        if (await thumbnailFile.exists()) await thumbnailFile.delete();
      }
    }

    _emit(record.key, const AttachmentDownloadSnapshot.idle());
  }

  Future<String> save(DownloadableAttachment attachment) async {
    if (!attachment.canSave) {
      throw Exception('legacy.attachment_not_available_save');
    }

    final existingPath = await savedPathFor(attachment);
    if (existingPath != null) {
      await _upsertRecord(attachment, existingPath);
      _emitSaved(attachment.key, existingPath);
      return existingPath;
    }

    if (_activeDownloads.contains(attachment.key)) {
      return _waitForActiveDownload(attachment.key);
    }

    _activeDownloads.add(attachment.key);
    final startedAt = DateTime.now();
    File? targetFile;

    try {
      _emit(
        attachment.key,
        const AttachmentDownloadSnapshot(
          isDownloading: true,
          isSaved: false,
          hasFailed: false,
          progress: 0,
        ),
      );

      final destination = await _createTargetFile(attachment);
      targetFile = destination;

      final localPath = attachment.localFilePath?.trim();
      if (localPath != null && localPath.isNotEmpty) {
        final localFile = File(localPath);
        if (await localFile.exists()) {
          await localFile.copy(destination.path);
          if (await destination.length() <= 0) {
            throw Exception('chat.could_not_save_try_again');
          }
          await _persistSavedPath(attachment.key, destination.path);
          await _upsertRecord(attachment, destination.path);
          _emitSaved(attachment.key, destination.path);
          return destination.path;
        }
      }

      final cleanStoragePath = attachment.cleanStoragePath;
      if (cleanStoragePath.isNotEmpty) {
        await _downloadFromStorage(
          key: attachment.key,
          storagePath: cleanStoragePath,
          targetFile: destination,
          startedAt: startedAt,
        );
      } else {
        final downloadUrl = attachment.directUrl?.trim();
        if (downloadUrl == null || downloadUrl.isEmpty) {
          throw Exception('legacy.attachment_not_available_save');
        }
        await _downloadFromUrl(
          key: attachment.key,
          url: downloadUrl,
          targetFile: destination,
          startedAt: startedAt,
        );
      }

      if (!await destination.exists() || await destination.length() <= 0) {
        throw Exception('chat.could_not_save_try_again');
      }

      await _persistSavedPath(attachment.key, destination.path);
      await _upsertRecord(attachment, destination.path);
      _emitSaved(attachment.key, destination.path);
      return destination.path;
    } catch (error) {
      final partialFile = targetFile;
      if (partialFile != null && await partialFile.exists()) {
        await partialFile.delete().catchError((_) => partialFile);
      }
      _emit(
        attachment.key,
        AttachmentDownloadSnapshot(
          isDownloading: false,
          isSaved: false,
          hasFailed: true,
          progress: 0,
          errorMessage: error.toString(),
        ),
      );
      rethrow;
    } finally {
      _activeDownloads.remove(attachment.key);
      _trimTrackedAttachments(keepKey: attachment.key);
    }
  }

  Future<String> _waitForActiveDownload(String key) async {
    final completer = Completer<String>();
    late final StreamSubscription<AttachmentDownloadSnapshot> subscription;

    subscription = _controllerFor(key).stream.listen((snapshot) {
      if (snapshot.isSaved && snapshot.savedPath != null) {
        if (!completer.isCompleted) completer.complete(snapshot.savedPath!);
      }
      if (snapshot.hasFailed) {
        if (!completer.isCompleted) {
          completer.completeError(
            Exception(snapshot.errorMessage ?? 'chat.could_not_save_try_again'),
          );
        }
      }
    });

    final current = _snapshots[key];
    if (current?.isSaved == true && current?.savedPath != null) {
      completer.complete(current!.savedPath!);
    } else if (current?.hasFailed == true) {
      completer.completeError(
        Exception(current?.errorMessage ?? 'chat.could_not_save_try_again'),
      );
    }

    try {
      return await completer.future.timeout(const Duration(minutes: 5));
    } finally {
      await subscription.cancel();
    }
  }

  Future<void> _downloadFromStorage({
    required String key,
    required String storagePath,
    required File targetFile,
    required DateTime startedAt,
  }) async {
    final task = _storage.ref().child(storagePath).writeToFile(targetFile);

    late final StreamSubscription<TaskSnapshot> subscription;
    subscription = task.snapshotEvents.listen((snapshot) {
      final totalBytes = snapshot.totalBytes;
      final transferred = snapshot.bytesTransferred;
      final progress = totalBytes > 0 ? transferred / totalBytes : 0.0;
      _emitProgress(
        key: key,
        progress: progress,
        bytesTransferred: transferred,
        totalBytes: totalBytes,
        startedAt: startedAt,
      );
    });

    try {
      final snapshot = await task;
      _emitProgress(
        key: key,
        progress: 1,
        bytesTransferred: snapshot.totalBytes,
        totalBytes: snapshot.totalBytes,
        startedAt: startedAt,
      );
    } finally {
      await subscription.cancel();
    }
  }

  Future<void> _downloadFromUrl({
    required String key,
    required String url,
    required File targetFile,
    required DateTime startedAt,
  }) async {
    final uri = Uri.parse(url);
    final client = HttpClient();

    try {
      final request = await client.getUrl(uri);
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'Download failed with status ${response.statusCode}',
        );
      }

      final totalBytes =
          response.contentLength > 0 ? response.contentLength : 0;
      var transferred = 0;
      final sink = targetFile.openWrite();

      try {
        await for (final chunk in response) {
          transferred += chunk.length;
          sink.add(chunk);
          _emitProgress(
            key: key,
            progress: totalBytes > 0 ? transferred / totalBytes : 0,
            bytesTransferred: transferred,
            totalBytes: totalBytes,
            startedAt: startedAt,
          );
        }
      } finally {
        await sink.close();
      }
    } finally {
      client.close(force: true);
    }
  }

  Future<File> _createTargetFile(DownloadableAttachment attachment) async {
    final root = await _bestSaveRootDirectory();
    final typeFolder = switch (attachment.type) {
      'image' => 'Images',
      'video' => 'Videos',
      'audio' => 'Audio',
      _ => 'Files',
    };

    final directory = Directory(
      '${root.path}${Platform.pathSeparator}$typeFolder',
    );
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    final cleanFileName = _sanitizeFileName(attachment.safeDisplayName);
    return _uniqueFile(directory, cleanFileName);
  }

  Future<Directory> _bestSaveRootDirectory() async {
    final existing = _saveRootDirectoryFuture;
    if (existing != null) return existing;

    final pending = _resolveBestSaveRootDirectory();
    _saveRootDirectoryFuture = pending;
    try {
      return await pending;
    } catch (_) {
      if (identical(_saveRootDirectoryFuture, pending)) {
        _saveRootDirectoryFuture = null;
      }
      rethrow;
    }
  }

  Future<Directory> _resolveBestSaveRootDirectory() async {
    if (Platform.isAndroid) {
      final publicDownloads = Directory(
        '/storage/emulated/0/Download/AlwatanyaChat',
      );
      try {
        if (!await publicDownloads.exists()) {
          await publicDownloads.create(recursive: true);
        }
        final probe = File(
          '${publicDownloads.path}${Platform.pathSeparator}.write_test_${DateTime.now().microsecondsSinceEpoch}',
        );
        await probe.writeAsString('ok', flush: true);
        await probe.delete();
        return publicDownloads;
      } catch (_) {
        // Scoped storage may prevent direct writes on some Android versions.
      }
    }

    final externalDirectory = await getExternalStorageDirectory();
    if (externalDirectory != null) {
      final directory = Directory(
        '${externalDirectory.path}${Platform.pathSeparator}AlwatanyaChat',
      );
      await directory.create(recursive: true);
      return directory;
    }

    final documentsDirectory = await getApplicationDocumentsDirectory();
    final directory = Directory(
      '${documentsDirectory.path}${Platform.pathSeparator}AlwatanyaChat',
    );
    await directory.create(recursive: true);
    return directory;
  }

  File _uniqueFile(Directory directory, String fileName) {
    final dotIndex = fileName.lastIndexOf('.');
    final baseName = dotIndex > 0 ? fileName.substring(0, dotIndex) : fileName;
    final extension = dotIndex > 0 ? fileName.substring(dotIndex) : '';

    var candidate = File('${directory.path}${Platform.pathSeparator}$fileName');
    var counter = 1;
    while (candidate.existsSync()) {
      candidate = File(
        '${directory.path}${Platform.pathSeparator}${baseName}_$counter$extension',
      );
      counter++;
    }

    return candidate;
  }

  String _sanitizeFileName(String value) {
    var fileName = value.trim();
    if (fileName.isEmpty) {
      fileName = 'attachment_${DateTime.now().millisecondsSinceEpoch}';
    }

    fileName =
        fileName
            .replaceAll(RegExp(r'[\\/:*?"<>|\n\r\t]'), '_')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();

    if (fileName.length > _maxFileNameLength) {
      final dotIndex = fileName.lastIndexOf('.');
      final extension = dotIndex > 0 ? fileName.substring(dotIndex) : '';
      final allowedBaseLength = math.max(
        24,
        _maxFileNameLength - extension.length,
      );
      fileName = '${fileName.substring(0, allowedBaseLength)}$extension';
    }

    return fileName;
  }

  Future<List<SavedAttachmentRecord>> _readRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_recordsPrefsKey) ?? const <String>[];
    final records = <SavedAttachmentRecord>[];

    for (final item in raw) {
      try {
        final decoded = jsonDecode(item);
        if (decoded is Map<String, dynamic>) {
          final record = SavedAttachmentRecord.fromMap(decoded);
          if (record.key.trim().isNotEmpty && record.path.trim().isNotEmpty) {
            records.add(record);
          }
        }
      } catch (_) {
        // Skip malformed legacy entries.
      }
    }

    return records;
  }

  Future<void> _writeRecordsUnlocked(
    List<SavedAttachmentRecord> records,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final unique = <String, SavedAttachmentRecord>{};
    for (final record in records) {
      unique[record.key] = record;
    }

    final recordsToPersist =
        unique.values.toList()..sort((a, b) => b.savedAt.compareTo(a.savedAt));

    final encoded = recordsToPersist
        .take(_maxSavedRecords)
        .map((record) => jsonEncode(record.toMap()))
        .toList(growable: false);
    await prefs.setStringList(_recordsPrefsKey, encoded);
  }

  Future<void> _upsertRecord(
    DownloadableAttachment attachment,
    String path,
  ) async {
    await _withRecordsLock(() async {
      final records = await _readRecords();
      final filtered =
          records.where((record) => record.key != attachment.key).toList();
      final file = File(path);
      final sizeBytes = await file.exists() ? await file.length() : 0;

      filtered.add(
        SavedAttachmentRecord(
          key: attachment.key,
          groupId: attachment.groupId,
          messageId: attachment.messageId,
          type: attachment.type,
          fileName: attachment.safeDisplayName,
          path: path,
          thumbnailPath: attachment.localThumbnailPath?.trim() ?? '',
          thumbnailUrl: attachment.thumbnailDirectUrl?.trim() ?? '',
          thumbnailStoragePath: attachment.cleanThumbnailStoragePath,
          savedAt: DateTime.now().millisecondsSinceEpoch,
          sizeBytes: sizeBytes,
        ),
      );

      await _writeRecordsUnlocked(filtered);
    });
  }

  Future<void> _removeRecord(String key) async {
    await _withRecordsLock(() async {
      final records = await _readRecords();
      await _writeRecordsUnlocked(
        records.where((record) => record.key != key).toList(),
      );
    });
  }

  Future<T> _withRecordsLock<T>(Future<T> Function() operation) {
    final completer = Completer<T>();
    _recordsWriteQueue = _recordsWriteQueue.then((_) async {
      try {
        completer.complete(await operation());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  Future<void> _persistSavedPath(String key, String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_prefsPrefix$key', path);
  }

  StreamController<AttachmentDownloadSnapshot> _controllerFor(String key) {
    return _controllers.putIfAbsent(
      key,
      () => StreamController<AttachmentDownloadSnapshot>.broadcast(),
    );
  }

  void _trimTrackedAttachments({String? keepKey}) {
    if (_controllers.length <= _maxTrackedAttachments) return;

    for (final key in _controllers.keys.toList(growable: false)) {
      if (_controllers.length <= _maxTrackedAttachments) break;
      if (key == keepKey || _activeDownloads.contains(key)) continue;

      final controller = _controllers[key];
      if (controller == null || controller.hasListener) continue;

      _controllers.remove(key);
      _snapshots.remove(key);
      if (!controller.isClosed) unawaited(controller.close());
    }
  }

  void _emit(String key, AttachmentDownloadSnapshot snapshot) {
    _snapshots[key] = snapshot;
    final controller = _controllerFor(key);
    if (!controller.isClosed) controller.add(snapshot);
  }

  void _emitSaved(String key, String savedPath) {
    _emit(
      key,
      AttachmentDownloadSnapshot(
        isDownloading: false,
        isSaved: true,
        hasFailed: false,
        progress: 1,
        savedPath: savedPath,
      ),
    );
  }

  void _emitProgress({
    required String key,
    required double progress,
    required int bytesTransferred,
    required int totalBytes,
    required DateTime startedAt,
  }) {
    final elapsed = DateTime.now().difference(startedAt);
    Duration? remaining;

    if (bytesTransferred > 0 &&
        totalBytes > bytesTransferred &&
        elapsed.inMilliseconds > 0) {
      final bytesPerMillisecond = bytesTransferred / elapsed.inMilliseconds;
      final remainingBytes = totalBytes - bytesTransferred;
      final remainingMilliseconds = remainingBytes / bytesPerMillisecond;
      if (remainingMilliseconds.isFinite && remainingMilliseconds > 0) {
        remaining = Duration(milliseconds: remainingMilliseconds.round());
      }
    }

    _emit(
      key,
      AttachmentDownloadSnapshot(
        isDownloading: true,
        isSaved: false,
        hasFailed: false,
        progress: progress.clamp(0.0, 1.0).toDouble(),
        remaining: remaining,
      ),
    );
  }
}
