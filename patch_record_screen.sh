#!/bin/bash
sed -i '/bool _useVideo = false;/a \  bool _loadingPresets = false;\n  List<dynamic> _apiPresets = [];\n  dynamic _selectedApiPreset = null;\n  bool _recordingSaved = false;\n  bool _isSaving = false;' client_flutter/lib/features/record/record_screen.dart
