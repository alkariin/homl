import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

import 'package:homl/data/transfer/export_file.dart';

/// The file is password protected and no password was given.
class ExportPasswordRequiredFailure implements Exception {}

/// The password does not open the file (or the file was altered: AES-GCM
/// cannot tell the two apart).
class ExportPasswordFailure implements Exception {}

/// Password protection of an export file (homl-web/docs/data-export.md): the
/// whole plain export, encrypted with AES-256-GCM under a key derived from
/// the password with PBKDF2-HMAC-SHA256. The envelope is JSON too and names
/// its parameters, so they can grow stronger without breaking old files.
///
/// Nothing ties the file to the account or the device: the password alone
/// opens it, anywhere. It is not the E2EE key, which never leaves the device.
class ExportSeal {
  static const format = 'homl-export-encrypted';
  static const version = 1;

  /// OWASP's figure for PBKDF2-HMAC-SHA256. Native on Android and through
  /// WebCrypto on the web (cryptography_flutter), so about a second at most.
  static const defaultIterations = 600000;

  /// A crafted file must not freeze the app deriving a key forever.
  static const _maxIterations = 10000000;

  static const _kdf = 'PBKDF2-HMAC-SHA256';
  static const _cipher = 'AES-256-GCM';
  static const _saltLength = 16;
  static const _nonceLength = 12;
  static const _macLength = 16;

  static final _aes = AesGcm.with256bits();

  /// Whether a decoded file is a sealed export.
  static bool isSealed(Object? json) =>
      json is Map<String, dynamic> && json['format'] == format;

  /// Encrypts [plaintext] (the bytes of a plain export) under [password].
  static Future<Map<String, dynamic>> seal(List<int> plaintext, String password,
      {int iterations = defaultIterations}) async {
    final random = Random.secure();
    final salt = List<int>.generate(_saltLength, (_) => random.nextInt(256));
    final key = await _deriveKey(password, salt, iterations);
    final box = await _aes.encrypt(plaintext, secretKey: key);
    return {
      'format': format,
      'version': version,
      'kdf': {
        'algorithm': _kdf,
        'iterations': iterations,
        'salt': base64.encode(salt),
      },
      'cipher': _cipher,
      'nonce': base64.encode(box.nonce),
      // The GCM tag is appended to the ciphertext, as WebCrypto does.
      'ciphertext': base64.encode([...box.cipherText, ...box.mac.bytes]),
    };
  }

  /// The plain export bytes of a sealed file.
  static Future<List<int>> open(
      Map<String, dynamic> json, String password) async {
    final fileVersion = json['version'];
    if (fileVersion is! int || fileVersion < 1) {
      throw const ExportFormatFailure('no valid version');
    }
    if (fileVersion > version) throw ExportVersionFailure();

    final kdf = json['kdf'];
    if (kdf is! Map<String, dynamic> ||
        kdf['algorithm'] != _kdf ||
        json['cipher'] != _cipher) {
      throw const ExportFormatFailure('unknown encryption');
    }
    final iterations = kdf['iterations'];
    if (iterations is! int || iterations < 1 || iterations > _maxIterations) {
      throw const ExportFormatFailure('iterations out of range');
    }
    final salt = _bytes(kdf['salt']);
    final nonce = _bytes(json['nonce']);
    final sealed = _bytes(json['ciphertext']);
    if (nonce.length != _nonceLength || sealed.length < _macLength) {
      throw const ExportFormatFailure('truncated encryption fields');
    }

    final key = await _deriveKey(password, salt, iterations);
    final box = SecretBox(sealed.sublist(0, sealed.length - _macLength),
        nonce: nonce, mac: Mac(sealed.sublist(sealed.length - _macLength)));
    try {
      return await _aes.decrypt(box, secretKey: key);
    } on SecretBoxAuthenticationError {
      throw ExportPasswordFailure();
    }
  }

  static Future<SecretKey> _deriveKey(
          String password, List<int> salt, int iterations) =>
      Pbkdf2.hmacSha256(iterations: iterations, bits: 256)
          .deriveKeyFromPassword(password: password, nonce: salt);

  static List<int> _bytes(Object? value) {
    if (value is String) {
      try {
        return base64.decode(value);
      } on FormatException {
        // Reported below.
      }
    }
    throw const ExportFormatFailure('an encryption field is not base64');
  }
}
