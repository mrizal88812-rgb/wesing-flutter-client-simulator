#pragma once
#include "dsp_processor.h"
#include <aaudio/AAudio.h>
#include <algorithm>
#include <android/log.h>
#include <atomic>
#include <memory>
#include <thread>
#include <unistd.h>
#include <vector>

#define LOGE(...)                                                              \
  __android_log_print(ANDROID_LOG_ERROR, "AAudioEngine", __VA_ARGS__)
#define LOGI(...)                                                              \
  __android_log_print(ANDROID_LOG_INFO, "AAudioEngine", __VA_ARGS__)

class LockFreeRingBuffer {
public:
  LockFreeRingBuffer(size_t size) : size(size), buffer(size) {}

  bool write(const float *data, size_t numFrames) {
    size_t w = writeIdx.load(std::memory_order_relaxed);
    size_t r = readIdx.load(std::memory_order_acquire);
    size_t available = size - (w - r);
    if (numFrames > available)
      return false;

    for (size_t i = 0; i < numFrames; ++i) {
      buffer[(w + i) % size] = data[i];
    }
    writeIdx.store(w + numFrames, std::memory_order_release);
    return true;
  }

  size_t read(float *data, size_t numFrames) {
    size_t w = writeIdx.load(std::memory_order_acquire);
    size_t r = readIdx.load(std::memory_order_relaxed);
    size_t available = w - r;
    size_t toRead = std::min(numFrames, available);

    for (size_t i = 0; i < toRead; ++i) {
      data[i] = buffer[(r + i) % size];
    }
    readIdx.store(r + toRead, std::memory_order_release);
    return toRead;
  }

  void clear() {
    writeIdx.store(0, std::memory_order_relaxed);
    readIdx.store(0, std::memory_order_relaxed);
  }

private:
  std::vector<float> buffer;
  size_t size;
  std::atomic<size_t> writeIdx{0};
  std::atomic<size_t> readIdx{0};
};

class AAudioEngine {
public:
  AAudioEngine(std::shared_ptr<DspProcessor> proc)
      : processor(proc), ringBuffer(48000) {}

  ~AAudioEngine() { stop(); }

  bool start() {
    if (isRunning && outputStream) {
      aaudio_stream_state_t state = AAudioStream_getState(outputStream);

      if (state != AAUDIO_STREAM_STATE_CLOSED &&
          state != AAUDIO_STREAM_STATE_CLOSING) {

        if (state == AAUDIO_STREAM_STATE_PAUSED ||
            state == AAUDIO_STREAM_STATE_STOPPED) {

          aaudio_result_t restartResult =
              AAudioStream_requestStart(outputStream);

          if (restartResult != AAUDIO_OK) {
            LOGE("Failed to restart output stream: %d (%s)", restartResult,
                 AAudio_convertResultToText(restartResult));
            return false;
          }
        }

        return true;
      }

      outputStream = nullptr;
      isRunning = false;
    }

    if (outputStream) {
      AAudioStream_requestStop(outputStream);
      AAudioStream_close(outputStream);
      outputStream = nullptr;
    }

    AAudioStreamBuilder *outBuilder = nullptr;

    aaudio_result_t builderResult = AAudio_createStreamBuilder(&outBuilder);

    if (builderResult != AAUDIO_OK || !outBuilder) {
      LOGE("Failed to create output stream builder: %d", builderResult);
      return false;
    }

    AAudioStreamBuilder_setFormat(outBuilder, AAUDIO_FORMAT_PCM_FLOAT);

    AAudioStreamBuilder_setChannelCount(outBuilder, 1);

    AAudioStreamBuilder_setPerformanceMode(outBuilder,
                                           AAUDIO_PERFORMANCE_MODE_LOW_LATENCY);

    AAudioStreamBuilder_setDirection(outBuilder, AAUDIO_DIRECTION_OUTPUT);

#if __ANDROID_API__ >= 28
    AAudioStreamBuilder_setUsage(outBuilder, AAUDIO_USAGE_MEDIA);

    AAudioStreamBuilder_setContentType(outBuilder, AAUDIO_CONTENT_TYPE_MUSIC);
#endif

    AAudioStreamBuilder_setDataCallback(outBuilder, outputCallback, this);

    AAudioStreamBuilder_setErrorCallback(outBuilder, errorCallback, this);

    AAudioStreamBuilder_setSampleRate(outBuilder, 48000);

    aaudio_result_t result =
        AAudioStreamBuilder_openStream(outBuilder, &outputStream);

    if (result != AAUDIO_OK) {
      LOGI("LOW_LATENCY output failed: %d (%s). "
           "Trying PERFORMANCE_MODE_NONE",
           result, AAudio_convertResultToText(result));

      AAudioStreamBuilder_setPerformanceMode(outBuilder,
                                             AAUDIO_PERFORMANCE_MODE_NONE);

      result = AAudioStreamBuilder_openStream(outBuilder, &outputStream);

      if (result != AAUDIO_OK) {
        LOGE("Failed to open output stream: %d (%s)", result,
             AAudio_convertResultToText(result));

        AAudioStreamBuilder_delete(outBuilder);
        outputStream = nullptr;
        isRunning = false;

        return false;
      }
    }

    AAudioStreamBuilder_delete(outBuilder);

    ringBuffer.clear();

    aaudio_result_t startResult = AAudioStream_requestStart(outputStream);

    if (startResult != AAUDIO_OK) {
      LOGE("Failed to start output stream: %d (%s)", startResult,
           AAudio_convertResultToText(startResult));

      AAudioStream_close(outputStream);
      outputStream = nullptr;
      isRunning = false;

      return false;
    }

    LOGI("Output stream started successfully");

    isRunning = true;
    return true;
  }

  bool startInput() {
    if (inputStream) {
      aaudio_stream_state_t state = AAudioStream_getState(inputStream);

      LOGI("startInput: existing stream state=%d", state);

      if (state != AAUDIO_STREAM_STATE_CLOSED &&
          state != AAUDIO_STREAM_STATE_CLOSING) {

        if (state == AAUDIO_STREAM_STATE_PAUSED ||
            state == AAUDIO_STREAM_STATE_STOPPED) {

          aaudio_result_t restartResult =
              AAudioStream_requestStart(inputStream);

          if (restartResult != AAUDIO_OK) {
            LOGE("Failed to restart input stream: %d (%s)", restartResult,
                 AAudio_convertResultToText(restartResult));

            return false;
          }
        }

        return true;
      }

      AAudioStream_close(inputStream);
      inputStream = nullptr;
    }

    AAudioStreamBuilder *inBuilder = nullptr;

    aaudio_result_t builderResult = AAudio_createStreamBuilder(&inBuilder);

    if (builderResult != AAUDIO_OK || !inBuilder) {
      LOGE("Failed to create input stream builder: %d", builderResult);

      return false;
    }

    AAudioStreamBuilder_setFormat(inBuilder, AAUDIO_FORMAT_PCM_FLOAT);

    AAudioStreamBuilder_setChannelCount(inBuilder, 1);

    AAudioStreamBuilder_setPerformanceMode(inBuilder,
                                           AAUDIO_PERFORMANCE_MODE_LOW_LATENCY);

    AAudioStreamBuilder_setDirection(inBuilder, AAUDIO_DIRECTION_INPUT);

    AAudioStreamBuilder_setDataCallback(inBuilder, inputCallback, this);

    AAudioStreamBuilder_setErrorCallback(inBuilder, errorCallback, this);

    int32_t sampleRate = 48000;

    if (outputStream) {
      sampleRate = AAudioStream_getSampleRate(outputStream);
    }

    AAudioStreamBuilder_setSampleRate(inBuilder, sampleRate);

    aaudio_result_t result =
        AAudioStreamBuilder_openStream(inBuilder, &inputStream);

    if (result != AAUDIO_OK) {
      LOGI("LOW_LATENCY input failed: %d (%s). "
           "Trying PERFORMANCE_MODE_NONE",
           result, AAudio_convertResultToText(result));

      AAudioStreamBuilder_setPerformanceMode(inBuilder,
                                             AAUDIO_PERFORMANCE_MODE_NONE);

      result = AAudioStreamBuilder_openStream(inBuilder, &inputStream);

      if (result != AAUDIO_OK) {
        LOGE("Failed to open input stream: %d (%s)", result,
             AAudio_convertResultToText(result));

        AAudioStreamBuilder_delete(inBuilder);
        inputStream = nullptr;

        return false;
      }
    }

    AAudioStreamBuilder_delete(inBuilder);

    aaudio_result_t startResult = AAudioStream_requestStart(inputStream);

    if (startResult != AAUDIO_OK) {
      LOGE("Failed to start input stream: %d (%s)", startResult,
           AAudio_convertResultToText(startResult));

      AAudioStream_close(inputStream);
      inputStream = nullptr;

      return false;
    }

    LOGI("Input stream started successfully");

    return true;
  }

  void stopInput() {
    if (inputStream) {
      AAudioStream_requestStop(inputStream);
      AAudioStream_close(inputStream);
      inputStream = nullptr;
    }
  }

  void stop() {
    if (outputStream) {
      AAudioStream_requestStop(outputStream);
      AAudioStream_close(outputStream);
      outputStream = nullptr;
    }
    if (inputStream) {
      AAudioStream_requestStop(inputStream);
      AAudioStream_close(inputStream);
      inputStream = nullptr;
    }
    isRunning = false;
    usleep(30000);
  }

  int32_t getSampleRate() {
    if (outputStream)
      return AAudioStream_getSampleRate(outputStream);
    return 48000;
  }

private:
  std::shared_ptr<DspProcessor> processor;
  AAudioStream *inputStream = nullptr;
  AAudioStream *outputStream = nullptr;
  bool isRunning = false;
  LockFreeRingBuffer ringBuffer;

  static aaudio_data_callback_result_t inputCallback(AAudioStream *stream,
                                                     void *userData,
                                                     void *audioData,
                                                     int32_t numFrames) {
    AAudioEngine *engine = static_cast<AAudioEngine *>(userData);
    float *inData = static_cast<float *>(audioData);
    static int callbackCount = 0;
    callbackCount++;

    if (callbackCount <= 10 || callbackCount % 100 == 0) {
      LOGI("INPUT CALLBACK #%d frames=%d firstSample=%f", callbackCount,
           numFrames, inData ? inData[0] : 0.0f);
    }

    if (engine) {
      engine->ringBuffer.write(inData, numFrames);

      if (engine->processor) {
        static int processCount = 0;
        processCount++;

        if (processCount <= 10 || processCount % 100 == 0) {
          float peak = 0.0f;

          for (int i = 0; i < numFrames; ++i) {
            peak = std::max(peak, std::abs(inData[i]));
          }

          LOGI("PROCESS INPUT #%d frames=%d peak=%f", processCount, numFrames,
               peak);
        }

        engine->processor->processInputRealtime(inData, numFrames);
      } else {
        LOGE("PROCESS INPUT: processor == NULL");
      }
    }

    return AAUDIO_CALLBACK_RESULT_CONTINUE;
    // // Write to ring buffer
    // engine->ringBuffer.write(inData, numFrames);

    // // Pass to processor for raw recording and pitch detection
    // if (engine->processor) {
    //   engine->processor->processInputRealtime(inData, numFrames);
    // }

    // return AAUDIO_CALLBACK_RESULT_CONTINUE;
  }

  static aaudio_data_callback_result_t outputCallback(AAudioStream *stream,
                                                      void *userData,
                                                      void *audioData,
                                                      int32_t numFrames) {
    AAudioEngine *engine = static_cast<AAudioEngine *>(userData);
    float *outData = static_cast<float *>(audioData);
    static std::atomic<int> callbackCount{0};
    int count = ++callbackCount;

    if (count % 100 == 0) {
      LOGI("OUTPUT CALLBACK #%d frames=%d position=%.3f", count, numFrames,
           engine->processor ? engine->processor->getPlaybackPosition() : 0.0f);
    }

    // Ambil audio microphone dari ring buffer
    size_t readFrames = engine->ringBuffer.read(outData, numFrames);

    // Isi sisanya dengan silence
    for (size_t i = readFrames; i < static_cast<size_t>(numFrames); ++i) {
      outData[i] = 0.0f;
    }

    // Proses playback + instrumental + vocal
    if (engine->processor) {
      engine->processor->processOutputRealtime(outData, numFrames);
    }

    return AAUDIO_CALLBACK_RESULT_CONTINUE;
    // // Read vocal from ring buffer
    // size_t readFrames = engine->ringBuffer.read(outData, numFrames);

    // // Fill rest with 0 if under-run
    // for (size_t i = readFrames; i < numFrames; i++) {
    //   outData[i] = 0.0f;
    // }

    // // DSP mixing
    // if (engine->processor) {
    //   engine->processor->processOutputRealtime(outData, numFrames);
    // }

    // return AAUDIO_CALLBACK_RESULT_CONTINUE;
  }

  static void errorCallback(AAudioStream *stream, void *userData,
                            aaudio_result_t error) {
    LOGE("AAudio Error: %d", error);
  }
};
