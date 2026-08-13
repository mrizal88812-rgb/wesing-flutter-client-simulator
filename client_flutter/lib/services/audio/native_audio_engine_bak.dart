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

  // State lifecycle engine
  bool _disposed = false;
  bool _initialized = false;
  bool _positionListening = false;
  bool _pitchListening = false;
  StreamSubscription? _positionSub;
  StreamSubscription? _pitchSub;

  final StreamController<Duration> _positionController =
      StreamController<Duration>.broadcast();

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

 
@override
Future<void> initialize() async {
  print('🔥 NATIVE ENGINE initialize() START');

print(
  '🔥 INITIALIZE '
  'disposed=$_disposed '
  'initialized=$_initialized '
  'positionSub=${_positionSub != null}',
);
  if (_disposed) {
    // Engine object pernah di-dispose.
    // Izinkan object yang sama dipakai kembali.
    _disposed = false;
  }

  if (_initialized) {
    print('🔥 initialize(): already initialized');

    // Pastikan subscription masih hidup.
    if (_positionSub == null) {
      print('🔥 positionSub NULL -> recreate');
      await _createPositionSubscription();
    }

    if (_pitchSub == null) {
      print('🔥 pitchSub NULL -> recreate');
      await _createPitchSubscription();
    }

    return;
  }

  print('🔥 calling native init()');

  await _channel.invokeMethod('init');

  print('🔥 native init() DONE');

  await _createPositionSubscription();
  await _createPitchSubscription();

  _initialized = true;

  print(
    '🔥 NATIVE ENGINE initialize() END '
    'initialized=$_initialized',
  );
}
Future<void> _createPositionSubscription() async {
  print('🔥 Creating POSITION EventChannel subscription...');

  await _positionSub?.cancel();
  _positionSub = null;

  _positionListening = false;

  final stream = _positionChannel.receiveBroadcastStream();

  print('🔥 POSITION broadcast stream created');

  _positionSub = stream.listen(
    (dynamic event) {
      print(
        '🎵🎵🎵 POSITION EVENT RECEIVED: '
        '$event (${event.runtimeType})',
      );

      if (_disposed) {
        print('⚠️ POSITION EVENT IGNORED: engine disposed');
        return;
      }

      double? seconds;

      if (event is num) {
        seconds = event.toDouble();
      }

      if (seconds == null) {
        print('⚠️ UNKNOWN POSITION EVENT: $event');
        return;
      }

      _lastPosition = Duration(
        microseconds: (seconds * 1000000).round(),
      );

      print(
        '🎵 POSITION UPDATE: '
        '${_lastPosition.inMilliseconds} ms '
        '(${seconds.toStringAsFixed(3)} sec)',
      );

      if (!_positionController.isClosed) {
        _positionController.add(_lastPosition);
      }
    },
    onError: (Object error, StackTrace stack) {
      print('❌ POSITION EVENT ERROR: $error');
      print(stack);
    },
    onDone: () {
      print('⚠️ POSITION STREAM DONE');

      _positionListening = false;
      _positionSub = null;
    },
    cancelOnError: false,
  );

  _positionListening = true;

  print(
    '🔥 POSITION EventChannel subscription CREATED '
    'sub=${_positionSub != null}',
  );
}
  Future<void> _createPitchSubscription() async {
  print('🔥 Creating PITCH EventChannel subscription...');

  await _pitchSub?.cancel();
  _pitchSub = null;

  _pitchListening = false;

  final stream = _pitchChannel.receiveBroadcastStream();

  _pitchSub = stream.listen(
    (dynamic event) {
      if (_disposed) return;

      if (event is Map) {
        _currentPitch =
            (event['pitch'] as num?)?.toDouble() ?? 0.0;

        _confidence =
            (event['confidence'] as num?)?.toDouble() ?? 0.0;

        if (_targetPitch > 0) {
          _pitchError =
              (_currentPitch - _targetPitch).abs();
        } else {
          _pitchError = 0.0;
        }
      }
    },
    onError: (Object error, StackTrace stack) {
      print('❌ PITCH EVENT ERROR: $error');
      print(stack);
    },
    onDone: () {
      print('⚠️ PITCH STREAM DONE');

      _pitchListening = false;
      _pitchSub = null;
    },
    cancelOnError: false,
  );

  _pitchListening = true;

  print('🔥 PITCH EventChannel subscription CREATED');
}
// await _channel.invokeMethod('init');

//   _pitchSub =
//       _pitchChannel.receiveBroadcastStream().listen(
//     (dynamic event) {
//       if (_disposed) return;

//       if (event is Map) {
//         _currentPitch =
//             (event['pitch'] as num?)?.toDouble() ?? 0.0;

//         _confidence =
//             (event['confidence'] as num?)?.toDouble() ?? 0.0;

//         if (_targetPitch > 0) {
//           _pitchError =
//               (_currentPitch - _targetPitch).abs();
//         } else {
//           _pitchError = 0.0;
//         }
//       }
//     },
//   );

//   _initialized = true;
// }

  @override
  Future<void> loadInstrumental(String url) async {
    final resolvedUrl = AppConfig.resolveMediaUrl(url);
    await _channel.invokeMethod('loadInstrumental', {'url': resolvedUrl});
    final durationMs = await _channel.invokeMethod<int>('getDuration') ?? 0;
    _duration = Duration(milliseconds: durationMs);
  }

  // double _vocalSongStart = 0.0;
  // double _vocalSongEnd = 0.0;

  @override
  Future<void> loadVocal(String url, {double songStart = 0.0, double songEnd = 0.0}) async {
    _vocalSongStart = songStart;
    _vocalSongEnd = songEnd;
    await _channel.invokeMethod('setVocalRange', {
      'songStart': songStart,
      'songEnd': songEnd,
    });
  }

  @override
  void setVocalRange(double songStart, double songEnd) {
    _vocalSongStart = songStart;
    _vocalSongEnd = songEnd;
    _channel.invokeMethod('setVocalRange', {
      'songStart': songStart,
      'songEnd': songEnd,
    });
  }

  @override
Future<void> startRecording() async {
  print(
    '🎤 START RECORDING '
    'disposed=$_disposed '
    'initialized=$_initialized '
    'positionSub=${_positionSub != null} '
    'positionListening=$_positionListening',
  );

  _isRecordingState = true;
  _isPlayingState = true;

  await _channel.invokeMethod('startRecording');
}

  @override
  Future<void> stopRecording() async {
    _isRecordingState = false;
    _isPlayingState = false;
    await _channel.invokeMethod('stopRecording');
  }

  @override
  Future<void> play() async {
    _isPlayingState = true;
    await _channel.invokeMethod('play');
  }

  @override
  Future<void> pause() async {
    _isPlayingState = false;
    await _channel.invokeMethod('pause');
  }

  @override
  Future<void> seek(Duration position) async {
    await _channel.invokeMethod('seek', {'position_ms': position.inMilliseconds});
  }

  @override
  Stream<Duration> get onPositionChanged => _positionController.stream;

  @override
  Duration getPlaybackPosition() {
    return _lastPosition;
  }

  @override
  Duration getDuration() => _duration;

  @override
  bool isPlaying() => _isPlayingState;

  @override
  bool isRecordingState() => _isRecordingState;

  @override
  void setVocalVolume(double volume) {
    _vocalVolume = volume;
    _channel.invokeMethod('setVocalVolume', {'volume': volume});
  }

  @override
  void setInstrumentalVolume(double volume) {
    _instrumentalVolume = volume;
    _channel.invokeMethod('setInstrumentalVolume', {'volume': volume});
  }

  @override
  double getVocalVolume() => _vocalVolume;

  @override
  double getInstrumentalVolume() => _instrumentalVolume;

  @override
  void setLatencyOffset(int offsetMs) {
    _latencyOffset = offsetMs;
    _channel.invokeMethod('setLatencyOffset', {'offsetMs': offsetMs});
  }

  @override
  int getLatencyOffset() => _latencyOffset;
  
  @override
  void setMonitoringEnabled(bool enabled) {
    _monitoringEnabled = enabled;
    _channel.invokeMethod('setMonitoringEnabled', {'enabled': enabled});
  }

  @override
  void applyPreset(KaraokePreset preset) {
    _activePreset = preset;
    // apply specific DSP based on preset
  }

  @override
  KaraokePreset getActivePreset() => _activePreset;

  @override
  void setEQBand(int bandIndex, double frequency, double gain, double q) {
    // Note: Eq is simplified for now
  }

  @override
  void setReverbEnabled(bool enabled) {
    _channel.invokeMethod('setReverbEnabled', {'enabled': enabled});
  }

  @override
  void setReverbPreset(String presetName) {
    _channel.invokeMethod('setReverbPreset', {'preset': presetName});
  }

  @override
  void setReverbMix(double mix) {
    _channel.invokeMethod('setReverbMix', {'mix': mix});
  }

  @override
  void setDelayEnabled(bool enabled) {
    _channel.invokeMethod('setDelayEnabled', {'enabled': enabled});
  }

  @override
  void setDelayTime(int milliseconds) {
    _channel.invokeMethod('setDelayTime', {'time_ms': milliseconds});
  }

  @override
  void setDelayFeedback(double feedback) {
    _channel.invokeMethod('setDelayFeedback', {'feedback': feedback});
  }

  @override
  void setDelayMix(double mix) {
    _channel.invokeMethod('setDelayMix', {'mix': mix});
  }

  @override
  void setCompressorEnabled(bool enabled) {
    _channel.invokeMethod('setCompressorEnabled', {'enabled': enabled});
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
  
  @override
  void setEQEnabled(bool enabled) {
    _channel.invokeMethod('setEqEnabled', {'enabled': enabled});
  }
  
  @override
  void setPitchCorrectionEnabled(bool enabled) {}
  
  @override
  void setPitchCorrectionStrength(double strength) {}
  
  @override
  void setPitchCorrectionSpeed(double speed) {}

  @override
  void setAutoTuneMode(AutoTuneMode mode) {
    _autoTuneMode = mode;
    _channel.invokeMethod('setAutoTuneMode', {'mode': mode.name});
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
  void setMasterVolume(double volume) {}
  
  @override
  void setVocalPan(double pan) {}
  
  @override
  void setNoiseReductionEnabled(bool enabled) {}
  
  @override
  void setNoiseReductionThreshold(double thresholdDb) {}

  @override
  double getPitchConfidence() => _confidence;

  @override
  double getPitchError() => _pitchError;

  @override
  double getCurrentUserPitch() => _currentPitch;

  @override
  double getTargetPitch() => _targetPitch;

  @override
  void resetEffects() {
    setVocalVolume(1.0);
    setInstrumentalVolume(0.85);
    setAutoTuneMode(AutoTuneMode.off);
    _activePreset = KaraokePreset.clean;
  }

  @override
  Future<String> exportMix({
    required double vocalVolume,
    required double instrumentalVolume,
    required KaraokeEffectsSettings settings,
    required Function(double progress) onProgress,
  }) async {
    bool isExporting = true;
    
    Timer.periodic(const Duration(milliseconds: 100), (timer) async {
      if (!isExporting) {
        timer.cancel();
        return;
      }
      try {
        final double progress = await _channel.invokeMethod('getExportProgress') ?? 0.0;
        onProgress(progress);
      } catch(e) {}
    });

    try {
      final String? result = await _channel.invokeMethod<String>('exportMix', {
        'vocalVolume': vocalVolume,
        'instrumentalVolume': instrumentalVolume,
        'outPath': '/sdcard/Download/karaoke_export_${DateTime.now().millisecondsSinceEpoch}.wav'
      });
      isExporting = false;
      onProgress(1.0);
      if (result != null) return result;
    } catch (e) {
      isExporting = false;
      throw Exception("EXPORT FAILED: $e");
    }
    isExporting = false;
    throw Exception("EXPORT FAILED: Unknown error");
  }

Future<void> _cancelStreams() async {
  print('🧹 Cancelling EventChannel subscriptions...');

  final positionSub = _positionSub;
  final pitchSub = _pitchSub;

  _positionSub = null;
  _pitchSub = null;

  _positionListening = false;
  _pitchListening = false;

  try {
    await positionSub?.cancel();
    print('🧹 POSITION subscription cancelled');
  } catch (e) {
    print('⚠️ POSITION cancel error: $e');
  }

  try {
    await pitchSub?.cancel();
    print('🧹 PITCH subscription cancelled');
  } catch (e) {
    print('⚠️ PITCH cancel error: $e');
  }
}

 
  @override
Future<void> dispose() async {
  print('🧹 NATIVE ENGINE dispose() START');

  if (_disposed) {
    print('🧹 dispose(): already disposed');
    return;
  }

  _disposed = true;

  _isPlayingState = false;
  _isRecordingState = false;

  await _cancelStreams();

  if (!_positionController.isClosed) {
    await _positionController.close();
  }

  // Jangan native dispose karena engine native dipakai
  // kembali oleh screen berikutnya.

  _initialized = false;

  print('🧹 NATIVE ENGINE dispose() END');
}
}
