import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:homl/l10n/app_localizations.dart';
import 'package:homl/components/button.dart';
import 'package:homl/components/input.dart';

import 'package:homl/helpers/app_message.dart';
import 'package:homl/helpers/validations.dart';
import 'package:homl/pages/account/bloc/account_bloc.dart';

class PasswordDialog extends StatelessWidget {
  final BuildContext accountContext;

  const PasswordDialog(this.accountContext, {super.key});

  static Route<String> route(BuildContext accountContext) {
    return DialogRoute<String>(
        context: accountContext,
        builder: (_) => PasswordDialog(accountContext));
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
        value: accountContext.read<AccountBloc>(),
        child: const PasswordDialogView());
  }
}

// -----

class PasswordDialogView extends StatefulWidget {
  const PasswordDialogView({super.key});

  @override
  State<PasswordDialogView> createState() => _PasswordDialogViewState();
}

// -----

class _PasswordDialogViewState extends State<PasswordDialogView> {
  late bool _oldToggleEye;
  late bool _newToggleEye;
  late bool _confirmToggleEye;
  late TextEditingController _oldController;
  late TextEditingController _newController;
  late TextEditingController _confirmController;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _oldToggleEye = true;
    _newToggleEye = true;
    _confirmToggleEye = true;
    _oldController = TextEditingController();
    _newController = TextEditingController();
    _confirmController = TextEditingController();
  }

  @override
  void dispose() {
    _oldController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var localization = AppLocalizations.of(context)!;

    return BlocListener<AccountBloc, AccountState>(
      listener: (context, state) {
        if (state.isFormSubmitted && state.responseError == null) {
          Navigator.pop(context);
        }
      },
      child: SimpleDialog(
        title: Text(localization.account_enterPassword),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Form(
                key: _formKey,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Input(
                    inputType: InputType.password,
                    labelText: localization.account_currentPassword,
                    initialValue: _oldController.text,
                    toggleEye: _oldToggleEye,
                    onToggleEye: () => setState(() {
                      _oldToggleEye = !_oldToggleEye;
                    }),
                    validator: (password) {
                      if (isPasswordValid(password)) return null;
                      return localization.account_currentPasswordError;
                    },
                    controller: _oldController,
                  ),
                  Input(
                    inputType: InputType.password,
                    labelText: localization.account_enterPassword,
                    initialValue: _newController.text,
                    toggleEye: _newToggleEye,
                    onToggleEye: () => setState(() {
                      _newToggleEye = !_newToggleEye;
                    }),
                    validator: (password) {
                      if (isPasswordValid(password)) return null;
                      return localization.login_invalidPassword;
                    },
                    controller: _newController,
                  ),
                  Input(
                    inputType: InputType.password,
                    labelText: localization.account_repeatPassword,
                    initialValue: _confirmController.text,
                    toggleEye: _confirmToggleEye,
                    onToggleEye: () => setState(() {
                      _confirmToggleEye = !_confirmToggleEye;
                    }),
                    validator: (password) {
                      if (password != "" && password == _newController.text) {
                        return null;
                      }
                      return localization.account_passwordsNotIdentical;
                    },
                    controller: _confirmController,
                  ),
                  BlocBuilder<AccountBloc, AccountState>(
                      builder: (context, state) {
                    return Visibility(
                      visible: state.responseError != null,
                      child: Text(
                        state.responseError?.localize(localization) ?? "",
                        style: const TextStyle(
                          color: Color.fromARGB(255, 255, 0, 0),
                        ),
                      ),
                    );
                  }),
                  Button(
                    text: localization.global_update,
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        context.read<AccountBloc>().add(
                            Submit(_oldController.text, _newController.text));
                      }
                    },
                  ),
                ])),
          )
        ],
      ),
    );
  }
}
