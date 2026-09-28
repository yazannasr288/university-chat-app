part of '../chat_controller.dart';

extension ChatAttachmentHelpers on ChatController {
  Future<void> _deleteLocalFileQuietly(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
    }
  }

  Future<bool> _waitForStableLocalFile(File file) async {
    var previousLength = -1;

    for (var attempt = 0; attempt < 8; attempt++) {
      if (!await file.exists()) return false;

      final length = await file.length();
      if (length > 512 && length == previousLength) {
        return true;
      }

      previousLength = length;
      await Future<void>.delayed(const Duration(milliseconds: 120));
    }

    return await file.exists() && await file.length() > 512;
  }

  Future<File?> _createVideoThumbnail(File videoFile) async {
    try {
      final bytes = await VideoThumbnail.thumbnailData(
        video: videoFile.path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 640,
        quality: 65,
      );

      if (bytes == null || bytes.isEmpty) {
        if (kDebugMode) {
          debugPrint('Video thumbnail generation returned empty bytes.');
        }
        return null;
      }

      final thumbnailFile = File(
        '${Directory.systemTemp.path}${Platform.pathSeparator}'
        'chat_video_thumb_${DateTime.now().microsecondsSinceEpoch}.jpg',
      );
      await thumbnailFile.writeAsBytes(bytes, flush: true);

      if (!await thumbnailFile.exists() || await thumbnailFile.length() == 0) {
        if (kDebugMode) {
          debugPrint('Video thumbnail file was not created correctly.');
        }
        return null;
      }

      return thumbnailFile;
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Video thumbnail generation failed: $error');
      }
      return null;
    }
  }

  ChatAttachmentType? _attachmentTypeFromValue(String value) {
    for (final type in ChatAttachmentType.values) {
      if (type.value == value) return type;
    }
    return null;
  }

  int _safeClientMessageTime(int requestedTime) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final earliestAllowed = now - const Duration(seconds: 55).inMilliseconds;
    final latestAllowed = now + const Duration(seconds: 55).inMilliseconds;

    if (requestedTime >= earliestAllowed && requestedTime <= latestAllowed) {
      return requestedTime;
    }

    return now;
  }

}
