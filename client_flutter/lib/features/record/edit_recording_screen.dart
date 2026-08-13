import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';
import '../../core/config/app_config.dart';
import '../../data/models/song.dart';
import '../../services/audio/karaoke_audio_engine.dart';
import '../../data/repositories_impl.dart';
import '../../data/models/audio_preset.dart';
import '../../main.dart';
import 'record_screen.dart' show VocalSegmentData;

class RecordingTemplate {
  final String id;
  final String name;
  final String imageUrl;
  final List<Color> gradientColors;

  const RecordingTemplate({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.gradientColors,
  });
}

final List<RecordingTemplate> _availableTemplates = [
  const RecordingTemplate(
    id: 'sunset_sea',
    name: 'Sunset Sea',
    imageUrl: 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=800&q=80',
    gradientColors: [Color(0xFFE07A5F), Color(0xFF3D405B)],
  ),
  const RecordingTemplate(
    id: 'sunset_clouds',
    name: 'Sunset Clouds',
    imageUrl: 'https://images.unsplash.com/photo-1517685352821-92cf88aee5a5?w=800&q=80',
    gradientColors: [Color(0xFFF4A261), Color(0xFF264653)],
  ),
  const RecordingTemplate(
    id: 'starry_night',
    name: 'Starry Night',
    imageUrl: 'https://images.unsplash.com/photo-1506703719100-a0f3a48c0f86?w=800&q=80',
    gradientColors: [Color(0xFF0F2027), Color(0xFF203A43)],
  ),
  const RecordingTemplate(
    id: 'neon_city',
    name: 'Neon City',
    imageUrl: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=800&q=80',
    gradientColors: [Color(0xFF8A2387), Color(0xFFE94057)],
  ),
  const RecordingTemplate(
    id: 'cozy_studio',
    name: 'Cozy Studio',
    imageUrl: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=800&q=80',
    gradientColors: [Color(0xFF232526), Color(0xFF414345)],
  ),
  const RecordingTemplate(
    id: 'emerald_nature',
    name: 'Emerald Nature',
    imageUrl: 'https://images.unsplash.com/photo-1448375240586-882707db888b?w=800&q=80',
    gradientColors: [Color(0xFF11998e), Color(0xFF38ef7d)],
  ),
  const RecordingTemplate(
    id: 'golden_glow',
    name: 'Golden Hour',
    imageUrl: 'https://images.unsplash.com/photo-1495616811223-4d98c6e9c869?w=800&q=80',
    gradientColors: [Color(0xFFFFB75E), Color(0xFFED8F03)],
  ),
];

class EditRecordingScreen extends StatefulWidget {
  final Song song;
  final KaraokeAudioEngine audioEngine;
  final Duration recordedDuration;
  final int score;
  final double songStart;
  final double songEnd;
  final double fullSongDurationSec; // Full song duration for proper timeline
  final List<VocalSegmentData>? vocalSegments; // Multi-segment vocal metadata for timeline sync

  const EditRecordingScreen({
    Key? key,
    required this.song,
    required this.audioEngine,
    required this.recordedDuration,
    required this.score,
    this.songStart = 0.0,
    this.songEnd = 0.0,
    this.fullSongDurationSec = 0.0,
    this.vocalSegments,
  }) : super(key: key);

  @override
  _EditRecordingScreenState createState() => _EditRecordingScreenState();
}

class _EditRecordingScreenState extends State<EditRecordingScreen> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final KaraokeAudioEngine _audioEngine;
  StreamSubscription<Duration>? _positionSubscription;
  bool isPlaying = false;
  bool _isDraggingSlider = false;
  Timer? _seekDebounce;
  Duration _currentTime = Duration.zero;
  late Duration _duration;

  // Karaoke engine UI & state parameters
  double _vocalVolume = 1.0;
  List<AudioPreset> _apiPresets = [];
  bool _loadingPresets = false;
  AudioPreset? _selectedApiPreset;
  double _musicVolume = 0.85;
  int _latencyOffset = 45;
  
  // Template & Custom Picture state
  RecordingTemplate _selectedTemplate = _availableTemplates.first;
  String? _customImageUrl;

  // Post & Caption Metadata
  final TextEditingController _captionController = TextEditingController();
  String _selectedVisibility = 'Public'; // 'Public', 'Private'

  // Nondestructive edit workspace state
  double _reverbMix = 0.25;
  String _reverbPreset = 'Studio';
  double _delayMix = 0.15;
  double _pitchCorrectionStrength = 0.5;
  AutoTuneMode _autoTuneMode = AutoTuneMode.off;
  bool _proTuningEnabled = false;
  bool _reverbEnabled = true;
  bool _delayEnabled = false;
  bool _pitchCorrectionEnabled = false;
  bool _compressorEnabled = true;
  bool _eqEnabled = true;
  bool _noiseReductionEnabled = true;

  bool _isSaving = false;
  bool _recordingSaved = false;

  late AnimationController _vinylAnimationController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _audioEngine = widget.audioEngine;

    final double takeDurationSec = (widget.songEnd > widget.songStart)
        ? (widget.songEnd - widget.songStart)
        : (widget.recordedDuration.inMilliseconds / 1000.0);

    _duration = Duration(milliseconds: (takeDurationSec * 1000).round());

    _vinylAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    );

    _initPlayback();
  }

  double _responsiveFontSize(BuildContext context, double baseFontSize) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double scaleFactor = (screenWidth / 375.0).clamp(1.0, 1.35);
    return baseFontSize * scaleFactor;
  }

  Future<void> _initPlayback() async {
    // CRITICAL: Set vocal range to FULL song duration for proper multi-segment playback
    // NOT just the recorded range. This ensures all vocal segments play at their
    // absolute timeline positions, not relative to recording start.
    final double fullSongDuration = widget.fullSongDurationSec > 0 
        ? widget.fullSongDurationSec 
        : (_audioEngine.getDuration().inMilliseconds / 1000.0);
    _audioEngine.setVocalRange(0.0, fullSongDuration);
    
    // Use full song duration for slider/timeline display
    _duration = Duration(milliseconds: (fullSongDuration * 1000).round());
    
    // Log vocal segments for debugging
    if (widget.vocalSegments != null && widget.vocalSegments!.isNotEmpty) {
      print('[EDIT] Received ${widget.vocalSegments!.length} vocal segments:');
      for (var seg in widget.vocalSegments!) {
        print('  Segment: ${seg.songStartTimeSec}s → ${seg.songEndTimeSec}s (${seg.durationSec}s)');
      }
    }
    
    // Start from songStart position (where first vocal segment begins)
    final double startMs = widget.songStart * 1000.0;
    await _audioEngine.seek(Duration(milliseconds: startMs.round()));
    _currentTime = Duration(milliseconds: (widget.songStart * 1000).round());
    _startTimelineTimer();
    await _audioEngine.play();
    _vinylAnimationController.repeat();
    _loadApiPresets();
  }

  void _startTimelineTimer() {
    _positionSubscription?.cancel();
    _positionSubscription = _audioEngine.onPositionChanged.listen((pos) {
      if (!mounted) return;

      final double posSec = pos.inMilliseconds / 1000.0;
      // CRITICAL: Use full song duration for loop detection, not just recorded range
      final double fullSongDuration = widget.fullSongDurationSec > 0 
          ? widget.fullSongDurationSec 
          : (_audioEngine.getDuration().inMilliseconds / 1000.0);
      final double endSec = widget.songEnd > widget.songStart ? widget.songEnd : fullSongDuration;

      if (posSec >= endSec && posSec < fullSongDuration) {
        // Loop back to start of recorded range
        final int startMs = (widget.songStart * 1000).round();
        _audioEngine.seek(Duration(milliseconds: startMs));
        _vinylAnimationController.repeat();
        setState(() {
          isPlaying = true;
          // Reset relative time to zero for UI consistency
          _currentTime = Duration(milliseconds: startMs);
        });
        return;
      }

      if (!_isDraggingSlider) {
        // CRITICAL: Use ABSOLUTE timeline position for multi-segment playback
        // posSec is already the absolute position in the song timeline
        // This ensures vocal segments play at their correct positions
        setState(() {
          _currentTime = Duration(milliseconds: (posSec * 1000).round());
          isPlaying = _audioEngine.isPlaying();
        });
      } else {
        setState(() {
          isPlaying = _audioEngine.isPlaying();
        });
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      if (isPlaying) {
        _togglePlayPause();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _positionSubscription?.cancel();
    _seekDebounce?.cancel();
    _vinylAnimationController.dispose();
    _captionController.dispose();
    _audioEngine.dispose();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  Future<void> _togglePlayPause() async {
    if (isPlaying) {
      await _audioEngine.pause();
      _vinylAnimationController.stop();
    } else {
      // If at end of song, seek to beginning (absolute position 0)
      final double fullSongDuration = widget.fullSongDurationSec > 0 
          ? widget.fullSongDurationSec 
          : (_audioEngine.getDuration().inMilliseconds / 1000.0);
      if (_currentTime.inMilliseconds >= (fullSongDuration * 1000 - 500)) {
        await _audioEngine.seek(Duration.zero);
        _currentTime = Duration.zero;
      }
      await _audioEngine.play();
      _vinylAnimationController.repeat();
    }
    setState(() {
      isPlaying = _audioEngine.isPlaying();
    });
  }

  Future<void> _loadApiPresets() async {
    setState(() {
      _loadingPresets = true;
    });
    try {
      final List<dynamic> rawList = await ApiRepository().fetchPresets();
      final List<AudioPreset> loaded = rawList.map((x) => AudioPreset.fromJson(Map<String, dynamic>.from(x))).toList();
      setState(() {
        _apiPresets = loaded;
        if (_apiPresets.isNotEmpty) {
          final bestDefault = _apiPresets.firstWhere(
            (p) => p.id.toLowerCase() == 'studio' || p.id.toLowerCase() == 'warm',
            orElse: () => _apiPresets.first,
          );
          _selectedApiPreset = bestDefault;
          _applyDynamicPreset(bestDefault);
        }
      });
    } catch (e) {
      print('Error loading api presets: $e');
    } finally {
      setState(() {
        _loadingPresets = false;
      });
    }
  }

  void _applyDynamicPreset(AudioPreset preset) {
    final dsp = preset.dsp;
    if (dsp == null) return;

    if (dsp.reverb > 0.0) {
      _audioEngine.setReverbEnabled(true);
      _audioEngine.setReverbMix(dsp.reverb);
    } else {
      _audioEngine.setReverbEnabled(false);
    }

    if (dsp.delay > 0.0 || dsp.echo > 0.0) {
      _audioEngine.setDelayEnabled(true);
      _audioEngine.setDelayMix(dsp.delay);
      _audioEngine.setDelayFeedback(dsp.echo > 0.0 ? dsp.echo : 0.35);
      _audioEngine.setDelayTime(250);
    } else {
      _audioEngine.setDelayEnabled(false);
    }

    final double clampedGain = dsp.vocalGain.clamp(0.0, 1.0);
    _audioEngine.setVocalVolume(clampedGain);

    if (dsp.compressor > 0.0) {
      _audioEngine.setCompressorEnabled(true);
      _audioEngine.setCompressorThreshold(-24.0 * dsp.compressor);
    } else {
      _audioEngine.setCompressorEnabled(false);
    }

    _audioEngine.setEQEnabled(true);
    _audioEngine.setEQBand(1, 150, dsp.eqLow * 12.0, 1.0);
    _audioEngine.setEQBand(2, 2500, dsp.eqMid * 12.0, 1.0);
    _audioEngine.setEQBand(3, 8000, dsp.eqHigh * 12.0, 1.0);

    if (dsp.noiseReduction > 0.0) {
      _audioEngine.setNoiseReductionEnabled(true);
    } else {
      _audioEngine.setNoiseReductionEnabled(false);
    }

    if (dsp.presence > 0.0) {
      _audioEngine.setProTuningEnabled(true);
    }

    setState(() {
      _selectedApiPreset = preset;
      _vocalVolume = clampedGain;
      _reverbEnabled = dsp.reverb > 0.0;
      _delayEnabled = dsp.delay > 0.0;
      _pitchCorrectionStrength = 0.5;
    });
  }

  Future<void> _exportAndSave() async {
    if (_isSaving || _recordingSaved) return;

    double renderProgress = 0.0;
    String renderStage = "Initializing multi-track mixing...";
    bool isExportCancelled = false;
    Timer? tickerTimer;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Guarded with ??= so exactly ONE periodic timer is ever created
            // for this dialog's lifetime, no matter how many times this
            // builder re-runs from setDialogState() below.
            tickerTimer ??= Timer.periodic(const Duration(milliseconds: 300), (t) {
              if (!mounted || renderProgress >= 1.0 || isExportCancelled) {
                t.cancel();
                return;
              }
              if (renderProgress < 0.25) {
                renderStage = "Extracting raw vocal track (mic capture)...";
              } else if (renderProgress < 0.50) {
                renderStage = "Applying 4-band Parametric EQ & Compressor...";
              } else if (renderProgress < 0.75) {
                renderStage = "Baking stereo convolution Reverb & Feedback Echo...";
              } else {
                renderStage = "Mixing instrumental and vocal buses... final rendering";
              }
              if (ctx.mounted) {
                setDialogState(() {});
              }
            });

            return Dialog(
              backgroundColor: const Color(0xFF0E0B19),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Colors.white12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.blur_on_rounded, color: Colors.orange, size: 48),
                    const SizedBox(height: 16),
                    const Text(
                      'DSP Rendering Pipeline',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      renderStage,
                      style: const TextStyle(color: Colors.grey, fontSize: 11),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    LinearProgressIndicator(
                      value: renderProgress,
                      color: Colors.orange,
                      backgroundColor: Colors.white12,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${(renderProgress * 100).toInt()}% Complete',
                      style: const TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () {
                        isExportCancelled = true;
                        tickerTimer?.cancel();
                        Navigator.pop(ctx);
                      },
                      child: const Text(
                        'Cancel Export',
                        style: TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    final settings = KaraokeEffectsSettings(
      reverbEnabled: _reverbEnabled,
      reverbMix: _reverbMix,
      reverbPreset: _reverbPreset,
      delayEnabled: _delayEnabled,
      delayMix: _delayMix,
      compressorEnabled: _compressorEnabled,
      eqEnabled: _eqEnabled,
      pitchCorrectionEnabled: _pitchCorrectionEnabled,
    );

    String exportedFilePath;
    try {
      // Pass vocal segments metadata to C++ export engine for proper multi-segment mixing
      final List<Map<String, double>>? segmentsData = widget.vocalSegments?.map((s) => {
        'songStart': s.songStartTimeSec,
        'songEnd': s.songEndTimeSec,
        'duration': s.durationSec,
      }).toList();
      
      print('[EXPORT] Exporting mix with ${segmentsData?.length ?? 0} vocal segments');
      
      exportedFilePath = await _audioEngine.exportMix(
        vocalVolume: _vocalVolume,
        instrumentalVolume: _musicVolume,
        settings: settings,
        vocalSegments: segmentsData,
        onProgress: (p) {
          if (!isExportCancelled) {
            renderProgress = p;
          }
        },
      );
    } catch (e) {
      tickerTimer?.cancel();
      if (mounted) {
        Navigator.pop(context); // Dismiss loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Rendering failed: $e')),
        );
      }
      return;
    }

    tickerTimer?.cancel();

    if (isExportCancelled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rendering cancelled by user.')),
      );
      return;
    }

    if (mounted) {
      Navigator.pop(context);
    }

    setState(() => _isSaving = true);
    final finalScore = widget.score > 10 ? widget.score : (72 + (DateTime.now().millisecond % 23));
    final repo = ApiRepository();
    
    bool success = false;
    int retryAttempts = 3;
    int delaySeconds = 1;

    final double takeDurationSec = (widget.songEnd > widget.songStart)
        ? (widget.songEnd - widget.songStart)
        : (widget.recordedDuration.inMilliseconds / 1000.0);

    while (retryAttempts > 0) {
      try {
        success = await repo.saveRecording(
          widget.song.id,
          exportedFilePath,
          finalScore,
          caption: _captionController.text,
          coverUrl: _customImageUrl ?? _selectedTemplate.imageUrl ?? widget.song.coverUrl,
          visibility: _selectedVisibility,
          songStart: widget.songStart,
          songEnd: widget.songEnd,
          duration: takeDurationSec,
        );
        if (success) break;
      } catch (e) {
        print('[ExportEngine] Save attempt failed: $e. Retrying in ${delaySeconds}s...');
      }

      retryAttempts--;
      if (retryAttempts > 0) {
        await Future.delayed(Duration(seconds: delaySeconds));
        delaySeconds *= 2; // exponential backoff
      }
    }

    if (!success && mounted) {
      final retry = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF161224),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Colors.white12),
          ),
          title: const Text("Export Save Failed", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          content: const Text("We were unable to save your recording to the feed. Would you like to retry?", style: TextStyle(color: Colors.grey, fontSize: 13)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: const Text("Retry Now"),
            ),
          ],
        ),
      );

      if (retry == true) {
        setState(() => _isSaving = false);
        _exportAndSave();
        return;
      }
    }

    if (mounted) {
      setState(() {
        _isSaving = false;
        if (success) {
          _recordingSaved = true;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Rekaman berhasil dipublikasikan! Menyambungkan ke Feed...'),
              backgroundColor: Color(0xFF10B981),
              duration: Duration(seconds: 2),
            ),
          );

          Future.delayed(const Duration(milliseconds: 600), () {
            if (mounted) {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (_) => const MainScreen(initialIndex: 0),
                ),
                (route) => false,
              );
            }
          });
        }
      });
    }
  }

  void _showTemplatePickerSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F0B1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.style, color: Colors.orange, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Pilih Template Visual & Gambar',
                        style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 160,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _availableTemplates.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return GestureDetector(
                        onTap: () {
                          Navigator.pop(ctx);
                          _showCustomUrlDialog();
                        },
                        child: Container(
                          width: 120,
                          margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1735),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.orange.withOpacity(0.5), width: 1.5),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: const BoxDecoration(
                                  color: Colors.orange,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.add_a_photo, color: Colors.black, size: 22),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Ganti Gambar',
                                style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    final template = _availableTemplates[index - 1];
                    final isSelected = _selectedTemplate.id == template.id && _customImageUrl == null;

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedTemplate = template;
                          _customImageUrl = null;
                        });
                        Navigator.pop(ctx);
                      },
                      child: Container(
                        width: 120,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected ? Colors.orange : Colors.white12,
                            width: isSelected ? 2.5 : 1,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(15),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              CachedNetworkImage(
                                imageUrl: template.imageUrl,
                                fit: BoxFit.cover,
                                errorWidget: (context, url, error) => Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(colors: template.gradientColors),
                                  ),
                                ),
                              ),
                              Container(
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [Colors.transparent, Colors.black87],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 8,
                                left: 8,
                                right: 8,
                                child: Text(
                                  template.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              if (isSelected)
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: const BoxDecoration(
                                      color: Colors.orange,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.check, color: Colors.black, size: 12),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _showCustomUrlDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161224),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.white12),
        ),
        title: const Text('Pilih / Input Gambar Kustom', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white, fontSize: 12),
              decoration: InputDecoration(
                hintText: 'Tempel URL Gambar (https://...)',
                hintStyle: const TextStyle(color: Colors.grey, fontSize: 12),
                filled: true,
                fillColor: Colors.black45,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.white24),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Atau pilih gambar latar contoh:', style: TextStyle(color: Colors.grey, fontSize: 11)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildPresetChip(ctx, 'Pantai Sunset', 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=800&q=80'),
                _buildPresetChip(ctx, 'Malam Bintang', 'https://images.unsplash.com/photo-1506703719100-a0f3a48c0f86?w=800&q=80'),
                _buildPresetChip(ctx, 'Lampu Neon', 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=800&q=80'),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                setState(() {
                  _customImageUrl = controller.text.trim();
                });
              }
              Navigator.pop(ctx);
            },
            child: const Text('Gunakan'),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetChip(BuildContext ctx, String label, String url) {
    return ActionChip(
      backgroundColor: const Color(0xFF2A2240),
      label: Text(label, style: const TextStyle(color: Colors.white, fontSize: 10)),
      onPressed: () {
        setState(() {
          _customImageUrl = url;
        });
        Navigator.pop(ctx);
      },
    );
  }

  IconData _getPresetIcon(String iconName) {
    switch (iconName.toLowerCase()) {
      case 'headphones':
      case 'studio':
        return Icons.headphones_outlined;
      case 'warm':
        return Icons.waves;
      case 'bright':
        return Icons.wb_sunny_outlined;
      case 'pop':
        return Icons.music_note_outlined;
      case 'ballad':
        return Icons.favorite_outline;
      case 'acoustic':
        return Icons.music_video_outlined;
      case 'jazz':
        return Icons.library_music_outlined;
      case 'rock':
        return Icons.flash_on_outlined;
      case 'live':
        return Icons.spatial_audio_off;
      case 'ktv':
        return Icons.mic_external_on_outlined;
      default:
        return Icons.radio_outlined;
    }
  }

  Widget _buildSliderRow({
    required String label,
    required double value,
    required double min,
    required double max,
    required String displayValue,
    required ValueChanged<double> onChanged,
    Color color = Colors.orange,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(color: Colors.white70, fontSize: _responsiveFontSize(context, 13.5), fontWeight: FontWeight.bold)),
            Text(displayValue, style: TextStyle(color: color, fontSize: _responsiveFontSize(context, 13.5), fontWeight: FontWeight.bold)),
          ],
        ),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 3.5,
            activeTrackColor: color,
            inactiveTrackColor: Colors.white12,
            thumbColor: Colors.white,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 12.0),
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  void _showAudioMixerBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0D0A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.tune_rounded, color: Colors.orange, size: 22),
                          const SizedBox(width: 8),
                          Text(
                            'Adjust',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: _responsiveFontSize(context, 16.0),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.grey, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Volume Vocal Slider
                  _buildSliderRow(
                    label: 'Volume Vocal',
                    value: _vocalVolume.clamp(0.0, 1.0),
                    min: 0.0,
                    max: 1.0,
                    displayValue: '${(_vocalVolume.clamp(0.0, 1.0) * 100).toInt()}%',
                    onChanged: (val) {
                      setState(() => _vocalVolume = val);
                      setSheetState(() {});
                      _audioEngine.setVocalVolume(val);
                    },
                  ),
                  const SizedBox(height: 14),

                  // Volume Musik Slider
                  _buildSliderRow(
                    label: 'Volume Musik',
                    value: _musicVolume.clamp(0.0, 1.0),
                    min: 0.0,
                    max: 1.0,
                    displayValue: '${(_musicVolume.clamp(0.0, 1.0) * 100).toInt()}%',
                    onChanged: (val) {
                      setState(() => _musicVolume = val);
                      setSheetState(() {});
                      _audioEngine.setInstrumentalVolume(val);
                    },
                  ),
                  const SizedBox(height: 16),

                  // Delay Section (Delay Offset -1000ms to +1000ms)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Delay Compensation',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: _responsiveFontSize(context, 13.5),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.amber.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _latencyOffset >= 0 ? '+${_latencyOffset} ms' : '${_latencyOffset} ms',
                                style: TextStyle(
                                  color: Colors.amber,
                                  fontSize: _responsiveFontSize(context, 12.5),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _latencyOffset = (_latencyOffset - 10).clamp(-1000, 1000);
                                });
                                setSheetState(() {});
                                _audioEngine.setLatencyOffset(_latencyOffset);
                              },
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.08),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white12),
                                ),
                                child: const Icon(Icons.remove, color: Colors.amber, size: 16),
                              ),
                            ),
                            Expanded(
                              child: Column(
                                children: [
                                  SliderTheme(
                                    data: SliderThemeData(
                                      trackHeight: 3.5,
                                      activeTrackColor: Colors.amber,
                                      inactiveTrackColor: Colors.white12,
                                      thumbColor: Colors.amber,
                                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7.0),
                                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 14.0),
                                    ),
                                    child: Slider(
                                      value: _latencyOffset.toDouble().clamp(-1000.0, 1000.0),
                                      min: -1000.0,
                                      max: 1000.0,
                                      divisions: 200,
                                      onChanged: (val) {
                                        setState(() {
                                          _latencyOffset = val.toInt();
                                        });
                                        setSheetState(() {});
                                        _audioEngine.setLatencyOffset(val.toInt());
                                      },
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 14.0),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: List.generate(21, (i) {
                                        final tickVal = -1000 + (i * 100);
                                        final isCenter = tickVal == 0;
                                        final isCurrent = (_latencyOffset - tickVal).abs() < 50;
                                        return Container(
                                          width: isCenter ? 2.0 : 1.0,
                                          height: isCenter ? 8.0 : (i % 5 == 0 ? 6.0 : 4.0),
                                          color: isCurrent
                                              ? Colors.amber
                                              : (isCenter ? Colors.white70 : Colors.white24),
                                        );
                                      }),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _latencyOffset = (_latencyOffset + 10).clamp(-1000, 1000);
                                });
                                setSheetState(() {});
                                _audioEngine.setLatencyOffset(_latencyOffset);
                              },
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.08),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white12),
                                ),
                                child: const Icon(Icons.add, color: Colors.amber, size: 16),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Autotune Control
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.auto_awesome, color: Color(0xFFFF2A54), size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  'Autotune Mode',
                                  style: TextStyle(color: Colors.white, fontSize: _responsiveFontSize(context, 13.5), fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            Text(
                              _autoTuneMode == AutoTuneMode.off
                                  ? 'OFF'
                                  : (_autoTuneMode == AutoTuneMode.natural ? 'Natural' : 'Strong'),
                              style: TextStyle(
                                color: const Color(0xFFFF2A54),
                                fontSize: _responsiveFontSize(context, 12.5),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            _buildAutoTuneOptionSheet(AutoTuneMode.off, 'OFF', Icons.mic_off, setSheetState),
                            const SizedBox(width: 8),
                            _buildAutoTuneOptionSheet(AutoTuneMode.natural, 'Natural', Icons.graphic_eq, setSheetState),
                            const SizedBox(width: 8),
                            _buildAutoTuneOptionSheet(AutoTuneMode.strong, 'Strong', Icons.auto_awesome, setSheetState),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Reverb Slider
                  _buildSliderRow(
                    label: 'Reverb',
                    value: _reverbMix.clamp(0.0, 1.0),
                    min: 0.0,
                    max: 1.0,
                    displayValue: '${(_reverbMix.clamp(0.0, 1.0) * 100).toInt()}%',
                    color: const Color(0xFFFF2A54),
                    onChanged: (val) {
                      setState(() {
                        _reverbMix = val;
                        _reverbEnabled = val > 0.01;
                      });
                      setSheetState(() {});
                      _audioEngine.setReverbEnabled(val > 0.01);
                      _audioEngine.setReverbMix(val);
                    },
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAutoTuneOptionSheet(AutoTuneMode mode, String label, IconData icon, StateSetter setSheetState) {
    final isSelected = _autoTuneMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _autoTuneMode = mode;
          });
          setSheetState(() {});
          _audioEngine.setAutoTuneMode(mode);
          if (mode != AutoTuneMode.off) {
            _audioEngine.setPitchCorrectionEnabled(true);
            _audioEngine.setPitchCorrectionStrength(mode == AutoTuneMode.strong ? 0.9 : 0.5);
          } else {
            _audioEngine.setPitchCorrectionEnabled(false);
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFFF2A54) : Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? const Color(0xFFFF2A54) : Colors.white12,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, size: 16, color: isSelected ? Colors.white : Colors.white60),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white70,
                  fontSize: _responsiveFontSize(context, 12.5),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAutoTuneOption(AutoTuneMode mode, String label, IconData icon) {
    final isSelected = _autoTuneMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _autoTuneMode = mode;
          });
          _audioEngine.setAutoTuneMode(mode);
          if (mode != AutoTuneMode.off) {
            _audioEngine.setPitchCorrectionEnabled(true);
            _audioEngine.setPitchCorrectionStrength(mode == AutoTuneMode.strong ? 0.9 : 0.5);
          } else {
            _audioEngine.setPitchCorrectionEnabled(false);
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFFF2A54) : Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? const Color(0xFFFF2A54) : Colors.white12,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFFFF2A54).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    )
                  ]
                : [],
          ),
          child: Column(
            children: [
              Icon(icon, size: 16, color: isSelected ? Colors.white : Colors.white60),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white70,
                  fontSize: _responsiveFontSize(context, 12.5),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVisibilityButton(String value, IconData icon, String label) {
    final isSelected = _selectedVisibility == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedVisibility = value;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(
            gradient: isSelected
                ? const LinearGradient(
                    colors: [Color(0xFFFF2A54), Color(0xFFFF6A00)],
                  )
                : null,
            color: isSelected ? null : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? Colors.transparent : Colors.white12,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFFFF2A54).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    )
                  ]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected ? Colors.white : Colors.white60,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white70,
                  fontSize: _responsiveFontSize(context, 12.0),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleBackNavigation() async {
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
                onPressed: () async {
                  Navigator.pop(ctx);
                
                  if (!mounted) return;
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
    String getActionButtonLabel() {
      if (_isSaving) return 'Sedang Memproses & Mengunggah...';
      switch (_selectedVisibility) {
        case 'Private':
          return 'Simpan Rekaman (Private)';
        case 'Draft':
          return 'Simpan ke Draft';
        case 'Post':
        default:
          return 'Post';
      }
    }

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
              style: TextStyle(
                color: Colors.white,
                fontSize: _responsiveFontSize(context, 16.0),
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              'C ${widget.score > 0 ? widget.score : 35} Scores',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: _responsiveFontSize(context, 12.5),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.more_horiz, color: Colors.white, size: 22),
            onPressed: () {
              _showTemplatePickerSheet();
            },
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
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 0.0, vertical: 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top Template Carousel & Active Preview Workspace (Full Width)
                  SizedBox(
                    height: 210,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: _availableTemplates.length + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          // "Templates" Button Card
                          return GestureDetector(
                            onTap: _showTemplatePickerSheet,
                            child: Container(
                              width: 90,
                              margin: const EdgeInsets.only(right: 12, top: 4, bottom: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF131023),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white.withOpacity(0.12)),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.06),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.collections_outlined, color: Colors.white, size: 22),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    'Templates',
                                    style: TextStyle(color: Colors.white, fontSize: _responsiveFontSize(context, 12.5), fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        final template = _availableTemplates[index - 1];
                        final isSelected = _selectedTemplate.id == template.id && _customImageUrl == null;

                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedTemplate = template;
                              _customImageUrl = null;
                            });
                          },
                          child: Container(
                            width: 200,
                            margin: const EdgeInsets.only(right: 12, top: 4, bottom: 4),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected ? Colors.orange : Colors.white12,
                                width: isSelected ? 2.5 : 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.4),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                )
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(19),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  CachedNetworkImage(
                                    imageUrl: template.imageUrl,
                                    fit: BoxFit.cover,
                                    errorWidget: (context, url, error) => Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(colors: template.gradientColors),
                                      ),
                                    ),
                                  ),
                                  Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.black.withOpacity(0.2),
                                          Colors.black.withOpacity(0.65),
                                        ],
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(14.0),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: const [
                                            Text('☀️', style: TextStyle(fontSize: 16)),
                                            SizedBox(width: 4),
                                            Text('🎵', style: TextStyle(fontSize: 13, color: Colors.amber)),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          widget.song.lyrics.isNotEmpty
                                              ? widget.song.lyrics.first.text
                                              : "It's been a long and winding journey",
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: _responsiveFontSize(context, 14.5),
                                            fontWeight: FontWeight.bold,
                                            shadows: const [
                                              Shadow(color: Colors.black87, blurRadius: 6, offset: Offset(0, 1)),
                                            ],
                                          ),
                                          textAlign: TextAlign.center,
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 10,
                                    right: 10,
                                    child: GestureDetector(
                                      onTap: _showTemplatePickerSheet,
                                      child: Container(
                                        width: 34,
                                        height: 34,
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.6),
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.white38, width: 1.2),
                                        ),
                                        child: const Icon(
                                          Icons.image_outlined,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Floating Playback Control Bar
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF141022),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white.withOpacity(0.12)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: _togglePlayPause,
                            child: Icon(
                              isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '${_formatDuration(_currentTime)} / ${_formatDuration(_duration)}',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: _responsiveFontSize(context, 13.5),
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            height: 16,
                            width: 1,
                            color: Colors.white24,
                          ),
                          const SizedBox(width: 10),
                          GestureDetector(
                            onTap: _showAudioMixerBottomSheet,
                            child: Row(
                              children: [
                                const Icon(Icons.tune_rounded, color: Colors.orange, size: 18),
                                const SizedBox(width: 4),
                                Text(
                                  'Adjust',
                                  style: TextStyle(
                                    color: Colors.orange,
                                    fontSize: _responsiveFontSize(context, 12.5),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    child: SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 3.0,
                        activeTrackColor: const Color(0xFFFF2A54),
                        inactiveTrackColor: Colors.white.withOpacity(0.08),
                        thumbColor: Colors.white,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5.0),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 10.0),
                      ),
                      child: Slider(
                        value: _currentTime.inMilliseconds.toDouble().clamp(0.0, math.max(100.0, _duration.inMilliseconds.toDouble())),
                        min: 0.0,
                        max: math.max(100.0, _duration.inMilliseconds.toDouble()),
                        onChangeStart: (val) {
                          _isDraggingSlider = true;
                          // Cancel any pending seek when starting a new drag
                          _seekDebounce?.cancel();
                        },
                        onChanged: (val) {
                          setState(() {
                            _currentTime = Duration(milliseconds: val.toInt());
                          });
                        },
                        onChangeEnd: (val) {
                          // DEBOUNCE SEEK: Wait 100ms after user releases slider to prevent rapid seeks
                          _seekDebounce?.cancel();
                          _seekDebounce = Timer(const Duration(milliseconds: 100), () {
                            // CRITICAL: Use ABSOLUTE timeline position for multi-segment vocal playback
                            // val is the absolute position in the song timeline (since we changed _duration to full song duration)
                            final double absoluteSec = val / 1000.0;
                            final double absoluteMs = absoluteSec * 1000.0;
                            
                            // Pause before seek to prevent audio stuttering
                            bool wasPlaying = isPlaying;
                            if (wasPlaying) {
                              _audioEngine.pause();
                              _vinylAnimationController.stop();
                              isPlaying = false;
                            }
                            _audioEngine.seek(Duration(milliseconds: absoluteMs.round()));
                            // Resume after seek completes
                            if (wasPlaying) {
                              Future.delayed(const Duration(milliseconds: 30), () {
                                if (mounted && !_audioEngine.isPlaying()) {
                                  _audioEngine.play();
                                  _vinylAnimationController.repeat();
                                  isPlaying = true;
                                }
                              });
                            }
                          });
                          _isDraggingSlider = false;
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Vocal Style Presets',
                              style: TextStyle(color: Colors.white, fontSize: _responsiveFontSize(context, 14.5), fontWeight: FontWeight.w900),
                            ),
                            if (_loadingPresets)
                              const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFFFF2A54)),
                              )
                          ],
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 110,
                          child: _apiPresets.isEmpty && _loadingPresets
                              ? Center(
                                  child: Text(
                                    'Menghubungi server preset...',
                                    style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: _responsiveFontSize(context, 12.0)),
                                  ),
                                )
                              : ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  physics: const BouncingScrollPhysics(),
                                  itemCount: _apiPresets.length,
                                  itemBuilder: (context, index) {
                                    final preset = _apiPresets[index];
                                    final isSelected = _selectedApiPreset?.id == preset.id;
                                    return GestureDetector(
                                      onTap: () => _applyDynamicPreset(preset),
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 250),
                                        curve: Curves.easeOutCubic,
                                        margin: const EdgeInsets.only(right: 10.0, top: 2, bottom: 4),
                                        width: 86,
                                        decoration: isSelected
                                            ? BoxDecoration(
                                                gradient: const LinearGradient(
                                                  colors: [Color(0xFFFF2A54), Color(0xFFFF6A00)],
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                ),
                                                borderRadius: BorderRadius.circular(16),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: const Color(0xFFFF2A54).withOpacity(0.35),
                                                    blurRadius: 10,
                                                    offset: const Offset(0, 4),
                                                  )
                                                ],
                                              )
                                            : BoxDecoration(
                                                color: const Color(0xFF131023),
                                                borderRadius: BorderRadius.circular(16),
                                                border: Border.all(color: Colors.white.withOpacity(0.06)),
                                              ),
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Container(
                                              width: 36,
                                              height: 36,
                                              decoration: BoxDecoration(
                                                color: isSelected ? Colors.white.withOpacity(0.2) : Colors.white.withOpacity(0.04),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(
                                                _getPresetIcon(preset.icon),
                                                color: Colors.white,
                                                size: 18,
                                              ),
                                            ),
                                            const SizedBox(height: 10),
                                            Text(
                                              preset.name,
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: _responsiveFontSize(context, 12.0),
                                                fontWeight: FontWeight.bold,
                                              ),
                                              textAlign: TextAlign.center,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                        if (_selectedApiPreset != null) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.03),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              _selectedApiPreset!.description,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: _responsiveFontSize(context, 12.0),
                                fontStyle: FontStyle.italic,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Autotune Mode positioned directly below Vocal Style Presets
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0C0817),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withOpacity(0.08)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.auto_awesome, color: Color(0xFFFF2A54), size: 16),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Autotune Mode',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: _responsiveFontSize(context, 13.5),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                _autoTuneMode == AutoTuneMode.off
                                    ? 'OFF'
                                    : (_autoTuneMode == AutoTuneMode.natural ? 'Natural' : 'Strong'),
                                style: TextStyle(
                                  color: const Color(0xFFFF2A54),
                                  fontSize: _responsiveFontSize(context, 12.5),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              _buildAutoTuneOption(AutoTuneMode.off, 'OFF', Icons.mic_off),
                              const SizedBox(width: 8),
                              _buildAutoTuneOption(AutoTuneMode.natural, 'Natural', Icons.graphic_eq),
                              const SizedBox(width: 8),
                              _buildAutoTuneOption(AutoTuneMode.strong, 'Strong', Icons.auto_awesome),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),

          // Bottom Post Metadata & Settings Section (Always fixed at bottom, label removed)
          Container(
            padding: EdgeInsets.only(
              left: 12,
              right: 12,
              top: 12,
              bottom: math.max(12.0, MediaQuery.of(context).padding.bottom + 8),
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF0C0817),
              border: Border(
                top: BorderSide(color: Colors.white.withOpacity(0.12)),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Cover image preview + Caption TextField
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Cover Image selector card
                    GestureDetector(
                      onTap: _showTemplatePickerSheet,
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              width: 72,
                              height: 72,
                              color: const Color(0xFF1F1B2E),
                              child: _customImageUrl != null
                                  ? CachedNetworkImage(
                                      imageUrl: _customImageUrl!,
                                      fit: BoxFit.cover,
                                    )
                                  : CachedNetworkImage(
                                      imageUrl: _selectedTemplate.imageUrl,
                                      fit: BoxFit.cover,
                                    ),
                            ),
                          ),
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: Colors.black38,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.camera_alt_outlined, color: Colors.white, size: 16),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Ubah Cover',
                                    style: TextStyle(color: Colors.white, fontSize: _responsiveFontSize(context, 10.0), fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Caption TextField
                    Expanded(
                      child: TextField(
                        controller: _captionController,
                        maxLines: 2,
                        minLines: 2,
                        style: TextStyle(color: Colors.white, fontSize: _responsiveFontSize(context, 12.5)),
                        decoration: InputDecoration(
                          hintText: 'Ketik caption, cerita, atau hashtag rekaman kamu...',
                          hintStyle: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: _responsiveFontSize(context, 11.5)),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.03),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.white12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.white12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.orange),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Publication status choices: Set to Public, Set to Private
                Row(
                  children: [
                    _buildVisibilityButton('Public', Icons.public_outlined, 'Set to Public'),
                    const SizedBox(width: 8),
                    _buildVisibilityButton('Private', Icons.lock_outline, 'Set to Private'),
                  ],
                ),

                const SizedBox(height: 12),

                // Action buttons: Draft and Post
                Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: SizedBox(
                        height: 42,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(color: Colors.white.withOpacity(0.25)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: _isSaving
                              ? null
                              : () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Rekaman telah disimpan sebagai Draft')),
                                  );
                                  Navigator.pop(context);
                                },
                          icon: const Icon(Icons.drafts_outlined, size: 16),
                          label: Text(
                            'Draft',
                            style: TextStyle(fontSize: _responsiveFontSize(context, 12.5), fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: 42,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF2A54),
                            foregroundColor: Colors.white,
                            elevation: 4,
                            shadowColor: const Color(0xFFFF2A54).withOpacity(0.4),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: _isSaving ? null : _exportAndSave,
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Icon(Icons.send_rounded, size: 15),
                          label: Text(
                            _isSaving ? 'Posting...' : 'Post',
                            style: TextStyle(fontSize: _responsiveFontSize(context, 13.0), fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                if (_recordingSaved) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0x1A00B050),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0x3300B050)),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '🎉 Post Berhasil Dipublikasikan!',
                          style: TextStyle(color: const Color(0xFF10B981), fontSize: _responsiveFontSize(context, 12.5), fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF059669),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          child: Text('Kembali ke Dashboard Feed', style: TextStyle(fontSize: _responsiveFontSize(context, 11.5), fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
}
