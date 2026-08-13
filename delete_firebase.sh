#!/bin/bash
# Remove google-services from settings.gradle if not already
sed -i 's/id "com.google.gms.google-services".*//g' client_flutter/android/settings.gradle
# Remove firebase from build.gradle
sed -i 's/id "com.google.gms.google-services".*//g' client_flutter/android/app/build.gradle
