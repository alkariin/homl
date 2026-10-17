import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:homl/data/transfer/export_file.dart';
import 'package:homl/data/transfer/export_seal.dart';

void main() {
  // The real cost is 600 000 rounds: far too slow for the pure Dart
  // implementation the tests run on. The format carries the count anyway.
  const iterations = 1000;
  final plain = utf8.encode('{"format":"homl-export"}');

  test('opens with the password it was sealed with', () async {
    final sealed =
        await ExportSeal.seal(plain, 'correct horse', iterations: iterations);

    expect(ExportSeal.isSealed(sealed), isTrue);
    expect(sealed['kdf']['iterations'], iterations);
    expect(await ExportSeal.open(sealed, 'correct horse'), plain);
  });

  test('never shows the content in clear', () async {
    final sealed = await ExportSeal.seal(
        utf8.encode('my secret diary'), 'correct horse',
        iterations: iterations);
    expect(jsonEncode(sealed), isNot(contains('secret')));
  });

  test('two seals of the same file differ (fresh salt and nonce)', () async {
    final a = await ExportSeal.seal(plain, 'pw-12345', iterations: iterations);
    final b = await ExportSeal.seal(plain, 'pw-12345', iterations: iterations);
    expect(a['kdf']['salt'], isNot(b['kdf']['salt']));
    expect(a['ciphertext'], isNot(b['ciphertext']));
  });

  test('a wrong password is told apart from a broken file', () async {
    final sealed =
        await ExportSeal.seal(plain, 'correct horse', iterations: iterations);
    expect(() => ExportSeal.open(sealed, 'wrong horse'),
        throwsA(isA<ExportPasswordFailure>()));
  });

  test('an altered file does not open', () async {
    final sealed =
        await ExportSeal.seal(plain, 'correct horse', iterations: iterations);
    final bytes = base64.decode(sealed['ciphertext'] as String);
    bytes[0] ^= 1;
    sealed['ciphertext'] = base64.encode(bytes);
    expect(() => ExportSeal.open(sealed, 'correct horse'),
        throwsA(isA<ExportPasswordFailure>()));
  });

  test('refuses a cost that would freeze the app', () async {
    final sealed =
        await ExportSeal.seal(plain, 'correct horse', iterations: iterations);
    (sealed['kdf'] as Map)['iterations'] = 1 << 40;
    expect(() => ExportSeal.open(sealed, 'correct horse'),
        throwsA(isA<ExportFormatFailure>()));
  });

  test('refuses a newer format and unknown algorithms', () async {
    final sealed =
        await ExportSeal.seal(plain, 'correct horse', iterations: iterations);
    expect(() => ExportSeal.open({...sealed, 'version': 2}, 'correct horse'),
        throwsA(isA<ExportVersionFailure>()));
    expect(
        () => ExportSeal.open({...sealed, 'cipher': 'ROT13'}, 'correct horse'),
        throwsA(isA<ExportFormatFailure>()));
  });
}
