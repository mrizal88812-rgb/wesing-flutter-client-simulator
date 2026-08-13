import re

with open("client_flutter/android/app/src/main/cpp/aaudio_engine.h", "r") as f:
    content = f.read()

stop_input_code = """    void stopInput() {
        if (inputStream) {
            AAudioStream_requestStop(inputStream);
            AAudioStream_close(inputStream);
            inputStream = nullptr;
        }
    }
    
    void stop() {"""

content = content.replace("    void stop() {", stop_input_code)

with open("client_flutter/android/app/src/main/cpp/aaudio_engine.h", "w") as f:
    f.write(content)
