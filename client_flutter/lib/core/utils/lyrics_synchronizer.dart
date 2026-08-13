import '../../data/models/song.dart';

class LyricSyncInfo {
  final int activeIndex;
  final double lineProgress; // 0.0 to 1.0 within current line duration
  final String activeText;
  final String nextText;
  final double activeStartTime;
  final double activeEndTime;

  const LyricSyncInfo({
    required this.activeIndex,
    required this.lineProgress,
    required this.activeText,
    required this.nextText,
    required this.activeStartTime,
    required this.activeEndTime,
  });
}

class LyricsSynchronizer {
  /// Find active lyric line index and calculate line progress percentage (0.0 - 1.0)
  static LyricSyncInfo synchronize({
    required double timeSec,
    required List<LyricLine> lyrics,
    double defaultLineDuration = 4.0,
  }) {
    if (lyrics.isEmpty) {
      return const LyricSyncInfo(
        activeIndex: -1,
        lineProgress: 0.0,
        activeText: '',
        nextText: '',
        activeStartTime: 0.0,
        activeEndTime: 0.0,
      );
    }

    if (timeSec < lyrics.first.time) {
      return LyricSyncInfo(
        activeIndex: -1,
        lineProgress: 0.0,
        activeText: '...',
        nextText: lyrics.first.text,
        activeStartTime: 0.0,
        activeEndTime: lyrics.first.time,
      );
    }

    int activeIndex = -1;
    for (int i = 0; i < lyrics.length; i++) {
      final startTime = lyrics[i].time;
      final nextStartTime = (i < lyrics.length - 1) ? lyrics[i + 1].time : (startTime + defaultLineDuration);
      
      if (timeSec >= startTime && timeSec < nextStartTime) {
        activeIndex = i;
        final itemEndTime = lyrics[i].endTime ?? nextStartTime;
        final lineDuration = (itemEndTime - startTime).clamp(0.05, 60.0);
        final elapsed = (timeSec - startTime).clamp(0.0, lineDuration);
        final lineProgress = (elapsed / lineDuration).clamp(0.0, 1.0);
        
        final nextText = (i < lyrics.length - 1) ? lyrics[i + 1].text : '';

        return LyricSyncInfo(
          activeIndex: activeIndex,
          lineProgress: lineProgress,
          activeText: lyrics[i].text,
          nextText: nextText,
          activeStartTime: startTime,
          activeEndTime: itemEndTime,
        );
      }
    }

    // Past last line
    final lastIndex = lyrics.length - 1;
    final lastStartTime = lyrics[lastIndex].time;
    return LyricSyncInfo(
      activeIndex: lastIndex,
      lineProgress: 1.0,
      activeText: lyrics[lastIndex].text,
      nextText: '',
      activeStartTime: lastStartTime,
      activeEndTime: lastStartTime + defaultLineDuration,
    );
  }
}
