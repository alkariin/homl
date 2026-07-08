import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:homl/l10n/app_localizations.dart';

import 'package:homl/components/button.dart';
import 'package:homl/components/input.dart';
import 'package:homl/data/repositories/users.repository.dart';
import 'package:homl/helpers/language.dart';
import 'package:homl/helpers/validations.dart';
import 'package:homl/pages/register/bloc/register_bloc.dart';

class RegisterPage extends StatelessWidget {
  const RegisterPage({super.key});

  static Route<void> route() {
    return MaterialPageRoute<void>(builder: (_) => const RegisterPage());
  }

  @override
  Widget build(BuildContext context) {
    final localization = AppLocalizations.of(context)!;
    final String lang = localization.localeName;

    return BlocProvider(
      create: (BuildContext context) =>
          RegisterBloc(context.read<UsersRepository>(), stringToLanguage(lang)),
      child: const RegisterView(),
    );
  }
}

class RegisterView extends StatefulWidget {
  const RegisterView({super.key});

  @override
  State<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends State<RegisterView> {
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    final localization = AppLocalizations.of(context)!;

    return BlocConsumer<RegisterBloc, RegisterState>(
        listener: (context, state) {
          final localization = AppLocalizations.of(context)!;
          if (state.isRegisterIncorrect) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(content: Text(localization.register_failure)),
              );
          }
        },
        builder: (context, state) => Scaffold(
            appBar: AppBar(
              title: const Text('HOML'),
            ),
            body: Align(
              alignment: const Alignment(0, -1 / 3),
              child: Container(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Input(
                          labelText: localization.login_usernameLabel,
                          onChange: (username) => context
                              .read<RegisterBloc>()
                              .add(RegisterUsernameChanged(username)),
                          initialValue:
                              context.read<RegisterBloc>().state.username,
                          validator: (username) {
                            if (isEmailValid(username)) return null;
                            return localization.login_invalidEmail;
                          }),
                      const Padding(padding: EdgeInsets.all(12)),
                      Input(
                        inputType: InputType.password,
                        labelText: localization.login_passwordLabel,
                        onChange: (password) => context
                            .read<RegisterBloc>()
                            .add(RegisterPasswordChanged(password)),
                        initialValue:
                            context.read<RegisterBloc>().state.password,
                        validator: (password) {
                          if (isPasswordValid(password)) return null;
                          return localization.login_invalidPassword;
                        },
                      ),
                      const Padding(padding: EdgeInsets.all(12)),
                      state.status == RegisterStatus.submitting
                          ? const Center(child: CircularProgressIndicator())
                          : Button(
                              text: localization.register_submit,
                              onPressed: () {
                                if (_formKey.currentState!.validate()) {
                                  context
                                      .read<RegisterBloc>()
                                      .add(RegisterSubmitted());
                                }
                              },
                            )
                    ],
                  ),
                ),
              ),
            )));
  }
}
