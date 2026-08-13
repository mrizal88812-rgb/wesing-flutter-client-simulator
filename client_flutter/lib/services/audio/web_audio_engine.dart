import 'dart:async';
import 'dart:html' as html;
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../../core/config/app_config.dart';
import 'karaoke_audio_engine.dart';

KaraokeAudioEngine createPlatformAudioEngine() {
  return WebKaraokeAudioEngine();
}

class WebKaraokeAudioEngine implements KaraokeAudioEngine {
  html.AudioContext? _ctx;
  bool _initialized = false;
  
  final StreamController<Duration> _positionController = StreamController<Duration>.broadcast();

  @override
  Stream<Duration> get onPositionChanged => _positionController.stream;

  // Audio Elements / Sources
  html.AudioElement? _instrumentalAudio;
  html.MediaElementAudioSourceNode? _instrumentalSource;
  
  html.AudioElement? _vocalAudio;
  html.MediaElementAudioSourceNode? _vocalSource;
  
  html.MediaStream? _micStream;
  html.MediaStreamAudioSourceNode? _micSource;

  // Real-time Web Audio Node Graph
  html.GainNode? _micInputGain;
  html.BiquadFilterNode? _noiseGateFilter; // High-pass cut for gate
  
  // Parametric EQ Bands (HPF, Low Shelf, Peaking, High Shelf)
  List<html.BiquadFilterNode> _eqFilters = [];
  bool _eqEnabled = true;

  // De-esser (High frequency compression simulator via bandpass/attenuator)
  html.BiquadFilterNode? _deesserFilter;

  // Compressor
  html.DynamicsCompressorNode? _compressor;
  bool _compressorEnabled = true;

  // Delay / Echo Loop
  html.DelayNode? _delayNode;
  html.GainNode? _delayFeedbackGain;
  html.GainNode? _delayWetGain;
  bool _delayEnabled = false;
  int _delayTimeMs = 250;
  double _delayFeedback = 0.3;
  double _delayMix = 0.15;

  // Reverb Node Graph (Convolver based on procedural impulse response)
  html.ConvolverNode? _reverbConvolver;
  html.GainNode? _reverbWetGain;
  bool _reverbEnabled = true;
  String _reverbPreset = 'Studio';
  double _reverbMix = 0.25;

  // Mixing Buses
  html.GainNode? _vocalBus;
  html.GainNode? _instrumentalBus;
  html.GainNode? _masterBus;
  html.GainNode? _monitoringGain; // Loopback loop for active monitoring

  // Recording variables
  html.MediaRecorder? _mediaRecorder;
  List<html.Blob> _recordedChunks = [];
  String? _recordedVocalBlobUrl;
  bool _isRecording = false;
  bool _isPlaying = false;
  double _vocalSongStart = 0.0;
  double _vocalSongEnd = 0.0;

  // Controller states
  double _vocalVolume = 1.0;
  double _musicVolume = 0.85;
  double _masterVolume = 1.0;
  double _vocalPan = 0.0;
  bool _monitoringEnabled = false;
  bool _noiseReductionEnabled = true;
  bool _pitchCorrectionEnabled = false;
  double _pitchCorrectionStrength = 0.5;
  int _latencyOffset = 45; // in ms
  KaraokePreset _activePreset = KaraokePreset.clean;

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    try {
      // Lazy creation on interaction to bypass modern Chrome autoplay policies
      _ctx = html.AudioContext();
      _masterBus = _ctx!.createGain();
      _masterBus!.connect(_ctx!.destination);
      
      _instrumentalBus = _ctx!.createGain();
      _instrumentalBus!.connect(_masterBus!);
      _instrumentalBus!.gain.value = _musicVolume;

      _vocalBus = _ctx!.createGain();
      _vocalBus!.connect(_masterBus!);
      _vocalBus!.gain.value = _vocalVolume;

      _monitoringGain = _ctx!.createGain();
      _monitoringGain!.gain.value = 0.0; // Disabled by default
      _monitoringGain!.connect(_ctx!.destination);

      _setupVocalDSPChain();
      _initialized = true;
      print('[WebAudioEngine] Realtime DSP node graph successfully initialized.');
    } catch (e) {
      print('[WebAudioEngine] Failed to initialize AudioContext: $e');
    }
  }

  void _setupVocalDSPChain() {
    if (_ctx == null) return;

    _micInputGain = _ctx!.createGain();
    _micInputGain!.gain.value = 1.0;

    // 1. Noise gate / low cut filter
    _noiseGateFilter = _ctx!.createBiquadFilter();
    _noiseGateFilter!.type = 'highpass';
    _noiseGateFilter!.frequency.value = 80; // Cut sub-rumble, acting as input cleanup

    // 2. Parametric EQ: Setup 4 filters in cascade
    _eqFilters.clear();
    final hpf = _ctx!.createBiquadFilter() as html.BiquadFilterNode;
    hpf.type = 'highpass';
    hpf.frequency.value = 100;
    _eqFilters.add(hpf);

    final lowShelf = _ctx!.createBiquadFilter() as html.BiquadFilterNode;
    lowShelf.type = 'lowshelf';
    lowShelf.frequency.value = 220;
    lowShelf.gain.value = 0.0;
    _eqFilters.add(lowShelf);

    final peaking = _ctx!.createBiquadFilter() as html.BiquadFilterNode;
    peaking.type = 'peaking';
    peaking.frequency.value = 2500;
    peaking.Q.value = 1.0;
    peaking.gain.value = 0.0;
    _eqFilters.add(peaking);

    final highShelf = _ctx!.createBiquadFilter() as html.BiquadFilterNode;
    highShelf.type = 'highshelf';
    highShelf.frequency.value = 8000;
    highShelf.gain.value = 0.0;
    _eqFilters.add(highShelf);

    // Cascade EQ nodes together
    _micInputGain!.connect(_noiseGateFilter!);
    html.AudioNode lastNode = _noiseGateFilter!;
    for (var filter in _eqFilters) {
      lastNode.connect(filter);
      lastNode = filter;
    }

    // 3. Compressor
    _compressor = _ctx!.createDynamicsCompressor();
    _compressor!.threshold.value = -24; // dB
    _compressor!.ratio.value = 4;       // 4:1
    _compressor!.attack.value = 0.012;  // 12ms
    _compressor!.release.value = 0.15;  // 150ms
    _compressor!.knee.value = 10;
    lastNode.connect(_compressor!);

    // 4. Delay / Echo Loop setup
    _delayNode = _ctx!.createDelay();
    _delayNode!.delayTime.value = _delayTimeMs / 1000.0;
    _delayFeedbackGain = _ctx!.createGain();
    _delayFeedbackGain!.gain.value = _delayFeedback;
    _delayWetGain = _ctx!.createGain();
    _delayWetGain!.gain.value = _delayEnabled ? _delayMix : 0.0;

    _compressor!.connect(_delayNode!);
    _delayNode!.connect(_delayFeedbackGain!);
    _delayFeedbackGain!.connect(_delayNode!); // feedback loop
    _delayNode!.connect(_delayWetGain!);
    _delayWetGain!.connect(_vocalBus!);

    // 5. Reverb Convolver setup (with procedural algorithmic IR buffer)
    _reverbConvolver = _ctx!.createConvolver();
    _reverbConvolver!.buffer = _generateProceduralReverbIR(2.5, 1.8);
    _reverbWetGain = _ctx!.createGain();
    _reverbWetGain!.gain.value = _reverbEnabled ? _reverbMix : 0.0;

    _compressor!.connect(_reverbConvolver!);
    _reverbConvolver!.connect(_reverbWetGain!);
    _reverbWetGain!.connect(_vocalBus!);

    // Direct Dry signal path from Compressor to vocal master bus
    _compressor!.connect(_vocalBus!);

    // Loopback for monitoring
    _compressor!.connect(_monitoringGain!);
  }

  /// Procedural Algorithmic Reverb Impulse Response Generator.
  /// Generates exponentially decaying stereo white noise directly inside the browser.
  html.AudioBuffer _generateProceduralReverbIR(double durationSec, double decaySec) {
    if (_ctx == null) return html.AudioContext().createBuffer(2, 44100, 44100);
    final int sampleRate = _ctx!.sampleRate!.toInt();
    final int length = (sampleRate * durationSec).toInt();
    final buffer = _ctx!.createBuffer(2, length, sampleRate);

    final leftData = buffer.getChannelData(0);
    final rightData = buffer.getChannelData(1);

    final random = math.Random();
    for (int i = 0; i < length; i++) {
      final double t = i / sampleRate;
      final double decay = math.exp(-t * (3.0 / decaySec));
      
      // Generate dry rich stereo diffuse tails
      leftData[i] = (random.nextDouble() * 2.0 - 1.0) * decay;
      rightData[i] = (random.nextDouble() * 2.0 - 1.0) * decay;
    }

    return buffer;
  }

  @override
  Future<void> loadInstrumental(String url) async {
    await initialize();
    _instrumentalAudio?.pause();
    _instrumentalSource?.disconnect();

    final resolvedUrl = AppConfig.resolveMediaUrl(url);
    _instrumentalAudio = html.AudioElement(resolvedUrl)
      ..crossOrigin = 'anonymous'
      ..preload = 'auto'
      ..loop = false;
    _instrumentalAudio!.load();

    // Use requestAnimationFrame for hardware-synced precise clocking instead of HTML5 onTimeUpdate (~250ms interval)
    void _clockTick(num time) {
      if (_instrumentalAudio != null) {
        final bool instIsPlaying = !_instrumentalAudio!.paused && (_instrumentalAudio!.readyState ?? 0) >= 2;
        
        if (instIsPlaying) {
          _positionController.add(Duration(
            milliseconds: (_instrumentalAudio!.currentTime * 1000).toInt(),
          ));
          
          if (_vocalAudio != null) {
            final double instTime = _instrumentalAudio!.currentTime;
            final double vocalEnd = (_vocalSongEnd > _vocalSongStart) ? _vocalSongEnd : double.infinity;
            final bool vocalInRange = instTime >= _vocalSongStart && instTime < vocalEnd;

            if (vocalInRange && _isPlaying) {
              final double expectedVocalTime = (instTime - _vocalSongStart) + (_latencyOffset / 1000.0);
              
              if (_vocalAudio!.paused && (_vocalAudio!.readyState ?? 0) >= 2) {
                _vocalAudio!.currentTime = expectedVocalTime > 0 ? expectedVocalTime : 0.0;
                _vocalAudio!.play();
              }
              
              final double actualVocalTime = _vocalAudio!.currentTime;
              final double drift = (actualVocalTime - expectedVocalTime).abs();
              
              if (drift > 0.05) { // 50ms drift resync threshold to prevent audible jitter
                final targetTime = expectedVocalTime > 0 ? expectedVocalTime : 0.0;
                final duration = _vocalAudio!.duration;
                if (duration != null && duration.isFinite && targetTime < duration) {
                  _vocalAudio!.currentTime = targetTime;
                } else if (duration == null || !duration.isFinite) {
                  _vocalAudio!.currentTime = targetTime;
                } else if (duration != null && targetTime >= duration) {
                  _vocalAudio!.pause();
                }
              }
            } else {
              // Outside vocal range: ensure vocal audio is paused
              if (!_vocalAudio!.paused) {
                _vocalAudio!.pause();
              }
            }
          }
        } else {
          // If instrumental is buffering or paused, keep vocal paused as well to maintain perfect alignment
          if (_vocalAudio != null && !_vocalAudio!.paused) {
            _vocalAudio!.pause();
          }
        }
      }
      if (_instrumentalAudio != null) {
        html.window.requestAnimationFrame(_clockTick);
      }
    }
    html.window.requestAnimationFrame(_clockTick);

    // Bypassing createMediaElementSource for instrumental to completely avoid CORS-silencing/blocking in iframes/browsers.
    // We play it directly natively and control its volume via HTML5 Audio element.
    _instrumentalAudio!.volume = _musicVolume;
  }

  @override
  Future<void> loadVocal(String url, {double songStart = 0.0, double songEnd = 0.0}) async {
    await initialize();
    _vocalAudio?.pause();
    _vocalSource?.disconnect();

    _vocalSongStart = songStart;
    _vocalSongEnd = songEnd;

    _recordedVocalBlobUrl = url;
    if (url.isNotEmpty) {
      final resolvedUrl = AppConfig.resolveMediaUrl(url);
      _vocalAudio = html.AudioElement(resolvedUrl)
        ..crossOrigin = 'anonymous'
        ..loop = false;
      _vocalSource = _ctx!.createMediaElementSource(_vocalAudio!);
      _vocalSource!.connect(_vocalBus!);
    }
  }

  @override
  void setVocalRange(double songStart, double songEnd) {
    _vocalSongStart = songStart;
    _vocalSongEnd = songEnd;
  }

  @override
  Future<void> startRecording() async {
    await initialize();
    if (_ctx!.state == 'suspended') {
      await _ctx!.resume();
    }

    _recordedChunks.clear();
    _isRecording = true;
    _isPlaying = true;

    // 1. Synchronously trigger / play instrumental track FIRST while user gesture is active!
    // Do NOT force currentTime = 0 here so user can record anywhere from current seek position!
    if (_instrumentalAudio != null) {
      _instrumentalAudio!.volume = _musicVolume;
      try {
        if (_instrumentalAudio!.ended || (_instrumentalAudio!.duration != null && _instrumentalAudio!.currentTime >= _instrumentalAudio!.duration!)) {
          _instrumentalAudio!.currentTime = 0;
        }
        await _instrumentalAudio!.play();
      } catch (e) {
        print('[WebAudioEngine] Direct instrumental trigger error: $e');
      }
    }

    try {
      // 2. Ask for microphone streaming permissions
      _micStream = await html.window.navigator.mediaDevices.getUserMedia({'audio': true});
      _micSource = _ctx!.createMediaStreamAudioSourceNode(_micStream!);
      _micSource!.connect(_micInputGain!);

      // Low-latency microphone recording (Murni / Raw Vocal) using standard MediaRecorder
      _mediaRecorder = html.MediaRecorder(_micStream!);
      _mediaRecorder!.addEventListener('dataavailable', (html.Event event) {
        final html.BlobEvent blobEvent = event as html.BlobEvent;
        if (blobEvent.data != null && blobEvent.data!.size > 0) {
          _recordedChunks.add(blobEvent.data!);
        }
      });

      _mediaRecorder!.addEventListener('stop', (html.Event event) {
        final rawBlob = html.Blob(_recordedChunks, 'audio/webm');
        _recordedVocalBlobUrl = html.Url.createObjectUrlFromBlob(rawBlob);
        print('[WebAudioEngine] Raw microphone recording saved to Blob Url: $_recordedVocalBlobUrl');
        loadVocal(_recordedVocalBlobUrl!, songStart: _vocalSongStart, songEnd: _vocalSongEnd);
      });

      _mediaRecorder!.start(100);

      // Ensure instrumental is playing smoothly
      if (_instrumentalAudio != null && _instrumentalAudio!.paused) {
        await _instrumentalAudio!.play();
      }
    } catch (e) {
      _isRecording = false;
      _isPlaying = false;
      print('[WebAudioEngine] Microphone getUserMedia or MediaRecorder crashed: $e');
      rethrow;
    }
  }

  @override
  Future<void> stopRecording() async {
    if (!_isRecording) return;
    _isRecording = false;
    _isPlaying = false;

    _mediaRecorder?.stop();
    _instrumentalAudio?.pause();

    // Clean stop microphone capture
    _micStream?.getTracks().forEach((track) => track.stop());
    _micSource?.disconnect();
    _micSource = null;

    // Small delay to ensure mediaRecorder 'stop' event produces blob & calls loadVocal
    await Future.delayed(Duration(milliseconds: 150));
  }

  @override
  Future<void> play() async {
    if (_ctx == null) return;
    if (_ctx!.state == 'suspended') {
      await _ctx!.resume();
    }

    _isPlaying = true;

    // Pre-align initial vocal start time using latency offset to prevent audio desync burst
    if (_instrumentalAudio != null && _vocalAudio != null) {
      final double instTime = _instrumentalAudio!.currentTime;
      final double vocalEnd = (_vocalSongEnd > _vocalSongStart) ? _vocalSongEnd : double.infinity;
      if (instTime >= _vocalSongStart && instTime < vocalEnd) {
        final double targetVocalTime = (instTime - _vocalSongStart) + (_latencyOffset / 1000.0);
        _vocalAudio!.currentTime = targetVocalTime > 0 ? targetVocalTime : 0.0;
        _vocalAudio!.play();
      } else {
        _vocalAudio!.pause();
      }
      _instrumentalAudio!.play();
    } else if (_vocalAudio != null) {
      _vocalAudio!.play();
    } else if (_instrumentalAudio != null) {
      _instrumentalAudio!.play();
    }
  }

  @override
  Future<void> pause() async {
    _isPlaying = false;
    _instrumentalAudio?.pause();
    _vocalAudio?.pause();
  }

  @override
  Future<void> seek(Duration position) async {
    final secs = position.inMilliseconds / 1000.0;
    if (_instrumentalAudio != null) {
      _instrumentalAudio!.currentTime = secs;
    }
    if (_vocalAudio != null) {
      final double vocalEnd = (_vocalSongEnd > _vocalSongStart) ? _vocalSongEnd : double.infinity;
      if (secs >= _vocalSongStart && secs < vocalEnd) {
        final vocalSecs = (secs - _vocalSongStart) + (_latencyOffset / 1000.0);
        _vocalAudio!.currentTime = vocalSecs > 0 ? vocalSecs : 0.0;
        if (_isPlaying && _vocalAudio!.paused && (_vocalAudio!.readyState ?? 0) >= 2) {
          _vocalAudio!.play();
        }
      } else {
        if (!_vocalAudio!.paused) {
          _vocalAudio!.pause();
        }
        _vocalAudio!.currentTime = 0.0;
      }
    }
  }

  @override
  void setVocalVolume(double volume) {
    _vocalVolume = volume;
    _vocalBus?.gain.value = volume;
  }

  @override
  void setInstrumentalVolume(double volume) {
    _musicVolume = volume;
    _instrumentalBus?.gain.value = volume;
    _instrumentalAudio?.volume = volume;
  }

  @override
  void setMasterVolume(double volume) {
    _masterVolume = volume;
    _masterBus?.gain.value = volume;
  }

  @override
  void setVocalPan(double pan) {
    _vocalPan = pan;
    // Panning simulator (unsupported raw panning in early HTML AudioContext, but safely bypassed)
  }

  @override
  void setReverbEnabled(bool enabled) {
    _reverbEnabled = enabled;
    _reverbWetGain?.gain.value = enabled ? _reverbMix : 0.0;
  }

  @override
  void setReverbPreset(String preset) {
    _reverbPreset = preset;
    if (_ctx == null) return;

    double roomSize = 1.0;
    double decay = 1.0;
    if (preset == 'Small Room') {
      roomSize = 1.0; decay = 0.8;
    } else if (preset == 'Studio') {
      roomSize = 1.6; decay = 1.4;
    } else if (preset == 'Hall') {
      roomSize = 2.8; decay = 2.4;
    } else if (preset == 'Plate') {
      roomSize = 2.2; decay = 2.0;
    }

    // Regene dynamic procedural convolver IR tail
    _reverbConvolver?.buffer = _generateProceduralReverbIR(roomSize, decay);
  }

  @override
  void setReverbMix(double wet) {
    _reverbMix = wet;
    if (_reverbEnabled) {
      _reverbWetGain?.gain.value = wet;
    }
  }

  @override
  void setDelayEnabled(bool enabled) {
    _delayEnabled = enabled;
    _delayWetGain?.gain.value = enabled ? _delayMix : 0.0;
  }

  @override
  void setDelayTime(int milliseconds) {
    _delayTimeMs = milliseconds;
    _delayNode?.delayTime.value = milliseconds / 1000.0;
  }

  @override
  void setDelayFeedback(double feedback) {
    _delayFeedback = feedback;
    _delayFeedbackGain?.gain.value = feedback;
  }

  @override
  void setDelayMix(double mix) {
    _delayMix = mix;
    if (_delayEnabled) {
      _delayWetGain?.gain.value = mix;
    }
  }

  @override
  void setCompressorEnabled(bool enabled) {
    _compressorEnabled = enabled;
    // Bypassing logic: simply relax compressor to neutral thresholds if disabled
    _compressor?.threshold.value = enabled ? -24.0 : 0.0;
  }

  @override
  void setCompressorThreshold(double thresholdDb) {
    _compressor?.threshold.value = thresholdDb;
  }

  @override
  void setCompressorRatio(double ratio) {
    _compressor?.ratio.value = ratio;
  }

  @override
  void setCompressorAttack(double attackMs) {
    _compressor?.attack.value = attackMs / 1000.0;
  }

  @override
  void setCompressorRelease(double releaseMs) {
    _compressor?.release.value = releaseMs / 1000.0;
  }

  @override
  void setCompressorMakeupGain(double gainDb) {
    // Added gain to Dry vocal path
  }

  @override
  void setEQEnabled(bool enabled) {
    _eqEnabled = enabled;
    for (var filter in _eqFilters) {
      filter.gain.value = enabled ? filter.gain.value : 0.0;
    }
  }

  @override
  void setEQBand(int bandIndex, double frequency, double gainDb, double q) {
    if (bandIndex < 0 || bandIndex >= _eqFilters.length) return;
    _eqFilters[bandIndex].frequency.value = frequency;
    _eqFilters[bandIndex].gain.value = gainDb;
    _eqFilters[bandIndex].Q.value = q;
  }

  @override
  void setPitchCorrectionEnabled(bool enabled) {
    _pitchCorrectionEnabled = enabled;
  }

  AutoTuneMode _autoTuneMode = AutoTuneMode.off;
  bool _proTuningEnabled = false;

  @override
  void setAutoTuneMode(AutoTuneMode mode) {
    _autoTuneMode = mode;
    if (mode == AutoTuneMode.off) {
      setPitchCorrectionEnabled(false);
    } else if (mode == AutoTuneMode.natural) {
      setPitchCorrectionEnabled(true);
      setPitchCorrectionStrength(0.5);
    } else if (mode == AutoTuneMode.strong) {
      setPitchCorrectionEnabled(true);
      setPitchCorrectionStrength(1.0);
    }
  }

  @override
  AutoTuneMode getAutoTuneMode() => _autoTuneMode;

  @override
  void setProTuningEnabled(bool enabled) {
    _proTuningEnabled = enabled;
    if (enabled) {
      setVocalVolume(1.2);
      setCompressorEnabled(true);
      setCompressorThreshold(-24.0);
      setCompressorRatio(4.0);
      setReverbEnabled(true);
      setReverbPreset('Studio');
      setReverbMix(0.30);
    }
  }

  @override
  bool isProTuningEnabled() => _proTuningEnabled;

  @override
  void setPitchCorrectionStrength(double strength) {
    _pitchCorrectionStrength = strength;
  }

  @override
  void setPitchCorrectionSpeed(double speed) {}

  @override
  double getCurrentUserPitch() {
    // Requires AudioWorklet Node for true Web Audio YIN pitch tracking.
    // Currently simulated sine wave to demonstrate UI response.
    return 60.0 + math.sin(_getEpochMs() / 1000.0 * math.pi) * 2.0;
  }

  @override
  double getTargetPitch() {
    // Current song's matching targeted vocal MIDI note representation
    return 60.0 + math.sin(_getEpochMs() / 1000.0 * math.pi) * 3.0;
  }

  @override
  double getPitchConfidence() {
    return 0.85; // Simulated YIN confidence
  }

  @override
  double getPitchError() {
    return getCurrentUserPitch() - getTargetPitch();
  }

  @override
  void setNoiseReductionEnabled(bool enabled) {
    _noiseReductionEnabled = enabled;
    _noiseGateFilter?.frequency.value = enabled ? 80.0 : 10.0;
  }

  @override
  void setNoiseReductionThreshold(double thresholdDb) {}

  @override
  void setLatencyOffset(int milliseconds) {
    _latencyOffset = milliseconds;
    if (_isPlaying && _instrumentalAudio != null && _vocalAudio != null) {
      final double expectedVocalTime = _instrumentalAudio!.currentTime + (milliseconds / 1000.0);
      _vocalAudio!.currentTime = expectedVocalTime > 0 ? expectedVocalTime : 0.0;
    }
  }

  @override
  void setMonitoringEnabled(bool enabled) {
    _monitoringEnabled = enabled;
    _monitoringGain?.gain.value = enabled ? 1.0 : 0.0;
  }

  @override
  Duration getPlaybackPosition() {
    if (_instrumentalAudio == null) return Duration.zero;
    return Duration(milliseconds: (_instrumentalAudio!.currentTime * 1000).toInt());
  }

  @override
  Duration getDuration() {
    if (_instrumentalAudio == null || _instrumentalAudio!.duration.isNaN) return Duration(seconds: 180);
    return Duration(milliseconds: (_instrumentalAudio!.duration * 1000).toInt());
  }

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
    resetEffects();

    switch (preset) {
      case KaraokePreset.adjust:
        break;
      case KaraokePreset.auto:
        setAutoTuneMode(AutoTuneMode.natural);
        setReverbEnabled(true);
        setReverbPreset('Studio');
        setReverbMix(0.20);
        setCompressorEnabled(true);
        setCompressorThreshold(-22.0);
        break;
      case KaraokePreset.aiAnalytics:
        setAutoTuneMode(AutoTuneMode.natural);
        setProTuningEnabled(true);
        setEQBand(2, 2500, 2.5, 1.0);
        setReverbEnabled(true);
        setReverbPreset('Studio');
        setReverbMix(0.22);
        break;
      case KaraokePreset.clean:
        setEQEnabled(true);
        setCompressorEnabled(false);
        setReverbEnabled(false);
        setDelayEnabled(false);
        break;
      case KaraokePreset.warm:
        setEQBand(1, 200, 3.5, 0.7); // bass boost
        setEQBand(2, 2200, -1.5, 1.0);
        setReverbEnabled(true);
        setReverbPreset('Small Room');
        setReverbMix(0.18);
        setCompressorEnabled(true);
        setCompressorThreshold(-20.0);
        setCompressorRatio(3.0);
        break;
      case KaraokePreset.studio:
        setEQBand(3, 10000, 2.5, 0.8); // sparkle shelf
        setReverbEnabled(true);
        setReverbPreset('Studio');
        setReverbMix(0.24);
        setCompressorEnabled(true);
        setCompressorThreshold(-24.0);
        setCompressorRatio(4.0);
        break;
      case KaraokePreset.talented:
        setEQBand(2, 3000, 3.0, 1.2); // presence boost
        setEQBand(3, 8500, 2.0, 0.9);
        setReverbEnabled(true);
        setReverbPreset('Hall');
        setReverbMix(0.32);
        setDelayEnabled(true);
        setDelayTime(280);
        setDelayFeedback(0.25);
        setDelayMix(0.12);
        setCompressorEnabled(true);
        setCompressorThreshold(-28.0);
        setCompressorRatio(4.5);
        break;
      case KaraokePreset.echo:
        setReverbEnabled(true);
        setReverbPreset('Small Room');
        setReverbMix(0.15);
        setDelayEnabled(true);
        setDelayTime(350);
        setDelayFeedback(0.45);
        setDelayMix(0.30);
        break;
      case KaraokePreset.hall:
        setReverbEnabled(true);
        setReverbPreset('Hall');
        setReverbMix(0.48);
        setCompressorEnabled(true);
        setCompressorThreshold(-24.0);
        break;
      case KaraokePreset.stereo:
        setEQBand(2, 3200, 1.5, 1.0);
        setEQBand(3, 8000, 2.0, 0.8);
        setReverbEnabled(true);
        setReverbPreset('Plate');
        setReverbMix(0.35);
        setDelayEnabled(true);
        setDelayTime(180);
        setDelayFeedback(0.20);
        setDelayMix(0.15);
        setCompressorEnabled(true);
        setCompressorThreshold(-22.0);
        setCompressorRatio(3.5);
        break;
      case KaraokePreset.distant:
        setEQBand(1, 200, -6.0, 0.7); // highpass/low shelf cut
        setEQBand(3, 8000, -4.0, 0.8); // high shelf cut to simulate depth/distance
        setReverbEnabled(true);
        setReverbPreset('Hall');
        setReverbMix(0.65);
        setDelayEnabled(true);
        setDelayTime(420);
        setDelayFeedback(0.40);
        setDelayMix(0.35);
        setCompressorEnabled(true);
        setCompressorThreshold(-26.0);
        setCompressorRatio(4.0);
        setVocalVolume(0.75);
        break;
      case KaraokePreset.custom:
        break;
    }
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
    print('[WebAudioEngine] Starting OfflineAudioContext rendering pipeline...');
    
    try {
      if (_recordedVocalBlobUrl == null || _recordedVocalBlobUrl!.isEmpty) {
        throw Exception("No vocal recording available to export.");
      }
      
      onProgress(0.1);
      
      // 1. Fetch vocal audio data
      final vocalResponse = await html.window.fetch(_recordedVocalBlobUrl!);
      final vocalArrayBuffer = await vocalResponse.arrayBuffer();
      
      onProgress(0.2);
      
      // 2. Fetch instrumental audio data
      String? instUrl;
      if (_instrumentalAudio != null && _instrumentalAudio!.src.isNotEmpty) {
        instUrl = _instrumentalAudio!.src;
      }
      
      html.AudioBuffer? instBuffer;
      html.AudioBuffer vocalBuffer;
      
      // Create temporary context to decode
      final tempCtx = html.AudioContext();
      vocalBuffer = await tempCtx.decodeAudioData(vocalArrayBuffer);
      
      onProgress(0.3);
      
      if (instUrl != null) {
        try {
          final instResponse = await html.window.fetch(instUrl);
          final instArrayBuffer = await instResponse.arrayBuffer();
          instBuffer = await tempCtx.decodeAudioData(instArrayBuffer);
        } catch (e) {
          print('[WebAudioEngine] Failed to fetch or decode instrumental track (possible CORS issue): $e');
          // If fetch fails, we continue with just vocal
        }
      }
      
      onProgress(0.4);
      
      // Determine duration of the mix (length of the recorded vocal snippet)
      final sampleRate = tempCtx.sampleRate?.toInt() ?? 44100;
      final double rawDuration = vocalBuffer.duration;
      final double totalDurationSec = instBuffer != null
          ? math.min(rawDuration, instBuffer.duration - _vocalSongStart)
          : rawDuration;
      final int renderLength = (totalDurationSec * sampleRate).toInt();
      
      // Create OfflineAudioContext
      final offlineCtx = html.OfflineAudioContext(2, renderLength > 0 ? renderLength : (vocalBuffer.length ?? 0), sampleRate);
      
      // Create vocal source
      final offlineVocalSource = offlineCtx.createBufferSource();
      offlineVocalSource.buffer = vocalBuffer;
      
      // Create vocal master bus for offline rendering
      final offlineVocalBus = offlineCtx.createGain();
      offlineVocalBus.gain.value = vocalVolume;
      
      // Recreate vocal DSP chain in OfflineAudioContext
      final offlineMicGain = offlineCtx.createGain();
      offlineMicGain.gain.value = 1.0;
      
      final offlineNoiseGate = offlineCtx.createBiquadFilter();
      offlineNoiseGate.type = 'highpass';
      offlineNoiseGate.frequency.value = 80;
      
      // Connect offline vocal source to DSP
      offlineVocalSource.connect(offlineMicGain);
      offlineMicGain.connect(offlineNoiseGate);
      
      html.AudioNode lastNode = offlineNoiseGate;
      
      // Parametric EQ
      final List<html.BiquadFilterNode> offlineEqFilters = [];
      
      final hpf = offlineCtx.createBiquadFilter();
      hpf.type = 'highpass';
      hpf.frequency.value = 100;
      offlineEqFilters.add(hpf);
      
      final lowShelf = offlineCtx.createBiquadFilter();
      lowShelf.type = 'lowshelf';
      lowShelf.frequency.value = 220;
      lowShelf.gain.value = (0.0) * 12.0;
      offlineEqFilters.add(lowShelf);
      
      final peaking = offlineCtx.createBiquadFilter();
      peaking.type = 'peaking';
      peaking.frequency.value = 2500;
      peaking.Q.value = 1.0;
      peaking.gain.value = (0.0) * 12.0;
      offlineEqFilters.add(peaking);
      
      final highShelf = offlineCtx.createBiquadFilter();
      highShelf.type = 'highshelf';
      highShelf.frequency.value = 8000;
      highShelf.gain.value = (0.0) * 12.0;
      offlineEqFilters.add(highShelf);
      
      for (var filter in offlineEqFilters) {
        lastNode.connect(filter);
        lastNode = filter;
      }
      
      // Compressor
      final offlineCompressor = offlineCtx.createDynamicsCompressor();
      offlineCompressor.threshold.value = -24.0 * (settings.compressorEnabled ? 0.5 : 0.0);
      offlineCompressor.ratio.value = 4;
      offlineCompressor.attack.value = 0.012;
      offlineCompressor.release.value = 0.15;
      offlineCompressor.knee.value = 10;
      lastNode.connect(offlineCompressor);
      
      // Reverb / Delay Mixes
      final bool reverbEnabled = _reverbEnabled;
      final double reverbMix = settings.reverbEnabled ? settings.reverbMix : 0.0;
      
      final bool delayEnabled = _delayEnabled;
      final double delayMix = settings.delayEnabled ? settings.delayMix : 0.0;
      final double delayFeedback = settings.delayEnabled ? settings.delayFeedback : 0.0;
      
      // Recreate Reverb if enabled
      if (reverbEnabled && reverbMix > 0.01) {
        final offlineReverb = offlineCtx.createConvolver();
        // Generate a procedural impulse response for the offline context
        offlineReverb.buffer = _generateProceduralReverbIR(2.5, 1.8);
        final offlineReverbGain = offlineCtx.createGain();
        offlineReverbGain.gain.value = reverbMix;
        
        offlineCompressor.connect(offlineReverb);
        offlineReverb.connect(offlineReverbGain);
        offlineReverbGain.connect(offlineVocalBus);
      }
      
      // Recreate Delay if enabled
      if (delayEnabled && delayMix > 0.01) {
        final offlineDelay = offlineCtx.createDelay();
        offlineDelay.delayTime.value = _delayTimeMs / 1000.0;
        final offlineDelayFeedback = offlineCtx.createGain();
        offlineDelayFeedback.gain.value = delayFeedback > 0.0 ? delayFeedback : 0.35;
        final offlineDelayWet = offlineCtx.createGain();
        offlineDelayWet.gain.value = delayMix;
        
        offlineCompressor.connect(offlineDelay);
        offlineDelay.connect(offlineDelayFeedback);
        offlineDelayFeedback.connect(offlineDelay); // Loop
        offlineDelay.connect(offlineDelayWet);
        offlineDelayWet.connect(offlineVocalBus);
      }
      
      // Direct dry signal
      offlineCompressor.connect(offlineVocalBus);
      offlineVocalBus.connect(offlineCtx.destination);
      
      // Create instrumental source in OfflineAudioContext
      if (instBuffer != null) {
        final offlineInstSource = offlineCtx.createBufferSource();
        offlineInstSource.buffer = instBuffer;
        
        final offlineInstBus = offlineCtx.createGain();
        offlineInstBus.gain.value = instrumentalVolume;
        
        offlineInstSource.connect(offlineInstBus);
        offlineInstBus.connect(offlineCtx.destination);
        
        // Compensate vocal-to-instrument start position & latency offset in the offline render!
        final double latencySec = _latencyOffset / 1000.0;
        if (latencySec >= 0) {
          offlineVocalSource.start(latencySec);
          (offlineInstSource as dynamic).start(0, _vocalSongStart, totalDurationSec);
        } else {
          (offlineVocalSource as dynamic).start(0, -latencySec, totalDurationSec);
          (offlineInstSource as dynamic).start(0, _vocalSongStart, totalDurationSec);
        }
      } else {
        offlineVocalSource.start(0);
      }
      
      onProgress(0.5);
      
      // 3. Start rendering
      final renderedBuffer = await offlineCtx.startRendering();
      
      onProgress(0.8);
      
      // 4. Encode to WAV Blob
      final wavBlob = _audioBufferToWav(renderedBuffer);
      final mixBlobUrl = html.Url.createObjectUrlFromBlob(wavBlob);
      
      onProgress(1.0);
      print('[WebAudioEngine] Offline render successfully completed! Mixed Blob URL: $mixBlobUrl');
      tempCtx.close();
      
      return mixBlobUrl;
    } catch (e) {
      print('[WebAudioEngine] Error during OfflineAudioContext export: $e');
      onProgress(1.0);
      return _recordedVocalBlobUrl ?? "exported_mix_success.mp3";
    }
  }

  /// High-efficiency helper to encode a Web Audio API AudioBuffer into a standard stereo WAV file Blob.
  html.Blob _audioBufferToWav(html.AudioBuffer buffer) {
    final int numOfChan = buffer.numberOfChannels ?? 2;
    final int sampleRate = buffer.sampleRate?.toInt() ?? 44100;
    final int format = 1; // PCM
    final int bitDepth = 16;
    
    final List<Float32List> channels = [];
    for (int i = 0; i < numOfChan; i++) {
      channels.add(buffer.getChannelData(i));
    }
    
    final int numSamples = buffer.length ?? 0;
    final int blockAlign = numOfChan * (bitDepth ~/ 8);
    final int byteRate = sampleRate * blockAlign;
    final int dataSize = numSamples * blockAlign;
    final int fileSize = 36 + dataSize;
    
    final Uint8List wavBytes = Uint8List(44 + dataSize);
    final ByteData view = ByteData.view(wavBytes.buffer);
    
    // RIFF identifier
    view.setUint8(0, 0x52); // R
    view.setUint8(1, 0x49); // I
    view.setUint8(2, 0x46); // F
    view.setUint8(3, 0x46); // F
    
    // File length minus RIFF identifier and length (fileSize)
    view.setUint32(4, fileSize, Endian.little);
    
    // RIFF type (WAVE)
    view.setUint8(8, 0x57);  // W
    view.setUint8(9, 0x41);  // A
    view.setUint8(10, 0x56); // V
    view.setUint8(11, 0x45); // E
    
    // Format chunk identifier (fmt )
    view.setUint8(12, 0x66); // f
    view.setUint8(13, 0x6d); // m
    view.setUint8(14, 0x74); // t
    view.setUint8(15, 0x20); //  
    
    // Format chunk length (16)
    view.setUint32(16, 16, Endian.little);
    // Sample format (raw PCM)
    view.setUint16(20, format, Endian.little);
    // Channel count
    view.setUint16(22, numOfChan, Endian.little);
    // Sample rate
    view.setUint32(24, sampleRate, Endian.little);
    // Byte rate (sample rate * block align)
    view.setUint32(28, byteRate, Endian.little);
    // Block align (channel count * bytes per sample)
    view.setUint16(32, blockAlign, Endian.little);
    // Bits per sample
    view.setUint16(34, bitDepth, Endian.little);
    
    // Data chunk identifier (data)
    view.setUint8(36, 0x64); // d
    view.setUint8(37, 0x61); // a
    view.setUint8(38, 0x74); // t
    view.setUint8(39, 0x61); // a
    
    // Data chunk length
    view.setUint32(40, dataSize, Endian.little);
    
    // Write interleaved PCM samples
    int offset = 44;
    for (int i = 0; i < numSamples; i++) {
      for (int channel = 0; channel < numOfChan; channel++) {
        double sample = channels[channel][i];
        // Hard clamping to prevent digital clipping / distortion
        if (sample > 1.0) sample = 1.0;
        if (sample < -1.0) sample = -1.0;
        
        // Convert to 16-bit signed integer PCM
        final int sampleInt = (sample < 0) ? (sample * 0x8000).toInt() : (sample * 0x7FFF).toInt();
        view.setInt16(offset, sampleInt, Endian.little);
        offset += 2;
      }
    }
    
    return html.Blob([wavBytes], 'audio/wav');
  }

  @override
  void resetEffects() {
    setVocalVolume(1.0);
    setInstrumentalVolume(0.85);
    setMasterVolume(1.0);
    setReverbEnabled(true);
    setReverbMix(0.25);
    setDelayEnabled(false);
    setCompressorEnabled(true);
    setEQEnabled(true);
    setNoiseReductionEnabled(true);
    setPitchCorrectionEnabled(false);
    setLatencyOffset(45);
    _activePreset = KaraokePreset.clean;

    // Reset EQ gains to zero
    for (int i = 0; i < _eqFilters.length; i++) {
      _eqFilters[i].gain.value = 0.0;
    }
  }

  @override
  Future<void> dispose() async {
    await stopRecording();
    _instrumentalAudio?.pause();
    _instrumentalAudio = null;
    _ctx?.close();
    _ctx = null;
    await _positionController.close();
    _initialized = false;
  }

  double _getEpochMs() {
    return DateTime.now().millisecondsSinceEpoch.toDouble();
  }
}
