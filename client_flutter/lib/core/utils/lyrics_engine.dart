import '../../data/models/song.dart';

class LyricsEngine {
  static int findActiveLyricIndex(double timeSec, List<LyricLine> lyrics) {
    if (lyrics.isEmpty) return -1;
    if (timeSec < lyrics.first.time) return -1;
    if (timeSec >= lyrics.last.time) return lyrics.length - 1;

    int low = 0;
    int high = lyrics.length - 1;

    while (low <= high) {
      int mid = low + ((high - low) >> 1);
      if (lyrics[mid].time <= timeSec) {
        if (mid == lyrics.length - 1 || lyrics[mid + 1].time > timeSec) {
          return mid;
        } else {
          low = mid + 1;
        }
      } else {
        high = mid - 1;
      }
    }
    return -1;
  }
}
