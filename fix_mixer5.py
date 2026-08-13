with open('client_flutter/lib/features/record/record_screen.dart', 'r') as f:
    content = f.read()

start_idx = content.find("if (_showMixerControls) ...[")
if start_idx != -1:
    end_idx = content.find("],\n        ],\n      ),\n    );\n  }\n}\n", start_idx)
    if end_idx == -1:
         end_idx = content.find("          ],\n        ],\n      ),\n    );\n  }\n}\n", start_idx)
         
    if end_idx != -1:
        new_mixer = """if (_showMixerControls) ...[
            Positioned.fill(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _showMixerControls = false;
                  });
                },
                child: Container(
                  color: Colors.black54,
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Color(0xFF0C0817),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                  border: Border(top: BorderSide(color: Colors.white12)),
                ),
                child: Column(
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
                    ),
                  ],
                ),
              ),
            ),
          """
        content = content[:start_idx] + new_mixer + content[end_idx:]
        with open('client_flutter/lib/features/record/record_screen.dart', 'w') as f:
            f.write(content)
        print("Done replacing entire mixer block 5")
    else:
        print("Could not find ] for mixer block, let's print tail")
        print(content[-500:])
else:
    print("Could not find start for mixer block")

