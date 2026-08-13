import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../data/models/recording.dart';
import '../../data/repositories_impl.dart';
import '../../services/audio/audio_manager.dart';
import '../../services/audio/audio_preload_manager.dart';
import 'package:just_audio/just_audio.dart';

class FeedScreen extends StatefulWidget {
  @override
  _FeedScreenState createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final ApiRepository api = ApiRepository();
  List<Recording> feed = [];
  bool isLoading = true;
  String? playingId;
  StreamSubscription? _stateSub;
  final Set<String> _likedIds = {};

  @override
  void initState() {
    super.initState();
    _loadFeed();
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    super.dispose();
  }

  Future<void> _loadFeed() async {
    setState(() => isLoading = true);
    try {
      final data = await api.fetchFeed();
      setState(() {
        feed = data;
        isLoading = false;
      });
    } catch (e) {
      print('Error fetching feed: $e');
      setState(() => isLoading = false);
    }
  }

  Future<void> _togglePlay(Recording item) async {
    String? audioUrl = item.audioUrl ?? item.song?.audioUrl;
    if (audioUrl == null || audioUrl.isEmpty) return;

    if (audioUrl.startsWith('/sdcard/') || audioUrl.startsWith('/data/') || audioUrl.startsWith('/var/') || audioUrl.startsWith('file:') || audioUrl.startsWith('blob:')) {
      audioUrl = item.song?.audioUrl;
    }
    if (audioUrl == null || audioUrl.isEmpty) return;

    if (playingId == item.id) {
      await AudioManager().currentPlayer?.pause();
      setState(() => playingId = null);
    } else {
      setState(() => playingId = item.id);
      
      await AudioManager().playUrl(item.id, audioUrl);
      
      _stateSub?.cancel();
      _stateSub = AudioManager().currentPlayer?.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          if (mounted) setState(() => playingId = null);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.red[600],
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(Icons.music_note, color: Colors.white, size: 16),
            ),
            SizedBox(width: 8),
            Text(
              'WeSing MVP',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.grey[400], size: 20),
            onPressed: _loadFeed,
          ),
        ],
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
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
          : feed.isEmpty 
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.mic, color: Colors.grey[800], size: 48),
                      SizedBox(height: 12),
                      Text(
                        "Belum ada rekaman yang diposting.\nMulai bernyanyi di menu Discover!",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[500], fontSize: 13, height: 1.4),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: feed.length,
                  itemBuilder: (context, index) {
                    final item = feed[index];
                    final isPlaying = playingId == item.id;
                    return _buildFeedItem(item, isPlaying);
                  },
                ),
    );
  }

  Widget _buildFeedItem(Recording item, bool isPlaying) {
    final cover = item.song?.coverUrl ?? '';
    final hasLiked = _likedIds.contains(item.id);

    return Container(
      padding: EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border(bottom: BorderSide(color: Color(0xFF222222), width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile Info Row
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Color(0xFF222222), width: 1),
                ),
                child: CircleAvatar(
                  radius: 20,
                  backgroundImage: CachedNetworkImageProvider(item.user?.avatar ?? ''),
                  backgroundColor: Colors.grey[800],
                ),
              ),
              SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.user?.username ?? 'Pengguna',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Level ${item.user?.level ?? 1} Artist',
                    style: TextStyle(
                      color: Color(0xFF888888),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 12),
          // 1:1 Aspect Ratio Cover Card
          GestureDetector(
            onTap: () => _togglePlay(item),
            child: AspectRatio(
              aspectRatio: 1.0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    cover.isNotEmpty 
                        ? CachedNetworkImage(
                            imageUrl: AudioPreloadManager.resolveUrl(cover),
                            fit: BoxFit.cover,
                            memCacheWidth: 600,
                            color: Colors.black.withOpacity(0.4),
                            colorBlendMode: BlendMode.darken,
                            placeholder: (context, url) => Container(color: Color(0xFF111111)),
                            errorWidget: (context, url, error) => Container(color: Color(0xFF111111)),
                          )
                        : Container(color: Color(0xFF111111)),
                    // Center translucent play button
                    Center(
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.3),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isPlaying ? Icons.pause : Icons.play_arrow,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    ),
                    // Bottom Left song details
                    Positioned(
                      bottom: 16,
                      left: 16,
                      right: 16,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.song?.title ?? '',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              shadows: [
                                Shadow(
                                  blurRadius: 4.0,
                                  color: Colors.black.withOpacity(0.5),
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 4),
                          Text(
                            '${item.score} Score',
                            style: TextStyle(
                              color: Color(0xFFEF4444),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              shadows: [
                                Shadow(
                                  blurRadius: 4.0,
                                  color: Colors.black.withOpacity(0.5),
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(height: 16),
          // Interaction Bar
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  setState(() {
                    if (hasLiked) {
                      _likedIds.remove(item.id);
                    } else {
                      _likedIds.add(item.id);
                    }
                  });
                },
                child: Row(
                  children: [
                    Icon(
                      hasLiked ? Icons.favorite : Icons.favorite_border,
                      color: hasLiked ? Color(0xFFEF4444) : Colors.white,
                      size: 24,
                    ),
                    SizedBox(width: 8),
                    Text(
                      '${item.likesCount + (hasLiked ? 1 : 0)}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 24),
              Row(
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    color: Colors.white,
                    size: 24,
                  ),
                  SizedBox(width: 8),
                  Text(
                    '${item.commentsCount}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
