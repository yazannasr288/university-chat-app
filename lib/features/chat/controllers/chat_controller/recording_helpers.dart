part of '../chat_controller.dart';

extension ChatRecordingHelpers on ChatController {
  double _normalizeRecordingAmplitude(Amplitude amplitude) {
    final db = amplitude.current;
    if (!db.isFinite) return 0.10;
    return ((db + 45) / 45).clamp(0.08, 1.0).toDouble();
  }

  void _startRecordingMeters() {
    _recordingTimer?.cancel();
    _amplitudeSub?.cancel();

    _recordingStartedAt = DateTime.now();
    recordingDuration = Duration.zero;
    recordingLevel = 0.12;
    _syncRecordingUi();
    _recordingTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      final startedAt = _recordingStartedAt;
      if (startedAt == null || !_hasActiveRecording) return;
      recordingDuration = DateTime.now().difference(startedAt);
      _syncRecordingUi();
    });

    try {
      _amplitudeSub = recorder
          .onAmplitudeChanged(const Duration(milliseconds: 120))
          .listen((amplitude) {
        if (!_hasActiveRecording) return;
        recordingLevel = _normalizeRecordingAmplitude(amplitude);
        _syncRecordingUi();
      });
    } catch (_) {
      _amplitudeSub = null;
    }
  }

  void _stopRecordingMeters() {
    _recordingTimer?.cancel();
    _recordingTimer = null;
    _amplitudeSub?.cancel();
    _amplitudeSub = null;
  }

  Future<Directory> _voiceNotesDirectory() async {
    final appDir = await path_provider.getApplicationSupportDirectory();
    final dir = Directory(
      '${appDir.path}${Platform.pathSeparator}chat_voice_notes',
    );
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

}
