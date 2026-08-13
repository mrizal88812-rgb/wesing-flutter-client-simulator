#!/bin/bash
sed -i 's/Stream<Duration> get onPositionChanged => _positionController.stream;/\@override\n  Stream<Duration> get onPositionChanged => _positionController.stream;/g' client_flutter/lib/services/audio/native_audio_engine.dart
