part of 'login_bloc.dart';

class LoginState extends Equatable {
  const LoginState(
      {this.username = "", this.password = "", this.isLoginIncorrect = false});

  final String username;
  final String password;
  final bool isLoginIncorrect;

  LoginState update(
      {String? username, String? password, bool? isLoginIncorrect}) {
    return LoginState(
        username: username ?? this.username,
        password: password ?? this.password,
        isLoginIncorrect: isLoginIncorrect ?? this.isLoginIncorrect);
  }

  @override
  List<Object> get props => [username, password];
}
