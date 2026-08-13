import 'dart:math' as math;

class PitchResult {
  final double frequency;
  final double midiNote;
  final String noteName;
  final double centsError;
  final double targetMidi;
  final bool isNoteHit;
  final double confidence;

  const PitchResult({
    required this.frequency,
    required this.midiNote,
    required this.noteName,
    required this.centsError,
    required this.targetMidi,
    required this.isNoteHit,
    this.confidence = 1.0,
  });
}

class PitchDetector {
  static const List<String> noteNames = [
    'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'
  ];

  /// Convert frequency in Hz to fractional MIDI note number
  /// Standard tuning: A4 = 440Hz = MIDI 69
  static double frequencyToMidi(double hz) {
    if (hz <= 10.0) return 0.0;
    return 69.0 + 12.0 * (math.log(hz / 440.0) / math.ln2);
  }

  /// Convert MIDI note number to frequency in Hz
  static double midiToFrequency(double midi) {
    if (midi <= 0.0) return 0.0;
    return 440.0 * math.pow(2.0, (midi - 69.0) / 12.0);
  }

  /// Convert MIDI note number to human-readable note name (e.g., 69 -> A4, 60 -> C4)
  static String midiToNoteName(double midi) {
    if (midi <= 0.0) return '-';
    final roundedMidi = midi.round();
    final noteIndex = (roundedMidi % 12 + 12) % 12;
    final octave = (roundedMidi ~/ 12) - 1;
    return '${noteNames[noteIndex]}$octave';
  }

  /// Calculate cents error between user frequency and target frequency
  /// 1 semitone = 100 cents
  static double getCentsError(double userHz, double targetHz) {
    if (userHz <= 10.0 || targetHz <= 10.0) return 0.0;
    return 1200.0 * (math.log(userHz / targetHz) / math.ln2);
  }

  /// Process live frequency input against target MIDI note
  static PitchResult processLivePitch({
    required double userFrequencyHz,
    required double targetMidiNote,
    double toleranceCents = 50.0,
    double confidence = 1.0,
  }) {
    if (userFrequencyHz <= 10.0) {
      return PitchResult(
        frequency: 0.0,
        midiNote: 0.0,
        noteName: '-',
        centsError: 0.0,
        targetMidi: targetMidiNote,
        isNoteHit: false,
        confidence: 0.0,
      );
    }

    final userMidi = frequencyToMidi(userFrequencyHz);
    final userNoteName = midiToNoteName(userMidi);
    final targetHz = midiToFrequency(targetMidiNote);
    
    double centsError = 0.0;
    bool isHit = false;

    if (targetMidiNote > 0 && targetHz > 0) {
      centsError = getCentsError(userFrequencyHz, targetHz);
      isHit = centsError.abs() <= toleranceCents;
    } else {
      isHit = true; // No target specified
    }

    return PitchResult(
      frequency: userFrequencyHz,
      midiNote: userMidi,
      noteName: userNoteName,
      centsError: centsError,
      targetMidi: targetMidiNote,
      isNoteHit: isHit,
      confidence: confidence,
    );
  }
}
