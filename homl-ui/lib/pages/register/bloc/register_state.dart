part of 'register_bloc.dart';

class RegisterState extends Equatable {
  const RegisterState(
      {this.username = "",
      this.password = "",
      this.isRegisterIncorrect = false});

  final String username;
  final String password;
  final bool isRegisterIncorrect;

  RegisterState update(
      {String? username, String? password, bool? isRegisterIncorrect}) {
    return RegisterState(
        username: username ?? this.username,
        password: password ?? this.password,
        isRegisterIncorrect: isRegisterIncorrect ?? this.isRegisterIncorrect);
  }

  @override
  List<Object> get props => [username, password];
}
