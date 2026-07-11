import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/material.dart';
import 'package:homl/l10n/app_localizations.dart';
import 'package:homl/components/pin_dialog.dart';
import 'package:homl/data/repositories/api.dart';

import 'package:homl/data/repositories/users.repository.dart';
import 'package:homl/helpers/app_message.dart';
import 'package:homl/pages/home/bloc/home_cubit.dart';
import 'package:homl/pages/account/bloc/account_cubit.dart';
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
            create: (BuildContext context) =>
                AccountCubit(context.read<UsersRepository>())),
        BlocProvider.value(value: homeCubit),
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

    return MultiBlocListener(
        listeners: [
          BlocListener<AccountCubit, AccountState>(
            listener: (context, state) {
              if (state.isFormSubmitted && state.responseError == null) {
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    SnackBar(
                        content:
                            Text(localization.account_passwordUpdated)),
                  );
              }
            },
          ),
          BlocListener<AccountCubit, AccountState>(
            listener: (context, state) {
              final accountCubit = context.read<AccountCubit>();
              if (state.modal != null) {
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(SnackBar(
                    content: Text(state.modal!.localize(localization)),
                    action: SnackBarAction(
                        label: localization.global_close, onPressed: () {}),
                    duration: const Duration(seconds: 5),
                  )).closed.then(
                    (_) {
                      accountCubit.endModal();
                    },
                  );
              }
            },
          ),
          BlocListener<HomeCubit, HomeState>(listener: (context, state) {
            if (state.modal != null) {
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(
                  content: Text(state.modal!.localize(localization)),
                  action: SnackBarAction(
                      label: localization.global_close, onPressed: () {}),
                  duration: const Duration(seconds: 5),
                )).closed.then(
                  (_) {
                    homeCubit.endModal();
                  },
                );
            }
          })
        ],
        child: Scaffold(
            appBar: AppBar(
              title: const Text("Homl"),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
            ),
            body: BlocBuilder<AccountCubit, AccountState>(
                builder: (context, state) {
              return Column(
                children: [
                  ElevatedButton(
                    child: Text(localization.account_updatePassword),
                    onPressed: () {
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
                    secondary: const Icon(Icons.lightbulb_outline),
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
                    secondary: const Icon(Icons.lightbulb_outline),
                  ),
                  ElevatedButton(
                    child: Text(localization.account_logout),
                    onPressed: () async {
                      await context.read<UsersRepository>().logout();
                    },
                  ),
                ],
              );
            })));
  }
}
