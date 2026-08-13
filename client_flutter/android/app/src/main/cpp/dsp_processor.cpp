#include "dsp_processor.h"
#include <algorithm>
#include <unistd.h>

DspProcessor::DspProcessor(int sampleRate) : sampleRate(sampleRate) {
  revBuffer1.resize(static_cast<size_t>(0.03604f * sampleRate), 0.0f);
  revBuffer2.resize(static_cast<size_t>(0.03112f * sampleRate), 0.0f);
  revBuffer3.resize(static_cast<size_t>(0.03732f * sampleRate), 0.0f);
  revBuffer4.resize(static_cast<size_t>(0.04234f * sampleRate), 0.0f);
  allpassBuf1.resize(static_cast<size_t>(0.00510f * sampleRate), 0.0f);
  allpassBuf2.resize(static_cast<size_t>(0.00170f * sampleRate), 0.0f);
  delayBuffer.resize(sampleRate * 2, 0.0f); // Up to 2 seconds delay
  grainBuffer.resize(grainSize, 0.0f);

  // Default EQ
  eqBands[0].setPeaking(100.0f, 0.0f, 0.707f, sampleRate);
  eqBands[1].setPeaking(1000.0f, 0.0f, 0.707f, sampleRate);
  eqBands[2].setPeaking(5000.0f, 0.0f, 0.707f, sampleRate);
}

DspProcessor::~DspProcessor() {}

void DspProcessor::loadInstrumental(const float *pcmData, size_t numSamples) {
  instrumentalBuffer.assign(pcmData, pcmData + numSamples);
  playbackFrame.store(0);
  recordingStartFrame = 0;
  LOGD("[AUDIO] loadInstrumental: loaded %zu samples (%.2f seconds)",
       numSamples, static_cast<float>(numSamples) / sampleRate);
}

void DspProcessor::startRecording() {
  // When starting a NEW recording session, clear everything
  if (vocalRecording.empty()) {
    vocalRecording.clear();
    vocalRecording.reserve(sampleRate * 60 * 5); // 5 mins reserve
    vocalSegments.clear();
    playbackFrame.store(0);
    recordingStartFrame = 0;
    currentSegmentStartFrame = 0;
  } else {
    // Continuing after a seek - start a new segment
    // Save the buffer position where this new segment will start
    currentSegmentStartFrame = vocalRecording.size();
    LOGD("[AUDIO] startRecording() continuing after seek, new segment starts at buffer frame %zu, song position %.3f s",
         currentSegmentStartFrame, getPlaybackPosition());
  }
  isRecording.store(true);
  isPlaying.store(true);
  LOGD("[AUDIO] startRecording() invoked, playbackFrame=%zu, instrumental samples=%zu",
       playbackFrame.load(), instrumentalBuffer.size());
}

void DspProcessor::stopRecording() {
  if (isRecording.load()) {
    // Finalize the current segment before stopping
    finalizeRecordingSegment();
  }
  isRecording.store(false);
  isPlaying.store(false);
  LOGD("[AUDIO] stopRecording() invoked, total segments=%zu", vocalSegments.size());
}

void DspProcessor::finalizeRecordingSegment() {
  if (!isRecording.load() || vocalRecording.empty()) {
    return;
  }
  
  size_t currentBufferPos = vocalRecording.size();
  size_t framesInThisSegment = currentBufferPos - currentSegmentStartFrame;
  size_t currentSongFrame = playbackFrame.load();
  
  if (framesInThisSegment > 0) {
    VocalSegment segment(
      currentSegmentStartFrame,           // Where in buffer this segment starts
      framesInThisSegment,                // How many frames recorded
      recordingStartFrame,                // Song position where recording started
      currentSongFrame                    // Song position where recording stopped
    );
    vocalSegments.push_back(segment);
    
    LOGD("[AUDIO] finalizeRecordingSegment: segment #%zu bufferStart=%zu frames=%zu songStart=%zu (%.3f s) songEnd=%zu (%.3f s)",
         vocalSegments.size(),
         segment.startFrameInBuffer,
         segment.numFrames,
         segment.songStartFrame, static_cast<float>(segment.songStartFrame) / sampleRate,
         segment.songEndFrame, static_cast<float>(segment.songEndFrame) / sampleRate);
  }
}

void DspProcessor::play() {
  isPlaying.store(true, std::memory_order_release);

  const size_t currentFrame = playbackFrame.load(std::memory_order_relaxed);

  if (instrumentalBuffer.empty()) {
    LOGD("[AUDIO_WARNING] play() invoked but instrumentalBuffer is EMPTY!");
  } else {
    LOGD("[AUDIO] play() invoked, isPlaying=true, "
         "playbackFrame=%zu, position=%.3f s, instrumental samples=%zu",
         currentFrame, static_cast<float>(currentFrame) / sampleRate,
         instrumentalBuffer.size());
  }
}

void DspProcessor::pause() {
  isPlaying.store(false, std::memory_order_release);

  const size_t currentFrame = playbackFrame.load(std::memory_order_relaxed);

  LOGD("[AUDIO] pause() invoked, "
       "playbackFrame=%zu, position=%.3f s",
       currentFrame, static_cast<float>(currentFrame) / sampleRate);
}

void DspProcessor::seek(float positionSeconds) {
  if (positionSeconds < 0.0f) {
    positionSeconds = 0.0f;
  }

  size_t frame = static_cast<size_t>(positionSeconds * sampleRate);

  if (!instrumentalBuffer.empty() && frame > instrumentalBuffer.size()) {
    frame = instrumentalBuffer.size();
  }

  bool wasPlaying = isPlaying.load(std::memory_order_relaxed);
  bool isCurrentlyRecording = isRecording.load(std::memory_order_relaxed);

  // CRITICAL: Store state BEFORE pausing for seek
  // We need to know if it WAS playing before we pause it
  bool shouldResumeAfterSeek = wasPlaying;

  // Store old playback frame for vocal sync calculation
  size_t oldPlaybackFrame = playbackFrame.load(std::memory_order_relaxed);

  // CRITICAL: When seeking during recording, finalize the current segment first
  // This ensures each recorded segment has its correct timeline position
  if (isCurrentlyRecording && wasPlaying && !vocalRecording.empty()) {
    finalizeRecordingSegment();
    // Reset for new segment - will be set in startRecording() when called again
    currentSegmentStartFrame = vocalRecording.size();
  }

  // CRITICAL FOR PREVENTING DOUBLE PLAYBACK:
  // Pause the playback flag BEFORE changing playbackFrame to prevent the audio callback
  // from reading stale data while we're seeking. This prevents buffer overlap.
  // NOTE: We do NOT use usleep() here because it can cause audio stuttering.
  // The atomic store with memory_order_release ensures proper synchronization
  // without blocking. The audio callback will see the paused state on its next iteration.
  if (wasPlaying) {
    isPlaying.store(false, std::memory_order_release);
    // No delay needed - the atomic operation with release semantics ensures
    // the audio callback will see this change on its next check.
    // Adding a delay here causes audio stuttering and buffer underruns.
  }

  // Now safe to change playback position while paused
  playbackFrame.store(frame, std::memory_order_release);

  // KARAOKE MULTI-SEGMENT RECORDING SYSTEM:
  // Master Timeline Concept:
  // - All audio (instrumental + vocal segments) and lyrics reference the same timeline
  // - Each vocal segment stores its absolute song position (songStartFrame to songEndFrame)
  // - When seeking, we don't need to adjust recordingStartFrame for old segments
  //   because they already have their absolute positions stored
  // - recordingStartFrame is only used for the CURRENT active recording segment

  if (isCurrentlyRecording && wasPlaying) {
    // Starting a new segment at the new position
    // recordingStartFrame will be set to the new playback position
    // so that any new vocal recorded here aligns correctly
    recordingStartFrame = frame;

    LOGD("[AUDIO] seek() during recording: finalized previous segment, oldFrame=%zu newFrame=%zu new recordingStartFrame=%zu",
         oldPlaybackFrame, frame, recordingStartFrame);
  } else if (!isCurrentlyRecording && wasPlaying && !vocalSegments.empty()) {
    // During playback with recorded segments:
    // No need to adjust anything - segments have absolute positions
    // The playback logic will place each segment at its correct timeline position

    LOGD("[AUDIO] seek() during playback: oldFrame=%zu newFrame=%zu segments count=%zu",
         oldPlaybackFrame, frame, vocalSegments.size());
  }

  // CRITICAL: Resume playback ONLY after seek is complete
  // We do NOT use usleep() here either. The atomic operations ensure proper ordering.
  // The audio callback will naturally pick up the new position on its next iteration.
  if (shouldResumeAfterSeek) {
    // No delay needed - atomic operations with proper memory ordering
    // ensure the audio callback sees the updated playbackFrame before isPlaying=true
    isPlaying.store(true, std::memory_order_release);
    LOGD("[AUDIO] seek() resumed playback at new position %.3f s", static_cast<float>(frame) / sampleRate);
  }

  LOGD("[AUDIO] seek() position=%.3f s frame=%zu isRecording=%d wasPlaying=%d",
       static_cast<float>(frame) / sampleRate, frame, isCurrentlyRecording ? 1 : 0, wasPlaying ? 1 : 0);
}

float DspProcessor::getPlaybackPosition() const {
  return static_cast<float>(playbackFrame.load()) / sampleRate;
}

float DspProcessor::getDuration() const {
  if (instrumentalBuffer.empty())
    return 0.0f;
  return static_cast<float>(instrumentalBuffer.size()) / sampleRate;
}

void DspProcessor::setMonitoringEnabled(bool enabled) {
  monitoringEnabled.store(enabled);
}

void DspProcessor::setLatencyOffset(int offsetMs) {
  // Positive offsetMs means the recorded vocal lags behind the
  // instrumental by that many ms (typical mic/round-trip latency).
  // We compensate by reading the vocal buffer that many frames ahead
  // during playback so it lines up with the instrumental again.
  int frames = static_cast<int>((offsetMs / 1000.0f) * sampleRate);
  latencyOffsetFrames.store(frames);
  LOGD("[AUDIO] setLatencyOffset offsetMs=%d frames=%d", offsetMs, frames);
}

void DspProcessor::setVocalVolume(float vol) { vocalVol.store(vol); }
void DspProcessor::setInstrumentalVolume(float vol) { instVol.store(vol); }

void DspProcessor::setNoiseGate(bool enabled, float threshold) {
  gateEnabled = enabled;
  gateThreshold = dbToLinear(threshold);
}

void DspProcessor::setCompressor(bool enabled, float threshold, float ratio) {
  compEnabled = enabled;
  compThreshold = threshold;
  compRatio = ratio;
}

void DspProcessor::setReverb(bool enabled, float mix, float roomSize,
                             float damp) {
  reverbEnabled = enabled;
  reverbMix = mix;
  roomSizeSetting = roomSize;
  dampSetting = damp;
}

void DspProcessor::setDelay(bool enabled, float timeMs, float feedback,
                            float mix) {
  delayEnabled = enabled;
  delayTimeMs = timeMs;
  delayFeedback = feedback;
  delayMix = mix;
}

void DspProcessor::setEq(int band, float freq, float gain, float q) {
  if (band >= 0 && band < 3) {
    eqBands[band].setPeaking(freq, gain, q, sampleRate);
  }
}

void DspProcessor::setEqEnabled(bool enabled) { eqEnabled = enabled; }

void DspProcessor::setPitchCorrectionMode(AutoTuneMode mode, float speed,
                                          float targetHz) {
  autoTuneMode = mode;
  pitchCorrectionSpeed = speed;
  targetPitchHz = targetHz;
}

void DspProcessor::processInputRealtime(float *inBuffer, int numFrames) {
  applyPitchDetection(inBuffer, numFrames);
  if (isRecording.load()) {
    size_t currentSize = vocalRecording.size();
    vocalRecording.resize(currentSize + numFrames);
    std::copy(inBuffer, inBuffer + numFrames,
              vocalRecording.begin() + currentSize);
  }
}

void DspProcessor::processOutputRealtime(float *outBuffer, int numFrames) {
  bool playing = isPlaying.load(std::memory_order_acquire);
  bool recording = isRecording.load(std::memory_order_acquire);
  bool monitoring = monitoringEnabled.load(std::memory_order_acquire);
  size_t pFrame = playbackFrame.load(std::memory_order_relaxed);
  static int stateDebugCounter = 0;
  if (++stateDebugCounter % 100 == 0) {
    LOGD("[STATE] playing=%d recording=%d monitoring=%d position=%.3f",
         playing ? 1 : 0, recording ? 1 : 0, monitoring ? 1 : 0,
         static_cast<float>(pFrame) / sampleRate);
  }

  float vVol = vocalVol.load();
  float iVol = instVol.load();
  static int debugCounter = 0;

  if (++debugCounter % 100 == 0) {
    LOGD("[POSITION DEBUG] playing=%d recording=%d pFrame=%zu position=%.3f",
         playing ? 1 : 0, recording ? 1 : 0, pFrame,
         static_cast<float>(pFrame) / sampleRate);
  }
  // 1. Gather vocal samples (either from mic or from recorded segments)
  for (int i = 0; i < numFrames; i++) {
    float vSample = 0.0f;
    if (recording) {
      if (monitoring) {
        vSample = outBuffer[i]; // Mic input via ring buffer
      } else {
        vSample = 0.0f;
      }
    } else if (playing && !vocalSegments.empty()) {
      // MULTI-SEGMENT PLAYBACK: Find which segment (if any) should play at this timeline position
      size_t currentSongFrame = pFrame + i;
      
      for (const auto& segment : vocalSegments) {
        // Check if current timeline position falls within this segment's range
        if (currentSongFrame >= segment.songStartFrame && 
            currentSongFrame < segment.songEndFrame) {
          // Calculate which frame in the buffer to read from
          size_t offsetInSegment = currentSongFrame - segment.songStartFrame;
          size_t bufferIndex = segment.startFrameInBuffer + offsetInSegment;
          
          if (bufferIndex < vocalRecording.size()) {
            vSample = vocalRecording[bufferIndex];
          }
          break; // Found the segment, no need to check others
        }
      }
    } else if (playing && vocalRecording.empty() == false) {
      // Fallback to old behavior for single-segment recordings (backward compatibility)
      long long idx = static_cast<long long>(pFrame) + i +
                      latencyOffsetFrames.load(std::memory_order_relaxed);
      if (idx >= 0 && static_cast<size_t>(idx) < vocalRecording.size()) {
        vSample = vocalRecording[static_cast<size_t>(idx)];
      } else {
        vSample = 0.0f;
      }
    }
    outBuffer[i] = vSample;
  }

  // 2. Apply DSP to the vocal track only!
  if (monitoring || (!recording && playing)) {
    applyPitchCorrection(outBuffer, numFrames);
    applyEq(outBuffer, numFrames);
    applyCompressor(outBuffer, numFrames);
    applyDelay(outBuffer, numFrames);
    applyReverb(outBuffer, numFrames);
  }

  // 3. Mix with instrumental
  for (int i = 0; i < numFrames; i++) {
    smoothVocalVol += 0.01f * (vVol - smoothVocalVol);
    smoothInstVol += 0.01f * (iVol - smoothInstVol);

    float iSample = 0.0f;
    if (playing && pFrame + i < instrumentalBuffer.size()) {
      iSample = instrumentalBuffer[pFrame + i] * smoothInstVol;
    }

    float vSample = outBuffer[i] * smoothVocalVol;
    outBuffer[i] = vSample + iSample;
  }

  // 4. Limiter on final mix to prevent clipping
  applyLimiter(outBuffer, numFrames);

  // Throttled diagnostic logging (every 1000ms)
  static auto lastLogTime = std::chrono::steady_clock::now();
  auto now = std::chrono::steady_clock::now();
  if (std::chrono::duration_cast<std::chrono::milliseconds>(now - lastLogTime)
          .count() >= 1000) {
    lastLogTime = now;
    float rms = 0.0f;
    for (int i = 0; i < numFrames; i++) {
      rms += outBuffer[i] * outBuffer[i];
    }
    rms = std::sqrt(rms / (numFrames > 0 ? numFrames : 1));
    LOGD("[AUDIO] play() = %s | playback position = %.2f s | instrumental "
         "samples = %zu | output RMS = %.4f | output buffer[0] = %.4f",
         playing ? "true" : "false", static_cast<float>(pFrame) / sampleRate,
         instrumentalBuffer.size(), rms, numFrames > 0 ? outBuffer[0] : 0.0f);
  }

  // 5. Advance playback position
  //
  // Saat recording, posisi timeline juga harus terus berjalan.
  // Tidak boleh bergantung hanya pada isPlaying.
  if (playing) {

    const size_t nextFrame = pFrame + static_cast<size_t>(numFrames);

    if (!instrumentalBuffer.empty() && nextFrame >= instrumentalBuffer.size()) {

      playbackFrame.store(instrumentalBuffer.size(), std::memory_order_relaxed);

      // Hanya hentikan playback otomatis.
      // Recording tetap boleh berjalan sampai user menekan END.
      if (!recording) {
        isPlaying.store(false, std::memory_order_release);
      }

    } else {

      playbackFrame.store(nextFrame, std::memory_order_relaxed);
    }
  }
}

void DspProcessor::applyPitchDetection(float *buffer, int frames) {
  if (frames < 256)
    return;

  pitchDetectionSkipCounter++;
  if (pitchDetectionSkipCounter < PITCH_DETECTION_INTERVAL) {
    return;
  }
  pitchDetectionSkipCounter = 0;

  int minPeriod = sampleRate / 800;
  int maxPeriod = sampleRate / 80;
  float minAmdf = 1e9f;
  int coarseBestPeriod = minPeriod;
  int coarseStep = 4;

  // Coarse phase
  for (int p = minPeriod; p <= maxPeriod; p += coarseStep) {
    if (p >= frames)
      break;
    float amdf = 0.0f;
    int count = 0;
    for (int i = 0; i < frames - p; i++) {
      amdf += std::abs(buffer[i] - buffer[i + p]);
      count++;
    }
    if (count > 0) {
      amdf /= count;
      if (amdf < minAmdf) {
        minAmdf = amdf;
        coarseBestPeriod = p;
      }
    }
  }

  // Fine phase
  int fineMin = std::max(minPeriod, coarseBestPeriod - coarseStep);
  int fineMax = std::min(maxPeriod, coarseBestPeriod + coarseStep);

  int bestPeriod = coarseBestPeriod;
  minAmdf = 1e9f;

  for (int p = fineMin; p <= fineMax; p++) {
    if (p >= frames)
      break;
    float amdf = 0.0f;
    int count = 0;
    for (int i = 0; i < frames - p; i++) {
      amdf += std::abs(buffer[i] - buffer[i + p]);
      count++;
    }
    if (count > 0) {
      amdf /= count;
      if (amdf < minAmdf) {
        minAmdf = amdf;
        bestPeriod = p;
      }
    }
  }

  float detectedPitch = static_cast<float>(sampleRate) / bestPeriod;
  float confidence = 1.0f - (minAmdf / 0.5f);
  confidence = std::clamp(confidence, 0.0f, 1.0f);
  if (confidence > 0.35f) {
    currentPitch.store(detectedPitch);
    pitchConfidence.store(confidence);
  } else {
    pitchConfidence.store(0.0f);
  }
}

void DspProcessor::applyPitchCorrection(float *buffer, int frames) {
  if (autoTuneMode == AutoTuneMode::OFF || targetPitchHz <= 0.0f ||
      pitchConfidence.load() < 0.35f)
    return;
  float inputPitch = currentPitch.load();
  if (inputPitch <= 0.0f)
    return;
  float speedFactor = (autoTuneMode == AutoTuneMode::STRONG)
                          ? 0.25f
                          : (0.05f * pitchCorrectionSpeed);
  if (smoothedTargetPitch <= 0.0f)
    smoothedTargetPitch = targetPitchHz;
  smoothedTargetPitch += speedFactor * (targetPitchHz - smoothedTargetPitch);
  float pitchRatio = smoothedTargetPitch / inputPitch;
  if (autoTuneMode == AutoTuneMode::NATURAL) {
    pitchRatio = 1.0f + 0.5f * (pitchRatio - 1.0f);
  }
  pitchRatio = std::clamp(pitchRatio, 0.67f, 1.5f);
  for (int i = 0; i < frames; i++) {
    grainBuffer[grainWritePtr] = buffer[i];
    grainReadPtr1 += pitchRatio;
    grainReadPtr2 += pitchRatio;
    if (grainReadPtr1 >= grainSize)
      grainReadPtr1 -= grainSize;
    if (grainReadPtr2 >= grainSize)
      grainReadPtr2 -= grainSize;
    float pos1 = grainReadPtr1 / grainSize;
    float w1 = 0.5f * (1.0f - std::cos(2.0f * 3.14159265f * pos1));
    float pos2 = grainReadPtr2 / grainSize;
    float w2 = 0.5f * (1.0f - std::cos(2.0f * 3.14159265f * pos2));
    int idx1 = (grainWritePtr - static_cast<int>(grainReadPtr1) + grainSize) %
               grainSize;
    int idx2 = (grainWritePtr - static_cast<int>(grainReadPtr2) + grainSize) %
               grainSize;
    buffer[i] = (grainBuffer[idx1] * w1) + (grainBuffer[idx2] * w2);
    grainWritePtr = (grainWritePtr + 1) % grainSize;
  }
}

void DspProcessor::applyEq(float *buffer, int frames) {
  if (!eqEnabled)
    return;
  for (int i = 0; i < frames; i++) {
    float sample = buffer[i];
    sample = eqBands[0].process(sample);
    sample = eqBands[1].process(sample);
    sample = eqBands[2].process(sample);
    buffer[i] = sample;
  }
}

void DspProcessor::applyReverb(float *buffer, int frames) {
  if (!reverbEnabled)
    return;
  float targetMix = reverbMix;
  float room = std::clamp(roomSizeSetting, 0.5f, 0.95f);
  float damp = std::clamp(dampSetting, 0.1f, 0.8f);
  for (int i = 0; i < frames; i++) {
    smoothReverbMix += 0.01f * (targetMix - smoothReverbMix);
    if (smoothReverbMix <= 0.001f)
      continue;
    float in = buffer[i];
    float c1 = revBuffer1[revPtr1];
    revBuffer1[revPtr1] = in + c1 * room * (1.0f - damp);
    revPtr1 = (revPtr1 + 1) % revBuffer1.size();
    float c2 = revBuffer2[revPtr2];
    revBuffer2[revPtr2] = in + c2 * room * (1.0f - damp);
    revPtr2 = (revPtr2 + 1) % revBuffer2.size();
    float c3 = revBuffer3[revPtr3];
    revBuffer3[revPtr3] = in + c3 * room * (1.0f - damp);
    revPtr3 = (revPtr3 + 1) % revBuffer3.size();
    float c4 = revBuffer4[revPtr4];
    revBuffer4[revPtr4] = in + c4 * room * (1.0f - damp);
    revPtr4 = (revPtr4 + 1) % revBuffer4.size();
    float outCombs = (c1 + c2 + c3 + c4) * 0.25f;
    float ap1 = allpassBuf1[apPtr1];
    float ap1_in = outCombs;
    allpassBuf1[apPtr1] = ap1_in + ap1 * 0.5f;
    float ap1_out = ap1 - ap1_in * 0.5f;
    apPtr1 = (apPtr1 + 1) % allpassBuf1.size();
    float ap2 = allpassBuf2[apPtr2];
    float ap2_in = ap1_out;
    allpassBuf2[apPtr2] = ap2_in + ap2 * 0.5f;
    float ap2_out = ap2 - ap2_in * 0.5f;
    apPtr2 = (apPtr2 + 1) % allpassBuf2.size();
    buffer[i] = in * (1.0f - smoothReverbMix) + ap2_out * smoothReverbMix;
  }
}

void DspProcessor::applyDelay(float *buffer, int frames) {
  if (!delayEnabled)
    return;
  int delaySamples = static_cast<int>((delayTimeMs / 1000.0f) * sampleRate);
  if (delaySamples >= delayBuffer.size())
    delaySamples = delayBuffer.size() - 1;
  float targetMix = delayMix;
  for (int i = 0; i < frames; i++) {
    smoothDelayMix += 0.01f * (targetMix - smoothDelayMix);
    if (smoothDelayMix <= 0.001f)
      continue;
    int readPtr = (delayWritePtr - delaySamples + delayBuffer.size()) %
                  delayBuffer.size();
    float delayedSample = delayBuffer[readPtr];
    float inSample = buffer[i];
    delayBuffer[delayWritePtr] = inSample + (delayedSample * delayFeedback);
    buffer[i] =
        inSample * (1.0f - smoothDelayMix) + delayedSample * smoothDelayMix;
    delayWritePtr = (delayWritePtr + 1) % delayBuffer.size();
  }
}

void DspProcessor::applyCompressor(float *buffer, int frames) {
  if (!compEnabled)
    return;
  float attackCoeff = std::exp(-1.0f / (0.005f * sampleRate));
  float releaseCoeff = std::exp(-1.0f / (0.100f * sampleRate));
  float kneeWidthDb = 6.0f;
  for (int i = 0; i < frames; i++) {
    float absVal = std::abs(buffer[i]);
    if (absVal > compEnvelope) {
      compEnvelope = attackCoeff * compEnvelope + (1.0f - attackCoeff) * absVal;
    } else {
      compEnvelope =
          releaseCoeff * compEnvelope + (1.0f - releaseCoeff) * absVal;
    }
    float envDb = linearToDb(compEnvelope);
    float gainReductionDb = 0.0f;
    if (envDb > (compThreshold + kneeWidthDb / 2.0f)) {
      gainReductionDb = (envDb - compThreshold) * (1.0f - 1.0f / compRatio);
    } else if (envDb > (compThreshold - kneeWidthDb / 2.0f)) {
      float delta = envDb - (compThreshold - kneeWidthDb / 2.0f);
      gainReductionDb =
          (1.0f - 1.0f / compRatio) * (delta * delta) / (2.0f * kneeWidthDb);
    }
    float makeupGainDb = compThreshold * (1.0f - 1.0f / compRatio) * -0.5f;
    float netGainLinear = dbToLinear(-gainReductionDb + makeupGainDb);
    buffer[i] *= netGainLinear;
  }
}

void DspProcessor::applyLimiter(float *buffer, int frames) {
  float maxThreshold = 0.95f;
  float releaseCoeff = std::exp(-1.0f / (0.050f * sampleRate));
  for (int i = 0; i < frames; i++) {
    float absVal = std::abs(buffer[i]);
    if (absVal > limiterEnvelope) {
      limiterEnvelope = absVal;
    } else {
      limiterEnvelope =
          releaseCoeff * limiterEnvelope + (1.0f - releaseCoeff) * absVal;
    }
    if (limiterEnvelope > maxThreshold) {
      float gain = maxThreshold / limiterEnvelope;
      buffer[i] *= gain;
    }
    if (buffer[i] > 1.0f)
      buffer[i] = std::tanh(buffer[i]);
    else if (buffer[i] < -1.0f)
      buffer[i] = std::tanh(buffer[i]);
  }
}

// Write simple WAV export
void writeWavHeader(std::ofstream &file, int sampleRate, int channels,
                    int dataBytes) {
  file.write("RIFF", 4);
  int fileSize = dataBytes + 36;
  file.write(reinterpret_cast<const char *>(&fileSize), 4);
  file.write("WAVE", 4);
  file.write("fmt ", 4);
  int fmtSize = 16;
  file.write(reinterpret_cast<const char *>(&fmtSize), 4);
  short audioFormat = 1; // PCM
  file.write(reinterpret_cast<const char *>(&audioFormat), 2);
  short numChannels = channels;
  file.write(reinterpret_cast<const char *>(&numChannels), 2);
  file.write(reinterpret_cast<const char *>(&sampleRate), 4);
  int byteRate = sampleRate * channels * 2;
  file.write(reinterpret_cast<const char *>(&byteRate), 4);
  short blockAlign = channels * 2;
  file.write(reinterpret_cast<const char *>(&blockAlign), 2);
  short bitsPerSample = 16;
  file.write(reinterpret_cast<const char *>(&bitsPerSample), 2);
  file.write("data", 4);
  file.write(reinterpret_cast<const char *>(&dataBytes), 4);
}

bool DspProcessor::exportMix(float vocalVolDb, float instVolDb,
                             const std::string &outPath) {
  exportProgress.store(0.0f);
  
  // MULTI-SEGMENT EXPORT: Calculate total song duration needed
  size_t songEndFrame = 0;
  if (!vocalSegments.empty()) {
    // Find the end position of the last segment
    for (const auto& seg : vocalSegments) {
      if (seg.songEndFrame > songEndFrame) {
        songEndFrame = seg.songEndFrame;
      }
    }
  } else if (!vocalRecording.empty()) {
    // Fallback to old behavior for single-segment recordings
    songEndFrame = recordingStartFrame + vocalRecording.size();
  }
  
  if (songEndFrame == 0 || instrumentalBuffer.empty()) {
    return false;
  }
  
  // Export buffer size = full song timeline from first vocal segment start to last end
  size_t outFrames = songEndFrame;
  std::vector<float> mixBuffer(outFrames, 0.0f);
  
  exportProgress.store(0.1f);
  
  // MULTI-SEGMENT VOCAL PLACEMENT: Place each vocal segment at its absolute timeline position
  int latencyFrames = latencyOffsetFrames.load(std::memory_order_relaxed);
  float vVol = vocalVol.load();
  
  for (const auto& segment : vocalSegments) {
    // For each frame in this segment
    for (size_t segFrame = 0; segFrame < segment.numFrames; segFrame++) {
      size_t bufferIndex = segment.startFrameInBuffer + segFrame;
      size_t songPosition = segment.songStartFrame + segFrame;
      
      if (bufferIndex < vocalRecording.size() && songPosition < outFrames) {
        mixBuffer[songPosition] = vocalRecording[bufferIndex] * vVol;
      }
    }
  }
  
  // If no segments but has old-style recording (backward compatibility)
  if (vocalSegments.empty() && !vocalRecording.empty()) {
    std::copy(vocalRecording.begin(), vocalRecording.end(), mixBuffer.begin());
    for (size_t i = 0; i < vocalRecording.size(); i++) {
      mixBuffer[i] *= vVol;
    }
  }
  
  exportProgress.store(0.3f);
  
  // Apply offline DSP block by block to the entire mix buffer (vocal portions only)
  int blockSize = 4096;
  for (size_t i = 0; i < outFrames; i += blockSize) {
    int frames = std::min(blockSize, static_cast<int>(outFrames - i));
    float *ptr = mixBuffer.data() + i;
    
    // Only apply DSP where there's vocal content (non-zero samples)
    bool hasVocal = false;
    for (int j = 0; j < frames; j++) {
      if (std::abs(ptr[j]) > 0.001f) {
        hasVocal = true;
        break;
      }
    }
    
    if (hasVocal) {
      applyPitchCorrection(ptr, frames);
      applyEq(ptr, frames);
      applyCompressor(ptr, frames);
      applyDelay(ptr, frames);
      applyReverb(ptr, frames);
    }
    
    if (i % (blockSize * 20) == 0)
      exportProgress.store(0.3f + 0.4f * (static_cast<float>(i) / outFrames));
  }

  exportProgress.store(0.7f);
  float iVol = instVol.load();
  
  // Mix with Instrumental - place instrumental at correct positions
  for (size_t i = 0; i < outFrames; i++) {
    float v = mixBuffer[i]; // Already has vocal processed
    long long instIdx = static_cast<long long>(i);
    float instr = (instIdx >= 0 &&
                    static_cast<size_t>(instIdx) < instrumentalBuffer.size())
                      ? (instrumentalBuffer[static_cast<size_t>(instIdx)] * iVol)
                      : 0.0f;
    mixBuffer[i] = v + instr;
    if (i % 44100 == 0)
      exportProgress.store(0.7f + 0.2f * (static_cast<float>(i) / outFrames));
  }

  exportProgress.store(0.9f);
  applyLimiter(mixBuffer.data(), outFrames);

  // Write WAV
  std::ofstream file(outPath, std::ios::binary);
  if (!file.is_open())
    return false;

  int dataBytes = outFrames * 2; // 16-bit PCM mono
  writeWavHeader(file, sampleRate, 1, dataBytes);

  for (size_t i = 0; i < outFrames; i++) {
    float s = mixBuffer[i];
    if (s > 1.0f)
      s = 1.0f;
    if (s < -1.0f)
      s = -1.0f;
    short val = static_cast<short>(s * 32767.0f);
    file.write(reinterpret_cast<const char *>(&val), 2);
  }

  file.close();
  exportProgress.store(1.0f);
  return true;
}
