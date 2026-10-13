import 'dart:convert';
import 'dart:developer';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';

import 'package:homl/helpers/local_storage_manager.dart';

import 'blob_store.dart';

/// What the local store keeps: the last payload the server sent for each.
enum StoreEntry { events, categories, settings }

class StoredPayload {
  /// The decoded JSON, exactly as the server sent it (ciphertext for an
  /// end-to-end encrypted account: decryption stays the repositories' job).
  final Object? payload;

  /// When it was fetched; null for data carried over from the previous
  /// storage, which did not record it.
  final DateTime? savedAt;

  const StoredPayload(this.payload, this.savedAt);
}

/// The data saved on this device, so the app works offline: one entry per
/// [StoreEntry], each sealed with AES-256-GCM under a random device key kept in
/// the secure storage (homl-ui/README.md, "Offline mode").
///
/// - Every entry records the account it belongs to; loading one saved by
///   another account wipes the store instead of showing it.
/// - [wipe] deletes the key first: whatever file deletion fails afterwards, the
///   files left behind can no longer be read.
/// - The store is a cache: a failure is logged and reads as "nothing saved",
///   never as an error the screens have to handle.
class LocalStore {
  LocalStore(this._blobs);

  /// Files on Android and iOS, the browser storage on the web. The tests swap
  /// in a memory-backed store.
  static LocalStore instance = LocalStore(BlobStore.platform());

  final BlobStore _blobs;
  final AesGcm _aes = AesGcm.with256bits();

  /// Operations run one at a time: two concurrent first writes would
  /// otherwise each create a device key, and one entry would end up sealed
  /// under the key that lost.
  Future<void> _tail = Future.value();
  bool _legacyMigrated = false;

  static const _formatVersion = 1;
  static const _nonceLength = 12;
  static const _macLength = 16;

  /// The secure-storage keys this store replaces, imported once.
  static const _legacyKeys = {
    StoreEntry.events: LocalStorageKey.eventsCache,
    StoreEntry.categories: LocalStorageKey.categoriesCache,
    StoreEntry.settings: LocalStorageKey.settingsCache,
  };

  Future<T> _serialized<T>(Future<T> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.then((_) {}, onError: (_) {});
    return result;
  }

  String _blobName(StoreEntry entry) => '${entry.name}.bin';

  /// Saves [payload] (JSON-encodable) as [entry], for the account currently
  /// signed in.
  Future<void> save(StoreEntry entry, Object? payload) =>
      _serialized(() async {
        try {
          await _migrateLegacy();
          await _write(entry, payload, DateTime.now());
        } catch (error) {
          log('Could not save ${entry.name}', name: 'LocalStore', error: error);
        }
      });

  /// The saved [entry], or null when there is none for the account currently
  /// signed in.
  Future<StoredPayload?> load(StoreEntry entry) => _serialized(() async {
        try {
          await _migrateLegacy();
          return await _read(entry);
        } catch (error) {
          log('Could not read ${entry.name}', name: 'LocalStore', error: error);
          await _deleteQuietly(entry);
          return null;
        }
      });

  /// Forgets [entry] alone (a payload the app can no longer parse).
  Future<void> remove(StoreEntry entry) =>
      _serialized(() => _deleteQuietly(entry));

  /// Deletes everything saved, device key first.
  Future<void> wipe() => _serialized(_wipe);

  Future<void> _write(StoreEntry entry, Object? payload, DateTime? savedAt) async {
    final key = await _deviceKey(create: true);
    final plaintext = utf8.encode(jsonEncode({
      'owner': await _currentOwner(),
      'savedAt': savedAt?.toUtc().toIso8601String(),
      'payload': payload,
    }));
    final box = await _aes.encrypt(plaintext,
        secretKey: key!, aad: utf8.encode(entry.name));
    await _blobs.write(_blobName(entry),
        Uint8List.fromList([_formatVersion, ...box.concatenation()]));
  }

  Future<StoredPayload?> _read(StoreEntry entry) async {
    final bytes = await _blobs.read(_blobName(entry));
    if (bytes == null) return null;

    final key = await _deviceKey(create: false);
    if (key == null || bytes.isEmpty || bytes.first != _formatVersion) {
      // Sealed under a key that is gone (wiped, or not restored with an OS
      // backup), or not ours: unreadable for good.
      await _deleteQuietly(entry);
      return null;
    }

    // The entry name is bound as associated data: a file copied over another
    // entry fails to open instead of being read as that entry.
    final box = SecretBox.fromConcatenation(bytes.sublist(1),
        nonceLength: _nonceLength, macLength: _macLength);
    final plaintext = await _aes.decrypt(box,
        secretKey: key, aad: utf8.encode(entry.name));
    final stored = jsonDecode(utf8.decode(plaintext)) as Map<String, dynamic>;

    if (stored['owner'] != await _currentOwner()) {
      // Saved by another account (signed out without the store being wiped):
      // never shown, and gone for good.
      await _wipe();
      return null;
    }

    final savedAt = stored['savedAt'];
    return StoredPayload(stored['payload'],
        savedAt is String ? DateTime.tryParse(savedAt)?.toLocal() : null);
  }

  Future<void> _wipe() async {
    try {
      await LocalStorageManager.remove(LocalStorageKey.localStoreKey);
    } catch (error) {
      log('Could not delete the device key', name: 'LocalStore', error: error);
    }
    for (final entry in StoreEntry.values) {
      await _deleteQuietly(entry);
    }
  }

  Future<void> _deleteQuietly(StoreEntry entry) async {
    try {
      await _blobs.delete(_blobName(entry));
    } catch (error) {
      log('Could not delete ${entry.name}', name: 'LocalStore', error: error);
    }
  }

  Future<SecretKey?> _deviceKey({required bool create}) async {
    final stored =
        await LocalStorageManager.getValue(LocalStorageKey.localStoreKey);
    if (stored != null) return SecretKey(base64.decode(stored));
    if (!create) return null;

    final key = await _aes.newSecretKey();
    await LocalStorageManager.setValue(
        LocalStorageKey.localStoreKey, base64.encode(await key.extractBytes()));
    return key;
  }

  /// The account signed in on this device, read from the `user_id` claim of
  /// the stored refresh token (no signature check: this only keeps one
  /// account's data away from the next one). Null without a readable token.
  Future<String?> _currentOwner() async {
    final token =
        await LocalStorageManager.getValue(LocalStorageKey.refreshToken);
    final parts = token?.split('.');
    if (parts == null || parts.length != 3) return null;
    try {
      final claims = jsonDecode(
              utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))))
          as Map<String, dynamic>;
      final userId = claims['user_id'];
      return userId == null ? null : '$userId';
    } catch (_) {
      return null;
    }
  }

  /// Moves the payloads the app used to keep in the secure storage into the
  /// store, once. They have no fetch date.
  Future<void> _migrateLegacy() async {
    if (_legacyMigrated) return;
    _legacyMigrated = true;
    for (final MapEntry(key: entry, value: legacyKey) in _legacyKeys.entries) {
      try {
        final raw = await LocalStorageManager.getValue(legacyKey);
        if (raw == null) continue;
        Object? payload;
        try {
          payload = jsonDecode(raw);
        } on FormatException {
          // Unreadable: nothing worth carrying over.
          await LocalStorageManager.remove(legacyKey);
          continue;
        }
        if (await _blobs.read(_blobName(entry)) == null) {
          await _write(entry, payload, null);
        }
        await LocalStorageManager.remove(legacyKey);
      } catch (error) {
        // Kept where it is: the next launch tries again.
        log('Could not carry ${entry.name} over',
            name: 'LocalStore', error: error);
      }
    }
  }

  @visibleForTesting
  static LocalStore inMemory() => LocalStore(MemoryBlobStore());
}
