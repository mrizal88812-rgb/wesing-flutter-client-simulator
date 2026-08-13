import 'package:flutter_test/flutter_test.dart';
import '../lib/core/config/app_config.dart';

void main() {
  group('AppConfig Tests', () {
    test('apiUrl appends /api to baseUrl', () {
      expect(AppConfig.apiUrl, '${AppConfig.baseUrl}/api');
    });

    test('resolveMediaUrl returns original URL if starting with http', () {
      const fullUrl = 'https://example.com/audio.mp3';
      expect(AppConfig.resolveMediaUrl(fullUrl), fullUrl);
    });

    test('resolveMediaUrl prepends baseUrl for relative path', () {
      const relativePath = '/media/song.mp3';
      expect(AppConfig.resolveMediaUrl(relativePath), '${AppConfig.baseUrl}$relativePath');
    });
  });
}
