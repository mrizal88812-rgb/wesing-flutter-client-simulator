import 'package:flutter/foundation.dart';

class AppConfig {
  // Public AI Studio URL untuk Cloud Run instance saat ini
  static const String _publicBackendUrl = 'http://192.168.1.203:3000';
  
  static const String _localEmulatorUrl ='http://192.168.1.203:3000'; // Android Emulator -> Host Machine localhost:3000
  static const String _localSimulatorUrl = 'http://192.168.1.203:3000'; // iOS Simulator
  static const String _localWebUrl = 'http://192.168.1.203:3000'; // Web Local

  static String get baseUrl {
    if (kIsWeb) {
      final origin = Uri.base.origin;
      if (origin.isNotEmpty && origin != 'null') {
        return origin;
      }
      return _localWebUrl;
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return _localEmulatorUrl;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return _localSimulatorUrl;
    }
    return _publicBackendUrl;
  }

  static String get apiUrl => '$baseUrl/api';

  static String resolveMediaUrl(String url) {
    if (url.isEmpty) return '';
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    if (url.startsWith('blob:') || url.startsWith('data:') || url.startsWith('file://')) return url;
    
    // Prevent appending baseUrl to absolute local file paths on mobile
    if (url.startsWith('/data/') || url.startsWith('/var/') || url.startsWith('/Users/') || url.startsWith('/storage/emulated/')) {
      return url; 
    }
    
    final base = baseUrl;
    if (url.startsWith('/')) {
      return '$base$url';
    }
    return '$base/$url';
  }
}

