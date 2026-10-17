part of 'register_cubit.dart';

enum RegisterStatus { editing, submitting }

class RegisterState extends Equatable {
  const RegisterState(
      {this.username = "",
      this.password = "",
      this.isRegisterIncorrect = false,
      this.isRegistrationClosed = false,
      this.status = RegisterStatus.editing});

  final String username;
  final String password;
  final bool isRegisterIncorrect;

  /// The server takes no new accounts: the page explains that instead of
  /// showing the form. Learnt when the page opens, or from a refused
  /// sign-up when the server could not be asked first.
  final bool isRegistrationClosed;
  final RegisterStatus status;

  RegisterState update(
      {String? username,
      String? password,
      bool? isRegisterIncorrect,
      bool? isRegistrationClosed,
      RegisterStatus? status}) {
    return RegisterState(
        username: username ?? this.username,
        password: password ?? this.password,
        isRegisterIncorrect: isRegisterIncorrect ?? this.isRegisterIncorrect,
        isRegistrationClosed: isRegistrationClosed ?? this.isRegistrationClosed,
        status: status ?? this.status);
  }

  @override
  List<Object> get props =>
      [username, password, isRegisterIncorrect, isRegistrationClosed, status];

  /// Never log the password (states are logged by the bloc observer).
  @override
  String toString() =>
      'RegisterState(username: $username, password: [REDACTED], '
      'isRegisterIncorrect: $isRegisterIncorrect, '
      'isRegistrationClosed: $isRegistrationClosed, status: $status)';
}
