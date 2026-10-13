import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'blob_store.dart';

BlobStore createBlobStore() => SecureStorageBlobStore();

/// The web has no file system: the sealed entries go to the browser storage
/// through flutter_secure_storage, base64-encoded.
class SecureStorageBlobStore implements BlobStore {
  static const _storage = FlutterSecureStorage();
  static const _prefix = 'store.';

  @override
  Future<Uint8List?> read(String name) async {
    final value = await _storage.read(key: '$_prefix$name');
    return value == null ? null : base64.decode(value);
  }

  @override
  Future<void> write(String name, Uint8List bytes) =>
      _storage.write(key: '$_prefix$name', value: base64.encode(bytes));

  @override
  Future<void> delete(String name) => _storage.delete(key: '$_prefix$name');
}
