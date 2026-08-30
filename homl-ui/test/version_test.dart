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
}
