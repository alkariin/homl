import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homl/helpers/pin_verifier.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const storageChannel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  late Map<String, String> storage;

  setUpAll(() {
    // Pure Dart PBKDF2 in the tests: keep it cheap.
    PinVerifier.iterations = 1000;
  });

  setUp(() {
    storage = {};
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, (call) async {
      final args = (call.arguments as Map?)?.cast<String, dynamic>();
      switch (call.method) {
        case 'read':
          return storage[args!['key'] as String];
        case 'write':
          storage[args!['key'] as String] = args['value'] as String;
          return null;
        case 'delete':
          storage.remove(args!['key'] as String);
          return null;
        case 'containsKey':
          return storage.containsKey(args!['key'] as String);
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, null);
  });

  test('without a stored PIN there is nothing to check against', () async {
    expect(await PinVerifier.verify('1234'), OfflinePinCheck.unavailable);
  });

  test('stores a salted hash, never the PIN itself', () async {
    await PinVerifier.store('1234');

    final stored = storage['pinVerifier']!;
    expect(stored, isNot(contains('1234')));
    expect(await PinVerifier.verify('1234'), OfflinePinCheck.match);

    // A fresh salt each time: the same PIN never stores the same hash.
    await PinVerifier.store('1234');
    expect(storage['pinVerifier'], isNot(stored));
  });

  test('counts the wrong PINs and locks at the third, like the server',
      () async {
    await PinVerifier.store('1234');

    expect(await PinVerifier.verify('0000'), OfflinePinCheck.mismatch);
    expect(await PinVerifier.remainingTries(), 2);
    expect(await PinVerifier.verify('0001'), OfflinePinCheck.mismatch);
    expect(await PinVerifier.remainingTries(), 1);
    expect(await PinVerifier.verify('0002'), OfflinePinCheck.locked);

    // Even the right PIN is refused once locked.
    expect(await PinVerifier.verify('1234'), OfflinePinCheck.locked);
  });

  test('the right PIN resets the count', () async {
    await PinVerifier.store('1234');

    await PinVerifier.verify('0000');
    await PinVerifier.verify('0001');
    expect(await PinVerifier.verify('1234'), OfflinePinCheck.match);
    expect(await PinVerifier.remainingTries(), PinVerifier.maxOfflineTries);
  });

  test('a PIN accepted online again resets the count too', () async {
    await PinVerifier.store('1234');
    await PinVerifier.verify('0000');

    await PinVerifier.store('1234');

    expect(await PinVerifier.remainingTries(), PinVerifier.maxOfflineTries);
  });

  test('clear forgets the PIN and the count', () async {
    await PinVerifier.store('1234');
    await PinVerifier.verify('0000');

    await PinVerifier.clear();

    expect(storage, isEmpty);
    expect(await PinVerifier.verify('1234'), OfflinePinCheck.unavailable);
  });

  test('an unreadable entry is dropped, not trusted', () async {
    storage['pinVerifier'] = 'not json';

    expect(await PinVerifier.verify('1234'), OfflinePinCheck.unavailable);
    expect(storage.containsKey('pinVerifier'), isFalse);
  });

  test('a hash keeps the iteration count it was made with', () async {
    await PinVerifier.store('1234');
    final previous = PinVerifier.iterations;
    PinVerifier.iterations = 2000;
    addTearDown(() => PinVerifier.iterations = previous);

    expect(await PinVerifier.verify('1234'), OfflinePinCheck.match);
  });
}
