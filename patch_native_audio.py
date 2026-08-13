import re

with open("client_flutter/lib/services/audio/native_audio_engine.dart", "r") as f:
    content = f.read()

old_code = """  @override
  Future<void> loadInstrumental(String url) async {
    final String resolvedUrl = AppConfig.resolveMediaUrl(url);
    await _channel.invokeMethod('loadInstrumental', {'url': resolvedUrl});
  }"""

new_code = """  @override
  Future<void> loadInstrumental(String url) async {
    // Check if it's a local file path
    final String resolvedUrl = (url.startsWith('/') || url.startsWith('file://')) 
        ? url 
        : AppConfig.resolveMediaUrl(url);
    await _channel.invokeMethod('loadInstrumental', {'url': resolvedUrl});
  }"""

content = content.replace(old_code, new_code)

with open("client_flutter/lib/services/audio/native_audio_engine.dart", "w") as f:
    f.write(content)
