import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/config/app_config.dart';
import '../../data/models/song.dart';
import '../../data/models/pitch_data.dart';
import '../../services/audio/karaoke_audio_engine.dart';
import '../../services/audio/audio_cache_manager.dart';
import '../../core/utils/lyrics_engine.dart';
import '../../core/pitch/pitch_detector.dart';
import '../../core/scoring/scoring_engine.dart';
import '../../core/utils/lyrics_synchronizer.dart';
import '../../main.dart';
import 'components/pitch_guide_renderer.dart';
import 'components/pitch_overlay_renderer.dart';
import 'edit_recording_screen.dart';

class RecordScreen extends StatefulWidget {
  final Song song;
  const RecordScreen({Key? key, required this.song}) : super(key: key);

  @override
  _RecordScreenState createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final KaraokeAudioEngine _audioEngine;
  Timer? _uiTimer;
  StreamSubscription<Duration>? _positionSubscription;

  late final List<PitchNoteBar> _guideNotes;
  final ScoringEngine _scoringEngine = ScoringEngine();
  final List<PitchTrailPoint> _userPitchTrail = [];
  ScoreBreakdown _scoreBreakdown = const ScoreBreakdown(
    pitchAccuracy: 80.0,
    timingAccuracy: 85.0,
    stability: 80.0,
    noteCompletion: 0.0,
    finalScore: 82.0,
    grade: ScoreGrade.S,
  );
  PitchResult _currentPitchResult = const PitchResult(
    frequency: 0,
    midiNote: 0,
    noteName: '-',
    centsError: 0,
    targetMidi: 0,
    isNoteHit: false,
  );
  LyricSyncInfo _lyricSyncInfo = const LyricSyncInfo(
    activeIndex: -1,
    lineProgress: 0.0,
    activeText: '',
    nextText: '',
    activeStartTime: 0.0,
    activeEndTime: 0.0,
  );

  final ValueNotifier<int> activeLyricIndexNotifier = ValueNotifier<int>(-1);
  final ValueNotifier<double> activeLyricProgressNotifier = ValueNotifier<double>(0.0);
  final ValueNotifier<Duration> currentTimeNotifier = ValueNotifier<Duration>(Duration.zero);
  final ValueNotifier<Duration> durationNotifier = ValueNotifier<Duration>(Duration.zero);
  final ValueNotifier<bool> isPlayingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isRecordingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<int> scoreNotifier = ValueNotifier<int>(0);
  final ScrollController _scrollController = ScrollController();
  static const double lyricItemHeight = 64.0;

  bool _isDraggingSlider = false;
  bool _isUserScrollingLyrics = false;
  bool _wasPlayingBeforeScroll = false;
  Timer? _lyricsScrollDebounce;
  int _lastScrolledLyricIndex = -1;
  double _lastUiUpdateSec = 0.0;

  // "Bersiap-siap" countdown shown right before recording/lyrics actually
  // start, so the singer has a moment to get ready.
  static const int kGetReadyCountdownSeconds = 3;
  bool _isCountingDown = false;
  int _countdownValue = kGetReadyCountdownSeconds;

  Duration _recordedDuration = Duration.zero;
  double _recordingSongStart = 0.0;
  double _recordingSongEnd = 0.0;

  // Karaoke engine UI & state parameters
  bool _isEarphoneConnected = true;
  double _vocalVolume = 1.0;
  double _musicVolume = 0.85;
  int _latencyOffset = 45;
  bool _monitoringEnabled = false;
  AutoTuneMode _autoTuneMode = AutoTuneMode.off;
  double _reverbMix = 0.2;
  bool _reverbEnabled = false;

  bool _isNavigatingToMix = false;
  bool _recordingSaved = false;
  bool _isSaving = false;
  bool _isInstrumentalLoaded = false;


  // Vinyl animation controller
  late AnimationController _vinylAnimationController;
  late final Ticker _smoothTicker;
  final ValueNotifier<double> smoothTimeSecNotifier = ValueNotifier<double>(0.0);
  double _lastEngineTimeSec = 0.0;
  DateTime? _lastEngineTimeReceivedAt;

  double _responsiveFontSize(BuildContext context, double baseFontSize) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double scaleFactor = (screenWidth / 375.0).clamp(1.0, 1.35);
    return baseFontSize * scaleFactor;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _vinylAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    );

    _smoothTicker = Ticker((elapsed) {
      if (!mounted) return;
      if (isPlayingNotifier.value && _lastEngineTimeReceivedAt != null) {
        final double elapsedSinceLast = DateTime.now().difference(_lastEngineTimeReceivedAt!).inMicroseconds / 1000000.0;
        final double estimatedTime = _lastEngineTimeSec + elapsedSinceLast;
        smoothTimeSecNotifier.value = estimatedTime;
      }
    });
    _smoothTicker.start();

    _guideNotes = PitchNoteBar.generateFromLyrics(widget.song.lyrics);
    _guideNotes.sort((a, b) => a.startTime.compareTo(b.startTime));
    _audioEngine = KaraokeAudioEngine.create();
    _initEngine();
  }

  PitchNoteBar? _findActiveNoteBar(double timeSec) {
    if (_guideNotes.isEmpty) return null;
    int low = 0;
    int high = _guideNotes.length - 1;
    while (low <= high) {
      final mid = (low + high) >> 1;
      final note = _guideNotes[mid];
      if (timeSec < note.startTime) {
        high = mid - 1;
      } else if (timeSec > note.endTime) {
        low = mid + 1;
      } else {
        return note;
      }
    }
    return null;
  }

  Future<void> _initEngine() async {
    try {
      await _audioEngine.initialize();
      _audioEngine.setInstrumentalVolume(_musicVolume);
      _audioEngine.setVocalVolume(_vocalVolume);
      
      if (widget.song.audioUrl.isEmpty) {
        print("Warning: Song audioUrl is empty. Proceeding without instrumental audio.");
        if (mounted) {
          setState(() {
            _isInstrumentalLoaded = true;
          });
        }
        _startTimelineTimer();
        return;
      }
      
      // Download/Cache audio file locally
      final String resolvedUrl = AppConfig.resolveMediaUrl(widget.song.audioUrl);
      print("Resolving and loading audio from URL: $resolvedUrl");
      final String localPath = await AudioCacheManager.getCachedAudioPath(resolvedUrl);
      
      await _audioEngine.loadInstrumental(localPath);
      _audioEngine.setMonitoringEnabled(_monitoringEnabled);
      _audioEngine.setLatencyOffset(_latencyOffset);

      // Set duration immediately once the instrumental is loaded, instead of
      // waiting for the (throttled) position-stream listener to eventually
      // populate it — that path only runs once real position events start
      // flowing, so any gap or delay there (e.g. on a fresh re-record
      // session) left the seekbar's total duration stuck at 0:00 even
      // though the instrumental itself loaded and played back fine.
      final loadedDuration = _audioEngine.getDuration();
      print("Instrumental loaded, duration=$loadedDuration");
      if (mounted) {
        durationNotifier.value = loadedDuration;
        setState(() {
          _isInstrumentalLoaded = true;
        });
      }
    } catch (e, stackTrace) {
      print("Error initEngine: $e\n$stackTrace");
      try {
        final String resolvedUrl = AppConfig.resolveMediaUrl(widget.song.audioUrl);
        await AudioCacheManager.removeCache(resolvedUrl);
      } catch (_) {}
      
      if (mounted) {
        // Fallback to allow entering screen even if audio fails to load
        setState(() {
          _isInstrumentalLoaded = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Gagal memuat musik instrumental ($e), masuk ke mode senyap/tanpa instrumen.",
              style: const TextStyle(fontSize: 12, color: Colors.white),
            ),
            backgroundColor: Colors.red[800],
          ),
        );
      }
    }
    _startTimelineTimer();
  }

  void _startTimelineTimer() {
    _positionSubscription?.cancel();
    final Stopwatch computeThrottleClock = Stopwatch()..start();
    const int computeIntervalMs = 33; // ~30Hz compute/scoring throttle to prevent UI thread overload from native EventChannel callbacks

    _positionSubscription = _audioEngine.onPositionChanged.listen((pos) {
      if (!mounted) return;

      final double timeSec = pos.inMilliseconds / 1000.0;
      _lastEngineTimeSec = timeSec;
      _lastEngineTimeReceivedAt = DateTime.now();
      smoothTimeSecNotifier.value = timeSec;

      // Throttle heavy computations (lyric sync, binary search note bar, pitch detection, scoring)
      // to ~30Hz (33ms) to avoid saturating the UI isolate with 100+ native callbacks/sec.
      if (computeThrottleClock.elapsedMilliseconds < computeIntervalMs) {
        return;
      }
      computeThrottleClock.reset();

      final engineDur = _audioEngine.getDuration();
      final totalDur = engineDur;
      final totalSec = totalDur.inSeconds > 0 ? totalDur.inSeconds.toDouble() : 120.0;

      // 1. Synchronize lyrics
      _lyricSyncInfo = LyricsSynchronizer.synchronize(
        timeSec: timeSec,
        lyrics: widget.song.lyrics,
      );

      // 2. Locate active target note bar at current time using binary search (O(log N))
      final activeTargetBar = _findActiveNoteBar(timeSec);
      final double targetMidi = activeTargetBar?.midiNote ?? 0.0;

      // 3. Process Live Pitch Conversion
      final double userHz = _audioEngine.getCurrentUserPitch();
      _currentPitchResult = PitchDetector.processLivePitch(
        userFrequencyHz: userHz,
        targetMidiNote: targetMidi,
      );

      // 4. Record pitch sample in Scoring Engine
      // Apply latency compensation for accurate vocal synchronization
      final double compensatedTimeSec = timeSec - (_latencyOffset / 1000.0);
      if (userHz > 10.0 && (isPlayingNotifier.value || isRecordingNotifier.value)) {
        _scoringEngine.addSample(
          timeSec: compensatedTimeSec,
          userMidi: _currentPitchResult.midiNote,
          targetMidi: targetMidi,
          centsError: _currentPitchResult.centsError,
          isVocalDetected: true,
        );

        _userPitchTrail.add(PitchTrailPoint(
          timestampSec: compensatedTimeSec,
          userMidi: _currentPitchResult.midiNote,
          targetMidi: targetMidi,
          isHit: _currentPitchResult.isNoteHit,
          centsError: _currentPitchResult.centsError,
        ));

        if (_userPitchTrail.length > 300) {
          _userPitchTrail.removeAt(0);
        }
      }

      final sessionProgress = (timeSec / totalSec).clamp(0.0, 1.0);
      _scoreBreakdown = _scoringEngine.calculateScore(sessionProgress: sessionProgress);

      final newActiveIndex = _lyricSyncInfo.activeIndex;

      if (!_isDraggingSlider && !_isUserScrollingLyrics) {
        currentTimeNotifier.value = pos;
        durationNotifier.value = totalDur;
        isPlayingNotifier.value = _audioEngine.isPlaying();
        isRecordingNotifier.value = _audioEngine.isRecordingState();
        scoreNotifier.value = _scoreBreakdown.finalScore.round();
      }

      // Handle auto transition to mixing state if song hits end during recording
      if (totalDur.inSeconds > 5 && pos.inSeconds >= totalDur.inSeconds - 1) {
        _transitionToMixingState();
      }

      if (!_isUserScrollingLyrics) {
        activeLyricProgressNotifier.value = _lyricSyncInfo.lineProgress;
        if (newActiveIndex != activeLyricIndexNotifier.value && newActiveIndex >= 0) {
          activeLyricIndexNotifier.value = newActiveIndex;
          if (_scrollController.hasClients) {
            double offset = (newActiveIndex * lyricItemHeight);
            if (offset < 0) offset = 0;
            _scrollController.animateTo(
              offset,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
            );
          }
        }
      } else {
        if (newActiveIndex != activeLyricIndexNotifier.value && newActiveIndex >= 0) {
          activeLyricIndexNotifier.value = newActiveIndex;
        }
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      // Pause playing or recording to avoid orphan audio / zombie players.
      // IMPORTANT: call pause directly rather than _togglePlayPause() — that
      // helper starts recording (turns the mic on!) whenever recording
      // hasn't started yet, which is the opposite of what backgrounding
      // the app should do.
      if (isPlayingNotifier.value) {
        _audioEngine.pause();
        _vinylAnimationController.stop();
        isPlayingNotifier.value = _audioEngine.isPlaying();
        isRecordingNotifier.value = _audioEngine.isRecordingState();
      }
    }
  }



  
  Future<void> _exportAndSave() async {
    // Stub
  }
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _smoothTicker.dispose();
    _positionSubscription?.cancel();
    _uiTimer?.cancel();
    _vinylAnimationController.dispose();
    // Keep the engine alive when handing off to EditRecordingScreen (it owns
    // disposal from here); otherwise release native audio resources (mic,
    // AAudio streams) now instead of leaking them on every exit.
    if (!_isNavigatingToMix) {
      _audioEngine.dispose();
    }
    _scrollController.dispose();
    activeLyricIndexNotifier.dispose();
    activeLyricProgressNotifier.dispose();
    currentTimeNotifier.dispose();
    smoothTimeSecNotifier.dispose();
    durationNotifier.dispose();
    isPlayingNotifier.dispose();
    isRecordingNotifier.dispose();
    scoreNotifier.dispose();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  Future<void> _startRecordingAndPlay() async {
    if (_isCountingDown) return;
    try {
      final status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Izin mikrofon diperlukan untuk merekam suara Anda.')),
          );
        }
        return;
      }

      // Beri jeda 3 detik untuk bersiap sebelum instrumental, lirik, dan
      // rekaman benar-benar mulai berjalan.
      if (mounted) {
        setState(() {
          _isCountingDown = true;
          _countdownValue = kGetReadyCountdownSeconds;
        });
      }
      for (int i = kGetReadyCountdownSeconds; i >= 1; i--) {
        if (!mounted) return;
        setState(() => _countdownValue = i);
        await Future.delayed(const Duration(seconds: 1));
      }
      if (!mounted) return;
      setState(() => _isCountingDown = false);

      await _audioEngine.play();
      await _audioEngine.startRecording();
      _recordingSongStart = currentTimeNotifier.value.inMilliseconds / 1000.0;
      isPlayingNotifier.value = true;
      isRecordingNotifier.value = true;
      _vinylAnimationController.repeat();
    } catch (e) {
      print('Failed to start recording: $e');
      if (mounted) {
        setState(() => _isCountingDown = false);
      }
      isPlayingNotifier.value = false;
      isRecordingNotifier.value = false;
    }
  }

  Future<void> _togglePlayPause() async {
    if (!isRecordingNotifier.value) {
      await _startRecordingAndPlay();
    } else {
      if (isPlayingNotifier.value) {
        await _audioEngine.pause();
        _vinylAnimationController.stop();
      } else {
        await _audioEngine.play();
        _vinylAnimationController.repeat();
      }
    }
    isPlayingNotifier.value = _audioEngine.isPlaying();
    isRecordingNotifier.value = _audioEngine.isRecordingState();
  }

  void _handleEndPressed() {
    final double currentSec = currentTimeNotifier.value.inMilliseconds / 1000.0;
    final double singingDurationSec = (isRecordingNotifier.value && currentSec > _recordingSongStart) 
        ? (currentSec - _recordingSongStart) 
        : currentSec;
debugPrint(
  'END DEBUG: '
  'currentSec=$currentSec, '
  'recordingStart=$_recordingSongStart, '
  'isRecording=${isRecordingNotifier.value}',
);
    if (singingDurationSec < 3) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF18181B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.info_outline, color: Colors.orange, size: 40),
              const SizedBox(height: 12),
              Text(
                'nyanyikan beberapa part',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: _responsiveFontSize(context, 14.0),
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF27272A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      );
    } else if (singingDurationSec > 30) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF18181B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Akhiri Rekaman?',
            style: TextStyle(
              color: Colors.white,
              fontSize: _responsiveFontSize(context, 16.0),
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Apakah Anda yakin ingin mengakhiri rekaman sekarang? Hasil bernyanyi Anda sudah cukup untuk diproses dan disimpan.',
            style: TextStyle(
              color: Colors.white70,
              fontSize: _responsiveFontSize(context, 13.5),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Lanjutkan Bernyanyi', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF2A54),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                Navigator.pop(context);
                _transitionToMixingState();
              },
              child: const Text('Akhiri & Simpan', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    } else {
      _transitionToMixingState();
    }
  }

  Future<void> _transitionToMixingState() async {
    _uiTimer?.cancel();
    _recordingSongEnd = currentTimeNotifier.value.inMilliseconds / 1000.0;
    
    final double actualTakeDurationSec = (_recordingSongEnd > _recordingSongStart)
        ? (_recordingSongEnd - _recordingSongStart)
        : (currentTimeNotifier.value.inMilliseconds / 1000.0);

    _recordedDuration = Duration(milliseconds: (actualTakeDurationSec * 1000).round());

    await _audioEngine.stopRecording();
    _vinylAnimationController.stop();

    _isNavigatingToMix = true;
    if (!mounted) return;
    
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => EditRecordingScreen(
          song: widget.song,
          audioEngine: _audioEngine,
          recordedDuration: _recordedDuration,
          score: scoreNotifier.value,
          songStart: _recordingSongStart,
          songEnd: _recordingSongEnd,
        ),
      ),
    );
  }

  Widget _buildRecordingView() {
    return Column(
      children: [
        // Earphone Status Warning Banner (Shown only when NOT connected)
        if (!_isEarphoneConnected)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (Colors.amber[500] ?? Colors.amber).withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: (Colors.amber[500] ?? Colors.amber).withOpacity(0.25)),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.amber[500], size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Earphone belum terhubung — Rekaman disarankan menggunakan earphone',
                      style: TextStyle(
                        color: Colors.amber[400],
                        fontSize: _responsiveFontSize(context, 12.0),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () {
                      setState(() {
                        _isEarphoneConnected = true;
                      });
                    },
                    child: Text('Hubungkan', style: TextStyle(color: Colors.amber, fontSize: _responsiveFontSize(context, 12.0), fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),

        // Live Pitch Canvas & Scoring Engine HUD
        _buildPitchAndScoringHUD(),

        const SizedBox(height: 8),

        // Timeline Progress Slider & Animated Waveform (Outside card, below pitch bar)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ValueListenableBuilder<Duration>(
                valueListenable: currentTimeNotifier,
                builder: (context, currentTime, child) {
                  return ValueListenableBuilder<Duration>(
                    valueListenable: durationNotifier,
                    builder: (context, duration, child) {
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatDuration(currentTime),
                            style: const TextStyle(color: Colors.grey, fontSize: 10, fontFamily: 'monospace'),
                          ),
                          Expanded(
                            child: SliderTheme(
                              data: SliderThemeData(
                                trackHeight: 3.0,
                                activeTrackColor: Colors.blue[500],
                                inactiveTrackColor: const Color(0xFF1F1F23),
                                thumbColor: Colors.white,
                                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5.0),
                                overlayShape: const RoundSliderOverlayShape(overlayRadius: 10.0),
                              ),
                              child: Slider(
                                value: currentTime.inMilliseconds.toDouble().clamp(0.0, math.max(100.0, duration.inMilliseconds.toDouble())),
                                min: 0.0,
                                max: math.max(100.0, duration.inMilliseconds.toDouble()),
                                onChangeStart: (val) {
                                  _isDraggingSlider = true;
                                },
                                onChanged: (val) {
                                  currentTimeNotifier.value = Duration(milliseconds: val.toInt());
                                },
                                onChangeEnd: (val) {
                                  _audioEngine.seek(Duration(milliseconds: val.toInt()));
                                  _isDraggingSlider = false;
                                },
                              ),
                            ),
                          ),
                          Text(
                            _formatDuration(duration),
                            style: const TextStyle(color: Colors.grey, fontSize: 10, fontFamily: 'monospace'),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
              ValueListenableBuilder<bool>(
                valueListenable: isPlayingNotifier,
                builder: (context, isPlaying, child) {
                  return AnimatedWaveform(isPlaying: isPlaying);
                },
              ),
            ],
          ),
        ),

        // Synchronized Scrolling Lyrics Area
        Expanded(
          child: widget.song.lyrics.isEmpty
              ? const Center(child: Text("Tidak ada Lirik", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)))
              : Stack(
                  children: [
                    NotificationListener<ScrollNotification>(
                      onNotification: (ScrollNotification notification) {
                        if (notification is ScrollStartNotification) {
                          _isUserScrollingLyrics = true;
                          _lyricsScrollDebounce?.cancel();
                          // Pause playback immediately when scroll starts to prevent audio overlap
                          if (isPlayingNotifier.value && !_isCountingDown) {
                            _wasPlayingBeforeScroll = true;
                            _audioEngine.pause();
                            _vinylAnimationController.stop();
                            isPlayingNotifier.value = false;
                          } else {
                            _wasPlayingBeforeScroll = false;
                          }
                        } else if (notification is ScrollEndNotification) {
                          _lyricsScrollDebounce?.cancel();
                          double offset = notification.metrics.pixels;
                          int centeredIndex = (offset / lyricItemHeight).round().clamp(0, widget.song.lyrics.length - 1);
                          if (centeredIndex >= 0 && centeredIndex < widget.song.lyrics.length) {
                            _lastScrolledLyricIndex = centeredIndex;
                            activeLyricIndexNotifier.value = centeredIndex;
                            
                            // Scroll-to-Seek: Seek audio to the time of the centered lyric
                            // Only seek when scroll stops to avoid audio stuttering
                            final targetLyric = widget.song.lyrics[centeredIndex];
                            final targetTimeSec = targetLyric.time;
                            if (targetTimeSec >= 0) {
                              // CRITICAL: Ensure we're paused before seek to prevent double playback
                              // The pause already happened in ScrollStartNotification
                              bool wasAlreadyPaused = !isPlayingNotifier.value;
                              if (isPlayingNotifier.value) {
                                _audioEngine.pause();
                                _vinylAnimationController.stop();
                                isPlayingNotifier.value = false;
                              }
                              
                              // Perform seek while paused - this prevents buffer overlap
                              _audioEngine.seek(Duration(milliseconds: (targetTimeSec * 1000).toInt()));
                              currentTimeNotifier.value = Duration(milliseconds: (targetTimeSec * 1000).toInt());
                              
                              // Resume playback if it was playing before scroll
                              // Use a shorter delay and check state to prevent race conditions
                              if (_wasPlayingBeforeScroll) {
                                // Reset the flag first to prevent multiple resumes
                                _wasPlayingBeforeScroll = false;
                                
                                // Small delay to ensure C++ seek is fully committed
                                // but not too long to cause noticeable gap
                                Future.delayed(const Duration(milliseconds: 20), () {
                                  if (mounted && !_audioEngine.isPlaying()) {
                                    _audioEngine.play();
                                    _vinylAnimationController.repeat();
                                    isPlayingNotifier.value = true;
                                  }
                                });
                              }
                            }
                          }

                          _lyricsScrollDebounce = Timer(const Duration(milliseconds: 1500), () {
                            _isUserScrollingLyrics = false;
                          });
                        } else if (notification is ScrollUpdateNotification) {
                          // Throttle scroll updates: only update active lyric index during scroll
                          // Do NOT seek during scroll to prevent audio stuttering
                          double offset = notification.metrics.pixels;
                          int centeredIndex = (offset / lyricItemHeight).round().clamp(0, widget.song.lyrics.length - 1);
                          if (centeredIndex >= 0 && centeredIndex < widget.song.lyrics.length) {
                            if (centeredIndex != _lastScrolledLyricIndex) {
                              _lastScrolledLyricIndex = centeredIndex;
                              activeLyricIndexNotifier.value = centeredIndex;
                              // Note: We intentionally do NOT seek here during scroll
                              // Seek will happen in ScrollEndNotification when user stops scrolling
                            }
                          }
                        }
                        return false;
                      },
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          // Posisikan lirik aktif lebih dekat ke pitch bar (atas)
                          final double topPadding = 24.0;
                          final double bottomPadding = constraints.maxHeight * 0.7; // Sisakan ruang bawah
                          return ListView.builder(
                            controller: _scrollController,
                            padding: EdgeInsets.only(
                              left: 12,
                              right: 12,
                              top: topPadding,
                              bottom: bottomPadding,
                            ),
                            itemCount: widget.song.lyrics.length,
                            itemExtent: lyricItemHeight,
                            itemBuilder: (context, index) {
                              final lyricItem = widget.song.lyrics[index];
                              return _LyricRow(
                                key: ValueKey('lyric_$index'),
                                index: index,
                                lyricItem: lyricItem,
                                activeLyricIndexNotifier: activeLyricIndexNotifier,
                                activeLyricProgressNotifier: activeLyricProgressNotifier,
                                responsiveFontSize: _responsiveFontSize,
                                onTap: (idx, item) async {
                                  _isUserScrollingLyrics = true;
                                  _lyricsScrollDebounce?.cancel();
                                  _lastScrolledLyricIndex = idx;
                                  double targetTimeSec = item.time;
                                  if (targetTimeSec >= 0) {
                                    final wasPlaying = isPlayingNotifier.value;
                                    if (wasPlaying) {
                                      await _audioEngine.pause();
                                      _vinylAnimationController.stop();
                                      isPlayingNotifier.value = false;
                                    }

                                    await _audioEngine.seek(Duration(milliseconds: (targetTimeSec * 1000).toInt()));
                                    currentTimeNotifier.value = Duration(milliseconds: (targetTimeSec * 1000).toInt());
                                    activeLyricIndexNotifier.value = idx;

                                    if (_scrollController.hasClients) {
                                      await _scrollController.animateTo(
                                        idx * lyricItemHeight,
                                        duration: const Duration(milliseconds: 300),
                                        curve: Curves.easeInOut,
                                      );
                                    }

                                    if (wasPlaying) {
                                      await _audioEngine.play();
                                      _vinylAnimationController.repeat();
                                      isPlayingNotifier.value = true;
                                    }
                                  }
                                  _lyricsScrollDebounce = Timer(const Duration(milliseconds: 1500), () {
                                    _isUserScrollingLyrics = false;
                                  });
                                },
                              );
                            },
                          );
                        },
                      ),
              ), // Close NotificationListener
                    // Shadow overlay for cinematic scrolling text fading
                    Positioned(
                      top: 0, left: 0, right: 0, height: 60,
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xFF09090B), Colors.transparent],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0, left: 0, right: 0, height: 60,
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [Color(0xFF09090B), Colors.transparent],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        ),

        // Recording Controls Panel
        Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
          decoration: const BoxDecoration(
            color: Color(0xFF09090B),
            border: Border(top: BorderSide(color: Color(0xFF1F1F23))),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ValueListenableBuilder<bool>(
                valueListenable: isPlayingNotifier,
                builder: (context, isPlaying, child) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Monitor Vocal Toggle
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _monitoringEnabled = !_monitoringEnabled;
                                _audioEngine.setMonitoringEnabled(_monitoringEnabled);
                              });
                            },
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: _monitoringEnabled ? Colors.green[900]?.withOpacity(0.3) : const Color(0xFF111113),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: _monitoringEnabled ? Colors.green[500]! : const Color(0xFF1F1F23)),
                                  ),
                                  child: Icon(
                                    _monitoringEnabled ? Icons.headset : Icons.headset_off,
                                    color: _monitoringEnabled ? Colors.green[400] : Colors.grey,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Monitor',
                                  style: TextStyle(
                                    color: _monitoringEnabled ? Colors.green[400] : Colors.grey,
                                    fontSize: _responsiveFontSize(context, 11.5),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 40),
                          // Main recording triggers
                          GestureDetector(
                            onTap: _togglePlayPause,
                            child: Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: isPlaying ? Colors.blue[600] : Colors.red[600],
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: isPlaying
                                        ? (Colors.blue[900] ?? Colors.blue).withOpacity(0.4)
                                        : (Colors.red[900] ?? Colors.red).withOpacity(0.3),
                                    blurRadius: 15,
                                    spreadRadius: 1,
                                    offset: const Offset(0, 4),
                                  )
                                ],
                              ),
                              child: Icon(
                                isPlaying ? Icons.pause : Icons.mic,
                                color: Colors.white,
                                size: 26,
                              ),
                            ),
                          ),
                          // Replay / Restart
                          GestureDetector(
                            onTap: () async {
                              await _audioEngine.seek(Duration.zero);
                              currentTimeNotifier.value = Duration.zero;
                              _recordingSongStart = 0.0;
                              if (!isPlaying) {
                                await _startRecordingAndPlay();
                              } else {
                                await _audioEngine.play();
                                isPlayingNotifier.value = true;
                              }
                            },
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF111113),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: const Color(0xFF1F1F23)),
                                  ),
                                  child: const Icon(Icons.replay, color: Colors.grey, size: 18),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Restart',
                                  style: TextStyle(color: Colors.grey, fontSize: _responsiveFontSize(context, 11.5), fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                          // Complete & Proceed to Mix view
                          GestureDetector(
                            onTap: _handleEndPressed,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF111113),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: const Color(0xFF1F1F23)),
                                  ),
                                  child: const Icon(
                                    Icons.check,
                                    color: Colors.orange,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'End',
                                  style: TextStyle(color: Colors.grey, fontSize: _responsiveFontSize(context, 11.5), fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPitchAndScoringHUD() {
    final gradeLabel = ScoreBreakdown.getGradeLabel(_scoreBreakdown.grade);
    Color gradeColor;
    switch (_scoreBreakdown.grade) {
      case ScoreGrade.SSS:
        gradeColor = const Color(0xFF00F2FE); // Cyan glow
        break;
      case ScoreGrade.SS:
        gradeColor = const Color(0xFF10B981); // Emerald glow
        break;
      case ScoreGrade.S:
        gradeColor = const Color(0xFFFBBF24); // Gold glow
        break;
      case ScoreGrade.A:
        gradeColor = const Color(0xFF818CF8); // Indigo glow
        break;
      case ScoreGrade.B:
        gradeColor = const Color(0xFFA78BFA); // Purple glow
        break;
      case ScoreGrade.C:
        gradeColor = Colors.grey;
        break;
    }

    final isHit = _currentPitchResult.isNoteHit;
    final cents = _currentPitchResult.centsError;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF0B0F19)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E293B), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        children: [
          // Row 1: Studio Grade Badge & Score Breakdown
          Row(
            children: [
              // Premium Studio Grade Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [gradeColor.withOpacity(0.25), gradeColor.withOpacity(0.05)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: gradeColor.withOpacity(0.5), width: 1.2),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      gradeLabel,
                      style: TextStyle(
                        color: gradeColor,
                        fontSize: _responsiveFontSize(context, 18.0),
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                        shadows: [
                          Shadow(
                            color: gradeColor.withOpacity(0.5),
                            blurRadius: 6.0,
                          )
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 1.5,
                      height: 14,
                      color: Colors.white12,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${_scoreBreakdown.finalScore.round()}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: _responsiveFontSize(context, 18.0),
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Live Formula Metrics breakdown (Pitch, Timing, Stability, Complete) - HIDDEN
              // Expanded(
              //   child: SingleChildScrollView(
              //     scrollDirection: Axis.horizontal,
              //     child: Row(
              //       children: [
              //         _buildMetricChip('Pitch', '${_scoreBreakdown.pitchAccuracy.round()}%', const Color(0xFF00F2FE)),
              //         const SizedBox(width: 5),
              //         _buildMetricChip('Timing', '${_scoreBreakdown.timingAccuracy.round()}%', const Color(0xFF10B981)),
              //         const SizedBox(width: 5),
              //         _buildMetricChip('Stability', '${_scoreBreakdown.stability.round()}%', const Color(0xFFA78BFA)),
              //         const SizedBox(width: 5),
              //         _buildMetricChip('Complete', '${_scoreBreakdown.noteCompletion.round()}%', const Color(0xFFFBBF24)),
              //       ],
              //     ),
              //   ),
              // ),
            ],
          ),

          const SizedBox(height: 8),

          // Row 2: Live Pitch Guide & User Pitch Overlay Canvas Stack
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 110,
              decoration: const BoxDecoration(
                color: Color(0xFF030712), // Deep black canvas for neon contrast
              ),
              child: ValueListenableBuilder<double>(
                valueListenable: smoothTimeSecNotifier,
                builder: (context, currentTimeSec, child) {
                  return Stack(
                    children: [
                      PitchGuideRenderer(
                        currentTimeSec: currentTimeSec,
                        guideNotes: _guideNotes,
                        height: 110,
                      ),
                      PitchOverlayRenderer(
                        currentTimeSec: currentTimeSec,
                        userPitchTrail: _userPitchTrail,
                        currentPitchHz: _currentPitchResult.frequency,
                        currentMidiNote: _currentPitchResult.midiNote,
                        targetMidiNote: _currentPitchResult.targetMidi,
                        isHit: _currentPitchResult.isNoteHit,
                        centsError: _currentPitchResult.centsError,
                        height: 110,
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(color: color, fontSize: _responsiveFontSize(context, 10.5), fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 3),
          Text(
            value,
            style: TextStyle(color: Colors.white, fontSize: _responsiveFontSize(context, 11.5), fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }



  Future<void> _handleBackNavigation() async {
    _audioEngine.pause();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF18181B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.white12),
        ),
        title: Row(
          children: const [
            Icon(Icons.help_outline_rounded, color: Colors.orange, size: 24),
            SizedBox(width: 8),
            Text(
              'Informasi Pilihan',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: const Text(
          'Apakah Anda ingin merekam ulang lagu ini atau keluar dari rekaman?',
          style: TextStyle(color: Colors.white70, fontSize: 13.5),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF2A54),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RecordScreen(song: widget.song),
                    ),
                  );
                },
                icon: const Icon(Icons.replay_rounded, size: 18),
                label: const Text('Merekam Ulang', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const MainScreen(initialIndex: 1),
                    ),
                    (route) => false,
                  );
                },
                icon: const Icon(Icons.exit_to_app_rounded, size: 18),
                label: const Text('Keluar dari Rekaman', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _handleBackNavigation();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF050505),
        appBar: AppBar(
          backgroundColor: const Color(0xFF09090B),
          elevation: 0,
          titleSpacing: 0,
          leading: IconButton(
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
            onPressed: _handleBackNavigation,
          ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              widget.song.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              'Recording Mode • ${widget.song.artist}',
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 9,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0x1AFFF3B0),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0x33FFF3B0)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.emoji_events, color: Colors.amber[400], size: 14),
                    const SizedBox(width: 4),
                    ValueListenableBuilder<int>(
                      valueListenable: scoreNotifier,
                      builder: (context, score, child) {
                        return Text(
                          '$score%',
                          style: TextStyle(
                            color: Colors.amber[400],
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: const Color(0xFF1F1F23),
            height: 1,
          ),
        ),
      ),
      body: Stack(
        children: [
          _isInstrumentalLoaded
              ? _buildRecordingView()
              : const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: Color(0xFFFF2A54)),
                      SizedBox(height: 16),
                      Text('Menyiapkan instrumen...', style: TextStyle(color: Colors.white, fontSize: 12)),
                    ],
                  ),
                ),
          if (_isCountingDown) _buildGetReadyCountdownOverlay(),
        ],
      ),
      ),
    );
  }

  Widget _buildGetReadyCountdownOverlay() {
    return Positioned.fill(
      child: IgnorePointer(
        ignoring: false,
        child: Container(
          color: Colors.black.withOpacity(0.75),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Bersiap-siap...',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              TweenAnimationBuilder<double>(
                key: ValueKey(_countdownValue),
                tween: Tween(begin: 1.4, end: 1.0),
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutBack,
                builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
                child: Text(
                  '$_countdownValue',
                  style: const TextStyle(
                    color: Color(0xFFFF2A54),
                    fontSize: 96,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LyricRow extends StatelessWidget {
  final int index;
  final LyricLine lyricItem;
  final ValueNotifier<int> activeLyricIndexNotifier;
  final ValueNotifier<double> activeLyricProgressNotifier;
  final double Function(BuildContext, double) responsiveFontSize;
  final Function(int, LyricLine) onTap;

  const _LyricRow({
    Key? key,
    required this.index,
    required this.lyricItem,
    required this.activeLyricIndexNotifier,
    required this.activeLyricProgressNotifier,
    required this.responsiveFontSize,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: activeLyricIndexNotifier,
      builder: (context, activeIndex, child) {
        final isActive = index == activeIndex;
        final isPast = index < activeIndex;
        final double textSize = isActive
            ? responsiveFontSize(context, 20.0)
            : (isPast ? responsiveFontSize(context, 15.0) : responsiveFontSize(context, 17.0));

        final TextStyle baseStyle = TextStyle(
          fontSize: textSize,
          fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
          letterSpacing: 0.2,
          color: isActive ? Colors.white70 : (isPast ? Colors.white24 : Colors.white60),
          fontFamily: 'Poppins',
        );

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onTap(index, lyricItem),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 1.0, end: isActive ? 1.04 : 1.0),
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutBack,
                builder: (context, scale, child) {
                  return Transform.scale(
                    alignment: Alignment.centerLeft,
                    scale: scale,
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 180),
                      style: baseStyle,
                      child: isActive
                          ? ValueListenableBuilder<double>(
                              valueListenable: activeLyricProgressNotifier,
                              builder: (context, progress, child) {
                                final p = progress.clamp(0.0, 1.0);
                                return ShaderMask(
                                  shaderCallback: (bounds) {
                                    return LinearGradient(
                                      colors: const [Colors.orange, Colors.orange, Colors.white70, Colors.white70],
                                      stops: [0.0, p, p, 1.0],
                                    ).createShader(bounds);
                                  },
                                  blendMode: BlendMode.srcIn,
                                  child: Text(
                                    lyricItem.text,
                                    textAlign: TextAlign.left,
                                    maxLines: 1,
                                    overflow: TextOverflow.fade,
                                  ),
                                );
                              },
                            )
                          : Text(
                              lyricItem.text,
                              textAlign: TextAlign.left,
                              maxLines: 1,
                              overflow: TextOverflow.fade,
                            ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class AnimatedWaveform extends StatefulWidget {
  final bool isPlaying;
  const AnimatedWaveform({required this.isPlaying});

  @override
  _AnimatedWaveformState createState() => _AnimatedWaveformState();
}

class _AnimatedWaveformState extends State<AnimatedWaveform> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    if (widget.isPlaying) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(AnimatedWaveform oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying) {
      _controller.repeat();
    } else {
      _controller.stop();
    }
  }



  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isPlaying) {
      return Container(
        height: 20,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(24, (index) => Container(
            margin: const EdgeInsets.symmetric(horizontal: 1.5),
            width: 2.5,
            height: 4,
            decoration: BoxDecoration(
              color: (Colors.blue[900] ?? Colors.blue).withOpacity(0.5),
              borderRadius: BorderRadius.circular(1.25),
            ),
          )),
        ),
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          height: 20,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(24, (index) {
              final val = (index * 0.08 + _controller.value) % 1.0;
              final height = 4.0 + (16.0 * (0.5 - (val - 0.5).abs()).abs());
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                width: 2.5,
                height: height,
                decoration: BoxDecoration(
                  color: Colors.blue[400],
                  borderRadius: BorderRadius.circular(1.25),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}