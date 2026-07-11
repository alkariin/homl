import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:homl/l10n/app_localizations.dart';
import 'package:pinput/pinput.dart';

import 'package:homl/components/button.dart';
import 'package:homl/components/input.dart';
import 'package:homl/data/repositories/users.repository.dart';
import 'package:homl/helpers/validations.dart';
import 'package:homl/pages/forgot_password/bloc/forgot_password_cubit.dart';

class ForgotPasswordPage extends StatelessWidget {
  const ForgotPasswordPage({super.key});

  static Route<void> route() {
    return MaterialPageRoute<void>(builder: (_) => const ForgotPasswordPage());
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (BuildContext context) =>
          ForgotPasswordCubit(context.read<UsersRepository>()),
      child: const ForgotPasswordView(),
    );
  }
}

class ForgotPasswordView extends StatefulWidget {
  const ForgotPasswordView({super.key});

  @override
  State<ForgotPasswordView> createState() => _ForgotPasswordViewState();
}

class _ForgotPasswordViewState extends State<ForgotPasswordView> {
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    final localization = AppLocalizations.of(context)!;

    return BlocConsumer<ForgotPasswordCubit, ForgotPasswordState>(
        listener: (context, state) {
          if (state.message == ForgotPasswordMessage.none) return;
          final content = state.message == ForgotPasswordMessage.invalidCode
              ? localization.forgot_invalidCode
              : localization.global_unexpectedError;
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(
              content: Text(content),
              backgroundColor: Colors.redAccent,
            ));
        },
        builder: (context, state) => Scaffold(
            appBar: AppBar(
              title: Text(localization.forgot_title),
            ),
            body: SingleChildScrollView(
              child: Container(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: state.step == ForgotPasswordStep.emailEntry
                      ? _EmailStep(formKey: _formKey)
                      : _CodeStep(formKey: _formKey),
                ),
              ),
            )));
  }
}

class _EmailStep extends StatelessWidget {
  final GlobalKey<FormState> formKey;

  const _EmailStep({required this.formKey});

  @override
  Widget build(BuildContext context) {
    final localization = AppLocalizations.of(context)!;
    final cubit = context.read<ForgotPasswordCubit>();
    final state = context.watch<ForgotPasswordCubit>().state;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(localization.forgot_emailInstructions),
        const Padding(padding: EdgeInsets.all(12)),
        Input(
            labelText: localization.login_usernameLabel,
            onChange: cubit.emailChanged,
            initialValue: state.email,
            validator: (email) {
              if (isEmailValid(email)) return null;
              return localization.login_invalidEmail;
            }),
        const Padding(padding: EdgeInsets.all(12)),
        state.status == ForgotPasswordStatus.submitting
            ? const Center(child: CircularProgressIndicator())
            : Button(
                text: localization.forgot_sendCode,
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    cubit.sendCode();
                  }
                },
              ),
      ],
    );
  }
}

class _CodeStep extends StatelessWidget {
  final GlobalKey<FormState> formKey;

  const _CodeStep({required this.formKey});

  @override
  Widget build(BuildContext context) {
    final localization = AppLocalizations.of(context)!;
    final cubit = context.read<ForgotPasswordCubit>();
    final state = context.watch<ForgotPasswordCubit>().state;

    final defaultPinTheme = PinTheme(
      width: 48,
      height: 56,
      textStyle: const TextStyle(
        fontSize: 22,
        color: Color.fromRGBO(30, 60, 87, 1),
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color.fromRGBO(23, 171, 144, 0.4)),
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(localization.forgot_codeInstructions),
        const Padding(padding: EdgeInsets.all(12)),
        Directionality(
          textDirection: TextDirection.ltr,
          child: Pinput(
            length: 6,
            autofocus: true,
            defaultPinTheme: defaultPinTheme,
            separatorBuilder: (index) => const SizedBox(width: 6),
            onChanged: cubit.codeChanged,
          ),
        ),
        const Padding(padding: EdgeInsets.all(12)),
        Input(
          inputType: InputType.password,
          labelText: localization.forgot_newPasswordLabel,
          onChange: cubit.newPasswordChanged,
          initialValue: state.newPassword,
          validator: (password) {
            if (isPasswordValid(password)) return null;
            return localization.login_invalidPassword;
          },
        ),
        const Padding(padding: EdgeInsets.all(12)),
        Input(
          inputType: InputType.password,
          labelText: localization.forgot_confirmPasswordLabel,
          onChange: cubit.confirmPasswordChanged,
          initialValue: state.confirmPassword,
          validator: (password) {
            if (password == cubit.state.newPassword) return null;
            return localization.account_passwordsNotIdentical;
          },
        ),
        const Padding(padding: EdgeInsets.all(12)),
        state.status == ForgotPasswordStatus.submitting
            ? const Center(child: CircularProgressIndicator())
            : Button(
                text: localization.forgot_submit,
                onPressed: () {
                  if (state.code.length == 6 &&
                      formKey.currentState!.validate()) {
                    cubit.submit();
                  }
                },
              ),
        TextButton(
            onPressed: state.status == ForgotPasswordStatus.submitting
                ? null
                : cubit.sendCode,
            child: Text(localization.forgot_resendCode)),
      ],
    );
  }
}
