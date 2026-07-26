import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:homl/l10n/app_localizations.dart';

/// Shows the freshly generated E2EE recovery phrase (12 BIP39 words + QR).
/// Returns true when the user proceeds (phrase saved, or explicitly skipped),
/// false/null when they back out — the caller then discards the pending key.
class E2eeMnemonicDialog extends StatelessWidget {
  final String mnemonic;

  const E2eeMnemonicDialog({super.key, required this.mnemonic});

  static Future<bool?> show(BuildContext context, String mnemonic) {
    return showDialog<bool>(
      context: context,
      // The phrase is shown exactly once: no accidental tap-outside dismiss.
      barrierDismissible: false,
      builder: (_) => E2eeMnemonicDialog(mnemonic: mnemonic),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localization = AppLocalizations.of(context)!;
    final words = mnemonic.split(' ');

    return AlertDialog(
      title: Text(localization.account_e2eeMnemonicTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(localization.account_e2eeMnemonicHint),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < words.length; i++)
                  Chip(label: Text('${i + 1}. ${words[i]}')),
              ],
            ),
            const SizedBox(height: 16),
            Center(
              child: QrImageView(
                data: mnemonic,
                size: 160,
                backgroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(localization.e2ee_cancel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(localization.account_e2eeMnemonicSkip),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(localization.account_e2eeMnemonicSaved),
        ),
      ],
    );
  }
}
