import re

with open("client_flutter/lib/features/record/record_screen.dart", "r") as f:
    content = f.read()

content = content.replace("bool _isSaving = false;", "bool _isSaving = false;\n  bool _isInstrumentalLoaded = false;")

init_engine = """  Future<void> _initEngine() async {
    await _audioEngine.initialize();
    _audioEngine.setInstrumentalVolume(_musicVolume);
    _audioEngine.setVocalVolume(_vocalVolume);
    await _audioEngine.loadInstrumental(AppConfig.resolveMediaUrl(widget.song.audioUrl));
    if (mounted) {
      setState(() {
        _isInstrumentalLoaded = true;
      });
    }
    _startTimelineTimer();
  }"""

content = re.sub(r'  Future<void> _initEngine\(\) async \{.*?\n  \}', init_engine, content, flags=re.DOTALL)

build_body = """      body: _isInstrumentalLoaded
          ? _buildRecordingView()
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFFFF2A54)),
                  SizedBox(height: 16),
                  Text('Menyiapkan instrumen...', style: TextStyle(color: Colors.white, fontSize: 12)),
                ],
              ),
            ),"""

content = content.replace("      body: _buildRecordingView(),", build_body)

with open("client_flutter/lib/features/record/record_screen.dart", "w") as f:
    f.write(content)
