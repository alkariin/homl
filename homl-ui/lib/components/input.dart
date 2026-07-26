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

  /// More than 1 line turns the input into a textarea
  final int maxLines;
  final int? minLines;

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
      this.maxLines = 1,
      this.minLines,
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
        return _NormalInput(labelText, onChange, initialValue, validator,
            onBlur, errorText, maxLines, minLines, controller);
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
  final int maxLines;
  final int? minLines;
  final TextEditingController? controller;

  const _NormalInput(this.labelText, this.onChange, this.initialValue,
      this.validator, this.onBlur, this.errorText, this.maxLines,
      this.minLines, this.controller);

  @override
  State<_NormalInput> createState() => _NormalInputState();
}

class _NormalInputState extends State<_NormalInput> {
  final FocusNode focusNode = FocusNode();
  final formKey = GlobalKey<FormFieldState>();

  /// Here to put the initial value and to get the text value afterward
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        widget.controller ?? TextEditingController(text: widget.initialValue);
    // Registered once: adding the listener in build would stack a new
    // callback on every rebuild.
    focusNode.addListener(_onFocusChanged);
  }

  void _onFocusChanged() {
    if (focusNode.hasFocus) return;
    widget.onBlur?.call(_controller.text);
    if (_controller.text.isEmpty) {
      _resetEmptied();
    } else if (formKey.currentState?.validate() ?? false) {
      formKey.currentState?.save();
    }
  }

  /// Drops the validation error left on a field the user emptied. The reset
  /// also puts the initial text back and re-notifies [Input.onChange] with
  /// it, so an emptied field would refill itself on blur (and the parent
  /// would hear a change it did not make): clear it again right after.
  void _resetEmptied() {
    formKey.currentState?.reset();
    if (_controller.text.isEmpty) return;
    _controller.clear();
    widget.onChange?.call('');
  }

  @override
  void dispose() {
    focusNode.dispose();
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
        key: formKey,
        onChanged: widget.onChange,
        focusNode: focusNode,
        controller: _controller,
        maxLines: widget.maxLines,
        minLines: widget.minLines,
        keyboardType:
            widget.maxLines > 1 ? TextInputType.multiline : null,
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
  final FocusNode focusNode = FocusNode();
  final formKey = GlobalKey<FormFieldState>();

  /// Here to put the initial value and to get the text value afterward
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _toggleEye = true;
    _controller =
        widget.controller ?? TextEditingController(text: widget.initialValue);
    // Registered once: adding the listener in build would stack a new
    // callback on every rebuild.
    focusNode.addListener(_onFocusChanged);
  }

  void _onFocusChanged() {
    if (focusNode.hasFocus) return;
    widget.onBlur?.call(_controller.text);
    if (_controller.text.isEmpty) {
      // See _NormalInputState._resetEmptied: the reset would refill the field
      // with its initial text.
      formKey.currentState?.reset();
      if (_controller.text.isNotEmpty) {
        _controller.clear();
        widget.onChange?.call('');
      }
    } else if (formKey.currentState?.validate() ?? false) {
      formKey.currentState?.save();
    }
  }

  @override
  void dispose() {
    focusNode.dispose();
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
