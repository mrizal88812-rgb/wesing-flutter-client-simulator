#!/bin/bash
sed -i 's/    return Duration.zero; \/\/ Fallback if not tracked/    return _lastPosition;/g' client_flutter/lib/services/audio/native_audio_engine.dart
sed -i '/Duration _duration = Duration.zero;/a \  Duration _lastPosition = Duration.zero;' client_flutter/lib/services/audio/native_audio_engine.dart
sed -i 's/        _positionController.add(Duration(milliseconds: (event \* 1000).toInt()));/        _lastPosition = Duration(milliseconds: (event \* 1000).toInt());\n        _positionController.add(_lastPosition);/g' client_flutter/lib/services/audio/native_audio_engine.dart
sed -i 's/        _positionController.add(Duration(milliseconds: (event.toDouble() \* 1000).toInt()));/        _lastPosition = Duration(milliseconds: (event.toDouble() \* 1000).toInt());\n        _positionController.add(_lastPosition);/g' client_flutter/lib/services/audio/native_audio_engine.dart
