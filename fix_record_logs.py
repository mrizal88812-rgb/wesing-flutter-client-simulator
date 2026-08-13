import re

with open('client_flutter/lib/services/audio/native_audio_engine.dart', 'r') as f:
    content = f.read()

stop_record_old = """  @override
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

stop_record_new = """  @override
  Future<void> stopRecording() async {
    _isRecordingState = false;
    _isPlayingState = false;
    
    try {
      if (await _audioRecorder.isRecording()) {
        final path = await _audioRecorder.stop();
        if (path != null) {
           _recordedFilePath = path;
           final file = File(path);
           if (file.existsSync()) {
             print("Recording saved successfully! Size: ${file.lengthSync()} bytes at path: $path");
           } else {
             print("Recording file does not exist at path: $path");
           }
           await _vocalPlayer.setFilePath(path);
           await _vocalPlayer.setVolume(_vocalVolume);
        } else {
           print("Audio recorder returned null path!");
        }
      } else {
        print("Audio recorder was not recording when stopRecording was called.");
      }
    } catch (e) {
      print("Error stopping record: $e");
    }

    await _safeInvoke('stopRecording');
    await pause();
  }"""

if stop_record_old in content:
    content = content.replace(stop_record_old, stop_record_new)
    with open('client_flutter/lib/services/audio/native_audio_engine.dart', 'w') as f:
        f.write(content)
    print("Added logs to stopRecording")
else:
    print("Could not find stopRecording")

