import 'package:flutter_test/flutter_test.dart';
import '../lib/data/models/song.dart';

void main() {
  group('Song Model Tests', () {
    test('Song.fromJson parses correctly', () {
      final json = {
        'id': 'song_1',
        'title': 'Test Title',
        'artist': 'Test Artist',
        'coverUrl': '/covers/1.jpg',
        'audioUrl': '/audio/1.mp3',
        'playCount': 100,
        'tags': ['pop', 'rock'],
        'lyrics': [
          {'time': 0.0, 'text': 'Hello'},
          {'time': 5.0, 'text': 'World'},
        ],
      };

      final song = Song.fromJson(json);

      expect(song.id, 'song_1');
      expect(song.title, 'Test Title');
      expect(song.artist, 'Test Artist');
      expect(song.coverUrl, '/covers/1.jpg');
      expect(song.audioUrl, '/audio/1.mp3');
      expect(song.playCount, 100);
      expect(song.tags, ['pop', 'rock']);
      expect(song.lyrics.length, 2);
      expect(song.lyrics[0].time, 0.0);
      expect(song.lyrics[0].text, 'Hello');
      expect(song.lyrics[1].time, 5.0);
      expect(song.lyrics[1].text, 'World');
    });

    test('Song.fromJson handles empty or missing optional fields', () {
      final json = {
        'id': 'song_2',
        'title': 'Minimal Song',
        'artist': 'Unknown',
        'coverUrl': '',
        'audioUrl': '',
      };

      final song = Song.fromJson(json);

      expect(song.id, 'song_2');
      expect(song.playCount, 0);
      expect(song.tags, isEmpty);
      expect(song.lyrics, isEmpty);
    });
  });
}
