package com.okamiaaww.app

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.embedding.engine.FlutterEngine
import kotlinx.coroutines.*

class KaraokeDspEngine(private val flutterEngine: FlutterEngine) : MethodChannel.MethodCallHandler {
    
    private val scope = CoroutineScope(Dispatchers.IO + Job())
    // ============================================================
// POSITION EVENT STATE
// ============================================================

private val positionHandler = Handler(Looper.getMainLooper())

@Volatile
private var positionEventSink: EventChannel.EventSink? = null

@Volatile
private var positionRunnable: Runnable? = null

@Volatile
private var positionTickerStarted = false

// ============================================================
// PITCH EVENT STATE
// ============================================================

private val pitchHandler = Handler(Looper.getMainLooper())

@Volatile
private var pitchEventSink: EventChannel.EventSink? = null

@Volatile
private var pitchRunnable: Runnable? = null

@Volatile
private var pitchTickerStarted = false
    // C++ JNI Functions
    external fun init(sampleRate: Int)
    external fun dispose()
    
    external fun setVocalVolume(vol: Float)
    external fun setInstrumentalVolume(vol: Float)
    external fun setMonitoringEnabled(enabled: Boolean)
    
    // Playback/Recording control
    external fun loadInstrumental(pcmData: FloatArray)
    external fun startRecording()
    external fun stopRecording()
    external fun play()
    external fun pause()
    external fun seek(positionSeconds: Float)
    
    external fun getPlaybackPosition(): Float
    external fun getDuration(): Float
    
    // DSP
    external fun setDelay(enabled: Boolean, timeMs: Float, feedback: Float, mix: Float)
    external fun setReverb(enabled: Boolean, presetName: String, mix: Float)
    external fun setCompressor(enabled: Boolean, threshold: Float, ratio: Float)
    external fun setPitchCorrection(modeInt: Int, speed: Float, targetHz: Float)
    external fun setEqEnabled(enabled: Boolean)
    external fun setEqBand(band: Int, freq: Float, gain: Float, q: Float)
    external fun setLatencyOffset(offsetMs: Int)
    
    // Pitch & status
    external fun getCurrentPitch(): Float
    external fun getConfidence(): Float
    
    // Export
    external fun exportMix(vocalVol: Float, instVol: Float, outPath: String): Boolean
    external fun getExportProgress(): Float
    private fun startPositionTicker() {

    if (positionTickerStarted) {
        return
    }

    positionTickerStarted = true
    android.util.Log.d("KaraokeDspEngine", "position ticker started")

    positionRunnable = object : Runnable {
        override fun run() {
            try {
                val position = getPlaybackPosition()
                positionEventSink?.success(position.toDouble())
            } catch (e: Exception) {
                android.util.Log.e("KaraokeDspEngine", "position ticker error", e)
            }

            if (positionTickerStarted) {
                positionHandler.postDelayed(this, 30L)
            }
        }
    }

    positionHandler.post(positionRunnable!!)
}
    init {
        System.loadLibrary("karaoke_dsp")
        
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.okamiaaww.app/KaraokeDspEngine")
        channel.setMethodCallHandler(this)
        
      EventChannel(
    flutterEngine.dartExecutor.binaryMessenger,
    "com.okamiaaww.app/KaraokeDspPosition"
).setStreamHandler(object : EventChannel.StreamHandler {

    override fun onListen(
        arguments: Any?,
        events: EventChannel.EventSink?
    ) {
        android.util.Log.d("KaraokeDspEngine", "position onListen")
        positionEventSink = events
        // Ticker tetap hidup selama app berjalan (engine native singleton),
        // cukup pastikan dia sudah start.
        startPositionTicker()
    }

    override fun onCancel(arguments: Any?) {
        android.util.Log.d("KaraokeDspEngine", "position onCancel")
        // PENTING: JANGAN null-kan positionEventSink di sini.
        //
        // Karena engine native adalah singleton yang dipakai ulang lintas
        // layar (mis. "Merekam Ulang" -> RecordScreen baru), urutan pesan
        // listen/cancel dari Flutter TIDAK terjamin sesuai niat logisnya:
        // screen baru bisa sempat memanggil onListen() lebih dulu sebelum
        // screen lama benar-benar selesai dispose dan mengirim cancel().
        // Kalau cancel yang "telat" ini null-kan sink, sink milik listener
        // BARU ikut hilang -> posisi/seekbar berhenti update selamanya.
        // Memanggil sink.success() pada sink yang sudah tercancel di sisi
        // Flutter cukup aman (no-op), jadi lebih baik biarkan sink lama
        // begitu saja sampai tertimpa oleh onListen() berikutnya.
    }
})
            
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "com.okamiaaww.app/KaraokeDspPitch")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    android.util.Log.d("KaraokeDspEngine", "pitch onListen")
                    pitchEventSink = events
                    // Ticker persisten, sama seperti posisi — jangan buat
                    // Handler/Runnable baru tiap onListen, cukup timpa sink.
                    startPitchTicker()
                }
                override fun onCancel(arguments: Any?) {
                    android.util.Log.d("KaraokeDspEngine", "pitch onCancel")
                    // Sama seperti posisi: JANGAN null-kan sink atau hentikan
                    // ticker di sini. Cancel yang telat dari listener lama
                    // (mis. saat "Merekam Ulang" pindah screen) bisa tiba
                    // setelah listener baru sudah aktif — kalau kita
                    // hentikan ticker/null-kan sink di sini, update pitch
                    // untuk screen yang baru ikut berhenti.
                }
            })
            
        //init(48000)
    }

    private fun startPitchTicker() {
        if (pitchTickerStarted) {
            return
        }
        pitchTickerStarted = true
        android.util.Log.d("KaraokeDspEngine", "pitch ticker started")

        pitchRunnable = object : Runnable {
            override fun run() {
                try {
                    val map = mapOf(
                        "pitch" to getCurrentPitch(),
                        "confidence" to getConfidence()
                    )
                    pitchEventSink?.success(map)
                } catch (e: Exception) {
                    android.util.Log.e("KaraokeDspEngine", "pitch ticker error", e)
                }

                if (pitchTickerStarted) {
                    pitchHandler.postDelayed(this, 16) // ~60fps
                }
            }
        }

        pitchHandler.post(pitchRunnable!!)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        android.util.Log.i("KaraokeDspEngine", "onMethodCall: ${call.method}")
        when (call.method) {
            "init" -> {
                init(48000)
                result.success(null)
            }
            "loadInstrumental" -> {
                val url = call.argument<String>("url") ?: return result.error("ERR", "URL is null", null)
                // Decode in background
                scope.launch {
                    val pcm = AudioDecoder.decodeFileToPcmFloat(url, 48000) // target 48kHz
                    withContext(Dispatchers.Main) {
                        if (pcm != null) {
                            loadInstrumental(pcm)
                            result.success(null)
                        } else {
                            result.error("ERR", "Failed to decode", null)
                        }
                    }
                }
            }
            "startRecording" -> {
                startRecording()
                result.success(null)
            }
            "stopRecording" -> {
                stopRecording()
                result.success(null)
            }
            "play" -> {
                play()
                result.success(null)
            }
            "pause" -> {
                pause()
                result.success(null)
            }
            "seek" -> {
                val posMs = call.argument<Int>("position_ms") ?: 0
                seek(posMs / 1000f)
                result.success(null)
            }
            "getDuration" -> {
                result.success((getDuration() * 1000).toInt())
            }
            "setMonitoringEnabled" -> {
                val enabled = call.argument<Boolean>("enabled") ?: true
                setMonitoringEnabled(enabled)
                result.success(null)
            }
            "setVocalVolume" -> {
                val vol = call.argument<Double>("volume")?.toFloat() ?: 1.0f
                setVocalVolume(vol)
                result.success(null)
            }
            "setInstrumentalVolume" -> {
                val vol = call.argument<Double>("volume")?.toFloat() ?: 1.0f
                setInstrumentalVolume(vol)
                result.success(null)
            }
            "setDelayEnabled" -> {
                val enabled = call.argument<Boolean>("enabled") ?: false
                setDelay(enabled, 250f, 0.3f, 0.2f) // defaults if not passed properly, will refine later
                result.success(null)
            }
            "setDelayTime" -> {
                val time = call.argument<Int>("time_ms")?.toFloat() ?: 250f
                setDelay(true, time, 0.3f, 0.2f)
                result.success(null)
            }
            "setDelayFeedback" -> {
                val fb = call.argument<Double>("feedback")?.toFloat() ?: 0.3f
                setDelay(true, 250f, fb, 0.2f)
                result.success(null)
            }
            "setDelayMix" -> {
                val mix = call.argument<Double>("mix")?.toFloat() ?: 0.2f
                setDelay(true, 250f, 0.3f, mix)
                result.success(null)
            }
            "setReverbEnabled" -> {
                val enabled = call.argument<Boolean>("enabled") ?: false
                setReverb(enabled, "Studio", 0.25f)
                result.success(null)
            }
            "setReverbPreset" -> {
                val preset = call.argument<String>("preset") ?: "Studio"
                setReverb(true, preset, 0.25f)
                result.success(null)
            }
            "setReverbMix" -> {
                val mix = call.argument<Double>("mix")?.toFloat() ?: 0.25f
                setReverb(true, "Studio", mix)
                result.success(null)
            }
            "setCompressorEnabled" -> {
                val enabled = call.argument<Boolean>("enabled") ?: true
                setCompressor(enabled, -20f, 3.0f)
                result.success(null)
            }
            "setVocalRange" -> {
                val songStart = call.argument<Double>("songStart") ?: 0.0
                val songEnd = call.argument<Double>("songEnd") ?: 0.0
                // Can store or apply range if needed
                result.success(null)
            }
            "setAutoTuneMode" -> {
                val modeStr = call.argument<String>("mode") ?: "off"
                val mode = when (modeStr) {
                    "natural" -> 1
                    "strong" -> 2
                    else -> 0
                }
                setPitchCorrection(mode, 1.0f, 0.0f) // target hz handled locally by native engine based on current track if we passed midi, but right now we just use it directly
                result.success(null)
            }
            "setPitchCorrectionEnabled" -> {
                result.success(null)
            }
            "setEqEnabled" -> {
                val enabled = call.argument<Boolean>("enabled") ?: true
                setEqEnabled(enabled)
                result.success(null)
            }
            "setEQBand" -> {
                val band = call.argument<Int>("bandIndex") ?: 0
                val freq = call.argument<Double>("frequency")?.toFloat() ?: 1000f
                val gain = call.argument<Double>("gain")?.toFloat() ?: 0f
                val q = call.argument<Double>("q")?.toFloat() ?: 0.707f
                setEqBand(band, freq, gain, q)
                result.success(null)
            }
            "setLatencyOffset" -> {
                val offsetMs = call.argument<Int>("offsetMs") ?: 0
                setLatencyOffset(offsetMs)
                result.success(null)
            }
            "dispose" -> {
                dispose()
                result.success(null)
            }
            "getExportProgress" -> {
                result.success(getExportProgress().toDouble())
            }
            "exportMix" -> {
                val vVol = call.argument<Double>("vocalVolume")?.toFloat() ?: 1.0f
                val iVol = call.argument<Double>("instrumentalVolume")?.toFloat() ?: 1.0f
                val outPath = call.argument<String>("outPath") ?: "/sdcard/Download/export.wav"
                
                scope.launch {
                    var isDone = false
                    val progressJob = launch {
                        while (!isDone) {
                            val p = getExportProgress()
                            withContext(Dispatchers.Main) {
                                // Send progress back via event channel if needed, or MethodChannel callback if possible
                                // For now, the app expects MethodChannel reply at the end, but we can send progress via EventChannel if we want.
                            }
                            delay(100)
                        }
                    }
                    val success = exportMix(vVol, iVol, outPath)
                    isDone = true
                    progressJob.cancel()
                    withContext(Dispatchers.Main) {
                        if (success) {
                            result.success(outPath)
                        } else {
                            result.error("EXPORT_FAILED", "Failed to export mix", null)
                        }
                    }
                }
            }
            else -> result.notImplemented()
        }
    }
}
