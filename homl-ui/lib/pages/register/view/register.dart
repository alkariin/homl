import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:homl/helpers/theme.dart';
import 'package:homl/l10n/app_localizations.dart';

import 'package:homl/components/button.dart';
import 'package:homl/components/input.dart';
import 'package:homl/data/repositories/users.repository.dart';
import 'package:homl/helpers/language.dart';
import 'package:homl/helpers/toast.dart';
import 'package:homl/helpers/validations.dart';
import 'package:homl/pages/register/bloc/register_cubit.dart';

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
      create: (BuildContext context) {
        final cubit = RegisterCubit(
            context.read<UsersRepository>(), stringToLanguage(lang));
        // A closed server is said before anything is typed.
        unawaited(cubit.checkRegistration());
        return cubit;
      },
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

    return BlocConsumer<RegisterCubit, RegisterState>(
        // Only on the transition into the error, see the login page: the flag
        // stays true until the next submit.
        listenWhen: (previous, current) =>
            current.isRegisterIncorrect && !previous.isRegisterIncorrect,
        listener: (context, state) {
          showToast(context, AppLocalizations.of(context)!.register_failure);
        },
        builder: (context, state) => Scaffold(
            appBar: AppBar(
              title: const Text('HOML'),
            ),
            body: Align(
              alignment: const Alignment(0, -1 / 3),
              child: Container(
                padding: const EdgeInsets.all(20),
                child: state.isRegistrationClosed
                    ? const _RegistrationClosed()
                    : Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Input(
                                labelText: localization.login_usernameLabel,
                                onChange: (username) => context
                                    .read<RegisterCubit>()
                                    .usernameChanged(username),
                                initialValue: context
                                    .read<RegisterCubit>()
                                    .state
                                    .username,
                                validator: (username) {
                                  if (isEmailValid(username)) return null;
                                  return localization.login_invalidEmail;
                                }),
                            const Padding(padding: EdgeInsets.all(12)),
                            Input(
                              inputType: InputType.password,
                              labelText: localization.login_passwordLabel,
                              onChange: (password) => context
                                  .read<RegisterCubit>()
                                  .passwordChanged(password),
                              initialValue:
                                  context.read<RegisterCubit>().state.password,
                              validator: (password) {
                                if (isPasswordValid(password)) return null;
                                return localization.login_invalidPassword;
                              },
                            ),
                            const Padding(padding: EdgeInsets.all(12)),
                            state.status == RegisterStatus.submitting
                                ? const Center(
                                    child: CircularProgressIndicator())
                                : Button(
                                    text: localization.register_submit,
                                    onPressed: () {
                                      if (_formKey.currentState!.validate()) {
                                        context.read<RegisterCubit>().submit();
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

/// In place of the form when the server takes no new accounts: what happened
/// and the way back to the login page, which pushed this one.
class _RegistrationClosed extends StatelessWidget {
  const _RegistrationClosed();

  @override
  Widget build(BuildContext context) {
    final localization = AppLocalizations.of(context)!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FaIcon(FontAwesomeIcons.lock,
            size: 28, color: context.homl.ink.withValues(alpha: 0.6)),
        const SizedBox(height: 16),
        Text(
          localization.register_closedTitle,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Text(
          localization.register_closedInfo,
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: context.homl.ink.withValues(alpha: 0.65)),
        ),
        const SizedBox(height: 24),
        Button(
          text: localization.register_backToLogin,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
