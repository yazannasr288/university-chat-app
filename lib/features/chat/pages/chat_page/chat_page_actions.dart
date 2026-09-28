part of '../chat_page.dart';

extension on _ChatPageState {
  Future<void> _showCreatePollSheet() async {
    if (_isSendingPoll ||
        _isPickingOrSendingMedia ||
        _isSendingRecording ||
        _isSendingText) {
      return;
    }

    final draft = await showModalBottomSheet<PollDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ChatPollSheet(),
    );

    if (draft == null) return;

    _safeSetState(() => _isSendingPoll = true);
    try {
      await controller.sendPoll(
        question: draft.question,
        options: draft.options,
        expiresAt: draft.expiresAt,
      );
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, cleanErrorMessage(e), type: SnackType.error);
    } finally {
      _safeSetState(() => _isSendingPoll = false);
    }
  }

  Future<void> _startVoiceRecording([Offset? position]) async {
    if (_isSendingRecording ||
        _isPickingOrSendingMedia ||
        _isSendingText ||
        _isSendingPoll) {
      return;
    }

    final started = await controller.startRecording(position);
    if (started) {
      HapticFeedback.heavyImpact();
      return;
    }

    _showErrorSnackBar('chat.enable_microphone_permission_send_voice_message'.tr());
  }

  Future<void> _sendRecordedAudio() async {
    if (_isSendingRecording) return;

    _safeSetState(() => _isSendingRecording = true);

    final durationBeforeStop = controller.recordingDuration;
    File? file;

    try {
      file = await controller.stopRecording();

      if (file == null) {
        if (!mounted) return;
        if (durationBeforeStop > Duration.zero &&
            durationBeforeStop < const Duration(milliseconds: 650)) {
          showAppSnackBar(
            context,
            'chat.recording_too_short'.tr(),
            type: SnackType.info,
          );
        }
        return;
      }

      await controller.sendAttachment(
        file: file,
        type: ChatAttachmentType.audio,
        audioDurationMs: controller.lastCompletedRecordingDurationMs,
      );
      HapticFeedback.mediumImpact();
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, cleanErrorMessage(e), type: SnackType.error);
    } finally {
      _safeSetState(() => _isSendingRecording = false);
    }
  }

  void _sendTextSafely() {
    if (_isSendingText || _isPickingOrSendingMedia || _isSendingRecording || _isSendingPoll) {
      return;
    }

    _keepComposerFocused();
    _safeSetState(() => _isSendingText = true);

    controller
        .sendText()
        .then((_) {
          _keepComposerFocused();
          HapticFeedback.lightImpact();
        })
        .catchError((e) {
          _keepComposerFocused();
          _showErrorSnackBar(cleanErrorMessage(e));
        })
        .whenComplete(() {
          _safeSetState(() => _isSendingText = false);
        });
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    showAppSnackBar(context, message, type: SnackType.error);
  }
}
