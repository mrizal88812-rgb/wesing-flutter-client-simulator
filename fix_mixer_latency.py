with open('client_flutter/lib/features/record/record_screen.dart', 'r') as f:
    content = f.read()

import re

# find `const Text('Latency Delay'`
match = re.search(r"const Text\('Latency Delay'", content)
if match:
    idx = match.start()
    # Go back to find the nearest `const SizedBox(height: 12),`
    sub_content = content[:idx]
    start_idx = sub_content.rfind("const SizedBox(height: 12),")
    
    # Go forward to find `const SizedBox(height: 16);` followed by `ElevatedButton`
    end_idx = content.find("const SizedBox(height: 16),\n                    ElevatedButton(", idx)
    
    if start_idx != -1 and end_idx != -1:
        container_code = content[start_idx:end_idx]
        new_container_code = f"if (_isMixingState) ...[\n                    {container_code}\n                    ],\n                    "
        content = content[:start_idx] + new_container_code + content[end_idx:]
        with open('client_flutter/lib/features/record/record_screen.dart', 'w') as f:
            f.write(content)
        print("Latency section wrapped successfully")
    else:
        print(f"Could not find start ({start_idx}) or end ({end_idx})")
else:
    print("Could not find Latency Delay text")

