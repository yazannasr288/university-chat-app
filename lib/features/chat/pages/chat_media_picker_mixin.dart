import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:easy_localization/easy_localization.dart';
import '../controllers/chat_controller.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../../core/utils/error_message.dart';
import '../../../core/theme/app_theme.dart';

class PickedChatFile {
  final File file;
  final String? name;

  const PickedChatFile({
    required this.file,
    this.name,
  });
}

mixin ChatMediaPickerMixin<T extends StatefulWidget> on State<T> {
  final ImagePicker picker = ImagePicker();

  Future<bool> confirmSend({
    required Widget preview,
    required String title,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: context.appCardColorStrong,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          side: BorderSide(color: context.appBorder),
        ),
        title: Text(
          title.tr(),
          style: context.textTheme.titleMedium?.copyWith(
            color: context.appTextPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: DefaultTextStyle(
          style: context.textTheme.bodyMedium!.copyWith(
            color: context.appTextPrimary,
          ),
          child: preview,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('common.cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('common.send'.tr()),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  Future<void> pickAndSend({
    required Future<PickedChatFile?> Function() pickerFunc,
    required String title,
    required Widget Function(PickedChatFile item) previewBuilder,
    required Future<void> Function(PickedChatFile item) onSend,
  }) async {
    final item = await pickerFunc();
    if (item == null || !mounted) return;

    final confirmed = await confirmSend(
      title: title,
      preview: previewBuilder(item),
    );

    if (!confirmed) return;

    try {
      await onSend(item);
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        cleanErrorMessage(e),
        type: SnackType.error,
      );
    }
  }

  Future<void> pickImage(ImageSource source, ChatController controller) async {
    await pickAndSend(
      pickerFunc: () async {
        final picked = await picker.pickImage(
          source: source,
          maxWidth: 3072,
          maxHeight: 3072,
          imageQuality: 90,
        );
        if (picked == null) return null;
        return PickedChatFile(file: File(picked.path), name: picked.name);
      },
      title: 'chat.send_image',
      previewBuilder: (item) => ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: Image.file(item.file, height: 220, fit: BoxFit.cover),
      ),
      onSend: (item) => controller.sendAttachment(
        file: item.file,
        type: ChatAttachmentType.image,
      ),
    );
  }

  Future<void> pickVideo(ChatController controller) async {
    await pickAndSend(
      pickerFunc: () async {
        final picked = await picker.pickVideo(
          source: ImageSource.gallery,
          maxDuration: const Duration(minutes: 3),
        );
        if (picked == null) return null;
        return PickedChatFile(file: File(picked.path), name: picked.name);
      },
      title: 'chat.send_video',
      previewBuilder: (item) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 140,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: AppGradients.video,
              borderRadius: BorderRadius.circular(AppRadii.md),
            ),
            child: const Center(
              child: Icon(
                Icons.play_circle_fill_rounded,
                color: Colors.white,
                size: 60,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(item.name ?? tr('chat.attachment.video')),
        ],
      ),
      onSend: (item) => controller.sendAttachment(
        file: item.file,
        type: ChatAttachmentType.video,
      ),
    );
  }

  Future<void> pickFile(ChatController controller) async {
    await pickAndSend(
      pickerFunc: () async {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: const [
            'pdf',
            'doc',
            'docx',
            'xls',
            'xlsx',
            'ppt',
            'pptx',
            'txt',
          ],
        );
        if (result == null || result.files.single.path == null) return null;

        return PickedChatFile(
          file: File(result.files.single.path!),
          name: result.files.single.name,
        );
      },
      title: 'chat.send_file',
      previewBuilder: (item) => Row(
        children: [
          const Icon(
            Icons.insert_drive_file_rounded,
            size: 40,
            color: AppColors.primary,
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(item.name ?? tr('chat.attachment.file'))),
        ],
      ),
      onSend: (item) => controller.sendAttachment(
        file: item.file,
        type: ChatAttachmentType.file,
        fileName: item.name,
      ),
    );
  }
}
