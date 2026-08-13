class LyricLine {
  final double time;
  final double? endTime;
  final String text;

  LyricLine({required this.time, this.endTime, required this.text});

  factory LyricLine.fromJson(Map<String, dynamic> json) {
    return LyricLine(
      time: (json['time'] as num).toDouble(),
      endTime: json['endTime'] != null ? (json['endTime'] as num).toDouble() : null,
      text: json['text'] as String,
    );
  }
}

class Song {
  final String id;
  final String title;
  final String artist;
  final String coverUrl;
  final String audioUrl;
  final int playCount;
  final List<String> tags;
  final List<LyricLine> lyrics;

  Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.coverUrl,
    required this.audioUrl,
    required this.playCount,
    required this.tags,
    required this.lyrics,
  });

  factory Song.fromJson(Map<String, dynamic> json) {
    var lyricsList = json['lyrics'] as List?;
    return Song(
      id: json['id'] as String,
      title: json['title'] as String,
      artist: json['artist'] as String,
      coverUrl: json['coverUrl'] as String,
      audioUrl: json['audioUrl'] as String,
      playCount: json['playCount'] as int? ?? 0,
      tags: (json['tags'] as List?)?.map((e) => e as String).toList() ?? [],
      lyrics: lyricsList?.map((e) => LyricLine.fromJson(e)).toList() ?? [],
    );
  }
}
