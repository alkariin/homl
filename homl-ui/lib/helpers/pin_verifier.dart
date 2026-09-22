import 'dart:convert';
import 'dart:developer';
import 'dart:math' show Random, max;

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';

import 'package:homl/helpers/local_storage_manager.dart';

/// Outcome of an offline PIN check.
enum OfflinePinCheck {
  /// No PIN was accepted by the server on this device yet: nothing to check
  /// against, the PIN only works online for now.
  unavailable,
  match,
  mismatch,

  /// The offline tries are used up: the caller ends the session, exactly
  /// like the server's PIN lockout.
  locked,
}

/// Offline check of the PIN, so a PIN account can open the data saved on
/// the device while the server is unreachable
/// (homl-web/docs/auth-flows.md, "Offline unlock").
///
/// The server stays the authority on the PIN: it holds the real copy and a
/// hard lockout. For the offline case the device keeps a PBKDF2 hash of the
/// last PIN the server accepted here, plus its own counter mirroring that
/// lockout. The trade-off, stated in the docs: whoever can read the secure
/// storage of the phone could brute-force the PIN on another machine. They
/// could read the cached data anyway, but the recovered PIN would also pass
/// the server's second factor until the password is changed.
class PinVerifier {
  PinVerifier._();

  /// Mirrors `user.MaxPinTries` on the backend.
  static const maxOfflineTries = 3;

  /// OWASP's PBKDF2-HMAC-SHA256 recommendation. Native on Android and iOS
  /// (cryptography_flutter), a few hundred milliseconds per check.
  static const defaultIterations = 600000;

  /// Lowered by the tests, which run the pure Dart implementation. Each
  /// stored hash carries its own count, so changing it never invalidates one.
  @visibleForTesting
  static int iterations = defaultIterations;

  static const _saltLength = 16;

  /// Stores [pin] as the one to accept offline. Call it only once the server
  /// has accepted that PIN. Never throws: without it the PIN only works
  /// online until the next online check, which is no reason to fail the
  /// unlock (or the PIN setup) the server just accepted.
  static Future<void> store(String pin) async {
    try {
      await _store(pin);
    } catch (error) {
      log('Offline PIN could not be stored', name: 'PinVerifier', error: error);
    }
  }

  static Future<void> _store(String pin) async {
    final random = Random.secure();
    final salt = List<int>.generate(_saltLength, (_) => random.nextInt(256));
    final hash = await _derive(pin, salt, iterations);
    await LocalStorageManager.setValue(
        LocalStorageKey.pinVerifier,
        jsonEncode({
          'v': 1,
          'kdf': 'pbkdf2-sha256',
          'iterations': iterations,
          'salt': base64.encode(salt),
          'hash': base64.encode(hash),
        }));
    await LocalStorageManager.remove(LocalStorageKey.pinOfflineFailures);
  }

  /// Checks [pin] against the stored hash and counts the failures.
  static Future<OfflinePinCheck> verify(String pin) async {
    final raw = await LocalStorageManager.getValue(LocalStorageKey.pinVerifier);
    if (raw == null) return OfflinePinCheck.unavailable;

    final failures = await _failures();
    if (failures >= maxOfflineTries) return OfflinePinCheck.locked;

    final List<int> salt;
    final List<int> expected;
    final int storedIterations;
    try {
      final stored = jsonDecode(raw) as Map<String, dynamic>;
      salt = base64.decode(stored['salt'] as String);
      expected = base64.decode(stored['hash'] as String);
      storedIterations = stored['iterations'] as int;
    } catch (_) {
      // Unreadable: drop it, the next online PIN check writes a fresh one.
      await clear();
      return OfflinePinCheck.unavailable;
    }

    final actual = await _derive(pin, salt, storedIterations);
    if (_constantTimeEquals(actual, expected)) {
      await LocalStorageManager.remove(LocalStorageKey.pinOfflineFailures);
      return OfflinePinCheck.match;
    }

    await LocalStorageManager.setValue(
        LocalStorageKey.pinOfflineFailures, '${failures + 1}');
    return failures + 1 >= maxOfflineTries
        ? OfflinePinCheck.locked
        : OfflinePinCheck.mismatch;
  }

  /// Offline tries left before the lockout.
  static Future<int> remainingTries() async =>
      max(0, maxOfflineTries - await _failures());

  /// Forgets the offline PIN: PIN disabled, session ended, lockout. Never
  /// throws, like [store]: it runs inside flows that must complete.
  static Future<void> clear() async {
    try {
      await LocalStorageManager.remove(LocalStorageKey.pinVerifier);
      await LocalStorageManager.remove(LocalStorageKey.pinOfflineFailures);
    } catch (error) {
      log('Offline PIN could not be cleared', name: 'PinVerifier', error: error);
    }
  }

  static Future<int> _failures() async =>
      int.tryParse(await LocalStorageManager.getValue(
                  LocalStorageKey.pinOfflineFailures) ??
              '') ??
      0;

  static Future<List<int>> _derive(
      String pin, List<int> salt, int iterations) async {
    final pbkdf2 = Pbkdf2(
        macAlgorithm: Hmac.sha256(), iterations: iterations, bits: 256);
    final key =
        await pbkdf2.deriveKeyFromPassword(password: pin, nonce: salt);
    return key.extractBytes();
  }

  static bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}
