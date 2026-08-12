import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

import 'package:homl/components/event_card.dart';
import 'package:homl/components/tag.dart' as components;
import 'package:homl/components/tag_input.dart';
import 'package:homl/data/models/category.dart';
import 'package:homl/data/models/event.dart';
import 'package:homl/data/models/settings.dart';
import 'package:homl/data/models/tag.dart';
import 'package:homl/data/repositories/categories.repository.dart';
import 'package:homl/data/repositories/events.repository.dart';
import 'package:homl/data/repositories/settings.repository.dart';
import 'package:homl/data/repositories/tags.repository.dart';
import 'package:homl/helpers/date_tags.dart';
import 'package:homl/l10n/app_localizations.dart';
import 'package:homl/pages/home/bloc/home_cubit.dart';
import 'package:homl/pages/insert/insert.dart';
import 'package:homl/pages/list/bloc/list_cubit.dart';
import 'package:homl/pages/list/list.dart';

class MockEventsRepository extends Mock implements EventsRepository {}

class MockCategoriesRepository extends Mock implements CategoriesRepository {}

class MockTagsRepository extends Mock implements TagsRepository {}

class MockSettingsRepository extends Mock implements SettingsRepository {}

final julyTag = Tag(id: 10, tag: 'July', idCategory: 1);
final yearTag = Tag(id: 11, tag: '2026', idCategory: 1);
final footballTag = Tag(id: 2, tag: 'Football', idCategory: 2);

final categories = [
  Category(
      id: 1,
      category: 'Dates',
      color: '#ffff60',
      isLocked: true,
      kind: CategoryKind.date,
      tags: [julyTag, yearTag]),
  Category(
      id: 2,
      category: 'Hobbies',
      color: '#f28b82',
      isLocked: false,
      kind: CategoryKind.custom,
      tags: [footballTag]),
];

final event = Event(
    id: 1,
    description: 'match',
    date: DateTime(2026, 7, 12),
    tags: [julyTag, yearTag, footballTag]);

void main() {
  group('tag labels', () {
    // The widget tests get this for free: the flutter_localizations delegate
    // initializes the intl data of the locale it loads.
    setUpAll(initializeDateFormatting);

    test('translates the month date tags, leaves the other tags alone', () {
      expect(localizedTagName('July', 'fr'), 'juillet');
      expect(localizedTagName('July', 'de'), 'Juli');
      expect(localizedTagName('July', 'en'), 'July');
      // The year tag and the user tags are language-independent.
      expect(localizedTagName('2026', 'fr'), '2026');
      expect(localizedTagName('Football', 'fr'), 'Football');
    });

    test('recognizes a month name whatever its casing', () {
      expect(monthOfTagName('July'), 7);
      expect(monthOfTagName('  december '), 12);
      expect(monthOfTagName('Juillet'), isNull);
    });
  });

  group('date chips and localized month tags', () {
    late MockEventsRepository eventsRepository;
    late MockCategoriesRepository categoriesRepository;
    late MockTagsRepository tagsRepository;
    late MockSettingsRepository settingsRepository;
    late HomeCubit homeCubit;

    setUp(() {
      eventsRepository = MockEventsRepository();
      categoriesRepository = MockCategoriesRepository();
      tagsRepository = MockTagsRepository();
      settingsRepository = MockSettingsRepository();

      when(() => settingsRepository.settingsStream)
          .thenAnswer((_) => const Stream<Settings>.empty());
      when(() => eventsRepository.changes)
          .thenAnswer((_) => const Stream<void>.empty());
      when(() => eventsRepository.getCachedEvents())
          .thenAnswer((_) async => [event]);
      when(() => eventsRepository.getEvents())
          .thenAnswer((_) async => [event]);
      when(() => categoriesRepository.getCachedCategories())
          .thenAnswer((_) async => categories);
      when(() => categoriesRepository.getCategories())
          .thenAnswer((_) async => categories);

      homeCubit = HomeCubit(settingsRepository, eventsRepository,
          categoriesRepository, tagsRepository, 'user');
    });

    tearDown(() => homeCubit.close());

    /// The edit form is [InsertView] seeded from [event]: same widget as the
    /// insert tab, with a fixed date instead of "now".
    Widget wrapEditForm(Locale locale) {
      return MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: EditEventPage(homeCubit: homeCubit, event: event),
      );
    }

    Widget wrapSearchTab(Locale locale) {
      return MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MultiBlocProvider(
          providers: [
            BlocProvider.value(value: homeCubit),
            BlocProvider(create: (_) => ListCubit(homeCubit)),
          ],
          child: const Scaffold(body: ListPage()),
        ),
      );
    }

    testWidgets('the date is two chips, the month in the app language',
        (tester) async {
      await tester.pumpWidget(wrapEditForm(const Locale('fr')));
      await tester.pumpAndSettle();

      // The two chips the event is filed under, not one packed date.
      expect(find.widgetWithText(components.Tag, 'juillet'), findsOneWidget);
      expect(find.widgetWithText(components.Tag, '2026'), findsOneWidget);
      expect(find.text('12/07/2026'), findsNothing);
    });

    testWidgets('picking a date updates both chips', (tester) async {
      await tester.pumpWidget(wrapEditForm(const Locale('fr')));
      await tester.pumpAndSettle();

      // Either chip opens the calendar (here the year one).
      await tester.tap(find.widgetWithText(components.Tag, '2026'));
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsOneWidget);

      // One month back, then a day of it: December 2025.
      for (var i = 0; i < 7; i++) {
        await tester.tap(find.byIcon(Icons.chevron_left));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('15'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(components.Tag, 'décembre'), findsOneWidget);
      expect(find.widgetWithText(components.Tag, '2025'), findsOneWidget);
      expect(find.widgetWithText(components.Tag, 'juillet'), findsNothing);
      expect(find.widgetWithText(components.Tag, '2026'), findsNothing);
    });

    testWidgets('a month tag is searchable in the app language',
        (tester) async {
      await tester.pumpWidget(wrapSearchTab(const Locale('fr')));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.descendant(
              of: find.byType(TagInput), matching: find.byType(TextFormField)),
          'juil');
      await tester.pumpAndSettle();

      // Suggested under its translated label...
      await tester.tap(find.text('juillet').last);
      await tester.pumpAndSettle();

      // ...chipped translated too, but filtered on the stored "July": the
      // event stays on screen, which a "juillet" filter would not match.
      expect(find.widgetWithText(components.Tag, 'juillet'), findsOneWidget);
      expect(find.byType(EventCard), findsOneWidget);
    });
  });
}
