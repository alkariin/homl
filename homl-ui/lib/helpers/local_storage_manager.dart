import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:homl/data/store/local_store.dart';

enum LocalStorageKey {
  refreshToken,
  isFingerprintEnabled,
  fingerprintStorage,
  pinKeypair,

  /// Where the events, categories and settings payloads used to be cached.
  /// They live in the [LocalStore] now, which carries these over once and
  /// deletes them.
  eventsCache,
  categoriesCache,
  settingsCache,

  /// The key sealing the [LocalStore] entries (base64). Kept on this device
  /// only: an OS backup restored elsewhere carries no readable copy of the
  /// saved data.
  localStoreKey,

  /// PBKDF2 hash of the last PIN the server accepted on this device, and the
  /// count of wrong offline tries (see helpers/pin_verifier.dart). Dropped
  /// whenever the session ends.
  pinVerifier,
  pinOfflineFailures,

  /// The appearance picked in the settings (a [ThemeMode] name): a
  /// preference of this device, kept across logouts.
  themeMode,

  /// 16-byte E2EE seed (base64). Deliberately NOT removed on logout: it must
  /// survive re-logins on the same device — losing it means losing the data.
  /// Account deletion is the one case that wipes it (see [clearAll]): there
  /// is no data left to unlock.
  e2eeMasterKey,
}

class LocalStorageManager {
  LocalStorageManager._();

  static const _androidOptions = AndroidOptions();

  static const _iosOptions =
      IOSOptions(accessibility: KeychainAccessibility.first_unlock);

  static const FlutterSecureStorage _secureStorage =
      FlutterSecureStorage(iOptions: _iosOptions, aOptions: _androidOptions);

  /// iOS only differs: a "this device only" keychain item never travels in a
  /// backup. Android keystore-backed values never do anyway.
  static const FlutterSecureStorage _deviceOnlyStorage = FlutterSecureStorage(
      iOptions: IOSOptions(
          accessibility: KeychainAccessibility.first_unlock_this_device),
      aOptions: _androidOptions);

  static FlutterSecureStorage _storageFor(LocalStorageKey key) =>
      key == LocalStorageKey.localStoreKey ? _deviceOnlyStorage : _secureStorage;

  static Future<void> setValue(LocalStorageKey key, String value) async =>
      await _storageFor(key).write(key: key.name, value: value);

  static Future<String?> getValue(LocalStorageKey key) async =>
      await _storageFor(key).read(key: key.name);

  static Future<void> remove(LocalStorageKey key) async =>
      await _storageFor(key).delete(key: key.name);

  /// Stores a boolean flag. Always use this together with [getBool] so the
  /// serialized representation stays consistent ("true"/"false").
  static Future<void> setBool(LocalStorageKey key, bool value) =>
      setValue(key, value.toString());

  /// Reads a boolean flag written with [setBool]. Missing keys read as false.
  static Future<bool> getBool(LocalStorageKey key) async =>
      await getValue(key) == true.toString();

  static Future<bool> has(LocalStorageKey key) async =>
      await _storageFor(key).containsKey(key: key.name);

  /// Removes the data saved for offline use (the [LocalStore], and the old
  /// cache keys if still there). Called whenever the local session ends so
  /// the next account on this device cannot read the previous user's data,
  /// and after an E2EE migration (the saved payloads changed representation).
  /// [keepOutbox]: keep the changes not sent yet (see [LocalStore.wipe]).
  static Future<void> clearDataCaches({bool keepOutbox = false}) async {
    await LocalStore.instance.wipe(keepOutbox: keepOutbox);
    await remove(LocalStorageKey.eventsCache);
    await remove(LocalStorageKey.categoriesCache);
    await remove(LocalStorageKey.settingsCache);
  }

  /// Removes every key this app owns, and the [LocalStore]. Account deletion
  /// only: unlike logout it also drops [LocalStorageKey.e2eeMasterKey], the
  /// PIN keypair and the fingerprint flag, because the account they unlock no
  /// longer exists.
  static Future<void> clearAll() async {
    await LocalStore.instance.wipe();
    for (final key in LocalStorageKey.values) {
      await remove(key);
    }
  }
}
