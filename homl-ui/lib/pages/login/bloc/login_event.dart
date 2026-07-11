part of 'login_bloc.dart';

@immutable
abstract class LoginEvent extends Equatable {
  const LoginEvent();

  @override
  List<Object> get props => [];
}

// ----

class LoginUsernameChanged extends LoginEvent {
  const LoginUsernameChanged(this.username);

  final String username;

  @override
  List<Object> get props => [username];
}

// ----

class LoginPasswordChanged extends LoginEvent {
  const LoginPasswordChanged(this.password);

  final String password;

  @override
  List<Object> get props => [password];

  /// Never log the password (events are logged by the bloc observer).
  @override
  String toString() => 'LoginPasswordChanged([REDACTED])';
}

// ----

class LoginSubmitted extends LoginEvent {}
