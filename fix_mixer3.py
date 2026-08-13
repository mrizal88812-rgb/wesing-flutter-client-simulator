with open('client_flutter/lib/features/record/record_screen.dart', 'r') as f:
    content = f.read()

import re

# find the block with "Audio Mixer & Latency Calibration"
mixer_pattern = re.compile(r'Align\(\s*alignment: Alignment\.bottomCenter,\s*child: Container\(.*?Terapkan Mixing.*?\),\s*\)\s*,\s*\]', re.DOTALL)
match = mixer_pattern.search(content)

if match:
    # replace 
    pass
else:
    # let's try a different approach. Just replace the contents of the container with the Column.
    column_start = content.find("child: Column(\n                  mainAxisSize: MainAxisSize.min,\n                  crossAxisAlignment: CrossAxisAlignment.stretch,\n                  children: [")
    if column_start != -1:
        column_end = content.find("                  ],\n                ),\n              ),\n            ),\n          ],", column_start)
        
        if column_end != -1:
            new_column = """child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.tune, color: Colors.orange, size: 16),
                                  SizedBox(width: 6),
                                  Text(
                                    'Audio Mixer & Latency Calibration',
                                    style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.grey, size: 20),
                          onPressed: () {
                            setState(() {
                              _showMixerControls = false;
                            });
                          },
                        ),
                      ],
                    ),
                    const Divider(color: Colors.white12, height: 16),
                    _buildSliderRow(
                      label: 'Vocal Volume',
                      value: _vocalVolume,
                      min: 0.0,
                      max: 1.5,
                      displayValue: '${(_vocalVolume * 100).toInt()}%',
                      onChanged: (val) {
                        setState(() => _vocalVolume = val);
                        _audioEngine.setVocalVolume(val);
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildSliderRow(
                      label: 'Music Volume',
                      value: _musicVolume,
                      min: 0.0,
                      max: 1.2,
                      displayValue: '${(_musicVolume * 100).toInt()}%',
                      onChanged: (val) {
                        setState(() => _musicVolume = val);
                        _audioEngine.setInstrumentalVolume(val);
                      },
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.02),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Latency Delay', style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  _latencyOffset >= 0 ? '+${_latencyOffset} ms' : '${_latencyOffset} ms',
                                  style: const TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline, color: Colors.amber),
                                onPressed: () {
                                  setState(() {
                                    _latencyOffset -= 10;
                                    if (_latencyOffset < -1000) _latencyOffset = -1000;
                                  });
                                  _audioEngine.setLatencyOffset(_latencyOffset);
                                },
                              ),
                              Expanded(
                                child: Slider(
                                  value: _latencyOffset.toDouble(),
                                  min: -1000.0,
                                  max: 1000.0,
                                  divisions: 200,
                                  activeColor: Colors.amber,
                                  inactiveColor: Colors.white12,
                                  onChanged: (val) {
                                    setState(() {
                                      _latencyOffset = val.toInt();
                                    });
                                    _audioEngine.setLatencyOffset(val.toInt());
                                  },
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline, color: Colors.amber),
                                onPressed: () {
                                  setState(() {
                                    _latencyOffset += 10;
                                    if (_latencyOffset > 1000) _latencyOffset = 1000;
                                  });
                                  _audioEngine.setLatencyOffset(_latencyOffset);
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () {
                        setState(() {
                          _showMixerControls = false;
                        });
                      },
                      child: const Text('Terapkan Mixing', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ),"""
            
            content = content[:column_start] + new_column + content[column_end:]
            with open('client_flutter/lib/features/record/record_screen.dart', 'w') as f:
                f.write(content)
            print("Successfully updated Mixer Layout with Column replace")
        else:
            print("column_end not found")
            print(content[column_start:column_start+2000])
    else:
        print("column_start not found")

