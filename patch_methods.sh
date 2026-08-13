#!/bin/bash
cat << 'DART' > methods.dart
  void _applyDynamicPreset(dynamic preset) {
    setState(() {
      _selectedApiPreset = preset;
    });
  }

  Future<void> _exportAndSave() async {
    // Stub
  }
DART
sed -i '/void dispose() {/i \'"$(cat methods.dart)"'' client_flutter/lib/features/record/record_screen.dart
