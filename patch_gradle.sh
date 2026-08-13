#!/bin/bash
sed -i '/defaultConfig {/a \        externalNativeBuild {\n            cmake {\n                cppFlags "-std=c++17"\n            }\n        }' client_flutter/android/app/build.gradle

sed -i '/buildTypes {/i \    externalNativeBuild {\n        cmake {\n            path "src/main/cpp/CMakeLists.txt"\n            version "3.22.1"\n        }\n    }\n' client_flutter/android/app/build.gradle
