#include "aaudio_engine.h"
#include "dsp_processor.h"
#include <jni.h>
#include <memory>
#include <string>

static std::shared_ptr<DspProcessor> g_processor;
static std::unique_ptr<AAudioEngine> g_audioEngine;

inline std::shared_ptr<DspProcessor>
getOrCreateProcessor(int sampleRate = 48000) {
  if (!g_processor) {
    g_processor = std::make_shared<DspProcessor>(sampleRate);
    __android_log_print(ANDROID_LOG_INFO, "JniBridge",
                        "Auto-created g_processor with sample rate %d",
                        sampleRate);
  }
  return g_processor;
}

extern "C" JNIEXPORT void JNICALL Java_com_okamiaaww_app_KaraokeDspEngine_init(
    JNIEnv *env, jobject /* this */, jint sampleRate) {
  if (!g_processor) {
    g_processor = std::make_shared<DspProcessor>(sampleRate);
    __android_log_print(
        ANDROID_LOG_INFO, "JniBridge",
        "Initialized single instance of DspProcessor with sample rate %d",
        sampleRate);
  } else {
    __android_log_print(ANDROID_LOG_INFO, "JniBridge",
                        "DspProcessor instance already exists, resetting "
                        "position/state for reuse.");
    g_processor->pause();
    g_processor->stopRecording();
    g_processor->seek(0.0f);
  }

  if (!g_audioEngine) {
    g_audioEngine = std::make_unique<AAudioEngine>(g_processor);
    if (!g_audioEngine->start()) {
      __android_log_print(ANDROID_LOG_ERROR, "AAudioEngine",
                          "AAudio engine start failed!");
    } else {
      __android_log_print(
          ANDROID_LOG_INFO, "AAudioEngine",
          "AAudio engine started successfully with sample rate %d", sampleRate);
    }
  } else {
    __android_log_print(ANDROID_LOG_INFO, "JniBridge",
                        "Ensuring AAudioEngine is started and input is ready.");
    g_audioEngine->start();
    g_audioEngine->startInput();
  }
}

extern "C" JNIEXPORT void JNICALL
Java_com_okamiaaww_app_KaraokeDspEngine_dispose(JNIEnv *env,
                                                jobject /* this */) {
  if (g_audioEngine) {
    g_audioEngine->stop();
  }
  if (g_processor) {
    g_processor->pause();
    g_processor->stopRecording();
  }
}

extern "C" JNIEXPORT void JNICALL
Java_com_okamiaaww_app_KaraokeDspEngine_setVocalVolume(JNIEnv *env,
                                                       jobject /* this */,
                                                       jfloat vol) {
  getOrCreateProcessor()->setVocalVolume(vol);
}

extern "C" JNIEXPORT void JNICALL
Java_com_okamiaaww_app_KaraokeDspEngine_setInstrumentalVolume(
    JNIEnv *env, jobject /* this */, jfloat vol) {
  getOrCreateProcessor()->setInstrumentalVolume(vol);
}

extern "C" JNIEXPORT void JNICALL
Java_com_okamiaaww_app_KaraokeDspEngine_setMonitoringEnabled(JNIEnv *env,
                                                             jobject /* this */,
                                                             jboolean enabled) {
  getOrCreateProcessor()->setMonitoringEnabled(enabled);
  if (enabled && g_audioEngine) {
    g_audioEngine->startInput();
  }
}

extern "C" JNIEXPORT void JNICALL
Java_com_okamiaaww_app_KaraokeDspEngine_loadInstrumental(JNIEnv *env,
                                                         jobject /* this */,
                                                         jfloatArray pcmData) {
  jsize len = env->GetArrayLength(pcmData);
  jfloat *ptr = env->GetFloatArrayElements(pcmData, NULL);
  getOrCreateProcessor()->loadInstrumental(ptr, len);
  env->ReleaseFloatArrayElements(pcmData, ptr, JNI_ABORT);
}

extern "C" JNIEXPORT void JNICALL
Java_com_okamiaaww_app_KaraokeDspEngine_startRecording(JNIEnv *env,
                                                       jobject /* this */) {

  if (!g_processor) {
    LOGE("startRecording: g_processor is NULL");
    return;
  }

  if (!g_audioEngine) {
    LOGE("startRecording: g_audioEngine is NULL");
    return;
  }

  // Start microphone terlebih dahulu.
  const bool inputStarted = g_audioEngine->startInput();

  if (!inputStarted) {
    LOGE("startRecording: FAILED to start microphone");
    g_processor->stopRecording();
    return;
  }

  // Hanya aktifkan recording jika mic berhasil.
  g_processor->startRecording();

  LOGI("startRecording: microphone + processor started");
}

extern "C" JNIEXPORT void JNICALL
Java_com_okamiaaww_app_KaraokeDspEngine_stopRecording(JNIEnv *env,
                                                      jobject /* this */) {
  getOrCreateProcessor()->stopRecording();
  if (g_audioEngine)
    g_audioEngine->stopInput();
}

extern "C" JNIEXPORT void JNICALL
Java_com_okamiaaww_app_KaraokeDspEngine_play(JNIEnv *env, jobject /* this */) {
  getOrCreateProcessor()->play();
}

extern "C" JNIEXPORT void JNICALL
Java_com_okamiaaww_app_KaraokeDspEngine_pause(JNIEnv *env, jobject /* this */) {
  getOrCreateProcessor()->pause();
}

extern "C" JNIEXPORT void JNICALL Java_com_okamiaaww_app_KaraokeDspEngine_seek(
    JNIEnv *env, jobject /* this */, jfloat posSeconds) {
  getOrCreateProcessor()->seek(posSeconds);
}

extern "C" JNIEXPORT jfloat JNICALL
Java_com_okamiaaww_app_KaraokeDspEngine_getPlaybackPosition(
    JNIEnv *env, jobject /* this */) {
  return g_processor ? g_processor->getPlaybackPosition() : 0.0f;
}

extern "C" JNIEXPORT jfloat JNICALL
Java_com_okamiaaww_app_KaraokeDspEngine_getDuration(JNIEnv *env,
                                                    jobject /* this */) {
  return g_processor ? g_processor->getDuration() : 0.0f;
}

extern "C" JNIEXPORT void JNICALL
Java_com_okamiaaww_app_KaraokeDspEngine_setDelay(JNIEnv *env,
                                                 jobject /* this */,
                                                 jboolean enabled,
                                                 jfloat timeMs, jfloat feedback,
                                                 jfloat mix) {
  if (g_processor)
    g_processor->setDelay(enabled, timeMs, feedback, mix);
}

extern "C" JNIEXPORT void JNICALL
Java_com_okamiaaww_app_KaraokeDspEngine_setReverb(JNIEnv *env,
                                                  jobject /* this */,
                                                  jboolean enabled,
                                                  jstring presetName,
                                                  jfloat mix) {
  if (g_processor)
    g_processor->setReverb(enabled, mix, 0.8f, 0.5f); // Simplified
}

extern "C" JNIEXPORT void JNICALL
Java_com_okamiaaww_app_KaraokeDspEngine_setCompressor(JNIEnv *env,
                                                      jobject /* this */,
                                                      jboolean enabled,
                                                      jfloat threshold,
                                                      jfloat ratio) {
  if (g_processor)
    g_processor->setCompressor(enabled, threshold, ratio);
}

extern "C" JNIEXPORT void JNICALL
Java_com_okamiaaww_app_KaraokeDspEngine_setPitchCorrection(JNIEnv *env,
                                                           jobject /* this */,
                                                           jint modeInt,
                                                           jfloat speed,
                                                           jfloat targetHz) {
  if (g_processor)
    g_processor->setPitchCorrectionMode(static_cast<AutoTuneMode>(modeInt),
                                        speed, targetHz);
}

extern "C" JNIEXPORT void JNICALL
Java_com_okamiaaww_app_KaraokeDspEngine_setEqEnabled(JNIEnv *env,
                                                     jobject /* this */,
                                                     jboolean enabled) {
  if (g_processor)
    g_processor->setEqEnabled(enabled);
}

extern "C" JNIEXPORT void JNICALL
Java_com_okamiaaww_app_KaraokeDspEngine_setEqBand(JNIEnv *env,
                                                  jobject /* this */,
                                                  jint band, jfloat freq,
                                                  jfloat gain, jfloat q) {
  if (g_processor)
    g_processor->setEq(band, freq, gain, q);
}

extern "C" JNIEXPORT void JNICALL
Java_com_okamiaaww_app_KaraokeDspEngine_setLatencyOffset(JNIEnv *env,
                                                         jobject /* this */,
                                                         jint offsetMs) {
  if (g_processor)
    g_processor->setLatencyOffset(offsetMs);
}

extern "C" JNIEXPORT jfloat JNICALL
Java_com_okamiaaww_app_KaraokeDspEngine_getCurrentPitch(JNIEnv *env,
                                                        jobject /* this */) {
  return g_processor ? g_processor->getCurrentPitch() : 0.0f;
}

extern "C" JNIEXPORT jfloat JNICALL
Java_com_okamiaaww_app_KaraokeDspEngine_getConfidence(JNIEnv *env,
                                                      jobject /* this */) {
  return g_processor ? g_processor->getConfidence() : 0.0f;
}

extern "C" JNIEXPORT jboolean JNICALL
Java_com_okamiaaww_app_KaraokeDspEngine_exportMix(JNIEnv *env,
                                                  jobject /* this */,
                                                  jfloat vVol, jfloat iVol,
                                                  jstring outPath) {
  if (!g_processor)
    return false;
  const char *path = env->GetStringUTFChars(outPath, 0);
  bool res = g_processor->exportMix(vVol, iVol, path);
  env->ReleaseStringUTFChars(outPath, path);
  return res;
}

extern "C" JNIEXPORT jfloat JNICALL
Java_com_okamiaaww_app_KaraokeDspEngine_getExportProgress(JNIEnv *env,
                                                          jobject /* this */) {
  return g_processor ? g_processor->getExportProgress() : 0.0f;
}

// MULTI-SEGMENT RECORDING SUPPORT
extern "C" JNIEXPORT void JNICALL
Java_com_okamiaaww_app_KaraokeDspEngine_finalizeRecordingSegment(JNIEnv *env,
                                                                 jobject /* this */) {
  if (g_processor) {
    g_processor->finalizeRecordingSegment();
  }
}

extern "C" JNIEXPORT jint JNICALL
Java_com_okamiaaww_app_KaraokeDspEngine_getVocalSegmentsCount(JNIEnv *env,
                                                              jobject /* this */) {
  if (!g_processor) return 0;
  return static_cast<jint>(g_processor->getVocalSegmentsCount());
}

extern "C" JNIEXPORT jfloatArray JNICALL
Java_com_okamiaaww_app_KaraokeDspEngine_getVocalSegmentData(JNIEnv *env,
                                                            jobject /* this */,
                                                            jint index) {
  if (!g_processor || index < 0) return nullptr;
  
  const auto& segments = g_processor->getVocalSegments();
  if (index >= static_cast<jint>(segments.size())) return nullptr;
  
  const auto& seg = segments[index];
  jfloatArray result = env->NewFloatArray(5);  // Changed to 5 to include recordingEndFrame
  if (result == nullptr) return nullptr;
  
  float data[5] = {
    static_cast<float>(seg.startFrameInBuffer),
    static_cast<float>(seg.numFrames),
    static_cast<float>(seg.songStartFrame),
    static_cast<float>(seg.songEndFrame),
    static_cast<float>(g_processor->getRecordingEndFrame())  // Add recording end frame
  };
  
  env->SetFloatArrayRegion(result, 0, 5, data);
  return result;
}

// NEW: Get the absolute recording end position (where End button was pressed)
extern "C" JNIEXPORT jfloat JNICALL
Java_com_okamiaaww_app_KaraokeDspEngine_getRecordingEndPosition(JNIEnv *env,
                                                                jobject /* this */) {
  if (!g_processor) return 0.0f;
  size_t endFrame = g_processor->getRecordingEndFrame();
  return static_cast<float>(endFrame) / g_processor->sampleRate;
}
