part of 'register_bloc.dart';

@immutable
abstract class RegisterEvent extends Equatable {
  const RegisterEvent();

  @override
  List<Object> get props => [];
}

// ----

class RegisterUsernameChanged extends RegisterEvent {
  const RegisterUsernameChanged(this.username);

  final String username;

  @override
  List<Object> get props => [username];
}

// ----

class RegisterPasswordChanged extends RegisterEvent {
  const RegisterPasswordChanged(this.password);

  final String password;

  @override
  List<Object> get props => [password];

  /// Never log the password (events are logged by the bloc observer).
  @override
  String toString() => 'RegisterPasswordChanged([REDACTED])';
}

// ----

class RegisterSubmitted extends RegisterEvent {}
