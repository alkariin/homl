import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:homl/data/repositories/api.dart';
import 'package:homl/data/repositories/users.repository.dart';
import 'package:homl/helpers/language.dart';
import 'package:homl/pages/register/bloc/register_cubit.dart';

class MockUsersRepository extends Mock implements UsersRepository {}

void main() {
  late MockUsersRepository repository;

  setUpAll(() {
    registerFallbackValue(Language.en);
  });

  setUp(() {
    repository = MockUsersRepository();
  });

  blocTest<RegisterCubit, RegisterState>(
    'sets isRegisterIncorrect when the registration is rejected',
    build: () {
      when(() => repository.register(any(), any(), any()))
          .thenThrow(UserRequestFailure());
      return RegisterCubit(repository, Language.en);
    },
    seed: () =>
        const RegisterState(username: 'user@example.com', password: 'Pass1!aa'),
    act: (cubit) => cubit.submit(),
    expect: () => [
      predicate<RegisterState>((s) =>
          s.status == RegisterStatus.submitting && !s.isRegisterIncorrect),
      predicate<RegisterState>(
          (s) => s.status == RegisterStatus.editing && s.isRegisterIncorrect),
    ],
  );

  blocTest<RegisterCubit, RegisterState>(
    'sets isRegisterIncorrect on an unexpected error too',
    build: () {
      when(() => repository.register(any(), any(), any()))
          .thenThrow(Exception('boom'));
      return RegisterCubit(repository, Language.en);
    },
    seed: () =>
        const RegisterState(username: 'user@example.com', password: 'Pass1!aa'),
    act: (cubit) => cubit.submit(),
    expect: () => [
      predicate<RegisterState>((s) => !s.isRegisterIncorrect),
      predicate<RegisterState>((s) => s.isRegisterIncorrect),
    ],
  );

  blocTest<RegisterCubit, RegisterState>(
    'resets the flag on a new submit so the listener re-triggers',
    build: () {
      when(() => repository.register(any(), any(), any()))
          .thenThrow(UserRequestFailure());
      return RegisterCubit(repository, Language.en);
    },
    seed: () => const RegisterState(
        username: 'user@example.com',
        password: 'Pass1!aa',
        isRegisterIncorrect: true),
    act: (cubit) => cubit.submit(),
    expect: () => [
      predicate<RegisterState>((s) => !s.isRegisterIncorrect),
      predicate<RegisterState>((s) => s.isRegisterIncorrect),
    ],
  );

  blocTest<RegisterCubit, RegisterState>(
    'does not set isRegisterIncorrect on success',
    build: () {
      when(() => repository.register(any(), any(), any()))
          .thenAnswer((_) async => AuthenticationStatus.authenticated);
      return RegisterCubit(repository, Language.en);
    },
    seed: () =>
        const RegisterState(username: 'user@example.com', password: 'Pass1!aa'),
    act: (cubit) => cubit.submit(),
    verify: (cubit) {
      expect(cubit.state.isRegisterIncorrect, isFalse);
      expect(cubit.state.status, RegisterStatus.editing);
    },
  );
}
