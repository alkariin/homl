import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:homl/data/repositories/api.dart';
import 'package:homl/data/repositories/users.repository.dart';
import 'package:homl/pages/login/bloc/login_cubit.dart';

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
  late LoginCubit cubit;

  setUp(() {
    repository = _StubUsersRepository();
    cubit = LoginCubit(repository);
    cubit.usernameChanged('user@example.com');
    cubit.passwordChanged('Password1!');
  });

  tearDown(() => cubit.close());

  test('sets isLoginIncorrect when credentials are rejected', () async {
    repository.error = UserRequestFailure();

    unawaited(cubit.submit());

    await expectLater(
      cubit.stream,
      emitsThrough(predicate<LoginState>((s) => s.isLoginIncorrect)),
    );
  });

  test('sets isLoginIncorrect again on a second failed attempt', () async {
    repository.error = UserRequestFailure();

    unawaited(cubit.submit());
    await expectLater(
      cubit.stream,
      emitsThrough(predicate<LoginState>((s) => s.isLoginIncorrect)),
    );

    // The flag is reset on submit, then raised again, so the listener
    // fires for every failed attempt — not just the first one. Subscribe
    // before submitting so the synchronous "submitting" state is observed.
    final expectation = expectLater(
      cubit.stream,
      emitsInOrder([
        predicate<LoginState>((s) => !s.isLoginIncorrect),
        predicate<LoginState>((s) => s.isLoginIncorrect),
      ]),
    );
    unawaited(cubit.submit());
    await expectation;
  });

  test('does not set isLoginIncorrect on success', () async {
    unawaited(cubit.submit());

    await expectLater(
      cubit.stream,
      emitsThrough(predicate<LoginState>(
        (s) => s.username.isNotEmpty && !s.isLoginIncorrect,
      )),
    );
    expect(cubit.state.isLoginIncorrect, isFalse);
  });
}
