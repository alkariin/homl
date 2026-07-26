// Offline recovery-phrase checker (debug helper). Validates a typed phrase
// exactly like the app's restore screen does — word count, dictionary
// membership, BIP39 checksum — without needing a device or a backend:
//   dart run tool/check_phrase.dart intact top ...twelve words...
// The phrase never leaves this machine.
import 'dart:io';

import 'package:bip39/bip39.dart' as bip39;
// ignore: implementation_imports
import 'package:bip39/src/wordlists/english.dart' as bip39_words;

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln('usage: dart run tool/check_phrase.dart <word1> <word2> ...');
    exit(2);
  }

  // Same normalization as E2ee.normalizeMnemonic (helpers/e2ee.dart).
  final words = args
      .join(' ')
      .toLowerCase()
      .split(RegExp(r'[^a-z]+'))
      .where((w) => w.isNotEmpty)
      .toList();

  stdout.writeln('word count: ${words.length} (expected 12)');

  final unknown =
      words.where((w) => !bip39_words.WORDLIST.contains(w)).toList();
  if (unknown.isNotEmpty) {
    stdout.writeln('words NOT in the BIP39 dictionary: ${unknown.join(', ')}');
  } else {
    stdout.writeln('all words are in the BIP39 dictionary');
  }

  final valid = bip39.validateMnemonic(words.join(' '));
  stdout.writeln(valid
      ? 'checksum: VALID — this is a well-formed recovery phrase'
      : 'checksum: INVALID — wrong count, swapped words, or a substituted word');
  exit(valid ? 0 : 1);
}
