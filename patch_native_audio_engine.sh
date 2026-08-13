#!/bin/bash
sed -i 's/Stream<Duration> get positionStream => _positionController.stream;/Stream<Duration> get onPositionChanged => _positionController.stream;\n\n  @override\n  Duration getPlaybackPosition() {\n    return Duration.zero; \/\/ Fallback if not tracked\n  }/g' client_flutter/lib/services/audio/native_audio_engine.dart
