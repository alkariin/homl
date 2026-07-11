import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:jwk/jwk.dart';

Future<(String, String)> generateKeyPair() async {
  final algorithm = Ed25519();
  final keyPair = await algorithm.newKeyPair();
  final publicKey = await keyPair.extractPublicKey();
  final jwk = await Jwk.fromKeyPair(keyPair);

  return (base64.encode(publicKey.bytes), jsonEncode(jwk.toJson()));
}

Future<Signature> signData(String strToSign, String? keyPair) async {
  if (keyPair == null) {
    throw Exception('Empty');
  }
  final jwk = Jwk.fromJson(jsonDecode(keyPair));
  final algorithm = Ed25519();
  final signature =
      await algorithm.sign(utf8.encode(strToSign), keyPair: jwk.toKeyPair());
  return signature;
}
