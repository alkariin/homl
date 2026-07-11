import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:homl/components/button.dart';
import 'package:homl/components/input.dart';
import 'package:homl/helpers/validations.dart';
import 'package:homl/l10n/app_localizations.dart';
import 'package:homl/pages/login/bloc/login_cubit.dart';
import 'package:homl/pages/register/view/register.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  static Route<void> route() {
    return MaterialPageRoute<void>(builder: (_) => const LoginPage());
  }

  @override
  Widget build(BuildContext context) {
    // The LoginCubit is provided at the app level (see app.dart) so that the
    // AppView can read the logged-in username after authentication. Creating
    // a page-local bloc here would swallow the events and leave the global
    // one empty.
    return const LoginView();
  }
}

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    final localization = AppLocalizations.of(context)!;

    return BlocConsumer<LoginCubit, LoginState>(
        listener: (context, state) {
          if (state.isLoginIncorrect) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text(localization.login_incorrectCredentials),
                  backgroundColor: Colors.redAccent,
                ),
              );
          }
        },
        builder: (context, state) => Scaffold(
            body: Align(
          alignment: const Alignment(0, -1 / 3),
          child: Form(
            key: _formKey,
            child: Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Input(
                      labelText: localization.login_usernameLabel,
                      onChange: (username) => context
                          .read<LoginCubit>()
                          .usernameChanged(username),
                      initialValue: context.read<LoginCubit>().state.username,
                      validator: (username) {
                        if (isEmailValid(username)) return null;
                        return localization.login_invalidEmail;
                      }),
                  const Padding(padding: EdgeInsets.all(12)),
                  Input(
                    inputType: InputType.password,
                    labelText: localization.login_passwordLabel,
                    onChange: (password) => context
                        .read<LoginCubit>()
                        .passwordChanged(password),
                    initialValue: context.read<LoginCubit>().state.password,
                    validator: (password) {
                      if (isPasswordValid(password)) return null;
                      return localization.login_invalidPassword;
                    },
                  ),
                  const Padding(padding: EdgeInsets.all(12)),
                  state.status == LoginStatus.submitting
                      ? const Center(child: CircularProgressIndicator())
                      : Button(
                          text: localization.login_submit,
                          onPressed: () {
                            if (_formKey.currentState!.validate()) {
                              context.read<LoginCubit>().submit();
                            }
                          },
                        ),
                  TextButton(
                      onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (context) => const RegisterPage())),
                      child: Text(localization.login_register))
                ],
              ),
            ),
          ),
        )));
  }
}
