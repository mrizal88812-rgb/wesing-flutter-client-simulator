import re

with open("client_flutter/lib/services/audio/audio_cache_manager.dart", "r") as f:
    content = f.read()

old_code = """      if (response.statusCode == 200) {
        await file.writeAsBytes(response.bodyBytes);
        print('[AudioCacheManager] Successfully downloaded and cached to $fileName');
        return file.path;
      }"""

new_code = """      if (response.statusCode == 200) {
        final contentType = response.headers['content-type']?.toLowerCase() ?? '';
        if (contentType.contains('text/html')) {
          print('[AudioCacheManager] Warning: Server returned HTML instead of audio file.');
          throw Exception("URL lagu tidak valid (Server mengembalikan halaman HTML, bukan file MP3). Kemungkinan file lagu belum terunggah ke server / storage admin.");
        }
        
        await file.writeAsBytes(response.bodyBytes);
        print('[AudioCacheManager] Successfully downloaded and cached to $fileName');
        return file.path;
      }"""

content = content.replace(old_code, new_code)

with open("client_flutter/lib/services/audio/audio_cache_manager.dart", "w") as f:
    f.write(content)
