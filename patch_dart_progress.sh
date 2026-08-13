#!/bin/bash
sed -i '/"exportMix" -> {/i \            "getExportProgress" -> {\n                result.success(getExportProgress().toDouble())\n            }' client_flutter/android/app/src/main/kotlin/com/okamiaaww/app/KaraokeDspEngine.kt
