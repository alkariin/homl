import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:homl/components/button.dart';
import 'package:homl/components/input.dart';
import 'package:homl/helpers/server_address.dart';
import 'package:homl/helpers/toast.dart';
import 'package:homl/helpers/validations.dart';
import 'package:homl/l10n/app_localizations.dart';
import 'package:homl/pages/forgot_password/view/forgot_password.dart';
import 'package:homl/pages/login/bloc/login_cubit.dart';
import 'package:homl/pages/login/view/server_dialog.dart';
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

  // Dev-only: submit the prefilled credentials as soon as the login screen
  // shows up (see run-local.sh). False in regular builds.
  static const _devAutologin = bool.fromEnvironment('DEV_AUTOLOGIN');

  @override
  void initState() {
    super.initState();
    if (_devAutologin) {
      final cubit = context.read<LoginCubit>();
      if (cubit.state.username.isNotEmpty && cubit.state.password.isNotEmpty) {
        cubit.submit();
      }
    }
  }

  /// Opens the server dialog; says which server answered once it is kept.
  Future<ServerCheck?> _pickServer() async {
    final localization = AppLocalizations.of(context)!;
    final check = await ServerDialog.show(context);
    if (!mounted || check == null) return check;
    // The address shown under the form.
    setState(() {});
    showToast(
        context,
        check.version == null
            ? localization.login_serverConnectedNoVersion
            : localization.login_serverConnected(check.version!));
    return check;
  }

  /// Runs [action] once there is a server to talk to: a build without a
  /// default one asks for it first.
  Future<void> _withServer(VoidCallback action) async {
    if (!ServerAddress.isSet && await _pickServer() == null) return;
    if (mounted) action();
  }

  @override
  Widget build(BuildContext context) {
    final localization = AppLocalizations.of(context)!;

    return BlocConsumer<LoginCubit, LoginState>(
        // Only on the transition into the error: the flag stays true until the
        // next submit, so listening to every emission re-showed the toast on
        // each keystroke of the corrected password.
        listenWhen: (previous, current) =>
            (current.isLoginIncorrect && !previous.isLoginIncorrect) ||
            (current.isServerUnreachable && !previous.isServerUnreachable),
        listener: (context, state) {
          showToast(
              context,
              state.isServerUnreachable
                  ? localization.login_serverUnreachable
                  : localization.login_incorrectCredentials,
              isError: true);
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
                              _withServer(
                                  () => context.read<LoginCubit>().submit());
                            }
                          },
                        ),
                  TextButton(
                      onPressed: () => _withServer(() => Navigator.of(context)
                          .push(MaterialPageRoute(
                              builder: (context) => const RegisterPage()))),
                      child: Text(localization.login_register)),
                  TextButton(
                      onPressed: () => _withServer(() => Navigator.of(context)
                          .push(ForgotPasswordPage.route())),
                      child: Text(localization.login_forgotPassword)),
                  const Padding(padding: EdgeInsets.all(8)),
                  TextButton.icon(
                      key: const Key('login_server'),
                      onPressed: _pickServer,
                      icon: const Icon(Icons.dns_outlined, size: 18),
                      label: Text(ServerAddress.isSet
                          ? displayServerAddress(ServerAddress.current)
                          : localization.login_serverChoose)),
                ],
              ),
            ),
          ),
        )));
  }
}
