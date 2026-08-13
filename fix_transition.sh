#!/bin/bash
sed -i '278,574c\
  Future<void> _transitionToMixingState() async {\
    _uiTimer?.cancel();\
    if (_currentTime > Duration.zero) {\
      _recordedDuration = _currentTime;\
    }\
    await _audioEngine.stopRecording();\
    _vinylAnimationController.stop();\
\
    _isNavigatingToMix = true;\
    if (!mounted) return;\
\
    Navigator.pushReplacement(\
      context,\
      MaterialPageRoute(\
        builder: (context) => EditRecordingScreen(\
          song: widget.song,\
          audioEngine: _audioEngine,\
          recordedDuration: _recordedDuration > Duration.zero ? _recordedDuration : _duration,\
          score: _score,\
        ),\
      ),\
    );\
  }\
\
  Widget _buildRecordingView() {' client_flutter/lib/features/record/record_screen.dart
