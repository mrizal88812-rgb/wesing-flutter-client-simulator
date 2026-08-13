import re

with open('client_flutter/lib/features/record/record_screen.dart', 'r') as f:
    content = f.read()

# 1. Add AudioPreset import
if "import '../../data/models/audio_preset.dart';" not in content:
    content = content.replace("import '../../data/models/pitch_data.dart';", "import '../../data/models/pitch_data.dart';\nimport '../../data/models/audio_preset.dart';")

# 2. Add preset list variable
if "List<AudioPreset> _availablePresets = [];" not in content:
    content = content.replace("bool _showMixerControls = false;", "bool _showMixerControls = false;\n  List<AudioPreset> _availablePresets = [];\n  String _activePresetId = 'studio';")

# 3. Add fetchPresets logic inside _initEngine
if "await _fetchPresets();" not in content:
    content = content.replace("await _audioEngine.loadInstrumental(AppConfig.resolveMediaUrl(widget.song.audioUrl));", "await _fetchPresets();\n    await _audioEngine.loadInstrumental(AppConfig.resolveMediaUrl(widget.song.audioUrl));")

# 4. Add _fetchPresets method
if "Future<void> _fetchPresets() async {" not in content:
    fetch_method = """
  Future<void> _fetchPresets() async {
    try {
      final repo = ApiRepository();
      final data = await repo.fetchPresets();
      setState(() {
        _availablePresets = data.map((e) => AudioPreset.fromJson(e)).toList();
        if (_availablePresets.isNotEmpty) {
           _activePresetId = _availablePresets.first.id;
        }
      });
    } catch (e) {
      print('Failed to fetch presets: $e');
    }
  }
"""
    content = content.replace("Future<void> _initEngine() async {", fetch_method + "\n  Future<void> _initEngine() async {")

# 5. Add apply method for AudioPreset
if "void _applyDynamicPreset(AudioPreset p) {" not in content:
    apply_method = """
  void _applyDynamicPreset(AudioPreset p) {
    setState(() {
      _activePresetId = p.id;
      if (p.dsp != null) {
         _reverbEnabled = p.dsp!.reverb > 0;
         _reverbMix = p.dsp!.reverb;
         _delayEnabled = p.dsp!.delay > 0;
         _delayMix = p.dsp!.delay;
         _compressorEnabled = p.dsp!.compressor > 0;
         _eqEnabled = p.dsp!.eqLow > 0 || p.dsp!.eqMid > 0 || p.dsp!.eqHigh > 0;
         
         // Apply to real engine
         _audioEngine.setReverbEnabled(_reverbEnabled);
         _audioEngine.setReverbMix(_reverbMix);
         _audioEngine.setDelayEnabled(_delayEnabled);
         _audioEngine.setDelayMix(_delayMix);
         _audioEngine.setCompressorEnabled(_compressorEnabled);
         _audioEngine.setEQEnabled(_eqEnabled);
         
         if (_eqEnabled) {
             _audioEngine.setEQBand(1, 150, p.dsp!.eqLow * 100, 1.0);
             _audioEngine.setEQBand(2, 2500, p.dsp!.eqMid * 100, 1.0);
             _audioEngine.setEQBand(3, 8000, p.dsp!.eqHigh * 100, 1.0);
         }
      }
    });
  }
"""
    content = content.replace("void _applyPresetEffect(KaraokePreset p) {", apply_method + "\n  void _applyPresetEffect(KaraokePreset p) {")

with open('client_flutter/lib/features/record/record_screen.dart', 'w') as f:
    f.write(content)

print("Updates applied to RecordScreen state logic.")
