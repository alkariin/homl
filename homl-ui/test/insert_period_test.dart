import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:homl/components/tag.dart' as components;
import 'package:homl/data/models/category.dart';
import 'package:homl/data/models/event.dart';
import 'package:homl/data/models/settings.dart';
import 'package:homl/data/models/tag.dart';
import 'package:homl/data/repositories/categories.repository.dart';
import 'package:homl/data/repositories/events.repository.dart';
import 'package:homl/data/repositories/settings.repository.dart';
import 'package:homl/data/repositories/tags.repository.dart';
import 'package:homl/l10n/app_localizations.dart';
import 'package:homl/pages/home/bloc/home_cubit.dart';
import 'package:homl/pages/insert/bloc/insert_cubit.dart';
import 'package:homl/pages/insert/insert.dart';

class MockEventsRepository extends Mock implements EventsRepository {}

class MockCategoriesRepository extends Mock implements CategoriesRepository {}

class MockTagsRepository extends Mock implements TagsRepository {}

class MockSettingsRepository extends Mock implements SettingsRepository {}

final categories = [
  Category(
      id: 1,
      category: 'Dates',
      color: '#ffff60',
      isLocked: true,
      kind: CategoryKind.date,
      tags: [Tag(id: 10, tag: 'July', idCategory: 1)]),
  Category(
      id: 2,
      category: 'Hobbies',
      color: '#f28b82',
      isLocked: false,
      kind: CategoryKind.custom,
      tags: [Tag(id: 2, tag: 'Football', idCategory: 2)]),
];

/// A single-day event on 12 July 2026, the shape every test starts from.
final event = Event(
    id: 1,
    description: 'match',
    date: DateTime(2026, 7, 12),
    isOngoing: false,
    tags: [
      Tag(id: 10, tag: 'July', idCategory: 1),
      Tag(id: 2, tag: 'Football', idCategory: 2),
    ]);

/// The three shapes and their end-date chip on the edit form, in French: the
/// segmented control follows the state, "period" opens the end picker right
/// away and only sticks once a day is picked.
void main() {
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
    when(() => eventsRepository.getEvents()).thenAnswer((_) async => [event]);
    when(() => categoriesRepository.getCachedCategories())
        .thenAnswer((_) async => categories);
    when(() => categoriesRepository.getCategories())
        .thenAnswer((_) async => categories);

    homeCubit = HomeCubit(settingsRepository, eventsRepository,
        categoriesRepository, tagsRepository, 'user');
  });

  tearDown(() => homeCubit.close());

  Future<void> pumpEditForm(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('fr'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: EditEventPage(homeCubit: homeCubit, event: event),
    ));
    await tester.pumpAndSettle();
  }

  Finder segment(String label) => find.descendant(
      of: find.byType(SegmentedButton<PeriodShape>),
      matching: find.text(label));

  Set<PeriodShape> selectedShape(WidgetTester tester) => tester
      .widget<SegmentedButton<PeriodShape>>(
          find.byType(SegmentedButton<PeriodShape>))
      .selected;

  Finder chip(String text) => find.widgetWithText(components.Tag, text);

  testWidgets('a single day: the two date chips and "one day" selected',
      (tester) async {
    await pumpEditForm(tester);

    expect(selectedShape(tester), {PeriodShape.singleDay});
    expect(chip('juillet'), findsOneWidget);
    expect(chip('2026'), findsOneWidget);
    expect(find.textContaining('→'), findsNothing);
    expect(chip('En cours'), findsNothing);
  });

  testWidgets('"ongoing" adds the Ongoing chip, "one day" removes it',
      (tester) async {
    await pumpEditForm(tester);

    await tester.tap(segment('En cours'));
    await tester.pumpAndSettle();

    // The chip mirrors the Ongoing date tag the event will be filed under,
    // translated like the month chip.
    expect(selectedShape(tester), {PeriodShape.ongoing});
    expect(chip('En cours'), findsOneWidget);

    await tester.tap(segment('Un jour'));
    await tester.pumpAndSettle();

    expect(selectedShape(tester), {PeriodShape.singleDay});
    expect(chip('En cours'), findsNothing);
  });

  testWidgets('"period" opens the end picker; cancelling keeps the shape',
      (tester) async {
    await pumpEditForm(tester);
    await tester.tap(segment('En cours'));
    await tester.pumpAndSettle();

    await tester.tap(segment('Période'));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);

    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();

    // Nothing picked, nothing changed: the form never rests on "a period
    // without an end".
    expect(find.byType(DatePickerDialog), findsNothing);
    expect(selectedShape(tester), {PeriodShape.ongoing});
    expect(chip('En cours'), findsOneWidget);
    expect(find.textContaining('→'), findsNothing);
  });

  testWidgets('picking an end makes a closed period with its end chip',
      (tester) async {
    await pumpEditForm(tester);

    await tester.tap(segment('Période'));
    await tester.pumpAndSettle();
    // The picker opens on the start month (July 2026): a later day of it.
    await tester.tap(find.text('20'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(selectedShape(tester), {PeriodShape.closed});
    expect(chip('→ 20 juil. 2026'), findsOneWidget);
    expect(chip('En cours'), findsNothing);
    // The start chips are untouched.
    expect(chip('juillet'), findsOneWidget);
    expect(chip('2026'), findsOneWidget);

    // The end chip reopens the picker to change the end.
    await tester.tap(chip('→ 20 juil. 2026'));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    expect(chip('→ 20 juil. 2026'), findsOneWidget);

    // Back to a single day drops the end.
    await tester.tap(segment('Un jour'));
    await tester.pumpAndSettle();
    expect(chip('→ 20 juil. 2026'), findsNothing);
    expect(selectedShape(tester), {PeriodShape.singleDay});
  });

  testWidgets('the end picker does not offer days before the start',
      (tester) async {
    await pumpEditForm(tester);

    await tester.tap(segment('Période'));
    await tester.pumpAndSettle();

    final dialog =
        tester.widget<DatePickerDialog>(find.byType(DatePickerDialog));
    expect(DateUtils.dateOnly(dialog.firstDate), DateTime(2026, 7, 12));
    expect(DateUtils.dateOnly(dialog.initialDate!), DateTime(2026, 7, 12));
  });
}
