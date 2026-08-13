import re

with open('client_flutter/lib/features/record/record_screen.dart', 'r') as f:
    content = f.read()

# Replace empty tap with a toast
old_tap = """setState(() {
                      _showMixerControls = true;
                    });"""
new_tap = """ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Pro Mix mode available in Studio version!')),
                    );"""

content = content.replace(old_tap, new_tap)

with open('client_flutter/lib/features/record/record_screen.dart', 'w') as f:
    f.write(content)
