import 'dart:io';

import '../constants/app_storage_folders.dart';

abstract final class AppFileMetadata {
  static const Map<String, String> _imageContentTypes = {
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'webp': 'image/webp',
  };

  static const Map<String, String> _videoContentTypes = {
    'mp4': 'video/mp4',
    'mov': 'video/quicktime',
    'm4v': 'video/x-m4v',
    'webm': 'video/webm',
  };

  static const Map<String, String> _audioContentTypes = {
    'm4a': 'audio/mp4',
    'mp3': 'audio/mpeg',
    'wav': 'audio/wav',
    'aac': 'audio/aac',
    'ogg': 'audio/ogg',
  };

  static const Map<String, String> _genericFileContentTypes = {
    'pdf': 'application/pdf',
    'doc': 'application/msword',
    'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'xls': 'application/vnd.ms-excel',
    'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'ppt': 'application/vnd.ms-powerpoint',
    'pptx': 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'txt': 'text/plain',
  };

  static const Map<String, int> _maxBytesByFolder = {
    AppStorageFolders.groupIcons: 3 * 1024 * 1024,
    AppStorageFolders.profileImages: 3 * 1024 * 1024,
    AppStorageFolders.chatImages: 8 * 1024 * 1024,
    AppStorageFolders.chatAudio: 15 * 1024 * 1024,
    AppStorageFolders.chatVideoThumbnails: 2 * 1024 * 1024,
    AppStorageFolders.files: 20 * 1024 * 1024,
    AppStorageFolders.chatVideos: 60 * 1024 * 1024,
  };

  static String cleanFileName(String? fileName) => fileName?.trim() ?? '';

  static String sourceNameFor(File file, {String? fileName}) {
    final cleanName = cleanFileName(fileName);
    if (cleanName.isNotEmpty) return cleanName;
    return file.path.split(Platform.pathSeparator).last;
  }

  static String extensionFromName(String? fileName) {
    final cleanName = cleanFileName(fileName);
    final dot = cleanName.lastIndexOf('.');
    if (dot == -1 || dot == cleanName.length - 1) return '';
    return cleanName.substring(dot + 1).toLowerCase();
  }

  static String extensionFor(File file, {String? fileName}) {
    return extensionFromName(sourceNameFor(file, fileName: fileName));
  }

  static String extensionWithDotFor(File file, {String? fileName}) {
    final source = sourceNameFor(file, fileName: fileName);
    final dot = source.lastIndexOf('.');
    if (dot == -1 || dot == source.length - 1) return '';
    return source.substring(dot);
  }

  static String contentTypeFor({
    required File file,
    required String folder,
    String? fileName,
  }) {
    final ext = extensionFor(file, fileName: fileName);

    if (AppStorageFolders.isImageFolder(folder)) {
      return _imageContentTypes[ext] ?? 'application/octet-stream';
    }

    if (AppStorageFolders.isVideoFolder(folder)) {
      return _videoContentTypes[ext] ?? 'application/octet-stream';
    }

    if (AppStorageFolders.isAudioFolder(folder)) {
      return _audioContentTypes[ext] ?? 'application/octet-stream';
    }

    return _genericFileContentTypes[ext] ?? 'application/octet-stream';
  }

  static int maxBytesForFolder(String folder) {
    return _maxBytesByFolder[folder] ?? _maxBytesByFolder[AppStorageFolders.chatImages]!;
  }

  static bool isAllowedImageContentType(String contentType) {
    return _imageContentTypes.values.contains(contentType);
  }

  static bool isAllowedGenericFileContentType(String contentType) {
    return _genericFileContentTypes.values.contains(contentType);
  }
}
