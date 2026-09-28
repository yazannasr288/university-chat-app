import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/storage/app_prefs.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../../core/utils/error_message.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../data/models/chat_message.dart';
import '../../../data/models/message_receipt_summary.dart';
import '../../../services/notification_service.dart';
import '../../group_info/pages/group_info_page.dart';
import '../controllers/chat_controller.dart';
import '../widgets/chat_attachment_sheet.dart';
import '../widgets/chat_forward_sheet.dart';
import '../widgets/chat_header.dart';
import '../widgets/chat_input.dart';
import '../widgets/chat_messages_list.dart';
import '../widgets/chat_poll_sheet.dart';
import 'chat_media_picker_mixin.dart';

part 'chat_page/chat_page_actions.dart';

part 'chat_page/chat_page_selection.dart';

part 'chat_page/chat_page_receipts.dart';

part 'chat_page/chat_page_selected_header.dart';

part 'chat_page/chat_page_media.dart';

part 'chat_page/chat_page_search.dart';

class ChatPage extends StatefulWidget {
  final String userName;
  final String groupId;
  final String groupName;
  final String initialGroupIcon;

  const ChatPage({
    super.key,
    required this.userName,
    required this.groupId,
    required this.groupName,
    this.initialGroupIcon = '',
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage>
    with ChatMediaPickerMixin<ChatPage> {
  late final ChatController controller;
  late final String userRole;
  ChatMessage? _selectedMessage;
  MessageReceiptSummary? _selectedReceiptSummary;
  bool _selectedCanDelete = false;
  bool _isSearching = false;
  bool _isSendingText = false;
  bool _isSendingRecording = false;
  bool _isPickingOrSendingMedia = false;
  bool _isSendingPoll = false;
  final TextEditingController _chatSearchController = TextEditingController();
  final FocusNode _messageFocusNode = FocusNode();

  void _safeSetState(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
  }

  @override
  void initState() {
    super.initState();
    controller = ChatController(
      groupId: widget.groupId,
      userName: widget.userName,
    );
    userRole = AppPrefs.userRole;
    controller.loadCachedMessages();
    NotificationService.setActiveGroup(widget.groupId);
  }

  @override
  void dispose() {
    controller.markGroupRead();
    _chatSearchController.dispose();
    _messageFocusNode.dispose();
    controller.dispose();
    NotificationService.setActiveGroup(null);
    super.dispose();
  }

  bool _handleBackNavigation() {
    if (_selectedMessage != null) {
      _clearSelectedMessage();
      return false;
    }

    if (_isSearching) {
      _closeChatSearch();
      return false;
    }

    return true;
  }

  void _keepComposerFocused() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _messageFocusNode.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ChatShellUiState>(
      valueListenable: controller.chatShellUiState,
      builder: (context, shellState, _) {
        if (!shellState.initialGroupLoaded) {
          return AppPageShell(
            useBackground: false,
            appBar: ChatHeader(
              groupId: widget.groupId,
              groupName: widget.groupName,
              groupIconBase64: widget.initialGroupIcon,
            ),
            body: const AppScaffoldBackground(
              animate: false,
              child: AppLoader(),
            ),
          );
        }

        final streamErrorMessage = shellState.errorMessage;
        if (streamErrorMessage != null && streamErrorMessage.isNotEmpty) {
          return AppPageShell(
            useBackground: false,
            body: AppScaffoldBackground(
              animate: false,
              child: AppEmptyState(
                icon: Icons.error_outline_rounded,
                text: streamErrorMessage,
              ),
            ),
          );
        }

        final group = shellState.group;
        if (group == null) {
          return AppPageShell(
            useBackground: false,
            body: AppScaffoldBackground(
              animate: false,
              child: AppEmptyState(
                icon: Icons.group_off_rounded,
                text: 'chat.errors.group_not_found'.tr(),
              ),
            ),
          );
        }

        final canSendMessage = controller.canSend(
          group,
          userRole,
          accountType: AppPrefs.userAccountType,
          currentDepartment: AppPrefs.userDepartment,
        );
        final warningMessage = shellState.warningMessage?.trim() ?? '';

        final canPopRoute = _selectedMessage == null && !_isSearching;
        return PopScope<Object?>(
          canPop: canPopRoute,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            _handleBackNavigation();
          },
          child: AppPageShell(
            backgroundColor: Colors.transparent,
            useBackground: false,
            resizeToAvoidBottomInset: false,
            appBar: PreferredSize(
              preferredSize: const Size.fromHeight(64),
              child: AnimatedSwitcher(
                duration: AppMotion.resolve(context, AppMotion.medium),
                reverseDuration: AppMotion.resolve(context, AppMotion.fast),
                switchInCurve: AppMotion.entrance,
                switchOutCurve: AppMotion.exit,
                transitionBuilder: (child, animation) {
                  final slide = Tween<Offset>(
                    begin: const Offset(0, -0.10),
                    end: Offset.zero,
                  ).animate(animation);
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(position: slide, child: child),
                  );
                },
                child:
                    _selectedMessage != null
                        ? _buildSelectedMessageHeader()
                        : _isSearching
                        ? _buildSearchHeader()
                        : ChatHeader(
                          key: const ValueKey('chat_header'),
                          groupId: widget.groupId,
                          groupName:
                              group.groupName.isNotEmpty
                                  ? group.groupName
                                  : widget.groupName,
                          groupIconBase64: group.groupIcon,
                          onSearchTap: _openChatSearch,
                          onInfoTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (_) => GroupInfoPage(
                                      groupId: widget.groupId,
                                      groupName: widget.groupName,
                                      adminName: group.adminName,
                                    ),
                              ),
                            );
                          },
                        ),
              ),
            ),
            body: AppScaffoldBackground(
              animate: false,
              child: Stack(
                children: [
                  ChatMessagesList(
                    controller: controller,
                    userRole: userRole,
                    groupAdminId: group.adminId,
                    groupAdminIds: group.adminIds,
                    selectedMessageId: _selectedMessage?.id,
                    onClearSelection: _clearSelectedMessage,
                    onMessageSelected: _selectMessage,
                    searchQuery: _chatSearchController.text,
                  ),
                  if (warningMessage.isNotEmpty)
                    PositionedDirectional(
                      top: 10,
                      start: 14,
                      end: 14,
                      child: _ChatConnectionWarningBanner(
                        message: warningMessage,
                      ),
                    ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child:
                        canSendMessage
                            ? ValueListenableBuilder<ChatComposerUiState>(
                              valueListenable: controller.chatComposerUiState,
                              builder: (context, composerState, _) {
                                return ChatInput(
                                  controller: controller.messageController,
                                  isRecording: controller.isRecording,
                                  isCancelled: controller.isCancelled,
                                  recordingDuration:
                                      controller.recordingDuration,
                                  recordingLevel: controller.recordingLevel,
                                  recordingUiState: controller.recordingUiState,
                                  focusNode: _messageFocusNode,
                                  isSendingText: _isSendingText,
                                  isSendingAttachment:
                                      _isPickingOrSendingMedia ||
                                      _isSendingPoll,
                                  isSendingRecording: _isSendingRecording,
                                  onSend: _sendTextSafely,
                                  onAttach: _showMediaOptions,
                                  onRecordTap: () {
                                    _startVoiceRecording();
                                  },
                                  onRecordCancel: () async {
                                    await controller.cancelRecording();
                                    HapticFeedback.lightImpact();
                                  },
                                  onRecordSend: _sendRecordedAudio,
                                  onRecordStart: (details) {
                                    _startVoiceRecording(
                                      details.globalPosition,
                                    );
                                  },
                                  onRecordMove: (details) {
                                    controller.updateRecording(
                                      details.globalPosition,
                                    );
                                  },
                                  onRecordEnd: (_) async {
                                    await _sendRecordedAudio();
                                  },
                                  replyingToMessage:
                                      composerState.replyingToMessage,
                                  onCancelReply: controller.clearReply,
                                );
                              },
                            )
                            : Container(
                              width: double.infinity,
                              margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: context.appCardColorStrong,
                                borderRadius: BorderRadius.circular(
                                  AppRadii.lg,
                                ),
                                border: Border.all(color: context.appBorder),
                                boxShadow: AppShadows.subtle,
                              ),
                              child: Text(
                                !group.isActive
                                    ? 'chat.errors.group_archived_read_only'
                                        .tr()
                                    : 'chat.errors.admins_only_can_write'.tr(),
                                textAlign: TextAlign.center,
                                style: context.textTheme.bodyMedium?.copyWith(
                                  color: context.appTextSecondary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ChatConnectionWarningBanner extends StatelessWidget {
  final String message;

  const _ChatConnectionWarningBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedContainer(
        duration: AppMotion.fast,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: AppDecorations.pill(
          color: context.scheme.errorContainer.withValues(alpha: 0.94),
          borderColor: context.scheme.onErrorContainer.withValues(alpha: 0.16),
        ).copyWith(boxShadow: AppShadows.subtle),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.wifi_off_rounded,
              color: context.scheme.onErrorContainer,
              size: 17,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.scheme.onErrorContainer,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
