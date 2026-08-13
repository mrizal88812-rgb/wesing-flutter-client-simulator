with open('client_flutter/lib/features/record/record_screen.dart', 'r') as f:
    content = f.read()

import re

new_prog = """          // Progress bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled, color: Colors.orange, size: 40),
                  onPressed: () {
                    setState(() {
                      if (isPlaying) {
                        _audioEngine.pause();
                        isPlaying = false;
                        _vinylAnimationController.stop();
                      } else {
                        _audioEngine.play();
                        isPlaying = true;
                        _vinylAnimationController.repeat();
                      }
                    });
                  },
                ),
                Expanded(
                  child: SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 4,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                      activeTrackColor: Colors.orange,
                      inactiveTrackColor: Colors.white.withOpacity(0.2),
                      thumbColor: Colors.white,
                    ),
                    child: Slider(
                      value: _currentTime.inMilliseconds.toDouble().clamp(0.0, math.max(1.0, _duration.inMilliseconds.toDouble())),
                      min: 0.0,
                      max: math.max(100.0, _duration.inMilliseconds.toDouble()),
                      onChanged: (val) {
                        _audioEngine.seek(Duration(milliseconds: val.toInt()));
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  "${_formatDuration(_currentTime)} / ${_formatDuration(_duration)}",
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),"""

# Let's replace the whole block between "// Progress bar" and "// Presets Bar"
prog_start = content.find("          // Progress bar")
prog_end = content.find("          // Presets Bar")

if prog_start != -1 and prog_end != -1:
    content = content[:prog_start] + new_prog + "\n          \n" + content[prog_end:]
    with open('client_flutter/lib/features/record/record_screen.dart', 'w') as f:
        f.write(content)
    print("Updated progress bar with Play/Pause button")
else:
    print("Could not find boundaries")

