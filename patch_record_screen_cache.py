import re

with open("client_flutter/lib/features/record/record_screen.dart", "r") as f:
    content = f.read()

import_str = "import '../../services/audio/karaoke_audio_engine.dart';\nimport '../../services/audio/audio_cache_manager.dart';"
content = content.replace("import '../../services/audio/karaoke_audio_engine.dart';", import_str)

init_str = """  Future<void> _initEngine() async {
    await _audioEngine.initialize();
    _audioEngine.setInstrumentalVolume(_musicVolume);
    _audioEngine.setVocalVolume(_vocalVolume);
    
    // Download/Cache audio file locally
    final String resolvedUrl = AppConfig.resolveMediaUrl(widget.song.audioUrl);
    final String localPath = await AudioCacheManager.getCachedAudioPath(resolvedUrl);
    
    await _audioEngine.loadInstrumental(localPath);
    _audioEngine.setMonitoringEnabled(_monitoringEnabled);"""

content = re.sub(r'  Future<void> _initEngine\(\) async \{\n    await _audioEngine\.initialize\(\);\n    _audioEngine\.setInstrumentalVolume\(_musicVolume\);\n    _audioEngine\.setVocalVolume\(_vocalVolume\);\n    await _audioEngine\.loadInstrumental\(AppConfig\.resolveMediaUrl\(widget\.song\.audioUrl\)\);\n    _audioEngine\.setMonitoringEnabled\(_monitoringEnabled\);', init_str, content)

with open("client_flutter/lib/features/record/record_screen.dart", "w") as f:
    f.write(content)
