import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homl/data/models/settings.dart';
import 'package:homl/helpers/e2ee.dart';
import 'package:homl/helpers/language.dart';

/// In-memory stand-in for flutter_secure_storage, mirroring the harness the
/// other cubit tests use.
void _mockSecureStorage() {
  final store = <String, String>{};
  const channel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  TestWidgetsFlutterBinding.ensureInitialized();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async {
    final args = (call.arguments as Map).cast<String, dynamic>();
    switch (call.method) {
      case 'write':
        store[args['key'] as String] = args['value'] as String;
        return null;
      case 'read':
        return store[args['key'] as String];
      case 'delete':
        store.remove(args['key'] as String);
        return null;
      case 'containsKey':
        return store.containsKey(args['key'] as String);
      case 'readAll':
        return store;
      case 'deleteAll':
        store.clear();
        return null;
    }
    return null;
  });
}

void main() {
  setUp(() {
    _mockSecureStorage();
    E2ee().lock();
  });

  group('E2ee crypto', () {
    test('encrypt/decrypt round-trips and produces a versioned blob',
        () async {
      final e2ee = E2ee();
      await e2ee.prepareEnable();
      await e2ee.commitEnable();

      final blob = await e2ee.encrypt('Movie night 🎬');
      expect(blob.startsWith(E2ee.prefix), isTrue);
      expect(await e2ee.decrypt(blob), 'Movie night 🎬');
    });

    test('encryption is non-deterministic (random nonce)', () async {
      final e2ee = E2ee();
      await e2ee.prepareEnable();
      await e2ee.commitEnable();

      final a = await e2ee.encrypt('Holidays');
      final b = await e2ee.encrypt('Holidays');
      expect(a, isNot(b));
      expect(await e2ee.decrypt(a), await e2ee.decrypt(b));
    });

    test('decrypt returns non-blob values verbatim', () async {
      final e2ee = E2ee();
      await e2ee.prepareEnable();
      await e2ee.commitEnable();
      expect(await e2ee.decrypt('plain legacy value'), 'plain legacy value');
    });

    test('blind index is deterministic and normalization-insensitive',
        () async {
      final e2ee = E2ee();
      await e2ee.prepareEnable();
      await e2ee.commitEnable();

      final a = await e2ee.tagIndex('movie NIGHT');
      final b = await e2ee.tagIndex('Movie Night');
      expect(a, b);
      expect(a.length, 32);
      expect(RegExp(r'^[0-9a-f]+$').hasMatch(a), isTrue);
    });

    test('keyCheck is 64 lowercase hex chars', () async {
      final e2ee = E2ee();
      await e2ee.prepareEnable();
      await e2ee.commitEnable();
      final check = await e2ee.keyCheck();
      expect(check.length, 64);
      expect(RegExp(r'^[0-9a-f]+$').hasMatch(check), isTrue);
    });

    test('blacklist mirrors the English month names', () {
      final e2ee = E2ee();
      expect(e2ee.isBlacklistedTag('july'), isTrue);
      expect(e2ee.isBlacklistedTag('DECEMBER'), isTrue);
      expect(e2ee.isBlacklistedTag('Cinema'), isFalse);
    });
  });

  group('E2ee lifecycle', () {
    test('a committed key survives lock + unlock and verifies its key check',
        () async {
      final e2ee = E2ee();
      await e2ee.prepareEnable();
      await e2ee.commitEnable();
      final blob = await e2ee.encrypt('secret');
      final check = await e2ee.keyCheck();

      e2ee.lock();
      expect(e2ee.enabled, isFalse);

      final settings = Settings(
          language: Language.en,
          defaultScreen: false,
          isE2eeEnabled: true,
          e2eeKeyCheck: check);
      expect(await e2ee.unlock(settings), isTrue);
      expect(e2ee.enabled, isTrue);
      expect(await e2ee.decrypt(blob), 'secret');
    });

    test('unlock blocks (returns false) when no key is stored', () async {
      final settings = Settings(
          language: Language.en,
          defaultScreen: false,
          isE2eeEnabled: true,
          e2eeKeyCheck: 'deadbeef');
      expect(await E2ee().unlock(settings), isFalse);
      expect(E2ee().enabled, isFalse);
    });

    test('unlock is a no-op when the account is not E2EE', () async {
      final settings = Settings(language: Language.en, defaultScreen: false);
      expect(await E2ee().unlock(settings), isTrue);
      expect(E2ee().enabled, isFalse);
    });

    test('a wrong recovery phrase does not unlock', () async {
      // Enable and capture the server-side key check.
      await E2ee().prepareEnable();
      await E2ee().commitEnable();
      final check = await E2ee().keyCheck();
      E2ee().lock();

      final restored = await E2ee().restore(
          'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about',
          check);
      expect(restored, isFalse);
      expect(E2ee().enabled, isFalse);
    });

    test('the correct recovery phrase restores the key', () async {
      // A fresh device: derive the phrase, then simulate typing it back.
      final mnemonic = await E2ee().prepareEnable();
      final check = await E2ee().keyCheck();
      final probe = await E2ee().encrypt('note');
      E2ee().abortEnable();

      final restored = await E2ee().restore(mnemonic, check);
      expect(restored, isTrue);
      expect(await E2ee().decrypt(probe), 'note');
    });

    test('disable wipes the key', () async {
      await E2ee().prepareEnable();
      await E2ee().commitEnable();
      expect(E2ee().enabled, isTrue);

      await E2ee().disable();
      expect(E2ee().enabled, isFalse);

      // A subsequent unlock with the server flag still set now blocks.
      final settings = Settings(
          language: Language.en, defaultScreen: false, isE2eeEnabled: true);
      expect(await E2ee().unlock(settings), isFalse);
    });
  });
}
