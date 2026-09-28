part of '../chat_page.dart';

extension on _ChatPageState {
  Future<void> _pickAndSendMediaSafely(Future<void> Function() action) async {
    if (_isPickingOrSendingMedia ||
        _isSendingRecording ||
        _isSendingText ||
        _isSendingPoll) {
      return;
    }

    _safeSetState(() => _isPickingOrSendingMedia = true);
    try {
      await action();
    } finally {
      _safeSetState(() => _isPickingOrSendingMedia = false);
    }
  }

  void _showMediaOptions() {
    if (_isPickingOrSendingMedia || _isSendingRecording || _isSendingPoll) {
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (_) => ChatAttachmentSheet(
            onCamera: () {
              Navigator.pop(context);
              _pickAndSendMediaSafely(() => pickImage(ImageSource.camera, controller));
            },
            onGallery: () {
              Navigator.pop(context);
              _pickAndSendMediaSafely(() => pickImage(ImageSource.gallery, controller));
            },
            onVideo: () {
              Navigator.pop(context);
              _pickAndSendMediaSafely(() => pickVideo(controller));
            },
            onFile: () {
              Navigator.pop(context);
              _pickAndSendMediaSafely(() => pickFile(controller));
            },
            onPoll: () {
              Navigator.pop(context);
              _showCreatePollSheet();
            },
          ),
    );
  }
}
