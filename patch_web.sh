#!/bin/bash
sed -i "s/effectsSettings\['eqLow'\] as double? ?? 0.0/0.0/g" client_flutter/lib/services/audio/web_audio_engine.dart
sed -i "s/effectsSettings\['eqMid'\] as double? ?? 0.0/0.0/g" client_flutter/lib/services/audio/web_audio_engine.dart
sed -i "s/effectsSettings\['eqHigh'\] as double? ?? 0.0/0.0/g" client_flutter/lib/services/audio/web_audio_engine.dart
sed -i "s/effectsSettings\['compressor'\] as double? ?? 0.5/settings.compressorEnabled ? 0.5 : 0.0/g" client_flutter/lib/services/audio/web_audio_engine.dart
sed -i "s/effectsSettings\['reverb'\] as double? ?? _reverbMix/settings.reverbEnabled ? settings.reverbMix : 0.0/g" client_flutter/lib/services/audio/web_audio_engine.dart
sed -i "s/effectsSettings\['delay'\] as double? ?? _delayMix/settings.delayEnabled ? settings.delayMix : 0.0/g" client_flutter/lib/services/audio/web_audio_engine.dart
sed -i "s/effectsSettings\['echo'\] as double? ?? _delayFeedback/settings.delayEnabled ? settings.delayFeedback : 0.0/g" client_flutter/lib/services/audio/web_audio_engine.dart
