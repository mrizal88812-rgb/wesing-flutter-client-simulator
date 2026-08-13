import re

with open("client_flutter/lib/services/audio/audio_cache_manager.dart", "r") as f:
    content = f.read()

old_code = """        await file.writeAsBytes(response.bodyBytes);
        print('[AudioCacheManager] Successfully downloaded and cached to $fileName');
        return file.path;"""

new_code = """        await file.writeAsBytes(response.bodyBytes);
        final size = await file.length();
        print('[AudioCacheManager] Successfully downloaded and cached to $fileName (Size: $size bytes)');
        if (size == 0) {
           throw Exception("File lagu yang diunduh berukuran 0 bytes (Kosong).");
        }
        return file.path;"""

content = content.replace(old_code, new_code)

with open("client_flutter/lib/services/audio/audio_cache_manager.dart", "w") as f:
    f.write(content)
