with open('client_flutter/lib/features/record/record_screen.dart', 'r') as f:
    content = f.read()

old_code = """                // Adjust Button
                GestureDetector(
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Pro Mix mode available in Studio version!')),
                    );
                  },"""

new_code = """                // Adjust Button
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _showMixerControls = true;
                    });
                  },"""

if old_code in content:
    content = content.replace(old_code, new_code)
    with open('client_flutter/lib/features/record/record_screen.dart', 'w') as f:
        f.write(content)
    print("Replaced Adjust button successfully.")
else:
    print("Could not find Adjust button code.")
