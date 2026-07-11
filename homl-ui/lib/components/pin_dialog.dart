import 'package:flutter/material.dart';
import 'package:homl/data/repositories/api.dart';
import 'package:homl/l10n/app_localizations.dart';
import 'package:pinput/pinput.dart';

class PinDialog extends StatelessWidget {
  final Future<PinAuthResult> Function(String) onChanged;
  final VoidCallback? returnToLogin;

  const PinDialog({super.key, required this.onChanged, this.returnToLogin});

  static Route<String> route(
      BuildContext context, Future<PinAuthResult> Function(String) onChanged,
      {VoidCallback? returnToLogin}) {
    return DialogRoute<String>(
        context: context,
        builder: (_) =>
            PinDialog(onChanged: onChanged, returnToLogin: returnToLogin));
  }

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
        widthFactor: 1, child: PinDialogView(onChanged, returnToLogin));
  }
}

// -----

class PinDialogView extends StatefulWidget {
  final Future<PinAuthResult> Function(String) onChanged;
  final VoidCallback? returnToLogin;

  const PinDialogView(this.onChanged, this.returnToLogin, {super.key});

  @override
  State<PinDialogView> createState() => _PinDialogViewState();
}

// -----

class _PinDialogViewState extends State<PinDialogView> {
  late final TextEditingController pinController;
  late final FocusNode focusNode;
  late final GlobalKey<FormState> formKey;

  bool showError = false;
  int? attemptsRemaining;

  @override
  void initState() {
    super.initState();
    formKey = GlobalKey<FormState>();
    pinController = TextEditingController();
    focusNode = FocusNode();
  }

  @override
  void dispose() {
    pinController.dispose();
    focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var localization = AppLocalizations.of(context)!;
    const focusedBorderColor = Color.fromRGBO(23, 171, 144, 1);
    const fillColor = Color.fromRGBO(243, 246, 249, 0);
    const borderColor = Color.fromRGBO(23, 171, 144, 0.4);

    final defaultPinTheme = PinTheme(
      width: 56,
      height: 56,
      textStyle: const TextStyle(
        fontSize: 22,
        color: Color.fromRGBO(30, 60, 87, 1),
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: borderColor),
      ),
    );

    return SimpleDialog(title: Text(localization.account_enterPin), children: [
      Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Pinput(
                    controller: pinController,
                    focusNode: focusNode,
                    autofocus: true,
                    defaultPinTheme: defaultPinTheme,
                    separatorBuilder: (index) => const SizedBox(width: 8),
                    hapticFeedbackType: HapticFeedbackType.lightImpact,
                    onCompleted: (value) async {
                      final result =
                          await widget.onChanged(pinController.text);
                      if (!mounted) return;
                      // On lockout the auth status stream drives the
                      // navigation away from this dialog: do nothing here.
                      if (!result.success && !result.locked) {
                        pinController.text = "";
                        setState(() {
                          showError = true;
                          attemptsRemaining = result.attemptsRemaining;
                        });
                      }
                    },
                    forceErrorState: showError,
                    errorText: attemptsRemaining != null
                        ? localization
                            .account_pinAttemptsRemaining(attemptsRemaining!)
                        : localization.account_pinIncorrect,
                    cursor: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(bottom: 9),
                          width: 22,
                          height: 1,
                          color: focusedBorderColor,
                        ),
                      ],
                    ),
                    focusedPinTheme: defaultPinTheme.copyWith(
                      decoration: defaultPinTheme.decoration!.copyWith(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: focusedBorderColor),
                      ),
                    ),
                    submittedPinTheme: defaultPinTheme.copyWith(
                      decoration: defaultPinTheme.decoration!.copyWith(
                        color: fillColor,
                        borderRadius: BorderRadius.circular(19),
                        border: Border.all(color: focusedBorderColor),
                      ),
                    ),
                    errorPinTheme: defaultPinTheme.copyBorderWith(
                      border: Border.all(color: Colors.redAccent),
                    ),
                  ),
                ),
                if (widget.returnToLogin != null)
                  Container(
                      margin: const EdgeInsets.only(top: 30, bottom: 10),
                      child: OutlinedButton(
                        onPressed: () {
                          widget.returnToLogin!();
                        },
                        child: Text(localization.account_returnToLogin),
                      ))
              ],
            ),
          ))
    ]);
  }
}
