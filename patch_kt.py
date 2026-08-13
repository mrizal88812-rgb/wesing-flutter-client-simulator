import re

with open("client_flutter/android/app/src/main/kotlin/com/okamiaaww/app/AudioDecoder.kt", "r") as f:
    content = f.read()

old_code = """        val extractor = MediaExtractor()
        try {
            extractor.setDataSource(filePath)"""

new_code = """        val extractor = MediaExtractor()
        try {
            val fis = java.io.FileInputStream(java.io.File(filePath))
            extractor.setDataSource(fis.fd)
            fis.close()"""

content = content.replace(old_code, new_code)

with open("client_flutter/android/app/src/main/kotlin/com/okamiaaww/app/AudioDecoder.kt", "w") as f:
    f.write(content)
