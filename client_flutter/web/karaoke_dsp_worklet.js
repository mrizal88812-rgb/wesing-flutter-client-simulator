class KaraokeDspWorklet extends AudioWorkletProcessor {
  constructor() {
    super();
    this.vocalVol = 1.0;
    this.smoothVocalVol = 1.0;
    this.smoothReverbMix = 0.0;
    this.smoothDelayMix = 0.0;
    
    // Gate
    this.gateEnabled = false;
    this.gateThreshold = 0.01;
    this.gateEnvelope = 0.0;
    this.gateGain = 1.0;
    
    // Compressor
    this.compEnabled = false;
    this.compThreshold = -24.0;
    this.compRatio = 3.0;
    this.compEnvelope = 0.0;
    
    // Reverb (4 Comb + 2 Allpass Diffusers)
    this.reverbEnabled = false;
    this.reverbMix = 0.0;
    this.roomSizeSetting = 0.8;
    this.dampSetting = 0.5;
    this.revBuffer1 = new Float32Array(Math.floor(sampleRate * 0.0353));
    this.revBuffer2 = new Float32Array(Math.floor(sampleRate * 0.0366));
    this.revBuffer3 = new Float32Array(Math.floor(sampleRate * 0.0377));
    this.revBuffer4 = new Float32Array(Math.floor(sampleRate * 0.0393));
    this.allpassBuf1 = new Float32Array(Math.floor(sampleRate * 0.0050));
    this.allpassBuf2 = new Float32Array(Math.floor(sampleRate * 0.0017));
    this.revPtr1 = 0; this.revPtr2 = 0; this.revPtr3 = 0; this.revPtr4 = 0;
    this.apPtr1 = 0; this.apPtr2 = 0;
    
    // Delay
    this.delayEnabled = false;
    this.delayTimeMs = 0;
    this.delayFeedback = 0;
    this.delayMix = 0;
    this.delayBuffer = new Float32Array(sampleRate * 2);
    this.delayWritePtr = 0;
    
    // AutoTune / Pitch Correction
    this.autoTuneMode = 0; // 0 = OFF, 1 = NATURAL, 2 = STRONG
    this.pitchCorrectionSpeed = 0.8;
    this.targetPitchHz = 0.0;
    this.smoothedTargetPitch = 0.0;
    
    // Dual-Delay Line Overlap-Add Pitch Shifter
    this.grainSize = 1024;
    this.grainBuffer = new Float32Array(2048);
    this.grainWritePtr = 0;
    this.grainReadPtr1 = 0.0;
    this.grainReadPtr2 = 512.0;

    // Limiter
    this.limiterEnvelope = 0.0;
    
    this.currentPitch = 0;
    this.pitchConfidence = 0;

    this.port.onmessage = (e) => {
      const msg = e.data;
      if (msg.type === 'setVocalVolume') this.vocalVol = msg.value;
      if (msg.type === 'setDelay') {
        this.delayEnabled = msg.enabled;
        this.delayTimeMs = msg.timeMs;
        this.delayFeedback = msg.feedback;
        this.delayMix = msg.mix;
      }
      if (msg.type === 'setReverb') {
        this.reverbEnabled = msg.enabled;
        this.reverbMix = msg.mix;
        if (msg.roomSize !== undefined) this.roomSizeSetting = msg.roomSize;
        if (msg.damp !== undefined) this.dampSetting = msg.damp;
      }
      if (msg.type === 'setNoiseGate') {
        this.gateEnabled = msg.enabled;
        this.gateThreshold = msg.threshold;
      }
      if (msg.type === 'setCompressor') {
        this.compEnabled = msg.enabled;
        this.compThreshold = msg.threshold;
        this.compRatio = msg.ratio;
      }
      if (msg.type === 'setPitchCorrection') {
        this.autoTuneMode = msg.mode !== undefined ? msg.mode : (msg.enabled ? 1 : 0);
        this.pitchCorrectionSpeed = msg.speed || 0.8;
        this.targetPitchHz = msg.targetHz || 0.0;
      }
    };
  }

  process(inputs, outputs, parameters) {
    const input = inputs[0];
    const output = outputs[0];
    
    if (!input || !input.length) return true;
    
    const inChannel = input[0];
    const outChannel = output[0];
    const frames = inChannel.length;
    
    // 1. Pitch Detection (AMDF) - ALWAYS runs regardless of AutoTune mode
    if (frames >= 64) {
        let minPeriod = Math.floor(sampleRate / 800);
        let maxPeriod = Math.floor(sampleRate / 80);
        let minAmdf = 1e9;
        let bestPeriod = minPeriod;
        
        for (let p = minPeriod; p <= maxPeriod; p++) {
            if (p >= frames) break;
            let amdf = 0;
            for (let i = 0; i < frames - p; i++) {
                amdf += Math.abs(inChannel[i] - inChannel[i+p]);
            }
            amdf /= (frames - p);
            if (amdf < minAmdf) {
                minAmdf = amdf;
                bestPeriod = p;
            }
        }
        
        let detectedPitch = sampleRate / bestPeriod;
        let confidence = 1.0 - (minAmdf / 0.5);
        if (confidence < 0) confidence = 0;
        if (confidence > 1) confidence = 1;
        
        if (confidence > 0.35) {
            this.currentPitch = detectedPitch;
            this.pitchConfidence = confidence;
        } else {
            this.pitchConfidence = 0.0;
        }
    }
    
    // Notify main thread periodically with timestamp
    if (currentTime * 1000 % 30 < 10) { 
        this.port.postMessage({ 
            type: 'pitch', 
            timestamp: currentTime,
            framePosition: currentFrame,
            freq: this.currentPitch, 
            conf: this.pitchConfidence 
        });
    }

    const delaySamples = Math.min(Math.floor((this.delayTimeMs / 1000) * sampleRate), this.delayBuffer.length - 1);
    const gateAttack = 0.01, gateRelease = 0.002;
    const compAttackCoeff = Math.exp(-1.0 / (0.005 * sampleRate));
    const compReleaseCoeff = Math.exp(-1.0 / (0.100 * sampleRate));
    const limiterReleaseCoeff = Math.exp(-1.0 / (0.050 * sampleRate));

    // Pitch Correction ratio pre-calculation
    let speedFactor = (this.autoTuneMode === 2) ? 0.25 : (0.05 * this.pitchCorrectionSpeed);
    if (this.targetPitchHz > 0) {
      if (this.smoothedTargetPitch <= 0) this.smoothedTargetPitch = this.targetPitchHz;
      this.smoothedTargetPitch += speedFactor * (this.targetPitchHz - this.smoothedTargetPitch);
    }

    let pitchRatio = 1.0;
    if (this.autoTuneMode !== 0 && this.smoothedTargetPitch > 0 && this.currentPitch > 0 && this.pitchConfidence > 0.35) {
      pitchRatio = this.smoothedTargetPitch / this.currentPitch;
      if (this.autoTuneMode === 1) { // NATURAL
        pitchRatio = 1.0 + 0.5 * (pitchRatio - 1.0);
      }
      pitchRatio = Math.max(0.67, Math.min(1.5, pitchRatio));
    }

    for (let i = 0; i < frames; ++i) {
      let sample = inChannel[i];
      
      // 1. Noise Gate
      if (this.gateEnabled) {
        let absS = Math.abs(sample);
        if (absS > this.gateEnvelope) this.gateEnvelope += gateAttack * (absS - this.gateEnvelope);
        else this.gateEnvelope += gateRelease * (absS - this.gateEnvelope);
        
        let targetGain = (this.gateEnvelope > this.gateThreshold) ? 1.0 : 0.0;
        this.gateGain += 0.005 * (targetGain - this.gateGain);
        sample *= this.gateGain;
      }
      
      // 2. Pitch Correction (Dual-Delay Line Overlap-Add Pitch Shifter)
      if (this.autoTuneMode !== 0 && pitchRatio !== 1.0) {
        this.grainBuffer[this.grainWritePtr] = sample;

        this.grainReadPtr1 += pitchRatio;
        this.grainReadPtr2 += pitchRatio;

        if (this.grainReadPtr1 >= this.grainSize) this.grainReadPtr1 -= this.grainSize;
        if (this.grainReadPtr2 >= this.grainSize) this.grainReadPtr2 -= this.grainSize;

        let pos1 = this.grainReadPtr1 / this.grainSize;
        let w1 = 0.5 * (1.0 - Math.cos(2.0 * Math.PI * pos1));

        let pos2 = this.grainReadPtr2 / this.grainSize;
        let w2 = 0.5 * (1.0 - Math.cos(2.0 * Math.PI * pos2));

        let idx1 = (this.grainWritePtr - Math.floor(this.grainReadPtr1) + this.grainBuffer.length) % this.grainBuffer.length;
        let idx2 = (this.grainWritePtr - Math.floor(this.grainReadPtr2) + this.grainBuffer.length) % this.grainBuffer.length;

        sample = (this.grainBuffer[idx1] * w1) + (this.grainBuffer[idx2] * w2);
        this.grainWritePtr = (this.grainWritePtr + 1) % this.grainBuffer.length;
      }

      // 3. Delay
      if (this.delayEnabled) {
        this.smoothDelayMix += 0.01 * (this.delayMix - this.smoothDelayMix);
        if (this.smoothDelayMix > 0.001) {
          let readPtr = (this.delayWritePtr - delaySamples + this.delayBuffer.length) % this.delayBuffer.length;
          let delayedSample = this.delayBuffer[readPtr];
          
          this.delayBuffer[this.delayWritePtr] = sample + (delayedSample * this.delayFeedback);
          sample = sample * (1.0 - this.smoothDelayMix) + delayedSample * this.smoothDelayMix;
          
          this.delayWritePtr = (this.delayWritePtr + 1) % this.delayBuffer.length;
        }
      }

      // 4. Reverb (Freeverb Comb + Allpass)
      if (this.reverbEnabled) {
        this.smoothReverbMix += 0.01 * (this.reverbMix - this.smoothReverbMix);
        if (this.smoothReverbMix > 0.001) {
          let room = Math.max(0.5, Math.min(0.95, this.roomSizeSetting));
          let damp = Math.max(0.1, Math.min(0.8, this.dampSetting));

          let c1 = this.revBuffer1[this.revPtr1];
          this.revBuffer1[this.revPtr1] = sample + c1 * room * (1.0 - damp);
          this.revPtr1 = (this.revPtr1 + 1) % this.revBuffer1.length;
          
          let c2 = this.revBuffer2[this.revPtr2];
          this.revBuffer2[this.revPtr2] = sample + c2 * room * (1.0 - damp);
          this.revPtr2 = (this.revPtr2 + 1) % this.revBuffer2.length;
          
          let c3 = this.revBuffer3[this.revPtr3];
          this.revBuffer3[this.revPtr3] = sample + c3 * room * (1.0 - damp);
          this.revPtr3 = (this.revPtr3 + 1) % this.revBuffer3.length;
          
          let c4 = this.revBuffer4[this.revPtr4];
          this.revBuffer4[this.revPtr4] = sample + c4 * room * (1.0 - damp);
          this.revPtr4 = (this.revPtr4 + 1) % this.revBuffer4.length;
          
          let outCombs = (c1 + c2 + c3 + c4) * 0.25;

          // Allpass 1
          let ap1 = this.allpassBuf1[this.apPtr1];
          let ap1_in = outCombs;
          this.allpassBuf1[this.apPtr1] = ap1_in + ap1 * 0.5;
          let ap1_out = ap1 - ap1_in * 0.5;
          this.apPtr1 = (this.apPtr1 + 1) % this.allpassBuf1.length;

          // Allpass 2
          let ap2 = this.allpassBuf2[this.apPtr2];
          let ap2_in = ap1_out;
          this.allpassBuf2[this.apPtr2] = ap2_in + ap2 * 0.5;
          let ap2_out = ap2 - ap2_in * 0.5;
          this.apPtr2 = (this.apPtr2 + 1) % this.allpassBuf2.length;

          sample = sample * (1.0 - this.smoothReverbMix) + ap2_out * this.smoothReverbMix;
        }
      }
      
      // 5. Compressor (Soft-Knee)
      if (this.compEnabled) {
          let absS = Math.abs(sample);
          if (absS > this.compEnvelope) this.compEnvelope = compAttackCoeff * this.compEnvelope + (1.0 - compAttackCoeff) * absS;
          else this.compEnvelope = compReleaseCoeff * this.compEnvelope + (1.0 - compReleaseCoeff) * absS;
          
          let envDb = 20.0 * Math.log10(this.compEnvelope + 1e-5);
          let kneeWidthDb = 6.0;
          let gainReductionDb = 0.0;

          if (envDb > (this.compThreshold + kneeWidthDb / 2.0)) {
            gainReductionDb = (envDb - this.compThreshold) * (1.0 - 1.0 / this.compRatio);
          } else if (envDb > (this.compThreshold - kneeWidthDb / 2.0)) {
            let delta = envDb - (this.compThreshold - kneeWidthDb / 2.0);
            gainReductionDb = (1.0 - 1.0 / this.compRatio) * (delta * delta) / (2.0 * kneeWidthDb);
          }

          let makeupGainDb = this.compThreshold * (1.0 - 1.0 / this.compRatio) * -0.5;
          let netGainLinear = Math.pow(10.0, (-gainReductionDb + makeupGainDb) / 20.0);
          sample *= netGainLinear;
      }
      
      // 6. Volume smoothing
      this.smoothVocalVol += 0.01 * (this.vocalVol - this.smoothVocalVol);
      sample *= this.smoothVocalVol;
      
      // 7. Limiter (Peak Envelope + Soft Clipper)
      let absS = Math.abs(sample);
      if (absS > this.limiterEnvelope) {
        this.limiterEnvelope = absS;
      } else {
        this.limiterEnvelope = limiterReleaseCoeff * this.limiterEnvelope + (1.0 - limiterReleaseCoeff) * absS;
      }

      let maxThreshold = 0.95;
      if (this.limiterEnvelope > maxThreshold) {
        let gain = maxThreshold / this.limiterEnvelope;
        sample *= gain;
      }

      if (sample > 1.0) sample = Math.tanh(sample);
      else if (sample < -1.0) sample = Math.tanh(sample);
      
      outChannel[i] = sample;
    }

    return true;
  }
}

registerProcessor('karaoke-dsp-worklet', KaraokeDspWorklet);

