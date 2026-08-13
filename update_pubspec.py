with open('client_flutter/pubspec.yaml', 'r') as f:
    lines = f.readlines()

new_lines = []
for line in lines:
    if line.strip().startswith('record:'):
        new_lines.append('  record: ^5.0.5\n')
    else:
        new_lines.append(line)

new_lines.append('\n')
new_lines.append('dependency_overrides:\n')
new_lines.append('  record_linux: ^0.5.0\n')
new_lines.append('  record_platform_interface: 1.0.2\n')

with open('client_flutter/pubspec.yaml', 'w') as f:
    f.writelines(new_lines)
