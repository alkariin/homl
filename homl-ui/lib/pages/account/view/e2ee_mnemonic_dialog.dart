import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:homl/l10n/app_localizations.dart';

/// Shows the freshly generated E2EE recovery phrase (12 BIP39 words).
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
      content: SizedBox(
        // Bound the width so the two-column word grid stays readable and the
        // dialog never overflows horizontally on a phone.
        width: 320,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(localization.account_e2eeMnemonicHint),
              const SizedBox(height: 8),
              // Explicit count: a phrase always has 12 words, so a shorter
              // display would be a bug the user can catch at a glance.
              Text(
                localization.account_e2eeMnemonicCount(words.length),
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: 12),
              _WordGrid(words: words),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  icon: const Icon(Icons.copy, size: 18),
                  label: Text(localization.account_e2eeMnemonicCopy),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: mnemonic));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(SnackBar(
                          content: Text(
                              localization.account_e2eeMnemonicCopied)));
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      // Stack the actions vertically: three localized labels never fit on one
      // row on a phone (it caused a layout overflow).
      actionsOverflowDirection: VerticalDirection.down,
      actionsOverflowButtonSpacing: 4,
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(localization.account_e2eeMnemonicSaved),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(localization.account_e2eeMnemonicSkip),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(localization.e2ee_cancel),
        ),
      ],
    );
  }
}

/// The 12 words in a fixed two-column numbered grid, so every word is always
/// visible and countable regardless of screen size.
class _WordGrid extends StatelessWidget {
  final List<String> words;

  const _WordGrid({required this.words});

  @override
  Widget build(BuildContext context) {
    final rows = (words.length / 2).ceil();
    return Column(
      children: [
        for (var r = 0; r < rows; r++)
          Row(
            children: [
              Expanded(child: _cell(context, r)),
              Expanded(child: _cell(context, r + rows)),
            ],
          ),
      ],
    );
  }

  Widget _cell(BuildContext context, int i) {
    if (i >= words.length) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: Text(
        '${i + 1}. ${words[i]}',
        style: const TextStyle(fontFamily: 'monospace'),
      ),
    );
  }
}
