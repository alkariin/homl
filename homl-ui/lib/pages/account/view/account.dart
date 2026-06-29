import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/material.dart';
import 'package:homl/l10n/app_localizations.dart';
import 'package:homl/components/pin_dialog.dart';

import 'package:homl/data/repositories/users.repository.dart';
import 'package:homl/pages/home/bloc/home_bloc.dart';
import 'package:homl/pages/account/bloc/account_bloc.dart';
import 'package:homl/pages/account/view/password_dialog.dart';

class AccountPage extends StatelessWidget {
  final HomeBloc homeBloc;

  const AccountPage({super.key, required this.homeBloc});

  static Route<void> route(HomeBloc homeBloc) {
    return MaterialPageRoute<void>(
        builder: (_) => AccountPage(homeBloc: homeBloc));
  }

  @override
  Widget build(BuildContext context) {
    var localization = AppLocalizations.of(context)!;
    return MultiBlocProvider(
      providers: [
        BlocProvider(
            create: (BuildContext context) =>
                AccountBloc(localization, context.read<UsersRepository>())),
        BlocProvider.value(value: homeBloc),
      ],
      child: AccountView(homeBloc),
    );
  }
}

class AccountView extends StatelessWidget {
  final HomeBloc homeBloc;

  const AccountView(this.homeBloc, {super.key});

  @override
  Widget build(BuildContext context) {
    var localization = AppLocalizations.of(context)!;

    Future<bool> onPinChanged(String pin) {
      Navigator.pop(context);
      context.read<AccountBloc>().add(SubmitPin(pin));
      return Future.value(true);
    }

    return MultiBlocListener(
        listeners: [
          BlocListener<AccountBloc, AccountState>(
            listener: (context, state) {
              if (state.isFormSubmitted && state.responseError == "") {
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    const SnackBar(
                        content: Text('Your password has been updated')),
                  );
              }
            },
          ),
          BlocListener<HomeBloc, HomeState>(listener: (context, state) {
            if (state.modal != null) {
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(
                  content: Text(state.modal!),
                  action: SnackBarAction(label: 'close', onPressed: () {}),
                  duration: const Duration(seconds: 5),
                )).closed.then(
                  (_) {
                    homeBloc.add(EndModal());
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
            body: BlocBuilder<AccountBloc, AccountState>(
                builder: (context, state) {
              return Column(
                children: [
                  ElevatedButton(
                    child: Text(localization.account_updatePassword),
                    onPressed: () {
                      context
                          .read<AccountBloc>()
                          .add(ResetPasswordDialogState());
                      Navigator.push(context, PasswordDialog.route(context));
                    },
                  ),
                  SwitchListTile(
                    title: Text(localization.account_fingerprintSwitchText),
                    value: state.user?.isFingerprintEnabled ?? false,
                    onChanged: (bool value) {
                      context
                          .read<AccountBloc>()
                          .add(UpdateIsFingerprintEnabled(value));
                    },
                    secondary: const Icon(Icons.lightbulb_outline),
                  ),
                  SwitchListTile(
                    title: Text(localization.account_pinSwitchText),
                    value: state.user?.isPinEnabled ?? false,
                    onChanged: (bool value) {
                      if (value) {
                        context.read<AccountBloc>().add(ResetPinViewState());
                        Navigator.push(
                            context, PinDialog.route(context, onPinChanged));
                      } else {
                        context.read<AccountBloc>().add(const SubmitPin(null));
                      }
                    },
                    secondary: const Icon(Icons.lightbulb_outline),
                  ),
                  ElevatedButton(
                    child: Text(localization.account_logout),
                    onPressed: () {
                      context.read<UsersRepository>().logout();
                    },
                  ),
                ],
              );
            })));
  }
}
