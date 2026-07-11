part of 'login_bloc.dart';

enum LoginStatus { editing, submitting }

class LoginState extends Equatable {
  const LoginState(
      {this.username = "",
      this.password = "",
      this.isLoginIncorrect = false,
      this.status = LoginStatus.editing});

  final String username;
  final String password;
  final bool isLoginIncorrect;
  final LoginStatus status;

  LoginState update(
      {String? username,
      String? password,
      bool? isLoginIncorrect,
      LoginStatus? status}) {
    return LoginState(
        username: username ?? this.username,
        password: password ?? this.password,
        isLoginIncorrect: isLoginIncorrect ?? this.isLoginIncorrect,
        status: status ?? this.status);
  }

  @override
  List<Object> get props => [username, password, isLoginIncorrect, status];

  /// Never log the password (states are logged by the bloc observer).
  @override
  String toString() =>
      'LoginState(username: $username, password: [REDACTED], '
      'isLoginIncorrect: $isLoginIncorrect, status: $status)';
}
