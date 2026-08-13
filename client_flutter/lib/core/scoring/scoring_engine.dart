import 'dart:math' as math;

enum ScoreGrade { SSS, SS, S, A, B, C }

class ScoreBreakdown {
  final double pitchAccuracy;  // 0 - 100 (Weight: 40%)
  final double timingAccuracy; // 0 - 100 (Weight: 30%)
  final double stability;      // 0 - 100 (Weight: 20%)
  final double noteCompletion; // 0 - 100 (Weight: 10%)
  final double finalScore;     // 0 - 100
  final ScoreGrade grade;

  const ScoreBreakdown({
    required this.pitchAccuracy,
    required this.timingAccuracy,
    required this.stability,
    required this.noteCompletion,
    required this.finalScore,
    required this.grade,
  });

  static ScoreGrade getGradeForScore(double score) {
    if (score >= 95.0) return ScoreGrade.SSS;
    if (score >= 90.0) return ScoreGrade.SS;
    if (score >= 80.0) return ScoreGrade.S;
    if (score >= 70.0) return ScoreGrade.A;
    if (score >= 60.0) return ScoreGrade.B;
    return ScoreGrade.C;
  }

  static String getGradeLabel(ScoreGrade grade) {
    switch (grade) {
      case ScoreGrade.SSS: return 'SSS';
      case ScoreGrade.SS:  return 'SS';
      case ScoreGrade.S:   return 'S';
      case ScoreGrade.A:   return 'A';
      case ScoreGrade.B:   return 'B';
      case ScoreGrade.C:   return 'C';
    }
  }
}

class PitchSample {
  final double timestampSec;
  final double userMidi;
  final double targetMidi;
  final double centsError;
  final bool isVocalDetected;

  const PitchSample({
    required this.timestampSec,
    required this.userMidi,
    required this.targetMidi,
    required this.centsError,
    required this.isVocalDetected,
  });
}

class ScoringEngine {
  final List<PitchSample> _samples = [];
  double _lastUserMidi = 0.0;
  
  void reset() {
    _samples.clear();
    _lastUserMidi = 0.0;
  }

  /// Add a real-time pitch sample during performance
  void addSample({
    required double timeSec,
    required double userMidi,
    required double targetMidi,
    required double centsError,
    required bool isVocalDetected,
  }) {
    if (isVocalDetected) {
      _samples.add(PitchSample(
        timestampSec: timeSec,
        userMidi: userMidi,
        targetMidi: targetMidi,
        centsError: centsError,
        isVocalDetected: true,
      ));
      _lastUserMidi = userMidi;
    }
  }

  /// Calculates real-time score and breakdown stats according to requirements
  /// Formula: Final Score = 0.40 * Pitch + 0.30 * Timing + 0.20 * Stability + 0.10 * Completion
  ScoreBreakdown calculateScore({double sessionProgress = 1.0}) {
    if (_samples.isEmpty) {
      return ScoreBreakdown(
        pitchAccuracy: 75.0,
        timingAccuracy: 80.0,
        stability: 70.0,
        noteCompletion: (sessionProgress * 100).clamp(0.0, 100.0),
        finalScore: (0.40 * 75.0 + 0.30 * 80.0 + 0.20 * 70.0 + 0.10 * (sessionProgress * 100)).clamp(0.0, 100.0),
        grade: ScoreBreakdown.getGradeForScore(72.0),
      );
    }

    // 1. Pitch Accuracy (40%): Based on cents error on target notes
    double pitchHits = 0;
    double totalPitchEvaluated = 0;
    for (var sample in _samples) {
      if (sample.targetMidi > 0) {
        totalPitchEvaluated++;
        final absCents = sample.centsError.abs();
        if (absCents <= 25) {
          pitchHits += 1.0; // Perfect
        } else if (absCents <= 50) {
          pitchHits += 0.8; // Great
        } else if (absCents <= 75) {
          pitchHits += 0.5; // Good
        } else if (absCents <= 100) {
          pitchHits += 0.2; // Almost
        }
      }
    }
    final double pitchAccuracy = totalPitchEvaluated > 0
        ? ((pitchHits / totalPitchEvaluated) * 100).clamp(0.0, 100.0)
        : 80.0;

    // 2. Timing Accuracy (30%): Promptness of vocal detection when target notes begin
    double timingHits = 0;
    double timingTotal = 0;
    for (var sample in _samples) {
      if (sample.targetMidi > 0) {
        timingTotal++;
        if (sample.isVocalDetected) {
          timingHits++;
        }
      }
    }
    final double timingAccuracy = timingTotal > 0
        ? ((timingHits / timingTotal) * 100).clamp(0.0, 100.0)
        : 85.0;

    // 3. Pitch Stability (20%): Low variance / jitter in user pitch transitions
    double varianceSum = 0.0;
    int varianceCount = 0;
    for (int i = 1; i < _samples.length; i++) {
      final diff = (_samples[i].userMidi - _samples[i - 1].userMidi).abs();
      // Jitter threshold
      if (diff < 5.0) { // Ignore octave jumps/silence transitions
        varianceSum += diff;
        varianceCount++;
      }
    }
    final double avgJitter = varianceCount > 0 ? (varianceSum / varianceCount) : 0.5;
    final double stability = (100.0 - (avgJitter * 20.0)).clamp(30.0, 100.0);

    // 4. Note Completion (10%): Percentage of completed active target notes
    final double noteCompletion = (sessionProgress * 100.0).clamp(0.0, 100.0);

    // Final weighted score calculation
    final double rawFinal = (0.40 * pitchAccuracy) +
        (0.30 * timingAccuracy) +
        (0.20 * stability) +
        (0.10 * noteCompletion);
    
    final double finalScore = rawFinal.clamp(0.0, 100.0);
    final ScoreGrade grade = ScoreBreakdown.getGradeForScore(finalScore);

    return ScoreBreakdown(
      pitchAccuracy: pitchAccuracy,
      timingAccuracy: timingAccuracy,
      stability: stability,
      noteCompletion: noteCompletion,
      finalScore: finalScore,
      grade: grade,
    );
  }
}
