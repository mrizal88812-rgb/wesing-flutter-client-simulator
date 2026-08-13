class PitchNoteBar {
  final double startTime;
  final double endTime;
  final double midiNote;
  final String text;

  const PitchNoteBar({
    required this.startTime,
    required this.endTime,
    required this.midiNote,
    this.text = '',
  });

  /// Generate sample pitch guide bars from lyric lines if explicit melody pitch track is not provided
  static List<PitchNoteBar> generateFromLyrics(List dynamicLyrics) {
    if (dynamicLyrics.isEmpty) return [];
    
    final List<PitchNoteBar> bars = [];
    // Base pitch pattern for songs (pentatonic scale around C4-G4)
    final baseMidis = [60.0, 62.0, 64.0, 65.0, 67.0, 69.0, 71.0, 72.0, 67.0, 65.0, 64.0, 62.0];

    for (int i = 0; i < dynamicLyrics.length; i++) {
      final line = dynamicLyrics[i];
      final double start = (line.time as num).toDouble();
      final double end = (i < dynamicLyrics.length - 1)
          ? (dynamicLyrics[i + 1].time as num).toDouble()
          : (start + 3.5);
      
      final String text = line.text ?? '';
      final words = text.split(' ').where((w) => w.isNotEmpty).toList();
      
      if (words.isNotEmpty) {
        final double noteDuration = (end - start) / words.length;
        for (int w = 0; w < words.length; w++) {
          final double wStart = start + (w * noteDuration);
          final double wEnd = wStart + (noteDuration * 0.85); // 15% gap between notes
          final double midi = baseMidis[(i * 3 + w) % baseMidis.length];
          bars.add(PitchNoteBar(
            startTime: wStart,
            endTime: wEnd,
            midiNote: midi,
            text: words[w],
          ));
        }
      } else {
        bars.add(PitchNoteBar(
          startTime: start,
          endTime: end * 0.9,
          midiNote: 65.0, // F4 default
          text: text,
        ));
      }
    }
    return bars;
  }
}

class PitchTrailPoint {
  final double timestampSec;
  final double userMidi;
  final double targetMidi;
  final bool isHit;
  final double centsError;

  const PitchTrailPoint({
    required this.timestampSec,
    required this.userMidi,
    required this.targetMidi,
    required this.isHit,
    required this.centsError,
  });
}
