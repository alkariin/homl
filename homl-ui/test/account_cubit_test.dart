import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:homl/data/models/user.dart';
import 'package:homl/data/repositories/users.repository.dart';
import 'package:homl/helpers/app_message.dart';
import 'package:homl/pages/account/bloc/account_cubit.dart';

class MockUsersRepository extends Mock implements UsersRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const storageChannel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  late Map<String, String> storage;
  late MockUsersRepository repository;

  setUpAll(() {
    registerFallbackValue(User(isFingerprintEnabled: false, isPinEnabled: false));
  });

  setUp(() {
    storage = {};
    repository = MockUsersRepository();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, (call) async {
      final args = (call.arguments as Map?)?.cast<String, dynamic>();
      switch (call.method) {
        case 'read':
          return storage[args!['key'] as String];
        case 'write':
          storage[args!['key'] as String] = args['value'] as String;
          return null;
        case 'delete':
          storage.remove(args!['key'] as String);
          return null;
        case 'containsKey':
          return storage.containsKey(args!['key'] as String);
        case 'readAll':
          return storage;
        case 'deleteAll':
          storage.clear();
          return null;
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, null);
  });

  Future<AccountCubit> buildInitializedCubit() async {
    final cubit = AccountCubit(repository);
    // Wait for the init() call triggered by the constructor.
    await expectLater(cubit.stream,
        emitsThrough(predicate<AccountState>((s) => s.user != null)));
    return cubit;
  }

  test('emits the pinEnabled modal when the PIN setup succeeds', () async {
    when(() => repository.secureAuth(any())).thenAnswer((_) async =>
        User(isFingerprintEnabled: false, isPinEnabled: true));

    final cubit = await buildInitializedCubit();
    unawaited(cubit.submitPin('1234'));

    await expectLater(
      cubit.stream,
      emitsThrough(predicate<AccountState>(
          (s) => s.modal == AppMessage.pinEnabled && s.user!.isPinEnabled)),
    );
    expect(storage.containsKey('pinKeypair'), isTrue);

    await cubit.close();
  });

  test('emits the unexpectedError modal when the backend rejects the update',
      () async {
    when(() => repository.secureAuth(any())).thenThrow(UserOtherFailure());

    final cubit = await buildInitializedCubit();
    unawaited(cubit.submitPin('1234'));

    await expectLater(
      cubit.stream,
      emitsThrough(predicate<AccountState>(
          (s) => s.modal == AppMessage.unexpectedError)),
    );

    await cubit.close();
  });

  test('endModal clears the modal so it can fire again', () async {
    when(() => repository.secureAuth(any())).thenThrow(UserOtherFailure());

    final cubit = await buildInitializedCubit();
    unawaited(cubit.submitPin('1234'));
    await expectLater(
      cubit.stream,
      emitsThrough(predicate<AccountState>((s) => s.modal != null)),
    );

    // Subscribe before clearing so the synchronous emit is observed.
    final expectation = expectLater(
      cubit.stream,
      emitsThrough(predicate<AccountState>((s) => s.modal == null)),
    );
    cubit.endModal();
    await expectation;

    await cubit.close();
  });

  test('deleteAccount reports a wrong password inline', () async {
    when(() => repository.deleteAccount(any()))
        .thenAnswer((_) async => throw UserRequestFailure());

    final cubit = await buildInitializedCubit();
    unawaited(cubit.deleteAccount('WrongPass123!'));

    await expectLater(
      cubit.stream,
      emitsThrough(predicate<AccountState>((s) =>
          s.deleteError == AppMessage.passwordIncorrect && !s.deleteBusy)),
    );
    verify(() => repository.deleteAccount('WrongPass123!')).called(1);

    await cubit.close();
  });

  test('deleteAccount maps any other failure to accountDeleteError', () async {
    when(() => repository.deleteAccount(any()))
        .thenAnswer((_) async => throw UserOtherFailure());

    final cubit = await buildInitializedCubit();
    unawaited(cubit.deleteAccount('Delete1234!'));

    await expectLater(
      cubit.stream,
      emitsThrough(predicate<AccountState>((s) =>
          s.deleteError == AppMessage.accountDeleteError && !s.deleteBusy)),
    );

    await cubit.close();
  });

  test('deleteAccount stays busy on success: the app navigates away', () async {
    when(() => repository.deleteAccount(any())).thenAnswer((_) async {});

    final cubit = await buildInitializedCubit();
    await cubit.deleteAccount('Delete1234!');

    expect(cubit.state.deleteBusy, isTrue);
    expect(cubit.state.deleteError, isNull);

    await cubit.close();
  });
}
