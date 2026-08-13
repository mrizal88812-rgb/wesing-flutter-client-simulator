cmake_minimum_required(VERSION 3.10.2)
project("karaoke_dsp")

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_library(
    karaoke_dsp
    SHARED
    jni_bridge.cpp
    dsp_processor.cpp
)
find_library(log-lib log)
find_library(aaudio-lib aaudio)
target_link_libraries(
    karaoke_dsp
    ${log-lib}
    ${aaudio-lib}
)
