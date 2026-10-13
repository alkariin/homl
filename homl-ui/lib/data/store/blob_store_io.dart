import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import 'blob_store.dart';

BlobStore createBlobStore() => FileBlobStore();

/// One file per entry under `<app support>/store/`. Android keeps that
/// directory out of the OS backups (see the manifest's data extraction
/// rules); on iOS a restored copy is useless anyway, since the key that seals
/// it is kept on this device only.
class FileBlobStore implements BlobStore {
  /// The tests point it at a temporary directory.
  FileBlobStore({Future<Directory> Function()? directory})
      : _directory = directory ?? _defaultDirectory;

  final Future<Directory> Function() _directory;

  /// Kept once created; a failure is not, so the next call tries again.
  Directory? _created;

  static Future<Directory> _defaultDirectory() async =>
      Directory('${(await getApplicationSupportDirectory()).path}/store');

  Future<File> _file(String name) async {
    var directory = _created;
    if (directory == null) {
      directory = await _directory();
      await directory.create(recursive: true);
      _created = directory;
    }
    return File('${directory.path}/$name');
  }

  @override
  Future<Uint8List?> read(String name) async {
    final file = await _file(name);
    return await file.exists() ? file.readAsBytes() : null;
  }

  /// Written next to the target, then renamed over it: a rename within one
  /// directory is atomic, so a reader sees the old entry or the new one.
  @override
  Future<void> write(String name, Uint8List bytes) async {
    final file = await _file(name);
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsBytes(bytes, flush: true);
    await temporary.rename(file.path);
  }

  @override
  Future<void> delete(String name) async {
    final file = await _file(name);
    if (await file.exists()) await file.delete();
  }
}
