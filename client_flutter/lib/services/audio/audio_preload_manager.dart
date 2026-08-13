import 'dart:async';
import 'package:just_audio/just_audio.dart';
import '../../core/config/app_config.dart';
import '../../data/models/song.dart';
import 'audio_manager.dart';

class AudioPreloadManager {
  static const int maxCacheSize = 5;
  static final Map<String, AudioPlayer> _cache = {};
  static final List<String> _lru = [];
  static final Map<String, Future<void>> _loadingTasks = {};
  
  static String resolveUrl(String url) {
    return AppConfig.resolveMediaUrl(url);
  }

  static bool isCached(String id) => _cache.containsKey(id);

  static Future<void> preload(Song song) async {
    if (_cache.containsKey(song.id)) {
      _updateLru(song.id);
      return;
    }

    if (_loadingTasks.containsKey(song.id)) {
      _updateLru(song.id);
      try {
        await _loadingTasks[song.id];
      } catch (_) {}
      return;
    }

    _evictCacheIfNeeded();

    final player = AudioPlayer();
    _cache[song.id] = player;
    _lru.add(song.id);

    final completer = Completer<void>();
    _loadingTasks[song.id] = completer.future;

    try {
      final uri = Uri.parse(resolveUrl(song.audioUrl));
      await player.setAudioSource(AudioSource.uri(uri), preload: true);
      print('[AudioPreloadManager] Preloaded: ${song.title} (${song.id})');
      completer.complete();
    } catch (e) {
      print('[AudioPreloadManager] Failed to preload ${song.id}: $e');
      _remove(song.id);
      completer.completeError(e);
    } finally {
      _loadingTasks.remove(song.id);
    }
  }

  static Future<AudioPlayer> getAudio(Song song) async {
    if (_cache.containsKey(song.id)) {
      _updateLru(song.id);
      print('[AudioPreloadManager] Cache HIT: ${song.title} (${song.id})');
      if (_loadingTasks.containsKey(song.id)) {
         try {
           await _loadingTasks[song.id];
         } catch (_) {}
      }
      return _cache[song.id]!;
    }

    print('[AudioPreloadManager] Cache MISS: ${song.title} (${song.id})');
    await preload(song);
    return _cache[song.id]!;
  }

  static void _evictCacheIfNeeded() {
    while (_cache.length >= maxCacheSize) {
      String? idToEvict;
      for (final id in _lru) {
        if (AudioManager().currentSongId != id) {
          idToEvict = id;
          break;
        }
      }

      if (idToEvict != null) {
        _remove(idToEvict);
      } else {
        break; // All cached are playing, cannot evict
      }
    }
  }

  static Future<void> _remove(String id) async {
    final player = _cache.remove(id);
    if (player != null) {
      await player.stop();
      await player.dispose();
      print('[AudioPreloadManager] Removed from cache: $id');
    }
    _lru.remove(id);
  }

  static Future<void> clear() async {
    for (final player in _cache.values) {
      await player.stop();
      await player.dispose();
    }
    _cache.clear();
    _lru.clear();
    _loadingTasks.clear();
    print('[AudioPreloadManager] Cache cleared');
  }

  static void _updateLru(String id) {
    _lru.remove(id);
    _lru.add(id);
  }
}
