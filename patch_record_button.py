import re

with open("client_flutter/lib/features/record/record_screen.dart", "r") as f:
    content = f.read()

# Fix default monitoring
content = content.replace("bool _monitoringEnabled = false;", "bool _monitoringEnabled = true;")

# Let's ensure the engine is updated in init
engine_init_replace = """    await _audioEngine.loadInstrumental(AppConfig.resolveMediaUrl(widget.song.audioUrl));
    _audioEngine.setMonitoringEnabled(_monitoringEnabled);
"""
content = content.replace("    await _audioEngine.loadInstrumental(AppConfig.resolveMediaUrl(widget.song.audioUrl));\n", engine_init_replace)

# Replace the SizedBox
row_str = """              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 40),
                  const SizedBox(width: 40),"""

new_row_str = """              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Monitor Vocal Toggle
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _monitoringEnabled = !_monitoringEnabled;
                        _audioEngine.setMonitoringEnabled(_monitoringEnabled);
                      });
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: _monitoringEnabled ? Colors.green[900]?.withOpacity(0.3) : const Color(0xFF111113),
                            shape: BoxShape.circle,
                            border: Border.all(color: _monitoringEnabled ? Colors.green[500]! : const Color(0xFF1F1F23)),
                          ),
                          child: Icon(
                            _monitoringEnabled ? Icons.headset : Icons.headset_off,
                            color: _monitoringEnabled ? Colors.green[400] : Colors.grey,
                            size: 18,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Monitor',
                          style: TextStyle(
                            color: _monitoringEnabled ? Colors.green[400] : Colors.grey,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 40),"""

content = content.replace(row_str, new_row_str)

with open("client_flutter/lib/features/record/record_screen.dart", "w") as f:
    f.write(content)
