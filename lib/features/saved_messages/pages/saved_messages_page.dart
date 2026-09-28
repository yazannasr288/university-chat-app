import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/storage/app_prefs.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../../core/utils/error_message.dart';
import '../../../core/widgets/app_icon_badge.dart';
import '../../../core/widgets/app_list_tile_card.dart';
import '../../../core/widgets/app_page_shell.dart';
import '../../../core/widgets/app_state_view.dart';
import '../../../data/repositories/group_repository.dart';
import '../../chat/pages/chat_page.dart';

class SavedMessagesPage extends StatefulWidget {
  const SavedMessagesPage({super.key});

  @override
  State<SavedMessagesPage> createState() => _SavedMessagesPageState();
}

class _SavedMessagesPageState extends State<SavedMessagesPage> {
  final GroupRepository _repository = GroupRepository();

  IconData _iconFor(String type) {
    switch (type) {
      case 'image':
        return Icons.image_rounded;
      case 'video':
        return Icons.videocam_rounded;
      case 'audio':
        return Icons.mic_rounded;
      case 'poll':
        return Icons.poll_rounded;
      case 'event':
        return Icons.event_rounded;
      case 'file':
        return Icons.insert_drive_file_rounded;
      default:
        return Icons.chat_bubble_outline_rounded;
    }
  }

  String _previewFor(Map<String, dynamic> data) {
    final message = (data['message'] ?? '').toString().trim();
    if (message.isNotEmpty) return message;

    final fileName = (data['fileName'] ?? '').toString().trim();
    if (fileName.isNotEmpty) return fileName;

    switch ((data['type'] ?? '').toString()) {
      case 'image':
        return 'chat.photos'.tr();
      case 'video':
        return 'chat.video'.tr();
      case 'audio':
        return 'chat.voice_recording'.tr();
      case 'poll':
        return 'chat.poll'.tr();
      case 'event':
        return 'events.title'.tr();
      case 'file':
        return 'chat.pdf_office'.tr();
      default:
        return 'chat.attachment.generic'.tr();
    }
  }

  int _timestampMillis(Object? value) {
    if (value is Timestamp) return value.millisecondsSinceEpoch;
    return int.tryParse(value?.toString() ?? '0') ?? 0;
  }

  String _dateLabel(int timestamp) {
    if (timestamp <= 0) return '';
    final locale = context.locale.toString();
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return DateFormat('d MMM yyyy • HH:mm', locale).format(date);
  }

  Future<void> _removeSaved(Map<String, dynamic> data) async {
    try {
      await _repository.removeSavedMessage(
        groupId: (data['groupId'] ?? '').toString(),
        messageId: (data['messageId'] ?? '').toString(),
      );
      if (!mounted) return;
      showAppSnackBar(
        context,
        'saved_messages.removed'.tr(),
        type: SnackType.success,
      );
    } catch (error) {
      if (!mounted) return;
      showAppSnackBar(context, cleanErrorMessage(error), type: SnackType.error);
    }
  }

  void _openChat(Map<String, dynamic> data) {
    final groupId = (data['groupId'] ?? '').toString().trim();
    if (groupId.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatPage(
          userName: AppPrefs.userName,
          groupId: groupId,
          groupName: (data['groupName'] ?? '').toString(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPageShell(
      title: 'saved_messages.title'.tr(),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _repository.savedMessagesStream(),
        builder: (context, snapshot) {
          final docs = snapshot.data?.docs ?? const <QueryDocumentSnapshot<Map<String, dynamic>>>[];

          return AppStateView(
            loading: !snapshot.hasData && !snapshot.hasError,
            error: snapshot.hasError ? 'saved_messages.load_failed'.tr() : null,
            empty: snapshot.hasData && docs.isEmpty,
            emptyIcon: Icons.bookmark_border_rounded,
            emptyText: 'saved_messages.empty'.tr(),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final data = docs[index].data();
                final type = (data['type'] ?? '').toString();
                final savedAt = _timestampMillis(data['savedAt']);
                final sender = (data['sender'] ?? '').toString().trim();
                final groupName = (data['groupName'] ?? '').toString().trim();

                return AppListTileCard(
                  leading: AppIconBadge(
                    icon: _iconFor(type),
                    size: 52,
                    iconSize: 24,
                  ),
                  title: Text(
                    _previewFor(data),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    [
                      if (groupName.isNotEmpty) groupName,
                      if (sender.isNotEmpty) sender,
                      if (savedAt > 0) _dateLabel(savedAt),
                    ].join(' • '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => _openChat(data),
                  trailing: IconButton(
                    icon: const Icon(Icons.bookmark_remove_rounded),
                    tooltip: 'saved_messages.remove'.tr(),
                    onPressed: () => _removeSaved(data),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
