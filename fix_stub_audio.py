with open('client_flutter/lib/services/audio/stub_audio_engine.dart', 'r') as f:
    content = f.read()

import re

# We want to change `double getCurrentUserPitch() => 60.0;`
# to something dynamic that changes based on time, so the UI updates.
dynamic_pitch = """  @override
  double getCurrentUserPitch() {
    if (!_isPlaying) return 0.0;
    // Generate a mock pitch frequency between 150 Hz and 450 Hz
    final time = DateTime.now().millisecondsSinceEpoch / 1000.0;
    import 'dart:math' as math; // will add at top if missing, wait better to use math.sin
    // just return a dummy varying value
    return 300.0 + 100.0 * (time % 2 == 0 ? 1 : -1); 
  }
"""

# Actually, let's use a proper `math.sin` and add the import if needed.
# It seems `import 'dart:async';` is there.

new_content = content.replace("double getCurrentUserPitch() => 60.0;", """
  @override
  double getCurrentUserPitch() {
    if (!_isPlaying && !_isRecording) return 0.0;
    // Simulate a changing vocal frequency (Hz)
    final time = DateTime.now().millisecondsSinceEpoch / 1000.0;
    return 250.0 + 100.0 * (time % 5) / 5.0; // Sweeps from 250Hz to 350Hz over 5 seconds
  }
""")

# Also in StubAudioEngine, we need to make sure the position stream is firing when playing!
# Currently `_positionStreamController` exists but nobody adds to it.
# Let's add a timer to StubAudioEngine!

timer_code = """
  Timer? _playbackTimer;
  Duration _currentPosition = Duration.zero;

  void _startTimer() {
    _playbackTimer?.cancel();
    _playbackTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (_isPlaying) {
        _currentPosition += const Duration(milliseconds: 100);
        _positionStreamController.add(_currentPosition);
      }
    });
  }
  
  void _stopTimer() {
    _playbackTimer?.cancel();
  }
"""

new_content = new_content.replace("class StubKaraokeAudioEngine implements KaraokeAudioEngine {", "class StubKaraokeAudioEngine implements KaraokeAudioEngine {\n" + timer_code)

new_content = new_content.replace("""  @override
  Future<void> startRecording() async {
    _isRecording = true;
    _isPlaying = true;
  }""", """  @override
  Future<void> startRecording() async {
    _isRecording = true;
    _isPlaying = true;
    _startTimer();
  }""")

new_content = new_content.replace("""  @override
  Future<void> stopRecording() async {
    _isRecording = false;
    _isPlaying = false;
  }""", """  @override
  Future<void> stopRecording() async {
    _isRecording = false;
    _isPlaying = false;
    _stopTimer();
  }""")

new_content = new_content.replace("""  @override
  Future<void> play() async {
    _isPlaying = true;
  }""", """  @override
  Future<void> play() async {
    _isPlaying = true;
    _startTimer();
  }""")

new_content = new_content.replace("""  @override
  Future<void> pause() async {
    _isPlaying = false;
  }""", """  @override
  Future<void> pause() async {
    _isPlaying = false;
    _stopTimer();
  }""")

new_content = new_content.replace("""  @override
  Duration getPlaybackPosition() => Duration.zero;""", """  @override
  Duration getPlaybackPosition() => _currentPosition;""")

new_content = new_content.replace("""  @override
  Future<void> seek(Duration position) async {}""", """  @override
  Future<void> seek(Duration position) async {
    _currentPosition = position;
    _positionStreamController.add(_currentPosition);
  }""")


with open('client_flutter/lib/services/audio/stub_audio_engine.dart', 'w') as f:
    f.write(new_content)
