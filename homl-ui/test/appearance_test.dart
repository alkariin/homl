import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:homl/data/models/settings.dart';
import 'package:homl/data/repositories/settings.repository.dart';
import 'package:homl/helpers/language.dart';
import 'package:homl/helpers/local_storage_manager.dart';
import 'package:homl/helpers/localizations.dart';
import 'package:homl/helpers/theme.dart';
import 'package:homl/l10n/app_localizations.dart';
import 'package:homl/pages/app/bloc/app_cubit.dart';
import 'package:homl/pages/settings/view/appearance_dialog.dart';

class MockSettingsRepository extends Mock implements SettingsRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const storageChannel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  late Map<String, String> storage;
  late MockSettingsRepository settingsRepository;

  setUp(() {
    storage = {};
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
      }
      return null;
    });

    settingsRepository = MockSettingsRepository();
    when(() => settingsRepository.settingsStream)
        .thenAnswer((_) => const Stream<Settings>.empty());
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, null);
  });

  group('the saved appearance', () {
    test('follows the system until a choice is made', () async {
      expect(await AppCubit.loadThemeMode(), ThemeMode.system);
    });

    test('a choice applies at once and is kept on this device', () async {
      final cubit = AppCubit(Language.en, settingsRepository);

      await cubit.updateThemeMode(ThemeMode.dark);

      expect(cubit.state.themeMode, ThemeMode.dark);
      expect(storage[LocalStorageKey.themeMode.name], 'dark');
      expect(await AppCubit.loadThemeMode(), ThemeMode.dark);
      await cubit.close();
    });

    test('a value it does not know follows the system', () async {
      storage[LocalStorageKey.themeMode.name] = 'sepia';

      expect(await AppCubit.loadThemeMode(), ThemeMode.system);
    });
  });

  group('the appearance dialog', () {
    late AppCubit cubit;

    Future<void> openDialog(WidgetTester tester, {Locale? locale}) async {
      await tester.pumpWidget(BlocProvider.value(
        value: cubit,
        // Wired like the app: the cubit's mode picks the theme.
        child: BlocBuilder<AppCubit, AppState>(
          builder: (context, state) => MaterialApp(
            theme: homlTheme(),
            darkTheme: homlTheme(brightness: Brightness.dark),
            themeMode: state.themeMode,
            locale: locale,
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () =>
                      Navigator.push(context, AppearanceDialog.route(context)),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    setUp(() {
      cubit =
          AppCubit(Language.en, settingsRepository, themeMode: ThemeMode.light);
    });

    tearDown(() => cubit.close());

    testWidgets('checks the current appearance', (tester) async {
      await openDialog(tester);

      expect(find.text('Select appearance'), findsOneWidget);
      expect(
          find.descendant(
              of: find.widgetWithText(ListTile, 'Light'),
              matching: find.byIcon(Icons.radio_button_checked)),
          findsOneWidget);
      expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
    });

    testWidgets('turns the app dark on the spot and saves the choice',
        (tester) async {
      await openDialog(tester);

      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();

      expect(find.text('Select appearance'), findsNothing);
      expect(cubit.state.themeMode, ThemeMode.dark);
      expect(Theme.of(tester.element(find.text('open'))).brightness,
          Brightness.dark);
      expect(storage[LocalStorageKey.themeMode.name], 'dark');
    });

    testWidgets('speaks the app language', (tester) async {
      await openDialog(tester, locale: const Locale('fr'));

      expect(find.text("Sélectionner l'apparence"), findsOneWidget);
      expect(find.text('Comme le système'), findsOneWidget);
      expect(find.text('Clair'), findsOneWidget);
      expect(find.text('Sombre'), findsOneWidget);
    });
  });
}
