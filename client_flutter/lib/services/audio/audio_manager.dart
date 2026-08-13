import 'dart:async';
import 'package:just_audio/just_audio.dart';
import '../../data/models/song.dart';
import 'audio_preload_manager.dart';

class AudioManager {
  static final AudioManager _instance = AudioManager._internal();
  factory AudioManager() => _instance;
  AudioManager._internal();

  String? currentSongId;
  AudioPlayer? currentPlayer;
  int _playRequestCounter = 0; // to handle race conditions

  Future<void> init() async {
    // Global initialization if needed, e.g., AudioSession
  }

  Future<void> play(Song song) async {
    final int requestId = ++_playRequestCounter;

    if (currentSongId == song.id && currentPlayer != null) {
      await currentPlayer!.play();
      return;
    }

    await stop();

    if (requestId != _playRequestCounter) return;

    currentSongId = song.id;
    final player = await AudioPreloadManager.getAudio(song);
    
    if (requestId != _playRequestCounter) {
      // Another request was made while we were waiting
      return;
    }

    currentPlayer = player;
    await currentPlayer!.seek(Duration.zero);
    await currentPlayer!.play();
  }

  Future<void> playUrl(String id, String url) async {
    final int requestId = ++_playRequestCounter;

    if (currentSongId == id && currentPlayer != null) {
      await currentPlayer!.play();
      return;
    }

    await stop();

    if (requestId != _playRequestCounter) return;

    currentSongId = id;
    final player = AudioPlayer();
    currentPlayer = player;
    
    try {
      final uri = Uri.parse(AudioPreloadManager.resolveUrl(url));
      await player.setAudioSource(AudioSource.uri(uri));
      if (requestId == _playRequestCounter) {
        await player.play();
      } else {
        await player.dispose();
      }
    } catch (e) {
      print('Error playing url: $e');
    }
  }

  Future<void> pause() async {
    if (currentPlayer != null) {
      await currentPlayer!.pause();
    }
  }

  Future<void> stop() async {
    _playRequestCounter++; // Invalidate any pending play requests
    if (currentPlayer != null) {
      await currentPlayer!.pause();
      
      if (currentSongId != null && !AudioPreloadManager.isCached(currentSongId!)) {
        await currentPlayer!.dispose();
      } else {
         await currentPlayer!.seek(Duration.zero);
      }
    }
    currentPlayer = null;
    currentSongId = null;
  }
}
