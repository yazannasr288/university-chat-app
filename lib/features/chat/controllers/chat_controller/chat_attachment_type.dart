part of '../chat_controller.dart';

enum ChatAttachmentType { image, video, audio, file }

extension ChatAttachmentTypeX on ChatAttachmentType {
  String get folder {
    switch (this) {
      case ChatAttachmentType.image:
        return AppStorageFolders.chatImages;
      case ChatAttachmentType.video:
        return AppStorageFolders.chatVideos;
      case ChatAttachmentType.audio:
        return AppStorageFolders.chatAudio;
      case ChatAttachmentType.file:
        return AppStorageFolders.files;
    }
  }



  String get value => name;

  String fallbackMessage(String? fileName) {
    switch (this) {
      case ChatAttachmentType.image:
        return '📷 صورة';
      case ChatAttachmentType.video:
        return '🎥 فيديو';
      case ChatAttachmentType.audio:
        return '🎤 رسالة صوتية';
      case ChatAttachmentType.file:
        return fileName?.trim().isNotEmpty == true ? fileName!.trim() : '📎 ملف';
    }
  }
}
