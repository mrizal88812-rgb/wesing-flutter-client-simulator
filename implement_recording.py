import re

with open('client_flutter/lib/services/audio/native_audio_engine.dart', 'r') as f:
    content = f.read()

# Add imports
if 'package:record/record.dart' not in content:
    content = content.replace("import 'package:just_audio/just_audio.dart';", "import 'package:just_audio/just_audio.dart';\nimport 'package:record/record.dart';\nimport 'package:path_provider/path_provider.dart';\nimport 'dart:io';")

# Add variables
vars_insert = """  final AudioPlayer _fallbackPlayer = AudioPlayer();
  final AudioPlayer _vocalPlayer = AudioPlayer(); // Added for playing back vocal
  final AudioRecorder _audioRecorder = AudioRecorder();
  String? _recordedFilePath;
"""
content = re.sub(r"  final AudioPlayer _fallbackPlayer = AudioPlayer\(\);", vars_insert, content)

# Modify play
play_old = """    try {
      await _fallbackPlayer.play();
    } catch (e) {
      print('Error playing fallback player: $e');
    }"""
play_new = """    try {
      if (_recordedFilePath != null && File(_recordedFilePath!).existsSync()) {
        if (_vocalPlayer.playing == false) {
           _vocalPlayer.play();
        }
      }
      await _fallbackPlayer.play();
    } catch (e) {
      print('Error playing fallback player: $e');
    }"""
content = content.replace(play_old, play_new)

# Modify pause
pause_old = """    try {
      await _fallbackPlayer.pause();
    } catch (e) {
      print('Error pausing fallback player: $e');
    }"""
pause_new = """    try {
      _vocalPlayer.pause();
      await _fallbackPlayer.pause();
    } catch (e) {
      print('Error pausing fallback player: $e');
    }"""
content = content.replace(pause_old, pause_new)

# Modify stop
stop_old = """    try {
      await _fallbackPlayer.stop();
    } catch (e) {
      print('Error stopping fallback player: $e');
    }"""
stop_new = """    try {
      _vocalPlayer.stop();
      await _fallbackPlayer.stop();
    } catch (e) {
      print('Error stopping fallback player: $e');
    }"""
content = content.replace(stop_old, stop_new)

# Modify seek
seek_old = """    try {
      await _fallbackPlayer.seek(position);
    } catch (e) {
      print('Error seeking fallback player: $e');
    }"""
seek_new = """    try {
      await _fallbackPlayer.seek(position);
      if (_recordedFilePath != null) {
        final vocalPos = position + Duration(milliseconds: _latencyOffset);
        if (vocalPos.inMilliseconds > 0) {
           await _vocalPlayer.seek(vocalPos);
        } else {
           await _vocalPlayer.seek(Duration.zero);
        }
      }
    } catch (e) {
      print('Error seeking fallback player: $e');
    }"""
content = content.replace(seek_old, seek_new)

# Modify startRecording
start_record_old = """  @override
  Future<void> startRecording() async {
    _isRecordingState = true;
    _isPlayingState = true;
    await _safeInvoke('startRecording');
    await play();
  }"""
start_record_new = """  @override
  Future<void> startRecording() async {
    _isRecordingState = true;
    _isPlayingState = true;
    
    try {
      if (await _audioRecorder.hasPermission()) {
        final dir = await getApplicationDocumentsDirectory();
        _recordedFilePath = '${dir.path}/vocal_record_${DateTime.now().millisecondsSinceEpoch}.m4a';
        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 128000), 
          path: _recordedFilePath!
        );
      }
    } catch (e) {
      print("Error starting record: $e");
    }

    await _safeInvoke('startRecording');
    await play();
  }"""
content = content.replace(start_record_old, start_record_new)

# Modify stopRecording
stop_record_old = """  @override
  Future<void> stopRecording() async {
    _isRecordingState = false;
    _isPlayingState = false;
    await _safeInvoke('stopRecording');
    await pause();
  }"""
stop_record_new = """  @override
  Future<void> stopRecording() async {
    _isRecordingState = false;
    _isPlayingState = false;
    
    try {
      if (await _audioRecorder.isRecording()) {
        final path = await _audioRecorder.stop();
        if (path != null) {
           _recordedFilePath = path;
           await _vocalPlayer.setFilePath(path);
           await _vocalPlayer.setVolume(_vocalVolume);
        }
      }
    } catch (e) {
      print("Error stopping record: $e");
    }

    await _safeInvoke('stopRecording');
    await pause();
  }"""
content = content.replace(stop_record_old, stop_record_new)

# Modify setVocalVolume
vol_vocal_old = """  @override
  void setVocalVolume(double volume) {
    _vocalVolume = volume;
    _safeInvoke('setVocalVolume', {'volume': volume});
  }"""
vol_vocal_new = """  @override
  void setVocalVolume(double volume) {
    _vocalVolume = volume;
    _vocalPlayer.setVolume(volume);
    _safeInvoke('setVocalVolume', {'volume': volume});
  }"""
content = content.replace(vol_vocal_old, vol_vocal_new)

# Modify setLatencyOffset
lat_old = """  @override
  void setLatencyOffset(int milliseconds) {
    _latencyOffset = milliseconds;
    _safeInvoke('setLatencyOffset', {'offset_ms': milliseconds});
  }"""
lat_new = """  @override
  void setLatencyOffset(int milliseconds) {
    _latencyOffset = milliseconds;
    _safeInvoke('setLatencyOffset', {'offset_ms': milliseconds});
    // Immediately apply to playback if playing
    if (_isPlayingState && !_isRecordingState && _recordedFilePath != null) {
       final newPos = _fallbackPlayer.position + Duration(milliseconds: milliseconds);
       _vocalPlayer.seek(newPos);
    }
  }"""
content = content.replace(lat_old, lat_new)

# Modify dispose
disp_old = """    await _fallbackPlayer.dispose();
    await _safeInvoke('dispose');"""
disp_new = """    await _fallbackPlayer.dispose();
    await _vocalPlayer.dispose();
    await _audioRecorder.dispose();
    await _safeInvoke('dispose');"""
content = content.replace(disp_old, disp_new)

with open('client_flutter/lib/services/audio/native_audio_engine.dart', 'w') as f:
    f.write(content)

print("Applied recording logic.")

