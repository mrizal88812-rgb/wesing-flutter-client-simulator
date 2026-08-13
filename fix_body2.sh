#!/bin/bash
sed -i '1527,1716c\
      body: _buildRecordingView(),\
    );\
  }\
}' client_flutter/lib/features/record/record_screen.dart
