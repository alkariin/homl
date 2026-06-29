import 'package:flutter_secure_storage/flutter_secure_storage.dart';

enum LocalStorageKey {
  refreshToken,
  isFingerprintEnabled,
  fingerprintStorage,
  pinKeypair
}

class LocalStorageManager {
  LocalStorageManager._();

  static const _androidOptions =
      AndroidOptions(encryptedSharedPreferences: true);

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

  static Future<bool> has(LocalStorageKey key) async =>
      await _secureStorage.containsKey(key: key.name);
}
