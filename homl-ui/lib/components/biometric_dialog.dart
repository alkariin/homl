import 'package:flutter/material.dart';
import 'package:homl/l10n/app_localizations.dart';

/// Dialog shown when the fingerprint prompt fails or is canceled at startup:
/// lets the user retry the fingerprint or fall back to the password login.
class BiometricDialog extends StatelessWidget {
  final Future<bool> Function() onRetry;
  final VoidCallback onUsePassword;

  const BiometricDialog(
      {super.key, required this.onRetry, required this.onUsePassword});

  static Route<void> route(BuildContext context,
      {required Future<bool> Function() onRetry,
      required VoidCallback onUsePassword}) {
    return DialogRoute<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) =>
            BiometricDialog(onRetry: onRetry, onUsePassword: onUsePassword));
  }

  @override
  Widget build(BuildContext context) {
    final localization = AppLocalizations.of(context)!;

    return FractionallySizedBox(
        widthFactor: 1,
        child: SimpleDialog(
            title: Text(localization.biometric_failedTitle),
            children: [
              Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(localization.biometric_failedMessage),
                      Container(
                          margin: const EdgeInsets.only(top: 30),
                          child: ElevatedButton(
                            onPressed: () => onRetry(),
                            child: Text(localization.biometric_retry),
                          )),
                      Container(
                          margin: const EdgeInsets.only(top: 10, bottom: 10),
                          child: OutlinedButton(
                            onPressed: onUsePassword,
                            child: Text(localization.biometric_usePassword),
                          ))
                    ],
                  ))
            ]));
  }
}
