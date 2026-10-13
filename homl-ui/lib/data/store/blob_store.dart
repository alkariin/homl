import 'dart:typed_data';

import 'blob_store_io.dart' if (dart.library.js_interop) 'blob_store_web.dart'
    as platform;

/// Where the local store keeps its sealed entries: opaque bytes by name. The
/// encryption is the store's job (see local_store.dart); this layer only has
/// to write atomically — a crash mid-write leaves the previous entry, never
/// half of one.
abstract class BlobStore {
  Future<Uint8List?> read(String name);
  Future<void> write(String name, Uint8List bytes);
  Future<void> delete(String name);

  /// Files in the app support directory on Android and iOS, the secure
  /// storage on the web (no file system there).
  factory BlobStore.platform() => platform.createBlobStore();
}

/// Keeps the entries in memory: the tests, and nothing else.
class MemoryBlobStore implements BlobStore {
  final Map<String, Uint8List> entries = {};

  @override
  Future<Uint8List?> read(String name) async => entries[name];

  @override
  Future<void> write(String name, Uint8List bytes) async =>
      entries[name] = Uint8List.fromList(bytes);

  @override
  Future<void> delete(String name) async => entries.remove(name);
}
