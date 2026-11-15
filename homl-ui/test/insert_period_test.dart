import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'package:homl/components/date_field.dart';
import 'package:homl/components/tag.dart' as components;
import 'package:homl/data/models/category.dart';
import 'package:homl/data/models/event.dart';
import 'package:homl/data/models/settings.dart';
import 'package:homl/data/models/tag.dart';
import 'package:homl/data/repositories/categories.repository.dart';
import 'package:homl/data/repositories/events.repository.dart';
import 'package:homl/data/repositories/settings.repository.dart';
import 'package:homl/data/repositories/tags.repository.dart';
import 'package:homl/helpers/date_entry.dart';
import 'package:homl/helpers/localizations.dart';
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

/// The three shapes on the edit form, in French: the segmented control
/// follows the state, "period" opens the end picker right away and only
/// sticks once a day is picked; the date fields show the dates, the chips
/// only mirror the date tags.
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
      localizationsDelegates: appLocalizationsDelegates,
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

  Finder dateField(String label) => find.widgetWithText(DateField, label);

  /// The date written in the field labelled [label].
  String dateIn(WidgetTester tester, String label) => fullDateLabel(
      tester.widget<DateField>(dateField(label)).date, 'fr');

  testWidgets('a single day: one date field, the two date chips',
      (tester) async {
    await pumpEditForm(tester);

    expect(selectedShape(tester), {PeriodShape.singleDay});
    expect(find.text('dimanche 12 juillet 2026'), findsOneWidget);
    expect(dateField('Date'), findsOneWidget);
    expect(dateField('Du'), findsNothing);
    expect(chip('Juillet'), findsOneWidget);
    expect(chip('2026'), findsOneWidget);
    expect(chip('En cours'), findsNothing);
  });

  testWidgets('the date chips are a reflection: no icon, no picker',
      (tester) async {
    await pumpEditForm(tester);

    expect(
        find.descendant(of: chip('Juillet'), matching: find.byType(FaIcon)),
        findsNothing);
    await tester.tap(chip('Juillet'));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsNothing);
  });

  testWidgets('"ongoing" adds the Ongoing chip and a "since" field',
      (tester) async {
    await pumpEditForm(tester);

    await tester.tap(segment('En cours'));
    await tester.pumpAndSettle();

    // The chip mirrors the Ongoing date tag the event will be filed under,
    // translated like the month chip.
    expect(selectedShape(tester), {PeriodShape.ongoing});
    expect(chip('En cours'), findsOneWidget);
    expect(dateField('Depuis'), findsOneWidget);
    expect(dateField('Date'), findsNothing);

    await tester.tap(segment('Un jour'));
    await tester.pumpAndSettle();

    expect(selectedShape(tester), {PeriodShape.singleDay});
    expect(chip('En cours'), findsNothing);
    expect(dateField('Date'), findsOneWidget);
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
    expect(dateField('Au'), findsNothing);
  });

  testWidgets('the date field takes a date typed as digits only',
      (tester) async {
    await pumpEditForm(tester);

    // The field opens the picker; its pencil switches to typing, on a
    // number keyboard that may have no "/".
    await tester.tap(dateField('Date'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.descendant(
            of: find.byType(DatePickerDialog),
            matching: find.byType(TextField)),
        '18102026');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.byType(DatePickerDialog), findsNothing);
    expect(dateIn(tester, 'Date'), 'dimanche 18 octobre 2026');
    expect(chip('Octobre'), findsOneWidget);
    expect(chip('2026'), findsOneWidget);
  });

  testWidgets('picking an end makes a closed period with "from" and "to"',
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
    expect(dateIn(tester, 'Du'), 'dimanche 12 juillet 2026');
    expect(dateIn(tester, 'Au'), 'lundi 20 juillet 2026');
    // The end is not a tag: no chip for it, the month and year stay alone.
    expect(find.textContaining('→'), findsNothing);
    expect(chip('Juillet'), findsOneWidget);
    expect(chip('2026'), findsOneWidget);
    expect(chip('En cours'), findsNothing);

    // The "to" field reopens the end picker.
    await tester.tap(dateField('Au'));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    expect(dateIn(tester, 'Au'), 'lundi 20 juillet 2026');

    // Back to a single day drops the end.
    await tester.tap(segment('Un jour'));
    await tester.pumpAndSettle();
    expect(dateField('Au'), findsNothing);
    expect(selectedShape(tester), {PeriodShape.singleDay});
  });

  testWidgets('a period chips every month it covers, folded after three',
      (tester) async {
    await pumpEditForm(tester);

    // Three months: all chipped, in the order of the period.
    await tester.tap(segment('Période'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.descendant(
            of: find.byType(DatePickerDialog),
            matching: find.byType(TextField)),
        '05092026');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(chip('Juillet'), findsOneWidget);
    expect(chip('Août'), findsOneWidget);
    expect(chip('Septembre'), findsOneWidget);
    expect(find.textContaining('mois'), findsNothing);

    // Into the next year: the months past the third fold into a note that
    // is not a chip, and both years are chipped.
    await tester.tap(dateField('Au'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.descendant(
            of: find.byType(DatePickerDialog),
            matching: find.byType(TextField)),
        '15022027');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(chip('Juillet'), findsOneWidget);
    expect(chip('Septembre'), findsOneWidget);
    expect(chip('Octobre'), findsNothing);
    // October 2026 to February 2027: five more months.
    expect(find.text('+ 5 mois'), findsOneWidget);
    expect(chip('+ 5 mois'), findsNothing);
    expect(chip('2026'), findsOneWidget);
    expect(chip('2027'), findsOneWidget);
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
