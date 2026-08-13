import re

with open("client_flutter/android/app/src/main/cpp/dsp_processor.cpp", "r") as f:
    content = f.read()

new_process_output = """void DspProcessor::processOutputRealtime(float* outBuffer, int numFrames) {
    bool playing = isPlaying.load();
    bool recording = isRecording.load();
    size_t pFrame = playbackFrame.load();
    bool monitoring = monitoringEnabled.load();
    
    float vVol = vocalVol.load();
    float iVol = instVol.load();
    
    // 1. Gather vocal samples (either from mic or from recorded buffer)
    for (int i = 0; i < numFrames; i++) {
        float vSample = 0.0f;
        if (recording) {
            if (monitoring) {
                vSample = outBuffer[i]; // Mic input via ring buffer
            } else {
                vSample = 0.0f;
            }
        } else if (playing) {
            if (pFrame + i < vocalRecording.size()) {
                vSample = vocalRecording[pFrame + i];
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
    
    // 5. Advance frame
    if (playing) {
        playbackFrame.store(pFrame + numFrames);
    }
}"""

content = re.sub(r'void DspProcessor::processOutputRealtime\(float\* outBuffer, int numFrames\).*?playbackFrame\.store\(pFrame \+ numFrames\);\n    \}\n\}', new_process_output, content, flags=re.DOTALL)

with open("client_flutter/android/app/src/main/cpp/dsp_processor.cpp", "w") as f:
    f.write(content)
