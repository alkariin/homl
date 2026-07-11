part of 'authentication_cubit.dart';

class AuthenticationState extends Equatable {
  final AuthenticationStatus status;
  final Settings? settings;

  const AuthenticationState._({
    this.status = AuthenticationStatus.unknown,
    this.settings,
  });

  const AuthenticationState.unknown() : this._();

  const AuthenticationState.authenticated()
      : this._(status: AuthenticationStatus.authenticated);

  const AuthenticationState.pinCheck()
      : this._(status: AuthenticationStatus.pinCheck);

  const AuthenticationState.pinLocked()
      : this._(status: AuthenticationStatus.pinLocked);

  const AuthenticationState.biometricCheck()
      : this._(status: AuthenticationStatus.biometricCheck);

  const AuthenticationState.unauthenticated()
      : this._(status: AuthenticationStatus.unauthenticated);

  @override
  List<Object> get props {
    if (settings == null) return [status];
    return [status, settings!];
  }
}
