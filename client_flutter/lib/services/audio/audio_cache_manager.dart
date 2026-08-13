import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../core/config/app_config.dart';

class AudioCacheManager {
  static Future<String> getCachedAudioPath(String url) async {
    if (url.startsWith('/data/') || url.startsWith('/var/') || url.startsWith('/Users/') || url.startsWith('/storage/emulated/') || url.startsWith('file://')) {
      return url; // Already a local path
    }

    final resolvedUrl = AppConfig.resolveMediaUrl(url);
    if (resolvedUrl.isEmpty) return url;

    final directory = await getTemporaryDirectory();
    final bytes = utf8.encode(resolvedUrl);
    final base64String = base64Url.encode(bytes).replaceAll('=', '');
    final ext = resolvedUrl.split('.').last.split('?').first;
    final safeExt = (ext.isNotEmpty && ext.length <= 4) ? ext : 'mp3';
    final fileName = '$base64String.$safeExt';
    final file = File('${directory.path}/$fileName');

    if (await file.exists()) {
      print('[AudioCacheManager] HIT cache: $fileName');
      return file.path;
    }

    print('[AudioCacheManager] MISS cache: Downloading $resolvedUrl...');
    try {
      final response = await http.get(Uri.parse(resolvedUrl));
      if (response.statusCode == 200) {
        final contentType = response.headers['content-type']?.toLowerCase() ?? '';
        if (contentType.contains('text/html')) {
          print('[AudioCacheManager] Warning: Server returned HTML instead of audio file.');
          return resolvedUrl;
        }
        
        await file.writeAsBytes(response.bodyBytes);
        final size = await file.length();
        print('[AudioCacheManager] Successfully downloaded and cached to $fileName (Size: $size bytes)');
        if (size == 0) {
           return resolvedUrl;
        }
        return file.path;
      } else {
        print('[AudioCacheManager] Failed to download: ${response.statusCode}');
        return resolvedUrl;
      }
    } catch (e) {
      print('[AudioCacheManager] Error downloading: $e');
      return resolvedUrl;
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
}
