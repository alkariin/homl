import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homl/helpers/version.dart';

void main() {
  group('healthzUrl', () {
    test('strips the /api suffix', () {
      expect(healthzUrl('http://localhost:8080/api'),
          'http://localhost:8080/healthz');
    });

    test('keeps a proxy sub-path', () {
      expect(healthzUrl('https://nas.example/homl/api'),
          'https://nas.example/homl/healthz');
    });

    test('tolerates a trailing slash and a bare origin', () {
      expect(healthzUrl('https://homl.example/api/'),
          'https://homl.example/healthz');
      expect(
          healthzUrl('https://homl.example'), 'https://homl.example/healthz');
    });
  });

  group('clientLabel', () {
    test('the platform and the version', () {
      expect(
          clientLabel(
              isWeb: false, platform: TargetPlatform.android, version: '0.5.0'),
          'android 0.5.0');
      expect(
          clientLabel(
              isWeb: false, platform: TargetPlatform.iOS, version: '0.5.0'),
          'ios 0.5.0');
      expect(
          clientLabel(
              isWeb: false, platform: TargetPlatform.macOS, version: '0.5.0'),
          'macos 0.5.0');
    });

    test('a browser is the web, whatever it runs on', () {
      expect(
          clientLabel(
              isWeb: true, platform: TargetPlatform.android, version: '0.5.0'),
          'web 0.5.0');
    });

    test('without a version, the platform alone', () {
      expect(
          clientLabel(isWeb: false, platform: TargetPlatform.linux), 'linux');
      expect(
          clientLabel(
              isWeb: false, platform: TargetPlatform.windows, version: ''),
          'windows');
    });
  });
}
