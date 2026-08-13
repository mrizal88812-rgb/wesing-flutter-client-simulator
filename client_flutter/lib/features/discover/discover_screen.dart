import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../data/models/song.dart';
import '../../data/repositories_impl.dart';
import '../../services/audio/audio_manager.dart';
import '../../services/audio/audio_preload_manager.dart';
import '../record/record_screen.dart';
import 'package:just_audio/just_audio.dart';

class DiscoverScreen extends StatefulWidget {
  @override
  _DiscoverScreenState createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final ApiRepository api = ApiRepository();
  List<Song> songs = [];
  bool isLoading = true;
  String? playingId;
  StreamSubscription? _stateSub;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadSongs();
  }
  
  @override
  void dispose() {
    _stateSub?.cancel();
    super.dispose();
  }

  Future<void> _loadSongs() async {
    setState(() => isLoading = true);
    try {
      final data = await api.fetchSongs();
      setState(() {
        songs = data;
        isLoading = false;
      });
      if (data.isNotEmpty) AudioPreloadManager.preload(data[0]);
      if (data.length > 1) AudioPreloadManager.preload(data[1]);
    } catch (e) {
      print('Error fetching songs: $e');
      setState(() => isLoading = false);
    }
  }

  Future<void> _togglePlay(Song song) async {
    if (playingId == song.id) {
      await AudioManager().currentPlayer?.pause();
      setState(() => playingId = null);
    } else {
      setState(() => playingId = song.id);
      await AudioManager().play(song);
      
      _stateSub?.cancel();
      _stateSub = AudioManager().currentPlayer?.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          if (mounted) setState(() => playingId = null);
        }
      });
      
      final index = songs.indexWhere((s) => s.id == song.id);
      if (index != -1 && index + 1 < songs.length) {
        AudioPreloadManager.preload(songs[index + 1]);
      }
    }
  }

  @override
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          'Discover',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.grey[400], size: 20),
            onPressed: _loadSongs,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Container(
            color: Color(0xFF222222),
            height: 1,
          ),
        ),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator(color: Colors.red))
          : songs.isEmpty
              ? Center(
                  child: Text(
                    "No backing tracks found",
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.all(16),
                  itemCount: songs.length,
                  itemBuilder: (context, index) {
                    final song = songs[index];
                    final isPlaying = playingId == song.id;
                    return _buildSongItem(song, isPlaying);
                  },
                ),
    );
  }

  Widget _buildSongItem(Song song, bool isPlaying) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Color(0xFF111111),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Album Cover Artwork (50x50)
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: AudioPreloadManager.resolveUrl(song.coverUrl),
              width: 50,
              height: 50,
              memCacheWidth: 150,
              memCacheHeight: 150,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(color: Color(0xFF111111)),
              errorWidget: (context, url, error) => Container(
                color: Color(0xFF111111),
                child: Icon(Icons.music_note, color: Colors.grey[600], size: 20),
              ),
            ),
          ),
          SizedBox(width: 12),
          // Title & Artist
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  song.title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 4),
                Text(
                  song.artist,
                  style: TextStyle(
                    color: Color(0xFF888888),
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          SizedBox(width: 12),
          // Play/Pause Button (40x40 circle)
          GestureDetector(
            onTap: () => _togglePlay(song),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isPlaying ? Color(0xFFEF4444) : Color(0xFF333333),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          SizedBox(width: 8),
          // Sing Mic Button (40x40 circle)
          GestureDetector(
            onTap: () {
              AudioManager().currentPlayer?.stop();
              setState(() => playingId = null);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => RecordScreen(song: song)),
              );
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Color(0xFF3B82F6),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.mic,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
