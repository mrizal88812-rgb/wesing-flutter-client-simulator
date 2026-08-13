with open('client_flutter/lib/data/repositories_impl.dart', 'r') as f:
    content = f.read()

# Find the last closing brace of the class before the method
# The class ends with:
#     ];
#   }
# }
#   Future<List<dynamic>> fetchPresets() async {

import re

# We can replace "}\n  Future<List<dynamic>> fetchPresets() async {"
# with "  Future<List<dynamic>> fetchPresets() async {"
# and append "}\n" at the very end.

content = content.replace("}\n  Future<List<dynamic>> fetchPresets() async {", "  Future<List<dynamic>> fetchPresets() async {")
if not content.endswith("}"):
    content = content.rstrip() + "\n}\n"
else:
    # already ends with }?
    # Let's just do a string replacement that's safer.
    pass

# A safer approach:
# Just take everything from "  Future<List<dynamic>> fetchPresets()" to the end,
# remove it, insert it before the last '}' of the class.

with open('client_flutter/lib/data/repositories_impl.dart', 'r') as f:
    lines = f.readlines()

new_lines = []
in_fetch_presets = False
fetch_presets_lines = []

for line in lines:
    if "Future<List<dynamic>> fetchPresets() async {" in line and not in_fetch_presets:
        in_fetch_presets = True
    
    if in_fetch_presets:
        fetch_presets_lines.append(line)
    else:
        new_lines.append(line)

# The last line of new_lines should be the closing brace of the class
while new_lines and new_lines[-1].strip() == "":
    new_lines.pop()

if new_lines and new_lines[-1].strip() == "}":
    new_lines.pop() # remove the closing brace

# Add the fetch_presets_lines
new_lines.extend(fetch_presets_lines)

# Add the closing brace back
new_lines.append("}\n")

with open('client_flutter/lib/data/repositories_impl.dart', 'w') as f:
    f.writelines(new_lines)

print("Fixed repositories_impl.dart")
