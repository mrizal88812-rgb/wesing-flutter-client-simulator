window.initKaraokeWorklet = async function(audioCtx) {
    await audioCtx.audioWorklet.addModule('karaoke_dsp_worklet.js');
    const workletNode = new AudioWorkletNode(audioCtx, 'karaoke-dsp-worklet');
    return workletNode;
};
