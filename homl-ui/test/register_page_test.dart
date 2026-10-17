import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import 'package:homl/data/repositories/users.repository.dart';
import 'package:homl/helpers/localizations.dart';
import 'package:homl/l10n/app_localizations.dart';
import 'package:homl/pages/register/register.dart';

class MockUsersRepository extends Mock implements UsersRepository {}

void main() {
  late MockUsersRepository repository;

  setUp(() => repository = MockUsersRepository());

  /// The login page stands in as a home with one button pushing the
  /// registration page, so the way back can be followed.
  Future<void> openRegistration(WidgetTester tester, bool? open) async {
    when(() => repository.isRegistrationOpen()).thenAnswer((_) async => open);
    await tester.pumpWidget(RepositoryProvider<UsersRepository>.value(
      value: repository,
      child: MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(RegisterPage.route()),
              child: const Text('login page'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('login page'));
    await tester.pumpAndSettle();
  }

  testWidgets('a closed server is explained instead of the form',
      (tester) async {
    await openRegistration(tester, false);

    expect(find.text('Registration is closed'), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);

    await tester.tap(find.text('Back to login'));
    await tester.pumpAndSettle();
    expect(find.text('login page'), findsOneWidget);
  });

  for (final open in [true, null]) {
    testWidgets('an answer of $open shows the form', (tester) async {
      await openRegistration(tester, open);

      expect(find.text('Registration is closed'), findsNothing);
      expect(find.byType(TextFormField), findsNWidgets(2));
    });
  }
}
