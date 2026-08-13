import re

with open("client_flutter/lib/features/record/record_screen.dart", "r") as f:
    content = f.read()

methods = """
  void _applyDynamicPreset(AudioPreset preset) {
    setState(() {
      _selectedApiPreset = preset;
    });
  }

  Future<void> _exportAndSave() async {
    // Stub
  }
"""

content = content.replace("void dispose() {", methods + "  @override\n  void dispose() {", 1)

with open("client_flutter/lib/features/record/record_screen.dart", "w") as f:
    f.write(content)
