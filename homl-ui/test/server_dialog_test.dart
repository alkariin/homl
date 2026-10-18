import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import 'package:homl/data/repositories/users.repository.dart';
import 'package:homl/helpers/localizations.dart';
import 'package:homl/helpers/server_address.dart';
import 'package:homl/l10n/app_localizations.dart';
import 'package:homl/pages/login/view/server_dialog.dart';

class MockUsersRepository extends Mock implements UsersRepository {}

void main() {
  late MockUsersRepository repository;
  late ServerCheck? result;

  setUp(() {
    repository = MockUsersRepository();
    result = null;
    ServerAddress.reset('');
  });

  tearDown(() => ServerAddress.reset());

  Future<void> openDialog(WidgetTester tester) async {
    await tester.pumpWidget(RepositoryProvider<UsersRepository>.value(
      value: repository,
      child: MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async => result = await ServerDialog.show(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('an http:// address is flagged as unencrypted', (tester) async {
    await openDialog(tester);

    await tester.enterText(find.byType(TextField), '192.168.1.10:8090');
    await tester.pump();
    expect(
        find.text('Unencrypted connection: use it on your home network only.'),
        findsOneWidget);

    await tester.enterText(find.byType(TextField), 'homl.example.com');
    await tester.pump();
    expect(
        find.text('Unencrypted connection: use it on your home network only.'),
        findsNothing);
  });

  testWidgets('an address that cannot be one is refused before any request',
      (tester) async {
    await openDialog(tester);

    await tester.enterText(find.byType(TextField), 'ftp://nas');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Enter an address such as http://192.168.1.10:8090'),
        findsOneWidget);
    verifyNever(() => repository.changeServer(any()));
  });

  testWidgets('the dialog stays open and says why when no server answers',
      (tester) async {
    when(() => repository.changeServer(any())).thenAnswer(
        (_) async => const ServerCheck(ServerCheckOutcome.unreachable));
    await openDialog(tester);

    await tester.enterText(find.byType(TextField), '192.168.1.10:8090');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    verify(() => repository.changeServer('http://192.168.1.10:8090/api'))
        .called(1);
    expect(find.text('No server answers at this address.'), findsOneWidget);
    expect(find.byType(ServerDialog), findsOneWidget);
  });

  testWidgets('a homl server that answers closes the dialog with its check',
      (tester) async {
    when(() => repository.changeServer(any())).thenAnswer(
        (_) async => const ServerCheck(ServerCheckOutcome.ok, 'v0.5.0'));
    await openDialog(tester);

    await tester.enterText(find.byType(TextField), '192.168.1.10:8090');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.byType(ServerDialog), findsNothing);
    expect(result?.version, 'v0.5.0');
  });
}
