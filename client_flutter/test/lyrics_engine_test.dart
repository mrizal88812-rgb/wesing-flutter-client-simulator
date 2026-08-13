import 'package:flutter_test/flutter_test.dart';
import '../lib/core/utils/lyrics_engine.dart';
import '../lib/data/models/song.dart';

void main() {
  group('LyricsEngine Tests', () {
    final lyrics = [
      LyricLine(time: 0.0, text: 'Line 1'),
      LyricLine(time: 4.0, text: 'Line 2'),
      LyricLine(time: 8.5, text: 'Line 3'),
      LyricLine(time: 12.0, text: 'Line 4'),
    ];

    test('findActiveLyricIndex returns -1 before first lyric', () {
      expect(LyricsEngine.findActiveLyricIndex(-1.0, lyrics), -1);
    });

    test('findActiveLyricIndex returns correct index', () {
      expect(LyricsEngine.findActiveLyricIndex(0.0, lyrics), 0);
      expect(LyricsEngine.findActiveLyricIndex(2.0, lyrics), 0);
      expect(LyricsEngine.findActiveLyricIndex(4.0, lyrics), 1);
      expect(LyricsEngine.findActiveLyricIndex(7.0, lyrics), 1);
      expect(LyricsEngine.findActiveLyricIndex(8.5, lyrics), 2);
      expect(LyricsEngine.findActiveLyricIndex(10.0, lyrics), 2);
      expect(LyricsEngine.findActiveLyricIndex(12.0, lyrics), 3);
    });

    test('findActiveLyricIndex returns last index when time exceeds last lyric', () {
      expect(LyricsEngine.findActiveLyricIndex(20.0, lyrics), 3);
    });
  });
}
