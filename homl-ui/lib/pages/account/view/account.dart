import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:homl/l10n/app_localizations.dart';
import 'package:homl/components/pin_dialog.dart';
import 'package:homl/data/repositories/api.dart';
import 'package:homl/data/repositories/data_transfer.repository.dart';

import 'package:homl/components/settings_group.dart';
import 'package:homl/data/repositories/settings.repository.dart';
import 'package:homl/data/repositories/users.repository.dart';
import 'package:homl/data/sync/outbox.dart';
import 'package:homl/helpers/app_message.dart';
import 'package:homl/helpers/colors.dart';
import 'package:homl/helpers/toast.dart';
import 'package:homl/pages/home/bloc/home_cubit.dart';
import 'package:homl/pages/account/bloc/account_cubit.dart';
import 'package:homl/pages/account/bloc/data_transfer_cubit.dart';
import 'package:homl/pages/account/view/data_transfer_group.dart';
import 'package:homl/pages/account/view/e2ee_mnemonic_dialog.dart';
import 'package:homl/pages/account/view/delete_account_dialog.dart';
import 'package:homl/pages/account/view/password_dialog.dart';

class AccountPage extends StatelessWidget {
  /// The HomeCubit is passed through the route on purpose: this page lives in
  /// its own navigator route, outside the provider scope of the home page, so
  /// re-providing the existing bloc instance is the standard way to keep
  /// listening to the shared home state (events/categories modals).
  final HomeCubit homeCubit;

  const AccountPage({super.key, required this.homeCubit});

  static Route<void> route(HomeCubit homeCubit) {
    return MaterialPageRoute<void>(
        builder: (_) => AccountPage(homeCubit: homeCubit));
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
            create: (BuildContext context) => AccountCubit(
                context.read<UsersRepository>(),
                settingsRepository: context.read<SettingsRepository>())),
        BlocProvider.value(value: homeCubit),
        // Built on the home page's repositories: an import notifies their
        // change stream, which reloads the shared home state.
        BlocProvider(
            create: (BuildContext context) =>
                DataTransferCubit(DataTransferRepository(
                  categoriesRepository: homeCubit.categoriesRepository,
                  tagsRepository: homeCubit.tagsRepository,
                  eventsRepository: homeCubit.eventsRepository,
                ))),
      ],
      child: AccountView(homeCubit),
    );
  }
}

class AccountView extends StatelessWidget {
  final HomeCubit homeCubit;

  const AccountView(this.homeCubit, {super.key});

  @override
  Widget build(BuildContext context) {
    var localization = AppLocalizations.of(context)!;

    Future<PinAuthResult> onPinChanged(String pin) {
      Navigator.pop(context);
      context.read<AccountCubit>().submitPin(pin);
      return Future.value(const PinAuthResult(success: true));
    }

    /// Enable flow: warning → recovery phrase (savable, skippable, or
    /// cancellable) → blocking migration handled by the cubit.
    Future<void> enableE2ee(BuildContext context) async {
      final cubit = context.read<AccountCubit>();

      final proceed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(localization.account_e2eeEnableTitle),
          content: Text(localization.account_e2eeEnableWarning),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(localization.e2ee_cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(localization.e2ee_continue),
            ),
          ],
        ),
      );
      if (proceed != true || !context.mounted) return;

      final mnemonic = await cubit.startEnableE2ee();
      if (!context.mounted) {
        cubit.cancelEnableE2ee();
        return;
      }

      final confirmed = await E2eeMnemonicDialog.show(context, mnemonic);
      if (confirmed != true) {
        cubit.cancelEnableE2ee();
        return;
      }

      await cubit.confirmEnableE2ee();
    }

    Future<void> disableE2ee(BuildContext context) async {
      final cubit = context.read<AccountCubit>();

      final proceed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(localization.account_e2eeDisableTitle),
          content: Text(localization.account_e2eeDisableWarning),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(localization.e2ee_cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(localization.e2ee_continue),
            ),
          ],
        ),
      );
      if (proceed != true) return;

      await cubit.disableE2ee();
    }

    return MultiBlocListener(
        listeners: [
          BlocListener<AccountCubit, AccountState>(
            listener: (context, state) {
              if (state.isFormSubmitted && state.responseError == null) {
                showToast(context, localization.account_passwordUpdated);
              }
            },
          ),
          BlocListener<AccountCubit, AccountState>(
            listener: (context, state) {
              final accountCubit = context.read<AccountCubit>();
              if (state.modal != null) {
                showToast(context, state.modal!.localize(localization),
                        duration: const Duration(seconds: 5))
                    .closed
                    .then(
                  (_) {
                    accountCubit.endModal();
                  },
                );
              }
            },
          ),
          BlocListener<HomeCubit, HomeState>(listener: (context, state) {
            if (state.modal != null) {
              showToast(context, state.modal!.localize(localization),
                      duration: const Duration(seconds: 5))
                  .closed
                  .then(
                (_) {
                  homeCubit.endModal();
                },
              );
            }
          })
        ],
        child: Scaffold(
            appBar: AppBar(
              title: Text(localization.account),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
            ),
            body: BlocBuilder<AccountCubit, AccountState>(
                builder: (context, state) {
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Authentication: password and the local unlock factors.
                  SettingsGroup(children: [
                    ListTile(
                      leading: const Icon(Icons.key_outlined),
                      title: Text(localization.account_updatePassword),
                      trailing: Icon(Icons.chevron_right,
                          size: 20, color: ink.withValues(alpha: 0.3)),
                      onTap: () {
                        context
                            .read<AccountCubit>()
                            .resetPasswordDialogState();
                        Navigator.push(context, PasswordDialog.route(context));
                      },
                    ),
                    SwitchListTile(
                      title: Text(localization.account_fingerprintSwitchText),
                      value: state.user?.isFingerprintEnabled ?? false,
                      onChanged: (bool value) {
                        context
                            .read<AccountCubit>()
                            .updateIsFingerprintEnabled(value);
                      },
                      secondary: const Icon(Icons.fingerprint),
                    ),
                    SwitchListTile(
                      title: Text(localization.account_pinSwitchText),
                      value: state.user?.isPinEnabled ?? false,
                      onChanged: (bool value) {
                        if (value) {
                          context.read<AccountCubit>().resetPinViewState();
                          Navigator.push(
                              context, PinDialog.route(context, onPinChanged));
                        } else {
                          context.read<AccountCubit>().submitPin(null);
                        }
                      },
                      secondary: const Icon(Icons.pin_outlined),
                    ),
                  ]),
                  // Encryption.
                  SettingsGroup(children: [
                    SwitchListTile(
                      title: Text(localization.account_e2eeSwitchText),
                      value: state.isE2eeEnabled,
                      onChanged: state.e2eeBusy
                          ? null
                          : (bool value) {
                              if (value) {
                                enableE2ee(context);
                              } else {
                                disableE2ee(context);
                              }
                            },
                      secondary: const Icon(Icons.lock_outline),
                    ),
                    if (state.e2eeBusy)
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: LinearProgressIndicator(),
                      ),
                  ]),
                  // A copy of the data to keep, or to bring in.
                  DataTransferGroup(isE2eeEnabled: state.isE2eeEnabled),
                  // Destructive, so styled apart from the toggles above.
                  SettingsGroup(children: [
                    ListTile(
                      leading: Icon(Icons.logout, color: Colors.red.shade400),
                      title: Text(
                        localization.account_logout,
                        style: TextStyle(
                            color: Colors.red.shade400,
                            fontWeight: FontWeight.w600),
                      ),
                      onTap: () async {
                        // Changes made offline not sent yet die with the
                        // session: say so first.
                        final pending = Outbox.instance.currentCounts.total;
                        if (pending > 0 &&
                            !await _confirmLosingChanges(context, pending)) {
                          return;
                        }
                        if (!context.mounted) return;
                        await context.read<UsersRepository>().logout();
                      },
                    ),
                    ListTile(
                      leading: Icon(Icons.delete_forever_outlined,
                          color: Colors.red.shade400),
                      title: Text(
                        localization.account_deleteAccount,
                        style: TextStyle(
                            color: Colors.red.shade400,
                            fontWeight: FontWeight.w600),
                      ),
                      onTap: () {
                        context.read<AccountCubit>().resetDeleteDialogState();
                        Navigator.push(
                            context, DeleteAccountDialog.route(context));
                      },
                    ),
                  ]),
                ],
              );
            })));
  }
}

Future<bool> _confirmLosingChanges(BuildContext context, int count) async {
  final localization = AppLocalizations.of(context)!;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(localization.logout_pendingTitle),
      content: Text(localization.logout_pendingInfo(count)),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(localization.global_cancel)),
        TextButton(
            style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(localization.logout_pendingConfirm)),
      ],
    ),
  );
  return confirmed == true;
}
