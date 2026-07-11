part of 'register_bloc.dart';

enum RegisterStatus { editing, submitting }

class RegisterState extends Equatable {
  const RegisterState(
      {this.username = "",
      this.password = "",
      this.isRegisterIncorrect = false,
      this.status = RegisterStatus.editing});

  final String username;
  final String password;
  final bool isRegisterIncorrect;
  final RegisterStatus status;

  RegisterState update(
      {String? username,
      String? password,
      bool? isRegisterIncorrect,
      RegisterStatus? status}) {
    return RegisterState(
        username: username ?? this.username,
        password: password ?? this.password,
        isRegisterIncorrect: isRegisterIncorrect ?? this.isRegisterIncorrect,
        status: status ?? this.status);
  }

  @override
  List<Object> get props => [username, password, isRegisterIncorrect, status];

  /// Never log the password (states are logged by the bloc observer).
  @override
  String toString() =>
      'RegisterState(username: $username, password: [REDACTED], '
      'isRegisterIncorrect: $isRegisterIncorrect, status: $status)';
}
