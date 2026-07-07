import 'package:flutter_test/flutter_test.dart';
import 'package:homl/data/repositories/api.dart';
import 'package:homl/data/repositories/users.repository.dart';
import 'package:homl/pages/login/bloc/login_bloc.dart';

class _StubUsersRepository extends UsersRepository {
  Object? error;

  @override
  Future<AuthenticationStatus> login(String username, String password) async {
    if (error != null) throw error!;
    return AuthenticationStatus.authenticated;
  }
}

void main() {
  late _StubUsersRepository repository;
  late LoginBloc bloc;

  setUp(() {
    repository = _StubUsersRepository();
    bloc = LoginBloc(repository);
    bloc.add(const LoginUsernameChanged('user@example.com'));
    bloc.add(const LoginPasswordChanged('Password1!'));
  });

  tearDown(() => bloc.close());

  test('sets isLoginIncorrect when credentials are rejected', () async {
    repository.error = UserRequestFailure();

    bloc.add(LoginSubmitted());

    await expectLater(
      bloc.stream,
      emitsThrough(predicate<LoginState>((s) => s.isLoginIncorrect)),
    );
  });

  test('sets isLoginIncorrect again on a second failed attempt', () async {
    repository.error = UserRequestFailure();

    bloc.add(LoginSubmitted());
    await expectLater(
      bloc.stream,
      emitsThrough(predicate<LoginState>((s) => s.isLoginIncorrect)),
    );

    // The flag is reset on submit, then raised again, so the listener
    // fires for every failed attempt — not just the first one.
    bloc.add(LoginSubmitted());
    await expectLater(
      bloc.stream,
      emitsInOrder([
        predicate<LoginState>((s) => !s.isLoginIncorrect),
        predicate<LoginState>((s) => s.isLoginIncorrect),
      ]),
    );
  });

  test('does not set isLoginIncorrect on success', () async {
    bloc.add(LoginSubmitted());

    await expectLater(
      bloc.stream,
      emitsThrough(predicate<LoginState>(
        (s) => s.username.isNotEmpty && !s.isLoginIncorrect,
      )),
    );
    expect(bloc.state.isLoginIncorrect, isFalse);
  });
}
