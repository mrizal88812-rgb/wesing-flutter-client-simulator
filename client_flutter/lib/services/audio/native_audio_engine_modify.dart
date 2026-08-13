import 'dart:async';

import 'package:flutter/services.dart';

import '../../core/config/app_config.dart';
import 'karaoke_audio_engine.dart';

KaraokeAudioEngine createPlatformAudioEngine() {
  return NativeKaraokeAudioEngine();
}

class NativeKaraokeAudioEngine implements KaraokeAudioEngine {
  static const MethodChannel _channel =
      MethodChannel('com.example.karaoke/dsp_engine');

  static const EventChannel _positionChannel =
      EventChannel('com.example.karaoke/dsp_position');

  static const EventChannel _pitchChannel =
      EventChannel('com.example.karaoke/dsp_pitch');

  StreamSubscription? _positionSub;
  StreamSubscription? _pitchSub;

  final StreamController<Duration> _positionController =
      StreamController<Duration>.broadcast();

  bool _initialized = false;
  bool _disposed = false;
  Future<void>? _initializeFuture;

  bool _isPlayingState = false;
  bool _isRecordingState = false;

  Duration _duration = Duration.zero;
  Duration _lastPosition = Duration.zero;

  double _vocalVolume = 1.0;
  double _instrumentalVolume = 0.85;

  int _latencyOffset = 45;

  bool _monitoringEnabled = true;

  KaraokePreset _activePreset = KaraokePreset.clean;
  AutoTuneMode _autoTuneMode = AutoTuneMode.off;

  bool _proTuningEnabled = false;

  double _currentPitch = 0.0;
  double _targetPitch = 0.0;
  double _confidence = 0.0;
  double _pitchError = 0.0;

  double _vocalSongStart = 0.0;
  double _vocalSongEnd = 0.0;

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  bool get _canCallNative => !_disposed;

  Future<void> _ensureInitialized() async {
    if (_disposed) {
      throw StateError(
        'NativeKaraokeAudioEngine sudah di-dispose.',
      );
    }

    if (_initialized) {
      return;
    }

    await initialize();
  }

  Future<void> _safeInvoke(
    String method, [
    dynamic arguments,
  ]) async {
    if (!_canCallNative) {
      return;
    }

    await _ensureInitialized();

    if (_disposed) {
      return;
    }

    await _channel.invokeMethod(method, arguments);
  }

  void _cancelStreams() {
    _positionSub?.cancel();
    _positionSub = null;

    _pitchSub?.cancel();
    _pitchSub = null;
  }

  void _listenToPosition() {
    _positionSub?.cancel();

    _positionSub =
        _positionChannel.receiveBroadcastStream().listen(
      (dynamic event) {
        if (_disposed) {
          return;
        }

        double? seconds;

        if (event is double) {
          seconds = event;
        } else if (event is num) {
          seconds = event.toDouble();
        }

        if (seconds == null || seconds.isNaN || seconds.isInfinite) {
          return;
        }

        if (seconds < 0) {
          seconds = 0;
        }

        _lastPosition =
            Duration(milliseconds: (seconds * 1000.0).round());

        if (!_positionController.isClosed) {
          _positionController.add(_lastPosition);
        }
      },
      onError: (Object error, StackTrace stack) {
        // Jangan mematikan stream hanya karena error satu event.
      },
    );
  }

  void _listenToPitch() {
    _pitchSub?.cancel();

    _pitchSub =
        _pitchChannel.receiveBroadcastStream().listen(
      (dynamic event) {
        if (_disposed) {
          return;
        }

        if (event is! Map) {
          return;
        }

        final dynamic pitchValue = event['pitch'];
        final dynamic confidenceValue = event['confidence'];

        _currentPitch =
            pitchValue is num ? pitchValue.toDouble() : 0.0;

        _confidence =
            confidenceValue is num
                ? confidenceValue.toDouble()
                : 0.0;

        if (_targetPitch > 0.0) {
          _pitchError =
              (_currentPitch - _targetPitch).abs();
        } else {
          _pitchError = 0.0;
        }
      },
      onError: (Object error, StackTrace stack) {},
    );
  }

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  Future<void> initialize() async {
    if (_disposed) {
      throw StateError(
        'Tidak dapat initialize engine yang sudah di-dispose.',
      );
    }

    if (_initialized) {
      return;
    }

    // Mencegah dua initialize berjalan bersamaan.
    if (_initializeFuture != null) {
      await _initializeFuture;
      return;
    }

    final future = _initializeInternal();
    _initializeFuture = future;

    try {
      await future;
    } finally {
      if (identical(_initializeFuture, future)) {
        _initializeFuture = null;
      }
    }
  }

  Future<void> _initializeInternal() async {
    if (_initialized || _disposed) {
      return;
    }

    // Native init dibuat idempotent.
    await _channel.invokeMethod('init');

    if (_disposed) {
      return;
    }

    _listenToPosition();
    _listenToPitch();

    _initialized = true;
  }

  // ---------------------------------------------------------------------------
  // Source loading
  // ---------------------------------------------------------------------------

  @override
  Future<void> loadInstrumental(String url) async {
    if (_disposed) {
      return;
    }

    await _ensureInitialized();

    final resolvedUrl =
        AppConfig.resolveMediaUrl(url);

    // Pastikan native playback berhenti sebelum mengganti buffer.
    // Ini penting karena callback AAudio membaca instrumentalBuffer
    // secara realtime.
    try {
      await _channel.invokeMethod('pause');
    } catch (_) {}

    _isPlayingState = false;
    _isRecordingState = false;

    await _channel.invokeMethod(
      'loadInstrumental',
      <String, dynamic>{
        'url': resolvedUrl,
      },
    );

    if (_disposed) {
      return;
    }

    final durationMs =
        await _channel.invokeMethod<int>('getDuration') ?? 0;

    _duration = Duration(
      milliseconds: durationMs,
    );

    _lastPosition = Duration.zero;
  }

  @override
  Future<void> loadVocal(
    String url, {
    double songStart = 0.0,
    double songEnd = 0.0,
  }) async {
    if (_disposed) {
      return;
    }

    await _ensureInitialized();

    _vocalSongStart = songStart;
    _vocalSongEnd = songEnd;

    await _channel.invokeMethod(
      'setVocalRange',
      <String, dynamic>{
        'songStart': songStart,
        'songEnd': songEnd,
      },
    );
  }

  @override
  void setVocalRange(
    double songStart,
    double songEnd,
  ) {
    if (!_canCallNative) {
      return;
    }

    _vocalSongStart = songStart;
    _vocalSongEnd = songEnd;

    _channel.invokeMethod(
      'setVocalRange',
      <String, dynamic>{
        'songStart': songStart,
        'songEnd': songEnd,
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Recording / Playback
  // ---------------------------------------------------------------------------

  @override
  Future<void> startRecording() async {
    if (_disposed) {
      return;
    }

    await _ensureInitialized();

    _isRecordingState = true;
    _isPlayingState = true;

    await _channel.invokeMethod('startRecording');
  }

  @override
  Future<void> stopRecording() async {
    if (_disposed) {
      return;
    }

    await _ensureInitialized();

    _isRecordingState = false;
    _isPlayingState = false;

    await _channel.invokeMethod('stopRecording');
  }

  @override
  Future<void> play() async {
    if (_disposed) {
      return;
    }

    await _ensureInitialized();

    await _channel.invokeMethod('play');

    _isPlayingState = true;
  }

  @override
  Future<void> pause() async {
    if (_disposed) {
      return;
    }

    await _ensureInitialized();

    await _channel.invokeMethod('pause');

    _isPlayingState = false;
  }

  @override
  Future<void> seek(Duration position) async {
    if (_disposed) {
      return;
    }

    await _ensureInitialized();

    final durationMs = _duration.inMilliseconds;

    var targetMs = position.inMilliseconds;

    if (targetMs < 0) {
      targetMs = 0;
    }

    if (durationMs > 0 && targetMs > durationMs) {
      targetMs = durationMs;
    }

    _lastPosition =
        Duration(milliseconds: targetMs);

    if (!_positionController.isClosed) {
      _positionController.add(_lastPosition);
    }

    await _channel.invokeMethod(
      'seek',
      <String, dynamic>{
        'position_ms': targetMs,
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Position
  // ---------------------------------------------------------------------------

  @override
  Stream<Duration> get onPositionChanged =>
      _positionController.stream;

  @override
  Duration getPlaybackPosition() =>
      _lastPosition;

  @override
  Duration getDuration() =>
      _duration;

  @override
  bool isPlaying() =>
      _isPlayingState;

  @override
  bool isRecordingState() =>
      _isRecordingState;

  // ---------------------------------------------------------------------------
  // Volume
  // ---------------------------------------------------------------------------

  @override
  void setVocalVolume(double volume) {
    _vocalVolume = volume.clamp(0.0, 1.5);

    if (!_canCallNative) {
      return;
    }

    _channel.invokeMethod(
      'setVocalVolume',
      <String, dynamic>{
        'volume': _vocalVolume,
      },
    );
  }

  @override
  void setInstrumentalVolume(double volume) {
    _instrumentalVolume = volume.clamp(0.0, 1.2);

    if (!_canCallNative) {
      return;
    }

    _channel.invokeMethod(
      'setInstrumentalVolume',
      <String, dynamic>{
        'volume': _instrumentalVolume,
      },
    );
  }

  @override
  double getVocalVolume() =>
      _vocalVolume;

  @override
  double getInstrumentalVolume() =>
      _instrumentalVolume;

  @override
  void setLatencyOffset(int offsetMs) {
    _latencyOffset = offsetMs;

    if (!_canCallNative) {
      return;
    }

    _channel.invokeMethod(
      'setLatencyOffset',
      <String, dynamic>{
        'offsetMs': offsetMs,
      },
    );
  }

  @override
  int getLatencyOffset() =>
      _latencyOffset;

  @override
  void setMonitoringEnabled(bool enabled) {
    _monitoringEnabled = enabled;

    if (!_canCallNative) {
      return;
    }

    _channel.invokeMethod(
      'setMonitoringEnabled',
      <String, dynamic>{
        'enabled': enabled,
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Preset
  // ---------------------------------------------------------------------------

  @override
  void applyPreset(KaraokePreset preset) {
    _activePreset = preset;
  }

  @override
  KaraokePreset getActivePreset() =>
      _activePreset;

  // ---------------------------------------------------------------------------
  // EQ
  // ---------------------------------------------------------------------------

  @override
  void setEQBand(
    int bandIndex,
    double frequency,
    double gain,
    double q,
  ) {
    // Native bridge saat ini belum expose setEQBand.
  }

  @override
  void setEQEnabled(bool enabled) {
    if (!_canCallNative) {
      return;
    }

    _channel.invokeMethod(
      'setEqEnabled',
      <String, dynamic>{
        'enabled': enabled,
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Reverb
  // ---------------------------------------------------------------------------

  @override
  void setReverbEnabled(bool enabled) {
    if (!_canCallNative) {
      return;
    }

    _channel.invokeMethod(
      'setReverbEnabled',
      <String, dynamic>{
        'enabled': enabled,
      },
    );
  }

  @override
  void setReverbPreset(String presetName) {
    if (!_canCallNative) {
      return;
    }

    _channel.invokeMethod(
      'setReverbPreset',
      <String, dynamic>{
        'preset': presetName,
      },
    );
  }

  @override
  void setReverbMix(double mix) {
    if (!_canCallNative) {
      return;
    }

    _channel.invokeMethod(
      'setReverbMix',
      <String, dynamic>{
        'mix': mix.clamp(0.0, 1.0),
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Delay
  // ---------------------------------------------------------------------------

  @override
  void setDelayEnabled(bool enabled) {
    if (!_canCallNative) {
      return;
    }

    _channel.invokeMethod(
      'setDelayEnabled',
      <String, dynamic>{
        'enabled': enabled,
      },
    );
  }

  @override
  void setDelayTime(int milliseconds) {
    if (!_canCallNative) {
      return;
    }

    _channel.invokeMethod(
      'setDelayTime',
      <String, dynamic>{
        'time_ms': milliseconds,
      },
    );
  }

  @override
  void setDelayFeedback(double feedback) {
    if (!_canCallNative) {
      return;
    }

    _channel.invokeMethod(
      'setDelayFeedback',
      <String, dynamic>{
        'feedback': feedback.clamp(0.0, 1.0),
      },
    );
  }

  @override
  void setDelayMix(double mix) {
    if (!_canCallNative) {
      return;
    }

    _channel.invokeMethod(
      'setDelayMix',
      <String, dynamic>{
        'mix': mix.clamp(0.0, 1.0),
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Compressor
  // ---------------------------------------------------------------------------

  @override
  void setCompressorEnabled(bool enabled) {
    if (!_canCallNative) {
      return;
    }

    _channel.invokeMethod(
      'setCompressorEnabled',
      <String, dynamic>{
        'enabled': enabled,
      },
    );
  }

  @override
  void setCompressorThreshold(double threshold) {}

  @override
  void setCompressorRatio(double ratio) {}

  @override
  void setCompressorAttack(double attackMs) {}

  @override
  void setCompressorRelease(double releaseMs) {}

  @override
  void setCompressorMakeupGain(double gainDb) {}

  // ---------------------------------------------------------------------------
  // Pitch correction
  // ---------------------------------------------------------------------------

  @override
  void setPitchCorrectionEnabled(bool enabled) {}

  @override
  void setPitchCorrectionStrength(double strength) {}

  @override
  void setPitchCorrectionSpeed(double speed) {}

  @override
  void setAutoTuneMode(AutoTuneMode mode) {
    _autoTuneMode = mode;

    if (!_canCallNative) {
      return;
    }

    _channel.invokeMethod(
      'setAutoTuneMode',
      <String, dynamic>{
        'mode': mode.name,
      },
    );
  }

  @override
  AutoTuneMode getAutoTuneMode() =>
      _autoTuneMode;

  @override
  void setProTuningEnabled(bool enabled) {
    _proTuningEnabled = enabled;
  }

  @override
  bool isProTuningEnabled() =>
      _proTuningEnabled;

  // ---------------------------------------------------------------------------
  // Master / Pan
  // ---------------------------------------------------------------------------

  @override
  void setMasterVolume(double volume) {}

  @override
  void setVocalPan(double pan) {}

  // ---------------------------------------------------------------------------
  // Noise reduction
  // ---------------------------------------------------------------------------

  @override
  void setNoiseReductionEnabled(bool enabled) {}

  @override
  void setNoiseReductionThreshold(double thresholdDb) {}

  // ---------------------------------------------------------------------------
  // Pitch result
  // ---------------------------------------------------------------------------

  @override
  double getPitchConfidence() =>
      _confidence;

  @override
  double getPitchError() =>
      _pitchError;

  @override
  double getCurrentUserPitch() =>
      _currentPitch;

  @override
  double getTargetPitch() =>
      _targetPitch;

  // ---------------------------------------------------------------------------
  // Reset effects
  // ---------------------------------------------------------------------------

  @override
  void resetEffects() {
    setVocalVolume(1.0);
    setInstrumentalVolume(0.85);
    setAutoTuneMode(AutoTuneMode.off);

    _activePreset = KaraokePreset.clean;
  }

  // ---------------------------------------------------------------------------
  // Export
  // ---------------------------------------------------------------------------

  @override
  Future<String> exportMix({
    required double vocalVolume,
    required double instrumentalVolume,
    required KaraokeEffectsSettings settings,
    required Function(double progress) onProgress,
  }) async {
    if (_disposed) {
      throw StateError(
        'Audio engine sudah di-dispose.',
      );
    }

    await _ensureInitialized();

    bool isExporting = true;

    final timer = Timer.periodic(
      const Duration(milliseconds: 100),
      (timer) async {
        if (!isExporting || _disposed) {
          timer.cancel();
          return;
        }

        try {
          final double progress =
              await _channel.invokeMethod(
                    'getExportProgress',
                  ) ??
                  0.0;

          onProgress(progress);
        } catch (_) {}
      },
    );

    try {
      final String? result =
          await _channel.invokeMethod<String>(
        'exportMix',
        <String, dynamic>{
          'vocalVolume': vocalVolume,
          'instrumentalVolume': instrumentalVolume,
          'outPath':
              '/sdcard/Download/karaoke_export_${DateTime.now().millisecondsSinceEpoch}.wav',
        },
      );

      isExporting = false;
      timer.cancel();

      onProgress(1.0);

      if (result != null) {
        return result;
      }

      throw Exception(
        'EXPORT FAILED: Native tidak mengembalikan path.',
      );
    } catch (e) {
      isExporting = false;
      timer.cancel();

      throw Exception(
        'EXPORT FAILED: $e',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Dispose
  // ---------------------------------------------------------------------------

  @override
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }

    _disposed = true;

    _isPlayingState = false;
    _isRecordingState = false;

    _cancelStreams();

    if (!_positionController.isClosed) {
      await _positionController.close();
    }

    /*
     * PENTING:
     *
     * Jangan panggil native "dispose" di sini.
     *
     * Native engine adalah singleton/global dan digunakan oleh
     * RecordScreen -> EditRecordingScreen.
     *
     * Kalau screen memanggil native dispose(), maka:
     *
     * g_processor.reset()
     * g_audioEngine.reset()
     *
     * Screen berikutnya kemudian melakukan play()/seek()
     * terhadap engine native yang sudah dihancurkan.
     *
     * Native shutdown harus dilakukan di lifecycle aplikasi,
     * bukan lifecycle screen.
     */
  }
}