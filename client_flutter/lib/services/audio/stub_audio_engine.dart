import 'dart:async';
import 'karaoke_audio_engine.dart';

KaraokeAudioEngine createPlatformAudioEngine() {
  return StubKaraokeAudioEngine();
}

class StubKaraokeAudioEngine implements KaraokeAudioEngine {

  Timer? _playbackTimer;
  Duration _currentPosition = Duration.zero;

  void _startTimer() {
    _playbackTimer?.cancel();
    _playbackTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (_isPlaying) {
        _currentPosition += const Duration(milliseconds: 100);
        _positionStreamController.add(_currentPosition);
      }
    });
  }
  
  void _stopTimer() {
    _playbackTimer?.cancel();
  }

  bool _isPlaying = false;
  bool _isRecording = false;
  double _vocalVolume = 1.0;
  double _musicVolume = 0.85;
  int _latencyOffset = 45;
  KaraokePreset _activePreset = KaraokePreset.clean;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> dispose() async {}

  @override
  Future<void> loadInstrumental(String url) async {}

  double _vocalSongStart = 0.0;
  double _vocalSongEnd = 0.0;

  @override
  Future<void> loadVocal(String url, {double songStart = 0.0, double songEnd = 0.0}) async {
    _vocalSongStart = songStart;
    _vocalSongEnd = songEnd;
  }

  @override
  void setVocalRange(double songStart, double songEnd) {
    _vocalSongStart = songStart;
    _vocalSongEnd = songEnd;
  }

  @override
  Future<void> startRecording() async {
    _isRecording = true;
    _isPlaying = true;
    _startTimer();
  }

  @override
  Future<void> stopRecording() async {
    _isRecording = false;
    _isPlaying = false;
    _stopTimer();
  }

  @override
  Future<void> play() async {
    _isPlaying = true;
    _startTimer();
  }

  @override
  Future<void> pause() async {
    _isPlaying = false;
    _stopTimer();
  }

  @override
  Future<void> seek(Duration position) async {
    _currentPosition = position;
    _positionStreamController.add(_currentPosition);
  }

  @override
  void setVocalVolume(double volume) {
    _vocalVolume = volume;
  }

  @override
  void setInstrumentalVolume(double volume) {
    _musicVolume = volume;
  }

  @override
  void setMasterVolume(double volume) {}

  @override
  void setVocalPan(double pan) {}

  @override
  void setReverbEnabled(bool enabled) {}

  @override
  void setReverbPreset(String preset) {}

  @override
  void setReverbMix(double wet) {}

  @override
  void setDelayEnabled(bool enabled) {}

  @override
  void setDelayTime(int milliseconds) {}

  @override
  void setDelayFeedback(double feedback) {}

  @override
  void setDelayMix(double mix) {}

  @override
  void setCompressorEnabled(bool enabled) {}

  @override
  void setCompressorThreshold(double thresholdDb) {}

  @override
  void setCompressorRatio(double ratio) {}

  @override
  void setCompressorAttack(double attackMs) {}

  @override
  void setCompressorRelease(double releaseMs) {}

  @override
  void setCompressorMakeupGain(double gainDb) {}

  @override
  void setEQEnabled(bool enabled) {}

  @override
  void setEQBand(int bandIndex, double frequency, double gainDb, double q) {}

  AutoTuneMode _autoTuneMode = AutoTuneMode.off;
  bool _proTuningEnabled = false;

  @override
  void setAutoTuneMode(AutoTuneMode mode) {
    _autoTuneMode = mode;
  }

  @override
  AutoTuneMode getAutoTuneMode() => _autoTuneMode;

  @override
  void setProTuningEnabled(bool enabled) {
    _proTuningEnabled = enabled;
  }

  @override
  bool isProTuningEnabled() => _proTuningEnabled;

  @override
  void setPitchCorrectionEnabled(bool enabled) {}

  @override
  void setPitchCorrectionStrength(double strength) {}

  @override
  void setPitchCorrectionSpeed(double speed) {}

  @override
  
  @override
  double getCurrentUserPitch() {
    if (!_isPlaying && !_isRecording) return 0.0;
    // Simulate a changing vocal frequency (Hz)
    final time = DateTime.now().millisecondsSinceEpoch / 1000.0;
    return 250.0 + 100.0 * (time % 5) / 5.0; // Sweeps from 250Hz to 350Hz over 5 seconds
  }


  @override
  double getTargetPitch() => 62.0;

  @override
  double getPitchConfidence() => 0.0;

  @override
  double getPitchError() => 0.0;

  @override
  void setNoiseReductionEnabled(bool enabled) {}

  @override
  void setNoiseReductionThreshold(double thresholdDb) {}

  @override
  void setLatencyOffset(int milliseconds) {
    _latencyOffset = milliseconds;
  }

  @override
  void setMonitoringEnabled(bool enabled) {}

  final StreamController<Duration> _positionStreamController = StreamController<Duration>.broadcast();

  @override
  Stream<Duration> get onPositionChanged => _positionStreamController.stream;

  @override
  Duration getPlaybackPosition() => _currentPosition;

  @override
  Duration getDuration() => Duration(seconds: 180);

  @override
  bool isPlaying() => _isPlaying;

  @override
  bool isRecordingState() => _isRecording;

  @override
  double getVocalVolume() => _vocalVolume;

  @override
  double getInstrumentalVolume() => _musicVolume;

  @override
  int getLatencyOffset() => _latencyOffset;

  @override
  void applyPreset(KaraokePreset preset) {
    _activePreset = preset;
  }

  @override
  KaraokePreset getActivePreset() => _activePreset;

  @override
  Future<String> exportMix({
    required double vocalVolume,
    required double instrumentalVolume,
    required KaraokeEffectsSettings settings,
    required Function(double progress) onProgress,
  }) async {
    for (int i = 1; i <= 10; i++) {
      await Future.delayed(Duration(milliseconds: 150));
      onProgress(i / 10.0);
    }
    return "mock_exported_mix_file.mp3";
  }

  @override
  void resetEffects() {
    _vocalVolume = 1.0;
    _musicVolume = 0.85;
    _latencyOffset = 45;
    _activePreset = KaraokePreset.clean;
  }
}
