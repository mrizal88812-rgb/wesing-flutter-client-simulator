import 'package:flutter/foundation.dart';
import 'stub_audio_engine.dart'
    if (dart.library.html) 'web_audio_engine.dart'
    if (dart.library.io) 'native_audio_engine.dart';

/// Predefined vocal effects presets for professional karaoke styling.
enum KaraokePreset {
  adjust,
  auto,
  aiAnalytics,
  clean,
  warm,
  studio,
  talented,
  stereo,
  distant,
  echo,
  hall,
  custom,
}

/// Real-time AutoTune modes for live pitch correction.
enum AutoTuneMode {
  off,
  natural,
  strong,
}

/// Abstract production-grade Karaoke Audio Engine interface.
/// Exposes real-time multi-track playing, recording, DSP parameters, and export.
abstract class KaraokeAudioEngine {
  /// Factory method to return the correct platform-specific audio engine.
  factory KaraokeAudioEngine.create() {
    return createPlatformAudioEngine();
  }

  // --- LIFECYCLE ---
  Future<void> initialize();
  Future<void> dispose();

  // --- SOURCE LOADING ---
  Future<void> loadInstrumental(String url);
  Future<void> loadVocal(String url, {double songStart = 0.0, double songEnd = 0.0});
  void setVocalRange(double songStart, double songEnd);

  // --- RECORDING & PLAYBACK CONTROLS ---
  Future<void> startRecording();
  Future<void> stopRecording();
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);

  // --- VOLUME & MIXING ---
  void setVocalVolume(double volume);        // 0.0 to 1.5
  void setInstrumentalVolume(double volume); // 0.0 to 1.2
  void setMasterVolume(double volume);       // 0.0 to 1.0
  void setVocalPan(double pan);              // -1.0 (Left) to 1.0 (Right)

  // --- REVERB EFFECTS ---
  void setReverbEnabled(bool enabled);
  void setReverbPreset(String preset);       // "Small Room", "Studio", "Hall", "Plate"
  void setReverbMix(double wet);             // 0.0 to 1.0

  // --- DELAY / ECHO EFFECTS ---
  void setDelayEnabled(bool enabled);
  void setDelayTime(int milliseconds);       // 50 to 1000 ms
  void setDelayFeedback(double feedback);    // 0.0 to 1.0
  void setDelayMix(double mix);              // 0.0 to 1.0

  // --- VOCAL COMPRESSOR ---
  void setCompressorEnabled(bool enabled);
  void setCompressorThreshold(double thresholdDb); // -60.0 to 0.0 dB
  void setCompressorRatio(double ratio);           // 1.0 to 20.0
  void setCompressorAttack(double attackMs);       // 1.0 to 100.0 ms
  void setCompressorRelease(double releaseMs);     // 10.0 to 1000.0 ms
  void setCompressorMakeupGain(double gainDb);     // 0.0 to 24.0 dB

  // --- PARAMETRIC EQUALIZER (EQ) ---
  void setEQEnabled(bool enabled);
  void setEQBand(int bandIndex, double frequency, double gainDb, double q);

  // --- PITCH DETECTION & CORRECTION ---
  void setPitchCorrectionEnabled(bool enabled);
  void setPitchCorrectionStrength(double strength); // 0.0 to 1.0
  void setPitchCorrectionSpeed(double speed);       // 0.0 to 1.0
  void setAutoTuneMode(AutoTuneMode mode);
  AutoTuneMode getAutoTuneMode();
  double getCurrentUserPitch();                    // Returns MIDI pitch or Hz
  double getTargetPitch();                         // Target melody pitch from pitch bars
  double getPitchConfidence();                     // 0.0 to 1.0 (YIN/AMDF confidence)
  double getPitchError();                          // Difference between current and target pitch in cents

  // --- PRO-TUNING ---
  void setProTuningEnabled(bool enabled);
  bool isProTuningEnabled();

  // --- NOISE REDUCTION / GATE ---
  void setNoiseReductionEnabled(bool enabled);
  void setNoiseReductionThreshold(double thresholdDb); // -80.0 to -30.0 dB

  // --- LATENCY COMPENSATION ---
  void setLatencyOffset(int milliseconds); // Compenses for Bluetooth/Wired delay

  // --- REAL-TIME MONITORING ---
  void setMonitoringEnabled(bool enabled); // Loopback voice to headphones

  // --- STATE ACCESSORS ---
  Duration getPlaybackPosition();
  Duration getDuration();
  bool isPlaying();
  bool isRecordingState();
  double getVocalVolume();
  double getInstrumentalVolume();
  int getLatencyOffset();
  
  // --- PRECISE AUDIO CLOCK STREAM ---
  /// Exposes a precise hardware-synced position changed stream to drive UI and pitch tracking
  Stream<Duration> get onPositionChanged;

  // --- PRESETS ---
  void applyPreset(KaraokePreset preset);
  KaraokePreset getActivePreset();

  // --- NON-DESTRUCTIVE RENDERING & EXPORT ---
  /// Renders the original vocal recording + instrumental with full DSP chain
  /// into a single final audio file. Emits progress via [onProgress] (0.0 to 1.0).
  Future<String> exportMix({
    required double vocalVolume,
    required double instrumentalVolume,
    required KaraokeEffectsSettings settings,
    required Function(double progress) onProgress,
  });

  /// Reset all audio effect parameter sliders to default values.
  void resetEffects();
}

/// Simple model representing standard effects parameter structures for ease of sharing.
class KaraokeEffectsSettings {
  final bool reverbEnabled;
  final String reverbPreset;
  final double reverbMix;
  final bool delayEnabled;
  final int delayTimeMs;
  final double delayFeedback;
  final double delayMix;
  final bool compressorEnabled;
  final double compressorThreshold;
  final double compressorRatio;
  final bool eqEnabled;
  final List<double> eqGains;
  final bool pitchCorrectionEnabled;
  final double pitchCorrectionStrength;
  final bool noiseReductionEnabled;

  KaraokeEffectsSettings({
    this.reverbEnabled = true,
    this.reverbPreset = 'Studio',
    this.reverbMix = 0.25,
    this.delayEnabled = false,
    this.delayTimeMs = 250,
    this.delayFeedback = 0.3,
    this.delayMix = 0.15,
    this.compressorEnabled = true,
    this.compressorThreshold = -24.0,
    this.compressorRatio = 4.0,
    this.eqEnabled = true,
    this.eqGains = const [0.0, 0.0, 0.0, 0.0],
    this.pitchCorrectionEnabled = false,
    this.pitchCorrectionStrength = 0.5,
    this.noiseReductionEnabled = true,
  });

  Map<String, dynamic> toJson() => {
    'reverbEnabled': reverbEnabled,
    'reverbPreset': reverbPreset,
    'reverbMix': reverbMix,
    'delayEnabled': delayEnabled,
    'delayTimeMs': delayTimeMs,
    'delayFeedback': delayFeedback,
    'delayMix': delayMix,
    'compressorEnabled': compressorEnabled,
    'compressorThreshold': compressorThreshold,
    'compressorRatio': compressorRatio,
    'eqEnabled': eqEnabled,
    'eqGains': eqGains,
    'pitchCorrectionEnabled': pitchCorrectionEnabled,
    'pitchCorrectionStrength': pitchCorrectionStrength,
    'noiseReductionEnabled': noiseReductionEnabled,
  };
}
