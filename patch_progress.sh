#!/bin/bash
sed -i '/std::atomic<bool> monitoringEnabled{true};/a \    std::atomic<float> exportProgress{0.0f};' client_flutter/android/app/src/main/cpp/dsp_processor.h

sed -i '/float getConfidence() const/a \    float getExportProgress() const { return exportProgress.load(); }' client_flutter/android/app/src/main/cpp/dsp_processor.h

sed -i 's/bool DspProcessor::exportMix(float vocalVolDb, float instVolDb, const std::string& outPath) {/bool DspProcessor::exportMix(float vocalVolDb, float instVolDb, const std::string\& outPath) {\n    exportProgress.store(0.0f);/g' client_flutter/android/app/src/main/cpp/dsp_processor.cpp

sed -i 's/        std::copy(vocalRecording.begin(), vocalRecording.end(), mixBuffer.begin());/        std::copy(vocalRecording.begin(), vocalRecording.end(), mixBuffer.begin());\n        exportProgress.store(0.1f);/g' client_flutter/android/app/src/main/cpp/dsp_processor.cpp

sed -i 's/            applyReverb(ptr, frames);/            applyReverb(ptr, frames);\n            if (i % (blockSize * 20) == 0) exportProgress.store(0.1f + 0.6f * (static_cast<float>(i) \/ vocalRecording.size()));/g' client_flutter/android/app/src/main/cpp/dsp_processor.cpp

sed -i 's/    float vVol = vocalVol.load();/    exportProgress.store(0.7f);\n    float vVol = vocalVol.load();/g' client_flutter/android/app/src/main/cpp/dsp_processor.cpp

sed -i 's/        mixBuffer\[i\] = v + instr;/        mixBuffer[i] = v + instr;\n        if (i % 44100 == 0) exportProgress.store(0.7f + 0.2f * (static_cast<float>(i) \/ outFrames));/g' client_flutter/android/app/src/main/cpp/dsp_processor.cpp

sed -i 's/    applyLimiter(mixBuffer.data(), outFrames);/    exportProgress.store(0.9f);\n    applyLimiter(mixBuffer.data(), outFrames);/g' client_flutter/android/app/src/main/cpp/dsp_processor.cpp

sed -i 's/    file.close();/    file.close();\n    exportProgress.store(1.0f);/g' client_flutter/android/app/src/main/cpp/dsp_processor.cpp

