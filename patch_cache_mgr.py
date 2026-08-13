import re

with open("client_flutter/lib/services/audio/audio_cache_manager.dart", "r") as f:
    content = f.read()

new_method = """    } catch (e) {
      print('[AudioCacheManager] Error downloading: $e');
      return url; // Fallback to URL
    }
  }

  static Future<void> removeCache(String url) async {
    try {
      final directory = await getTemporaryDirectory();
      final bytes = utf8.encode(url);
      final base64String = base64Url.encode(bytes).replaceAll('=', '');
      final ext = url.split('.').last.split('?').first;
      final safeExt = (ext.isNotEmpty && ext.length <= 4) ? ext : 'mp3';
      final fileName = '$base64String.$safeExt';
      final file = File('${directory.path}/$fileName');
      if (await file.exists()) {
        await file.delete();
        print('[AudioCacheManager] Deleted corrupted cache: $fileName');
      }
    } catch (e) {
      print('[AudioCacheManager] Error removing cache: $e');
    }
  }
}"""

content = content.replace("    } catch (e) {\n      print('[AudioCacheManager] Error downloading: $e');\n      return url; // Fallback to URL\n    }\n  }\n}", new_method)

with open("client_flutter/lib/services/audio/audio_cache_manager.dart", "w") as f:
    f.write(content)
