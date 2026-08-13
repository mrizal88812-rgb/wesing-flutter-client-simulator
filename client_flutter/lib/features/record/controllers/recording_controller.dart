import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../data/models/song.dart';
import '../../../data/models/pitch_data.dart';
import '../../../services/audio/karaoke_audio_engine.dart';
import '../../../core/pitch/pitch_detector.dart';
import '../../../core/scoring/scoring_engine.dart';
import '../../../core/utils/lyrics_synchronizer.dart';

class RecordingController {
  final Song song;
  late final KaraokeAudioEngine audioEngine;
  late final List<PitchNoteBar> guideNotes;
  
  final ScoringEngine scoringEngine = ScoringEngine();
  final List<PitchTrailPoint> userPitchHistory = [];

  StreamSubscription<Duration>? _positionSub;
  
  // ValueNotifiers for Flutter UI reactive updates
  final ValueNotifier<Duration> positionNotifier = ValueNotifier<Duration>(Duration.zero);
  final ValueNotifier<Duration> durationNotifier = ValueNotifier<Duration>(Duration.zero);
  final ValueNotifier<PitchResult> pitchResultNotifier = ValueNotifier<PitchResult>(
    const PitchResult(
      frequency: 0,
      midiNote: 0,
      noteName: '-',
      centsError: 0,
      targetMidi: 0,
      isNoteHit: false,
    ),
  );
  final ValueNotifier<ScoreBreakdown> scoreNotifier = ValueNotifier<ScoreBreakdown>(
    const ScoreBreakdown(
      pitchAccuracy: 75.0,
      timingAccuracy: 80.0,
      stability: 70.0,
      noteCompletion: 0.0,
      finalScore: 75.0,
      grade: ScoreGrade.A,
    ),
  );
  final ValueNotifier<LyricSyncInfo> lyricSyncNotifier = ValueNotifier<LyricSyncInfo>(
    const LyricSyncInfo(
      activeIndex: -1,
      lineProgress: 0.0,
      activeText: '',
      nextText: '',
      activeStartTime: 0.0,
      activeEndTime: 0.0,
    ),
  );
  final ValueNotifier<bool> isPlayingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isRecordingNotifier = ValueNotifier<bool>(false);

  RecordingController({required this.song}) {
    audioEngine = KaraokeAudioEngine.create();
    guideNotes = PitchNoteBar.generateFromLyrics(song.lyrics);
  }

  Future<void> initialize() async {
    await audioEngine.initialize();
    
    // Listen to real hardware / clock derived audio position
    _positionSub = audioEngine.onPositionChanged.listen((pos) {
      positionNotifier.value = pos;
      final totalDur = audioEngine.getDuration();
      durationNotifier.value = totalDur;

      final double timeSec = pos.inMilliseconds / 1000.0;
      final double totalSec = totalDur.inSeconds > 0 ? totalDur.inSeconds.toDouble() : 120.0;

      // 1. Sync Lyrics
      final lyricSync = LyricsSynchronizer.synchronize(
        timeSec: timeSec,
        lyrics: song.lyrics,
      );
      lyricSyncNotifier.value = lyricSync;

      // 2. Determine target pitch at current timestamp
      final targetBar = _findTargetNoteBarAt(timeSec);
      final double targetMidi = targetBar?.midiNote ?? 0.0;

      // 3. Query current live hardware pitch
      final double userPitchHz = audioEngine.getCurrentUserPitch();
      
      // Process pitch conversion & detection
      final pitchResult = PitchDetector.processLivePitch(
        userFrequencyHz: userPitchHz,
        targetMidiNote: targetMidi,
      );
      pitchResultNotifier.value = pitchResult;

      // 4. Record sample in Scoring Engine if actively recording/singing
      if (isRecordingNotifier.value && userPitchHz > 10.0) {
        scoringEngine.addSample(
          timeSec: timeSec,
          userMidi: pitchResult.midiNote,
          targetMidi: targetMidi,
          centsError: pitchResult.centsError,
          isVocalDetected: true,
        );

        userPitchHistory.add(PitchTrailPoint(
          timestampSec: timeSec,
          userMidi: pitchResult.midiNote,
          targetMidi: targetMidi,
          isHit: pitchResult.isNoteHit,
          centsError: pitchResult.centsError,
        ));

        // Keep history window manageable (last 300 points)
        if (userPitchHistory.length > 300) {
          userPitchHistory.removeAt(0);
        }
      }

      // Update real-time score calculation
      final progressRatio = (timeSec / totalSec).clamp(0.0, 1.0);
      scoreNotifier.value = scoringEngine.calculateScore(sessionProgress: progressRatio);
    });
  }

  PitchNoteBar? _findTargetNoteBarAt(double timeSec) {
    for (final note in guideNotes) {
      if (timeSec >= note.startTime && timeSec <= note.endTime) {
        return note;
      }
    }
    return null;
  }

  Future<void> startRecordingAndPlay() async {
    userPitchHistory.clear();
    scoringEngine.reset();
    isRecordingNotifier.value = true;
    isPlayingNotifier.value = true;
    await audioEngine.play();
    await audioEngine.startRecording();
  }

  Future<void> stopRecording() async {
    isRecordingNotifier.value = false;
    isPlayingNotifier.value = false;
    await audioEngine.stopRecording();
  }

  Future<void> play() async {
    isPlayingNotifier.value = true;
    await audioEngine.play();
  }

  Future<void> pause() async {
    isPlayingNotifier.value = false;
    await audioEngine.pause();
  }

  Future<void> seek(Duration position) async {
    await audioEngine.seek(position);
  }

  void dispose() {
    _positionSub?.cancel();
    positionNotifier.dispose();
    durationNotifier.dispose();
    pitchResultNotifier.dispose();
    scoreNotifier.dispose();
    lyricSyncNotifier.dispose();
    isPlayingNotifier.dispose();
    isRecordingNotifier.dispose();
    audioEngine.dispose();
  }
}
