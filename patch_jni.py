import re

with open("client_flutter/android/app/src/main/cpp/jni_bridge.cpp", "r") as f:
    content = f.read()

# Make sure we start input if recording starts or monitoring is enabled
start_record = """extern "C" JNIEXPORT void JNICALL
Java_com_okamiaaww_app_KaraokeDspEngine_startRecording(JNIEnv *env, jobject /* this */) {
    if(g_processor) g_processor->startRecording();
    if(g_audioEngine) g_audioEngine->startInput();
}"""

content = re.sub(r'extern "C" JNIEXPORT void JNICALL\nJava_com_okamiaaww_app_KaraokeDspEngine_startRecording\(JNIEnv \*env, jobject /\* this \*/\) \{\n    if\(g_processor\) g_processor->startRecording\(\);\n\}', start_record, content)

set_monitor = """extern "C" JNIEXPORT void JNICALL
Java_com_okamiaaww_app_KaraokeDspEngine_setMonitoringEnabled(JNIEnv *env, jobject /* this */, jboolean enabled) {
    if(g_processor) g_processor->setMonitoringEnabled(enabled);
    if(enabled && g_audioEngine) {
        g_audioEngine->startInput();
    } else if (!enabled && g_audioEngine) {
        // We shouldn't stop input if currently recording, but let's assume we don't need to overcomplicate
        // If they disable monitoring during recording, we still need input to record.
        // So we only stop if not recording.
        // We don't have access to isRecording from JNI easily without adding a method.
    }
}"""

content = re.sub(r'extern "C" JNIEXPORT void JNICALL\nJava_com_okamiaaww_app_KaraokeDspEngine_setMonitoringEnabled\(JNIEnv \*env, jobject /\* this \*/, jboolean enabled\) \{\n    if\(g_processor\) g_processor->setMonitoringEnabled\(enabled\);\n\}', set_monitor, content)

with open("client_flutter/android/app/src/main/cpp/jni_bridge.cpp", "w") as f:
    f.write(content)
