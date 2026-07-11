part of 'forgot_password_cubit.dart';

enum ForgotPasswordStep { emailEntry, codeEntry }

enum ForgotPasswordStatus { editing, submitting }

enum ForgotPasswordMessage { none, invalidCode, error }

class ForgotPasswordState extends Equatable {
  const ForgotPasswordState(
      {this.email = "",
      this.code = "",
      this.newPassword = "",
      this.confirmPassword = "",
      this.step = ForgotPasswordStep.emailEntry,
      this.status = ForgotPasswordStatus.editing,
      this.message = ForgotPasswordMessage.none});

  final String email;
  final String code;
  final String newPassword;
  final String confirmPassword;
  final ForgotPasswordStep step;
  final ForgotPasswordStatus status;
  final ForgotPasswordMessage message;

  ForgotPasswordState update(
      {String? email,
      String? code,
      String? newPassword,
      String? confirmPassword,
      ForgotPasswordStep? step,
      ForgotPasswordStatus? status,
      ForgotPasswordMessage? message}) {
    return ForgotPasswordState(
        email: email ?? this.email,
        code: code ?? this.code,
        newPassword: newPassword ?? this.newPassword,
        confirmPassword: confirmPassword ?? this.confirmPassword,
        step: step ?? this.step,
        status: status ?? this.status,
        message: message ?? this.message);
  }

  @override
  List<Object> get props =>
      [email, code, newPassword, confirmPassword, step, status, message];

  /// Never log the password (states are logged by the bloc observer).
  @override
  String toString() =>
      'ForgotPasswordState(email: $email, code: $code, '
      'newPassword: [REDACTED], confirmPassword: [REDACTED], '
      'step: $step, status: $status, message: $message)';
}
