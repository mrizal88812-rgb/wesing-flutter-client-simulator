#!/bin/bash
sed -i '1052,1242c\
      body: _buildRecordingView(),\
    );\
  }\
}' client_flutter/lib/features/record/record_screen.dart
