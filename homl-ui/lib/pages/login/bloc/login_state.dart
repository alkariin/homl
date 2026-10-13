part of 'login_cubit.dart';

enum LoginStatus { editing, submitting }

class LoginState extends Equatable {
  const LoginState(
      {this.username = "",
      this.password = "",
      this.isLoginIncorrect = false,
      this.isServerUnreachable = false,
      this.status = LoginStatus.editing});

  final String username;
  final String password;
  final bool isLoginIncorrect;

  /// The login failed because the server could not be reached, not because
  /// of the credentials.
  final bool isServerUnreachable;
  final LoginStatus status;

  LoginState update(
      {String? username,
      String? password,
      bool? isLoginIncorrect,
      bool? isServerUnreachable,
      LoginStatus? status}) {
    return LoginState(
        username: username ?? this.username,
        password: password ?? this.password,
        isLoginIncorrect: isLoginIncorrect ?? this.isLoginIncorrect,
        isServerUnreachable: isServerUnreachable ?? this.isServerUnreachable,
        status: status ?? this.status);
  }

  @override
  List<Object> get props =>
      [username, password, isLoginIncorrect, isServerUnreachable, status];

  /// Never log the password (states are logged by the bloc observer).
  @override
  String toString() =>
      'LoginState(username: $username, password: [REDACTED], '
      'isLoginIncorrect: $isLoginIncorrect, '
      'isServerUnreachable: $isServerUnreachable, status: $status)';
}
