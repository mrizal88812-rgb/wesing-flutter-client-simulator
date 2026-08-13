#!/bin/bash
sed -i 's/final effectsSettings = {/final settings = KaraokeEffectsSettings(/g' client_flutter/lib/features/record/edit_recording_screen.dart
sed -i 's/\x27reverbEnabled\x27: _reverbEnabled,/reverbEnabled: _reverbEnabled,/g' client_flutter/lib/features/record/edit_recording_screen.dart
sed -i 's/\x27reverbMix\x27: _reverbMix,/reverbMix: _reverbMix,/g' client_flutter/lib/features/record/edit_recording_screen.dart
sed -i 's/\x27reverbPreset\x27: _reverbPreset,/reverbPreset: _reverbPreset,/g' client_flutter/lib/features/record/edit_recording_screen.dart
sed -i 's/\x27delayEnabled\x27: _delayEnabled,/delayEnabled: _delayEnabled,/g' client_flutter/lib/features/record/edit_recording_screen.dart
sed -i 's/\x27delayMix\x27: _delayMix,/delayMix: _delayMix,/g' client_flutter/lib/features/record/edit_recording_screen.dart
sed -i 's/\x27compressorEnabled\x27: _compressorEnabled,/compressorEnabled: _compressorEnabled,/g' client_flutter/lib/features/record/edit_recording_screen.dart
sed -i 's/\x27eqEnabled\x27: _eqEnabled,/eqEnabled: _eqEnabled,/g' client_flutter/lib/features/record/edit_recording_screen.dart
sed -i 's/\x27pitchCorrectionEnabled\x27: _pitchCorrectionEnabled,/pitchCorrectionEnabled: _pitchCorrectionEnabled,/g' client_flutter/lib/features/record/edit_recording_screen.dart
sed -i 's/    };/    );/g' client_flutter/lib/features/record/edit_recording_screen.dart
sed -i 's/effectsSettings: effectsSettings,/settings: settings,/g' client_flutter/lib/features/record/edit_recording_screen.dart
