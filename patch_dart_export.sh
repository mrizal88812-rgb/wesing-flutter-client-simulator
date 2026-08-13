#!/bin/bash
cat << 'DART' > temp.dart
  @override
  Future<String> exportMix({
    required double vocalVolume,
    required double instrumentalVolume,
    required KaraokeEffectsSettings settings,
    required Function(double progress) onProgress,
  }) async {
    bool isExporting = true;
    
    Timer.periodic(const Duration(milliseconds: 100), (timer) async {
      if (!isExporting) {
        timer.cancel();
        return;
      }
      try {
        final double progress = await _channel.invokeMethod('getExportProgress') ?? 0.0;
        onProgress(progress);
      } catch(e) {}
    });

    try {
      final String? result = await _channel.invokeMethod<String>('exportMix', {
        'vocalVolume': vocalVolume,
        'instrumentalVolume': instrumentalVolume,
        'outPath': '/sdcard/Download/karaoke_export_${DateTime.now().millisecondsSinceEpoch}.wav'
      });
      isExporting = false;
      onProgress(1.0);
      if (result != null) return result;
    } catch (e) {
      isExporting = false;
      throw Exception("EXPORT FAILED: $e");
    }
    isExporting = false;
    throw Exception("EXPORT FAILED: Unknown error");
  }
DART

sed -i '/Future<String> exportMix({/,/throw Exception("EXPORT FAILED: Unknown error");\n  }/c \'"$(cat temp.dart)"'' client_flutter/lib/services/audio/native_audio_engine.dart
