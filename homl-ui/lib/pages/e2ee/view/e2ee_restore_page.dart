import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:homl/data/repositories/e2ee.repository.dart';
import 'package:homl/data/repositories/settings.repository.dart';
import 'package:homl/data/repositories/users.repository.dart';
import 'package:homl/helpers/e2ee.dart';
import 'package:homl/l10n/app_localizations.dart';
import 'package:homl/services/authentication/bloc/authentication_cubit.dart';

/// Blocking screen shown after login when the account is end-to-end
/// encrypted but this device holds no (matching) key. The user either types
/// the recovery phrase, deletes the encrypted data for good, or logs out —
/// there is deliberately no way past it (homl-web/docs/e2ee.md §7).
class E2eeRestorePage extends StatefulWidget {
  const E2eeRestorePage({super.key});

  static Route<void> route() {
    return MaterialPageRoute<void>(builder: (_) => const E2eeRestorePage());
  }

  @override
  State<E2eeRestorePage> createState() => _E2eeRestorePageState();
}

class _E2eeRestorePageState extends State<E2eeRestorePage> {
  final _phraseController = TextEditingController();
  final _e2eeRepository = E2eeRepository();

  bool _busy = false;
  E2eeRestoreResult? _restoreFailure;
  List<String> _unknownWords = const [];

  @override
  void dispose() {
    _phraseController.dispose();
    super.dispose();
  }

  Future<void> _restore() async {
    setState(() {
      _busy = true;
      _restoreFailure = null;
    });

    final keyCheck = context.read<SettingsRepository>().current?.e2eeKeyCheck;
    final result = await E2ee().restore(_phraseController.text, keyCheck);
    if (!mounted) return;

    if (result != E2eeRestoreResult.ok) {
      setState(() {
        _busy = false;
        _restoreFailure = result;
        _unknownWords = result == E2eeRestoreResult.malformed
            ? E2ee.unknownMnemonicWords(_phraseController.text)
            : const [];
      });
      return;
    }

    await context.read<AuthenticationCubit>().recheckAuthenticated();
  }

  String? _restoreErrorText(AppLocalizations localization) {
    switch (_restoreFailure) {
      case E2eeRestoreResult.malformed:
        // Point at the offending words: the actionable half of the error.
        if (_unknownWords.isNotEmpty) {
          return '${localization.e2ee_restoreMalformed}\n'
              '${localization.e2ee_restoreUnknownWords}: '
              '${_unknownWords.join(', ')}';
        }
        return localization.e2ee_restoreMalformed;
      case E2eeRestoreResult.mismatch:
        return localization.e2ee_restoreInvalid;
      case E2eeRestoreResult.ok:
      case null:
        return null;
    }
  }

  Future<void> _confirmPurge() async {
    final localization = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(localization.e2ee_purgeConfirmTitle),
        content: Text(localization.e2ee_purgeConfirmText),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(localization.e2ee_cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(localization.e2ee_purgeConfirmAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await _e2eeRepository.purge();
      if (!mounted) return;
      await context.read<SettingsRepository>().getSettings();
      if (!mounted) return;
      await context.read<AuthenticationCubit>().recheckAuthenticated();
    } on E2eeRequestFailure {
      if (!mounted) return;
      setState(() => _busy = false);
      final localization = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(localization.global_unexpectedError),
          duration: const Duration(seconds: 5),
        ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final localization = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: const Text('Homl')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.lock_outline, size: 48),
              const SizedBox(height: 16),
              Text(
                localization.e2ee_lockedTitle,
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                localization.e2ee_lockedExplanation,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _phraseController,
                enabled: !_busy,
                minLines: 2,
                maxLines: 3,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  labelText: localization.e2ee_restoreHint,
                  errorText: _restoreErrorText(localization),
                  errorMaxLines: 5,
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _busy ? null : _restore,
                child: _busy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(localization.e2ee_restoreButton),
              ),
              const SizedBox(height: 32),
              TextButton(
                onPressed: _busy ? null : _confirmPurge,
                child: Text(
                  localization.e2ee_purgeButton,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
              TextButton(
                onPressed: _busy
                    ? null
                    : () => context.read<UsersRepository>().logout(),
                child: Text(localization.account_logout),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
