#pragma once
#include <android/log.h>
#include <atomic>
#include <cmath>
#include <fstream>
#include <mutex>
#include <string>
#include <vector>

#define LOGD(...)                                                              \
  __android_log_print(ANDROID_LOG_DEBUG, "DspProcessor", __VA_ARGS__)

enum class AutoTuneMode { OFF = 0, NATURAL = 1, STRONG = 2 };

// Structure to track individual vocal segments with their absolute timeline positions
struct VocalSegment {
  size_t startFrameInBuffer;    // Where in vocalRecording buffer this segment starts
  size_t numFrames;             // Duration of this segment in frames
  size_t songStartFrame;        // Absolute position in song timeline where recording started
  size_t songEndFrame;          // Absolute position in song timeline where recording ended
  
  VocalSegment() : startFrameInBuffer(0), numFrames(0), songStartFrame(0), songEndFrame(0) {}
  VocalSegment(size_t bufStart, size_t frames, size_t songStart, size_t songEnd)
    : startFrameInBuffer(bufStart), numFrames(frames), songStartFrame(songStart), songEndFrame(songEnd) {}
};

struct BiquadFilter {
  float b0{1.0f}, b1{0.0f}, b2{0.0f}, a1{0.0f}, a2{0.0f};
  float z1{0.0f}, z2{0.0f};
  float process(float in) {
    float out = in * b0 + z1;
    z1 = in * b1 - out * a1 + z2;
    z2 = in * b2 - out * a2;
    return out;
  }
  void setPeaking(float freq, float gainDb, float Q, float sampleRate) {
    float A = std::pow(10.0f, gainDb / 40.0f);
    float w0 = 2.0f * 3.1415926535f * freq / sampleRate;
    float alpha = std::sin(w0) / (2.0f * Q);

    float norm = 1.0f + alpha / A;
    b0 = (1.0f + alpha * A) / norm;
    b1 = (-2.0f * std::cos(w0)) / norm;
    b2 = (1.0f - alpha * A) / norm;
    a1 = (-2.0f * std::cos(w0)) / norm;
    a2 = (1.0f - alpha / A) / norm;
  }
};

class DspProcessor {
public:
  DspProcessor(int sampleRate);
  ~DspProcessor();

  // New Realtime callbacks
  void processInputRealtime(float *inBuffer, int numFrames);
  void processOutputRealtime(float *outBuffer, int numFrames);

  // Audio State
  void loadInstrumental(const float *pcmData, size_t numSamples);
  void startRecording();
  void stopRecording();
  void finalizeRecordingSegment();  // Save current recording segment with timeline position
  void play();
  void pause();
  void seek(float positionSeconds);
  float getPlaybackPosition() const;
  float getDuration() const;
  bool exportMix(float vocalVol, float instVol, const std::string &outPath);

  // Monitoring
  void setMonitoringEnabled(bool enabled);

  // Latency compensation (mic capture + DSP + output round-trip delay)
  void setLatencyOffset(int offsetMs);

  // Parameters
  void setVocalVolume(float vol);
  void setInstrumentalVolume(float vol);

  void setNoiseGate(bool enabled, float threshold);
  void setCompressor(bool enabled, float threshold, float ratio);
  void setReverb(bool enabled, float mix, float roomSize = 0.8f,
                 float damp = 0.5f);
  void setDelay(bool enabled, float timeMs, float feedback, float mix);
  void setEq(int band, float freq, float gain, float q);
  void setEqEnabled(bool enabled);
  void setPitchCorrectionMode(AutoTuneMode mode, float speed = 0.8f,
                              float targetPitchHz = 0.0f);

  // Results
  float getCurrentPitch() const { return currentPitch.load(); }
  float getConfidence() const { return pitchConfidence.load(); }
  float getExportProgress() const { return exportProgress.load(); }
  size_t getVocalSegmentsCount() const { return vocalSegments.size(); }
  const std::vector<VocalSegment>& getVocalSegments() const { return vocalSegments; }

private:
  int sampleRate;

  // Playback state
  std::vector<float> instrumentalBuffer;
  std::vector<float> vocalRecording;
  std::vector<VocalSegment> vocalSegments;  // Track multiple vocal segments with absolute timeline positions
  size_t recordingStartFrame{0};
  size_t currentSegmentStartFrame{0};  // Buffer position where current recording segment started
  std::atomic<bool> isPlaying{false};
  std::atomic<bool> isRecording{false};
  std::atomic<size_t> playbackFrame{0};
  std::atomic<bool> monitoringEnabled{true};
  std::atomic<float> exportProgress{0.0f};
  std::atomic<int> latencyOffsetFrames{0};

  // DSP State & Smoothing
  std::atomic<float> vocalVol{1.0f};
  std::atomic<float> instVol{1.0f};
  float smoothVocalVol{1.0f};
  float smoothInstVol{1.0f};
  float smoothReverbMix{0.0f};
  float smoothDelayMix{0.0f};

  // Noise Gate
  bool gateEnabled{false};
  float gateThreshold{0.01f};
  float gateEnvelope{0.0f};
  float gateGain{1.0f};

  // Biquad EQ
  BiquadFilter eqBands[3];
  bool eqEnabled{true};

  // Reverb
  bool reverbEnabled{false};
  float reverbMix{0.0f};
  float roomSizeSetting{0.8f};
  float dampSetting{0.5f};
  std::vector<float> revBuffer1, revBuffer2, revBuffer3, revBuffer4;
  std::vector<float> allpassBuf1, allpassBuf2;
  int revPtr1{0}, revPtr2{0}, revPtr3{0}, revPtr4{0};
  int apPtr1{0}, apPtr2{0};

  // Delay
  bool delayEnabled{false};
  float delayTimeMs{0.0f};
  float delayFeedback{0.0f};
  float delayMix{0.0f};
  std::vector<float> delayBuffer;
  int delayWritePtr{0};

  // Pitch Detection
  std::atomic<float> currentPitch{0.0f};
  std::atomic<float> pitchConfidence{0.0f};
  int pitchDetectionSkipCounter{0};
  static constexpr int PITCH_DETECTION_INTERVAL = 3;

  // Pitch Correction
  AutoTuneMode autoTuneMode{AutoTuneMode::OFF};
  float pitchCorrectionSpeed{0.8f};
  float targetPitchHz{0.0f};
  float smoothedTargetPitch{0.0f};
  std::vector<float> grainBuffer;
  int grainWritePtr{0};
  float grainReadPtr1{0.0f};
  float grainReadPtr2{0.0f};
  int grainSize{1024};

  // Compressor
  bool compEnabled{false};
  float compThreshold{-24.0f};
  float compRatio{3.0f};
  float compEnvelope{0.0f};

  // Limiter
  float limiterEnvelope{0.0f};

  void applyPitchDetection(float *buffer, int frames);
  void applyPitchCorrection(float *buffer, int frames);
  void applyEq(float *buffer, int frames);
  void applyReverb(float *buffer, int frames);
  void applyDelay(float *buffer, int frames);
  void applyCompressor(float *buffer, int frames);
  void applyLimiter(float *buffer, int frames);

  float dbToLinear(float db) { return std::pow(10.0f, db / 20.0f); }
  float linearToDb(float lin) { return 20.0f * std::log10(lin + 1e-5f); }
};
