import re

with open('client_flutter/lib/services/audio/native_audio_engine.dart', 'r') as f:
    content = f.read()

play_old = """    try {
      if (_recordedFilePath != null && File(_recordedFilePath!).existsSync()) {
        if (_vocalPlayer.playing == false) {
           _vocalPlayer.play();
        }
      }
      await _fallbackPlayer.play();"""
      
play_new = """    try {
      if (_recordedFilePath != null && File(_recordedFilePath!).existsSync()) {
        _vocalPlayer.play();
      }
      await _fallbackPlayer.play();"""

if play_old in content:
    content = content.replace(play_old, play_new)
    with open('client_flutter/lib/services/audio/native_audio_engine.dart', 'w') as f:
        f.write(content)
    print("Fixed play vocal logic")
else:
    print("Could not find play vocal logic")

