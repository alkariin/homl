import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:homl/data/repositories/users.repository.dart';
import 'package:homl/l10n/app_localizations.dart';
import 'package:homl/pages/account/bloc/account_cubit.dart';
import 'package:homl/pages/account/view/delete_account_dialog.dart';

class MockUsersRepository extends Mock implements UsersRepository {}

void main() {
  const storageChannel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  late MockUsersRepository repository;

  setUp(() {
    repository = MockUsersRepository();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, (call) async => null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, null);
  });

  Future<void> pumpDialog(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: BlocProvider(
        create: (_) => AccountCubit(repository),
        child: const Scaffold(body: DeleteAccountDialogView()),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('warns about the irreversible loss before asking the password',
      (tester) async {
    await pumpDialog(tester);

    expect(find.textContaining('permanently deletes your account'),
        findsOneWidget);
    expect(find.text('Current password'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
  });

  testWidgets('refuses to delete without a password', (tester) async {
    await pumpDialog(tester);

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Enter your current password'), findsOneWidget);
    verifyNever(() => repository.deleteAccount(any()));
  });

  testWidgets('sends the typed password to the repository', (tester) async {
    when(() => repository.deleteAccount(any())).thenAnswer((_) async {});

    await pumpDialog(tester);

    await tester.enterText(find.byType(TextFormField), 'Delete1234!');
    await tester.tap(find.text('Delete'));
    // Not pumpAndSettle: on success the progress indicator keeps spinning
    // until the app navigates away, so the frames never settle.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    verify(() => repository.deleteAccount('Delete1234!')).called(1);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });

  testWidgets('shows the wrong-password error inline', (tester) async {
    when(() => repository.deleteAccount(any()))
        .thenAnswer((_) async => throw UserRequestFailure());

    await pumpDialog(tester);

    await tester.enterText(find.byType(TextFormField), 'WrongPass123!');
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('The password is not correct'), findsOneWidget);
  });
}
