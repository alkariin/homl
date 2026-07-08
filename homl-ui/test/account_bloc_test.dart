import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:homl/data/models/user.dart';
import 'package:homl/data/repositories/users.repository.dart';
import 'package:homl/helpers/app_message.dart';
import 'package:homl/pages/account/bloc/account_bloc.dart';

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

  Future<AccountBloc> buildInitializedBloc() async {
    final bloc = AccountBloc(repository);
    // Wait for the InitValues event triggered by the constructor.
    await expectLater(
        bloc.stream, emitsThrough(predicate<AccountState>((s) => s.user != null)));
    return bloc;
  }

  test('emits the pinEnabled modal when the PIN setup succeeds', () async {
    when(() => repository.secureAuth(any())).thenAnswer((_) async =>
        User(isFingerprintEnabled: false, isPinEnabled: true));

    final bloc = await buildInitializedBloc();
    bloc.add(const SubmitPin('1234'));

    await expectLater(
      bloc.stream,
      emitsThrough(predicate<AccountState>(
          (s) => s.modal == AppMessage.pinEnabled && s.user!.isPinEnabled)),
    );
    expect(storage.containsKey('pinKeypair'), isTrue);

    await bloc.close();
  });

  test('emits the unexpectedError modal when the backend rejects the update',
      () async {
    when(() => repository.secureAuth(any())).thenThrow(UserOtherFailure());

    final bloc = await buildInitializedBloc();
    bloc.add(const SubmitPin('1234'));

    await expectLater(
      bloc.stream,
      emitsThrough(predicate<AccountState>(
          (s) => s.modal == AppMessage.unexpectedError)),
    );

    await bloc.close();
  });

  test('EndAccountModal clears the modal so it can fire again', () async {
    when(() => repository.secureAuth(any())).thenThrow(UserOtherFailure());

    final bloc = await buildInitializedBloc();
    bloc.add(const SubmitPin('1234'));
    await expectLater(
      bloc.stream,
      emitsThrough(predicate<AccountState>((s) => s.modal != null)),
    );

    bloc.add(EndAccountModal());
    await expectLater(
      bloc.stream,
      emitsThrough(predicate<AccountState>((s) => s.modal == null)),
    );

    await bloc.close();
  });
}
