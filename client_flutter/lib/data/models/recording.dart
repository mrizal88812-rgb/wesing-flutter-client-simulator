import 'user.dart';
import 'song.dart';

class Recording {
  final String id;
  final String userId;
  final String songId;
  final String? audioUrl;
  final String? coverUrl;
  final String? caption;
  final String visibility;
  final int score;
  final String createdAt;
  final User? user;
  final Song? song;
  final int likesCount;
  final int commentsCount;
  final double songStart;
  final double songEnd;
  final double duration;

  Recording({
    required this.id,
    required this.userId,
    required this.songId,
    this.audioUrl,
    this.coverUrl,
    this.caption,
    this.visibility = 'Public',
    required this.score,
    required this.createdAt,
    this.user,
    this.song,
    required this.likesCount,
    required this.commentsCount,
    this.songStart = 0.0,
    this.songEnd = 0.0,
    this.duration = 0.0,
  });

  factory Recording.fromJson(Map<String, dynamic> json) {
    return Recording(
      id: json['id'] as String,
      userId: json['userId'] as String,
      songId: json['songId'] as String,
      audioUrl: json['audioUrl'] as String?,
      coverUrl: json['coverUrl'] as String?,
      caption: json['caption'] as String?,
      visibility: json['visibility'] as String? ?? 'Public',
      score: json['score'] as int? ?? 0,
      createdAt: json['createdAt'] as String,
      user: json['user'] != null ? User.fromJson(json['user']) : null,
      song: json['song'] != null ? Song.fromJson(json['song']) : null,
      likesCount: json['likesCount'] as int? ?? 0,
      commentsCount: json['commentsCount'] as int? ?? 0,
      songStart: (json['songStart'] ?? json['song_start'] ?? 0.0).toDouble(),
      songEnd: (json['songEnd'] ?? json['song_end'] ?? 0.0).toDouble(),
      duration: (json['duration'] ?? 0.0).toDouble(),
    );
  }
}
