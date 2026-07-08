import 'package:biometric_storage/biometric_storage.dart';
import 'package:cryptography/cryptography.dart';
import 'package:homl/helpers/encryption.dart' as encryption;

enum BiometricErrors { noBiometric, noStorage }

BiometricStorageFile? _storageFile;

Future<BiometricStorageFile> _getStorageFile() async {
  return BiometricStorage().getStorage('authenticated_storage');
}

Future<void> _createBioProtectedEntry(String keyPair) async {
  final response = await BiometricStorage().canAuthenticate();
  if (response != CanAuthenticateResponse.success) {
    throw AuthException(
        AuthExceptionCode.unknown, BiometricErrors.noBiometric.toString());
  }
  _storageFile = await _getStorageFile();
  // ask user for fingerprint
  await _storageFile?.write(keyPair);
}

Future<String?> _readBioProtectedEntry() async {
  final response = await BiometricStorage().canAuthenticate();
  if (response != CanAuthenticateResponse.success) {
    throw AuthException(
        AuthExceptionCode.unknown, BiometricErrors.noBiometric.toString());
  }
  _storageFile = await _getStorageFile();
  if (_storageFile == null) {
    throw AuthException(
        AuthExceptionCode.unknown, BiometricErrors.noStorage.toString());
  }
  // ask user for fingerprint
  final data = await _storageFile?.read();
  return data;
}

Future<void> removeStorageFile() async {
  // Actually delete the stored keypair, not just the cached handle.
  _storageFile ??= await _getStorageFile();
  await _storageFile?.delete();
  _storageFile = null;
}

Future<String> generateKeyPair() async {
  var (publicKey, keyPairJson) = await encryption.generateKeyPair();
  await _createBioProtectedEntry(keyPairJson);
  return publicKey;
}

Future<Signature> signData(String challenge) async {
  final keyPair = await _readBioProtectedEntry();
  return encryption.signData(challenge, keyPair);
}
