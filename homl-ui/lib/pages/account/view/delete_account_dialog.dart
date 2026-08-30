import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:homl/l10n/app_localizations.dart';
import 'package:homl/components/input.dart';

import 'package:homl/helpers/app_message.dart';
import 'package:homl/helpers/validations.dart';
import 'package:homl/pages/account/bloc/account_cubit.dart';

/// Confirmation of an irreversible action: the warning and the password
/// re-entry live in the same dialog, so the user reads what they are about to
/// lose while typing the password that authorizes it.
class DeleteAccountDialog extends StatelessWidget {
  final BuildContext accountContext;

  const DeleteAccountDialog(this.accountContext, {super.key});

  static Route<void> route(BuildContext accountContext) {
    return DialogRoute<void>(
        context: accountContext,
        builder: (_) => DeleteAccountDialog(accountContext));
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
        value: accountContext.read<AccountCubit>(),
        child: const DeleteAccountDialogView());
  }
}

// -----

class DeleteAccountDialogView extends StatefulWidget {
  const DeleteAccountDialogView({super.key});

  @override
  State<DeleteAccountDialogView> createState() =>
      _DeleteAccountDialogViewState();
}

// -----

class _DeleteAccountDialogViewState extends State<DeleteAccountDialogView> {
  late bool _toggleEye;
  late TextEditingController _passwordController;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _toggleEye = true;
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var localization = AppLocalizations.of(context)!;

    return BlocBuilder<AccountCubit, AccountState>(builder: (context, state) {
      return AlertDialog(
        title: Text(localization.account_deleteAccountTitle),
        content: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(localization.account_deleteAccountWarning),
              const SizedBox(height: 16),
              Input(
                inputType: InputType.password,
                labelText: localization.account_currentPassword,
                toggleEye: _toggleEye,
                onToggleEye: () => setState(() {
                  _toggleEye = !_toggleEye;
                }),
                validator: (password) {
                  if (isPasswordValid(password)) return null;
                  return localization.account_currentPasswordError;
                },
                controller: _passwordController,
              ),
              Visibility(
                visible: state.deleteError != null,
                child: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    state.deleteError?.localize(localization) ?? "",
                    style: TextStyle(color: Colors.red.shade400),
                  ),
                ),
              ),
              if (state.deleteBusy)
                const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: LinearProgressIndicator(),
                ),
            ]),
          ),
        ),
        actions: [
          TextButton(
            onPressed:
                state.deleteBusy ? null : () => Navigator.pop(context),
            child: Text(localization.global_cancel),
          ),
          TextButton(
            style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error),
            onPressed: state.deleteBusy
                ? null
                : () {
                    if (_formKey.currentState!.validate()) {
                      context
                          .read<AccountCubit>()
                          .deleteAccount(_passwordController.text);
                    }
                  },
            child: Text(localization.global_delete),
          ),
        ],
      );
    });
  }
}
