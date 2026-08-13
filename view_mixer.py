with open('client_flutter/lib/features/record/record_screen.dart', 'r') as f:
    content = f.read()

idx = content.find("if (_showMixerControls)")
if idx != -1:
    print(content[idx:idx+3500])
