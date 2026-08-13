import re

with open("client_flutter/lib/features/record/record_screen.dart", "r") as f:
    content = f.read()

# The extra one was added before `void dispose()` at line 1594
# Let's just remove the block:
block_to_remove = """  @override
    void _applyDynamicPreset(AudioPreset preset) {
    setState(() {
      _selectedApiPreset = preset;
    });
  }

  Future<void> _exportAndSave() async {
    // Stub
  }"""

content = content.replace(block_to_remove, "")

with open("client_flutter/lib/features/record/record_screen.dart", "w") as f:
    f.write(content)
