import re

with open("client_flutter/lib/features/record/record_screen.dart", "r") as f:
    content = f.read()

methods = """  void _applyDynamicPreset(dynamic preset) {
    setState(() {
      _selectedApiPreset = preset;
    });
  }

  Future<void> _exportAndSave() async {
    // Stub
  }
"""

content = content.replace("void dispose() {", methods + "\n  @override\n  void dispose() {")

with open("client_flutter/lib/features/record/record_screen.dart", "w") as f:
    f.write(content)
