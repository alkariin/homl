import 'package:flutter_secure_storage/flutter_secure_storage.dart';

enum LocalStorageKey {
  refreshToken,
  isFingerprintEnabled,
  fingerprintStorage,
  pinKeypair,
  eventsCache,
  categoriesCache,

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

  static Future<void> setValue(LocalStorageKey key, String value) async =>
      await _secureStorage.write(key: key.name, value: value);

  static Future<String?> getValue(LocalStorageKey key) async =>
      await _secureStorage.read(key: key.name);

  static Future<void> remove(LocalStorageKey key) async =>
      await _secureStorage.delete(key: key.name);

  /// Stores a boolean flag. Always use this together with [getBool] so the
  /// serialized representation stays consistent ("true"/"false").
  static Future<void> setBool(LocalStorageKey key, bool value) =>
      setValue(key, value.toString());

  /// Reads a boolean flag written with [setBool]. Missing keys read as false.
  static Future<bool> getBool(LocalStorageKey key) async =>
      await getValue(key) == true.toString();

  static Future<bool> has(LocalStorageKey key) async =>
      await _secureStorage.containsKey(key: key.name);

  /// Removes the offline data caches. Called whenever the local session ends
  /// so the next account on this device cannot read the previous user's data.
  static Future<void> clearDataCaches() async {
    await remove(LocalStorageKey.eventsCache);
    await remove(LocalStorageKey.categoriesCache);
  }

  /// Removes every key this app owns. Account deletion only: unlike logout it
  /// also drops [LocalStorageKey.e2eeMasterKey], the PIN keypair and the
  /// fingerprint flag, because the account they unlock no longer exists.
  static Future<void> clearAll() async {
    for (final key in LocalStorageKey.values) {
      await remove(key);
    }
  }
}
