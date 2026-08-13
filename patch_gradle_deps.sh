#!/bin/bash
sed -i '/dependencies {/a \    implementation "org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3"' client_flutter/android/app/build.gradle
