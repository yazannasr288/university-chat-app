part of '../chat_controller.dart';

extension ChatRecordingActions on ChatController {
  Future<bool> _ensureMicrophonePermission() async {
    if (await recorder.hasPermission()) {
      _microphonePermissionStatus = PermissionStatus.granted;
      return true;
    }

    final current = await Permission.microphone.status;

    if (current.isGranted) {
      _microphonePermissionStatus = current;
      return await recorder.hasPermission();
    }

    if (current.isPermanentlyDenied || current.isRestricted) {
      _microphonePermissionStatus = current;
      await openAppSettings();
      return false;
    }

    _microphonePermissionStatus = await Permission.microphone.request();
    return _microphonePermissionStatus!.isGranted && await recorder.hasPermission();
  }

  Future<bool> startRecording([Offset? globalPosition]) async {
    if (isRecording && _hasActiveRecording) return true;

    final permissionGranted = await _ensureMicrophonePermission();
    if (!permissionGranted) return false;

    _startDragPosition = globalPosition;
    isCancelled = false;
    _hasActiveRecording = false;
    _lastCompletedRecordingDurationMs = 0;

    final voiceDir = await _voiceNotesDirectory();
    final path =
        '${voiceDir.path}${Platform.pathSeparator}voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

    try {
      await recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 32000,
          sampleRate: 44100,
          numChannels: 1,
        ),
        path: path,
      );

      _activeRecordingPath = path;
      _hasActiveRecording = true;
      isRecording = true;
      _startRecordingMeters();
      HapticFeedback.lightImpact();
      return true;
    } catch (error) {
      if (kDebugMode) debugPrint('Audio recording start failed: $error');
      _stopRecordingMeters();
      _activeRecordingPath = null;
      _hasActiveRecording = false;
      isRecording = false;
      recordingDuration = Duration.zero;
      recordingLevel = 0.08;
      _syncRecordingUi();
      return false;
    }
  }

  void updateRecording(Offset currentPosition) {
    if (_startDragPosition == null || !_hasActiveRecording) return;

    final distance = currentPosition.dx - _startDragPosition!.dx;
    final shouldCancel = distance < -100;

    if (isCancelled == shouldCancel) return;

    isCancelled = shouldCancel;
    _syncRecordingUi();
  }

  Future<File?> stopRecording() async {
    if (!_hasActiveRecording) {
      isRecording = false;
      isCancelled = false;
      recordingDuration = Duration.zero;
      recordingLevel = 0.08;
      _syncRecordingUi();

      return null;
    }

    final wasCancelled = isCancelled;
    final finalDuration = _recordingStartedAt == null
        ? recordingDuration
        : DateTime.now().difference(_recordingStartedAt!);
    _lastCompletedRecordingDurationMs = finalDuration.inMilliseconds;
    String? path;

    try {
      path = await recorder.stop();
      if (wasCancelled) {
        HapticFeedback.heavyImpact();
      } else if (path != null) {
        HapticFeedback.mediumImpact();
      }
    } catch (error) {
      if (kDebugMode) debugPrint('Audio recording stop failed: $error');
      path = _activeRecordingPath;
    } finally {
      _stopRecordingMeters();
      _hasActiveRecording = false;
      _activeRecordingPath = null;
      _startDragPosition = null;
      _recordingStartedAt = null;
      isRecording = false;
      isCancelled = false;
      recordingDuration = Duration.zero;
      recordingLevel = 0.08;
      _syncRecordingUi();

    }

    if (path == null || path.trim().isEmpty) return null;

    final file = File(path);
    if (wasCancelled || _lastCompletedRecordingDurationMs < 650) {
      await _deleteLocalFileQuietly(file);
      return null;
    }

    if (!await _waitForStableLocalFile(file)) {
      await _deleteLocalFileQuietly(file);
      return null;
    }

    _lastCompletedRecordingDurationMs = finalDuration.inMilliseconds;

    return file;
  }

  Future<void> cancelRecording() async {
    if (!_hasActiveRecording) {
      isRecording = false;
      isCancelled = false;
      recordingDuration = Duration.zero;
      recordingLevel = 0.08;
      _syncRecordingUi();
      return;
    }

    String? path;
    try {
      path = await recorder.stop();
    } catch (_) {
      path = _activeRecordingPath;
    } finally {
      _stopRecordingMeters();
      _hasActiveRecording = false;
      _activeRecordingPath = null;
      _startDragPosition = null;
      _recordingStartedAt = null;
      _lastCompletedRecordingDurationMs = 0;
      isRecording = false;
      isCancelled = false;
      recordingDuration = Duration.zero;
      recordingLevel = 0.08;
      _syncRecordingUi();
    }

    if (path != null && path.trim().isNotEmpty) {
      await _deleteLocalFileQuietly(File(path));
    }
  }

}
