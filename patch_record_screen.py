import re

with open("client_flutter/lib/features/record/record_screen.dart", "r") as f:
    content = f.read()

content = content.replace("bool _monitoringEnabled = true;", "bool _monitoringEnabled = false;")

with open("client_flutter/lib/features/record/record_screen.dart", "w") as f:
    f.write(content)
