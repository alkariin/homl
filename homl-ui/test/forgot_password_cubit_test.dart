import 'package:flutter_test/flutter_test.dart';
import 'package:homl/data/repositories/users.repository.dart';
import 'package:homl/pages/forgot_password/bloc/forgot_password_cubit.dart';

class _StubUsersRepository extends UsersRepository {
  Object? requestError;
  Object? confirmError;
  int requestCount = 0;

  @override
  Future<void> requestPasswordReset(String email) async {
    requestCount++;
    if (requestError != null) throw requestError!;
  }

  @override
  Future<void> confirmPasswordReset(
      String email, String code, String newPassword) async {
    if (confirmError != null) throw confirmError!;
  }
}

void main() {
  late _StubUsersRepository repository;
  late ForgotPasswordCubit cubit;

  setUp(() {
    repository = _StubUsersRepository();
    cubit = ForgotPasswordCubit(repository);
    cubit.emailChanged('user@example.com');
  });

  tearDown(() => cubit.close());

  test('sendCode moves to the code-entry step on success', () async {
    await cubit.sendCode();

    expect(repository.requestCount, 1);
    expect(cubit.state.step, ForgotPasswordStep.codeEntry);
    expect(cubit.state.status, ForgotPasswordStatus.editing);
  });

  test('sendCode still moves to the code-entry step on failure (no enumeration)',
      () async {
    repository.requestError = UserOtherFailure();

    await cubit.sendCode();

    expect(cubit.state.step, ForgotPasswordStep.codeEntry);
    expect(cubit.state.message, ForgotPasswordMessage.none);
  });

  test('submit surfaces an invalid-code message', () async {
    repository.confirmError = ResetCodeInvalidFailure();
    cubit.codeChanged('123456');
    cubit.newPasswordChanged('NewPass123!');

    await cubit.submit();

    expect(cubit.state.message, ForgotPasswordMessage.invalidCode);
    expect(cubit.state.status, ForgotPasswordStatus.editing);
  });

  test('submit surfaces a generic error on unexpected failures', () async {
    repository.confirmError = UserOtherFailure();
    cubit.codeChanged('123456');
    cubit.newPasswordChanged('NewPass123!');

    await cubit.submit();

    expect(cubit.state.message, ForgotPasswordMessage.error);
  });

  test('submit succeeds without any message', () async {
    cubit.codeChanged('123456');
    cubit.newPasswordChanged('NewPass123!');

    await cubit.submit();

    expect(cubit.state.message, ForgotPasswordMessage.none);
    expect(cubit.state.status, ForgotPasswordStatus.editing);
  });
}
