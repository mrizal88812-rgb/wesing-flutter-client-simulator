with open('client_flutter/lib/services/audio/native_audio_engine.dart', 'r') as f:
    content = f.read()

import re

# We previously added:
#   @override
#   double getCurrentUserPitch() {
#     if (_isPlayingState && _isRecordingState) {
#       final time = DateTime.now().millisecondsSinceEpoch / 1000.0;
#       return 250.0 + 100.0 * (time % 5) / 5.0; // Dynamic pitch sweep
#     }
#     return _currentPitch;
#   }

old_code = """  @override
  double getCurrentUserPitch() {
    if (_isPlayingState && _isRecordingState) {
      final time = DateTime.now().millisecondsSinceEpoch / 1000.0;
      return 250.0 + 100.0 * (time % 5) / 5.0; // Dynamic pitch sweep
    }
    return _currentPitch;
  }"""

new_code = """  @override
  double getCurrentUserPitch() => _currentPitch;"""

if old_code in content:
    content = content.replace(old_code, new_code)
    with open('client_flutter/lib/services/audio/native_audio_engine.dart', 'w') as f:
        f.write(content)
    print("Reverted native pitch dummy logic.")
else:
    print("Could not find native pitch dummy logic.")
