#!/bin/bash
sed -i 's/required Map<String, dynamic> effectsSettings,/required KaraokeEffectsSettings settings,/g' client_flutter/lib/services/audio/karaoke_audio_engine.dart
sed -i 's/required Map<String, dynamic> effectsSettings,/required KaraokeEffectsSettings settings,/g' client_flutter/lib/services/audio/native_audio_engine.dart
sed -i 's/required Map<String, dynamic> effectsSettings,/required KaraokeEffectsSettings settings,/g' client_flutter/lib/services/audio/stub_audio_engine.dart
sed -i 's/required Map<String, dynamic> effectsSettings,/required KaraokeEffectsSettings settings,/g' client_flutter/lib/services/audio/web_audio_engine.dart
