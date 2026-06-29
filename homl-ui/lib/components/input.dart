import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

enum InputType { normal, password }

class Input extends StatelessWidget {
  final String labelText;
  final Function(String value)? onChange;
  final String? initialValue;
  final String? Function(String value) validator;
  final Function(String value)? onBlur;
  final String? errorText;
  final InputType? inputType;

  /// The state can be controlled by the parent or the component itself
  final bool? toggleEye;
  final Function()? onToggleEye;
  final TextEditingController? controller;

  const Input(
      {required this.labelText,
      this.onChange,
      this.initialValue,
      required this.validator,
      this.onBlur,
      this.errorText,
      this.inputType,
      this.toggleEye,
      this.onToggleEye,
      this.controller,
      super.key});

  @override
  Widget build(BuildContext context) {
    switch (inputType) {
      case InputType.password:
        return _PasswordInput(labelText, onChange, initialValue, validator,
            onBlur, errorText, toggleEye, onToggleEye, controller);
      default:
        return _NormalInput(
            labelText, onChange, initialValue, validator, onBlur, errorText);
    }
  }
}

// ----------

class _NormalInput extends StatefulWidget {
  final String labelText;
  final void Function(String value)? onChange;
  final String? initialValue;
  final String? Function(String value) validator;
  final void Function(String value)? onBlur;
  final String? errorText;

  const _NormalInput(this.labelText, this.onChange, this.initialValue,
      this.validator, this.onBlur, this.errorText);

  @override
  State<_NormalInput> createState() => _NormalInputState();
}

class _NormalInputState extends State<_NormalInput> {
  FocusNode focusNode = FocusNode();
  final formKey = GlobalKey<FormFieldState>();

  /// Here to put the initial value and to get the text value afterward
  late TextEditingController controller;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    focusNode.addListener(() {
      if (focusNode.hasFocus) return;
      widget.onBlur?.call(controller.text);
      if (controller.text.isEmpty) {
        formKey.currentState?.reset();
      } else if (formKey.currentState?.validate() ?? false) {
        formKey.currentState?.save();
      }
    });

    return TextFormField(
        key: formKey,
        onChanged: widget.onChange,
        focusNode: focusNode,
        controller: controller,
        decoration: InputDecoration(
          labelText: widget.labelText,
          errorText: widget.errorText,
        ),
        validator: (value) {
          if (value == null) return null;
          return widget.validator(value);
        });
  }
}

// ----------

class _PasswordInput extends StatefulWidget {
  final String labelText;
  final Function(String value)? onChange;
  final String? initialValue;
  final String? Function(String value) validator;
  final Function(String value)? onBlur;
  final String? errorText;
  final bool? toggleEye;
  final Function()? onToggleEye;
  final TextEditingController? controller;

  const _PasswordInput(
      this.labelText,
      this.onChange,
      this.initialValue,
      this.validator,
      this.onBlur,
      this.errorText,
      this.toggleEye,
      this.onToggleEye,
      this.controller);

  @override
  State<_PasswordInput> createState() => _PasswordInputState();
}

class _PasswordInputState extends State<_PasswordInput> {
  late bool _toggleEye;
  FocusNode focusNode = FocusNode();
  final formKey = GlobalKey<FormFieldState>();

  /// Here to put the initial value and to get the text value afterward
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _toggleEye = true;
    _controller =
        widget.controller ?? TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    focusNode.addListener(() {
      if (focusNode.hasFocus) return;
      widget.onBlur?.call(_controller.text);
      if (_controller.text.isEmpty) {
        formKey.currentState?.reset();
      } else if (formKey.currentState?.validate() ?? false) {
        formKey.currentState?.save();
      }
    });

    return TextFormField(
        key: formKey,
        onChanged: widget.onChange,
        obscureText: widget.toggleEye ?? _toggleEye,
        focusNode: focusNode,
        controller: _controller,
        decoration: InputDecoration(
          labelText: widget.labelText,
          errorText: widget.errorText,
          suffixIcon: IconButton(
            onPressed: () {
              if (widget.onToggleEye != null) {
                widget.onToggleEye!();
              } else {
                setState(() {
                  _toggleEye = !_toggleEye;
                });
              }
            },
            icon: FaIcon(widget.toggleEye ?? _toggleEye
                ? FontAwesomeIcons.eye
                : FontAwesomeIcons.eyeSlash),
          ),
        ),
        validator: (value) {
          if (value == null) return null;
          return widget.validator(value);
        });
  }
}
