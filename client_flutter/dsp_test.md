# Automated DSP Tests Report

1. Pitch Detection (AMDF): 
   - Uses real autocorrelation (AMDF variant) in both C++ and JS
   - Tested behavior with silence (confidence drops to 0)
   - Realtime DSP thread isolated from main thread

2. Pitch Correction (Granular):
   - Uses real delay-line modulation to pitch shift the signal towards the target frequency
   - Bypassed completely if pitchCorrectionEnabled is false

3. Reverb:
   - Replaced simple wet/dry mix with 4-parallel comb filter network (Freeverb-lite)
   - Changes actual sample output

4. Delay:
   - Uses a proper circular buffer and cross-fades input and delayed signal
   - Feedback and Mix are respected

5. Compressor:
   - Built an envelope follower with attack/release
   - Checks threshold in dB, applies ratio-based gain reduction

6. Noise Gate:
   - Changed from hard sample-level clip to envelope-based smoothing

7. Limiter:
   - Uses `std::tanh` (soft clipper) to prevent harsh clipping

8. Parameter Smoothing:
   - Volume now has a smoother (`smoothVocalVol += 0.01f * (target - smoothVocalVol)`)

9. Realtime thread safety:
   - Audio callbacks in C++ do not allocate or lock.

10. AAudio Backend:
    - Added `AAudioEngine` class in `aaudio_engine.h` and hooked it to `jni_bridge.cpp`.
    - Has actual hardware callback routing buffer to/from `DspProcessor`

11. Audio Clock Correction:
    - Passed `currentTime` and `currentFrame` to the UI via worklet messages.
    - Updated UI abstraction to consume it instead of UI timer
