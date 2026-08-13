import re

with open("client_flutter/lib/features/record/record_screen.dart", "r") as f:
    content = f.read()

# Replace lyrics text
old_lyrics = 'const Center(child: Text("No Lyrics Available", style: TextStyle(color: Colors.grey)))'
new_lyrics = 'const Center(child: Text("Tidak ada Lirik", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)))'
content = content.replace(old_lyrics, new_lyrics)

# Add try-catch in _initEngine
init_str_old = """  Future<void> _initEngine() async {
    await _audioEngine.initialize();
    _audioEngine.setInstrumentalVolume(_musicVolume);
    _audioEngine.setVocalVolume(_vocalVolume);
    
    // Download/Cache audio file locally
    final String resolvedUrl = AppConfig.resolveMediaUrl(widget.song.audioUrl);
    final String localPath = await AudioCacheManager.getCachedAudioPath(resolvedUrl);
    
    await _audioEngine.loadInstrumental(localPath);
    _audioEngine.setMonitoringEnabled(_monitoringEnabled);
    if (mounted) {
      setState(() {
        _isInstrumentalLoaded = true;
      });
    }"""

init_str_new = """  Future<void> _initEngine() async {
    try {
      await _audioEngine.initialize();
      _audioEngine.setInstrumentalVolume(_musicVolume);
      _audioEngine.setVocalVolume(_vocalVolume);
      
      if (widget.song.audioUrl.isEmpty) {
        throw Exception("Audio URL kosong, tidak dapat memutar musik instrumental.");
      }
      
      // Download/Cache audio file locally
      final String resolvedUrl = AppConfig.resolveMediaUrl(widget.song.audioUrl);
      final String localPath = await AudioCacheManager.getCachedAudioPath(resolvedUrl);
      
      await _audioEngine.loadInstrumental(localPath);
      _audioEngine.setMonitoringEnabled(_monitoringEnabled);
      if (mounted) {
        setState(() {
          _isInstrumentalLoaded = true;
        });
      }
    } catch (e) {
      print("Error initEngine: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Gagal memuat musik: $e",
              style: const TextStyle(fontSize: 12),
            ),
            backgroundColor: Colors.red[800],
          ),
        );
      }
    }"""

content = content.replace(init_str_old, init_str_new)

with open("client_flutter/lib/features/record/record_screen.dart", "w") as f:
    f.write(content)
