import re

with open("client_flutter/android/app/src/main/cpp/aaudio_engine.h", "r") as f:
    content = f.read()

# Replace start() to not open inputStream by default, or just open outputStream
new_start = """    bool start() {
        if (isRunning) return true;
        
        AAudioStreamBuilder *outBuilder;
        AAudio_createStreamBuilder(&outBuilder);
        AAudioStreamBuilder_setFormat(outBuilder, AAUDIO_FORMAT_PCM_FLOAT);
        AAudioStreamBuilder_setChannelCount(outBuilder, 1);
        AAudioStreamBuilder_setPerformanceMode(outBuilder, AAUDIO_PERFORMANCE_MODE_LOW_LATENCY);
        AAudioStreamBuilder_setDirection(outBuilder, AAUDIO_DIRECTION_OUTPUT);
        AAudioStreamBuilder_setDataCallback(outBuilder, outputCallback, this);
        AAudioStreamBuilder_setErrorCallback(outBuilder, errorCallback, this);
        AAudioStreamBuilder_setSampleRate(outBuilder, 48000);
        
        if (AAudioStreamBuilder_openStream(outBuilder, &outputStream) != AAUDIO_OK) {
            LOGE("Failed to open output stream");
            AAudioStreamBuilder_delete(outBuilder);
            return false;
        }
        AAudioStreamBuilder_delete(outBuilder);
        
        ringBuffer.clear();
        AAudioStream_requestStart(outputStream);
        
        isRunning = true;
        return true;
    }
    
    bool startInput() {
        if (inputStream) return true; // Already running
        
        AAudioStreamBuilder *inBuilder;
        AAudio_createStreamBuilder(&inBuilder);
        AAudioStreamBuilder_setFormat(inBuilder, AAUDIO_FORMAT_PCM_FLOAT);
        AAudioStreamBuilder_setChannelCount(inBuilder, 1);
        AAudioStreamBuilder_setPerformanceMode(inBuilder, AAUDIO_PERFORMANCE_MODE_LOW_LATENCY);
        AAudioStreamBuilder_setDirection(inBuilder, AAUDIO_DIRECTION_INPUT);
        AAudioStreamBuilder_setDataCallback(inBuilder, inputCallback, this);
        AAudioStreamBuilder_setErrorCallback(inBuilder, errorCallback, this);
        
        if (outputStream) {
            AAudioStreamBuilder_setSampleRate(inBuilder, AAudioStream_getSampleRate(outputStream));
        } else {
            AAudioStreamBuilder_setSampleRate(inBuilder, 48000);
        }
        
        if (AAudioStreamBuilder_openStream(inBuilder, &inputStream) != AAUDIO_OK) {
            LOGE("Failed to open input stream");
            AAudioStreamBuilder_delete(inBuilder);
            return false;
        }
        AAudioStreamBuilder_delete(inBuilder);
        
        AAudioStream_requestStart(inputStream);
        return true;
    }
    
    void stopInput() {
        if (inputStream) {
            AAudioStream_requestStop(inputStream);
            AAudioStream_close(inputStream);
            inputStream = nullptr;
        }
    }
    
    void stop() {"""

content = re.sub(r'    bool start\(\) \{.*?    void stopInput\(\) \{\n        if \(inputStream\) \{\n            AAudioStream_requestStop\(inputStream\);\n            AAudioStream_close\(inputStream\);\n            inputStream = nullptr;\n        \}\n    \}\n    \n    void stop\(\) \{', new_start, content, flags=re.DOTALL)

with open("client_flutter/android/app/src/main/cpp/aaudio_engine.h", "w") as f:
    f.write(content)
