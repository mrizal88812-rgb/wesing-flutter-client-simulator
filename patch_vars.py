import re

with open("client_flutter/lib/features/record/record_screen.dart", "r") as f:
    content = f.read()

content = content.replace("List<dynamic> _apiPresets = [];", "List<AudioPreset> _apiPresets = [];")
content = content.replace("dynamic _selectedApiPreset = null;", "AudioPreset? _selectedApiPreset;")
content = content.replace("void _applyDynamicPreset(dynamic preset)", "void _applyDynamicPreset(AudioPreset preset)")

with open("client_flutter/lib/features/record/record_screen.dart", "w") as f:
    f.write(content)
