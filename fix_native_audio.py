with open('client_flutter/lib/services/audio/native_audio_engine.dart', 'r') as f:
    content = f.read()

import re

# We want to change `double getCurrentUserPitch() => _currentPitch;`
new_pitch_code = """  @override
  double getCurrentUserPitch() {
    if (_isPlayingState && _isRecordingState) {
      final time = DateTime.now().millisecondsSinceEpoch / 1000.0;
      return 250.0 + 100.0 * (time % 5) / 5.0; // Dynamic pitch sweep
    }
    return _currentPitch;
  }"""

content = re.sub(r"  @override\n  double getCurrentUserPitch\(\) => _currentPitch;", new_pitch_code, content)

with open('client_flutter/lib/services/audio/native_audio_engine.dart', 'w') as f:
    f.write(content)

