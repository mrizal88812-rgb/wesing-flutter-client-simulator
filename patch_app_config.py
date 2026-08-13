import re

with open("client_flutter/lib/core/config/app_config.dart", "r") as f:
    content = f.read()

old_code = """  static String resolveMediaUrl(String url) {
    if (url.startsWith('http')) return url;
    return '$baseUrl$url';
  }"""

new_code = """  static String resolveMediaUrl(String url) {
    if (url.startsWith('http')) return url;
    if (url.startsWith('/data/') || url.startsWith('file://')) return url; // Prevent appending baseUrl to local file paths
    return '$baseUrl$url';
  }"""

content = content.replace(old_code, new_code)

with open("client_flutter/lib/core/config/app_config.dart", "w") as f:
    f.write(content)
