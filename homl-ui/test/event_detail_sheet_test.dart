import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mocktail/mocktail.dart';

import 'package:homl/components/event_card.dart';
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
import 'package:homl/pages/insert/insert.dart';
import 'package:homl/pages/list/bloc/list_cubit.dart';
import 'package:homl/pages/list/list.dart';

class MockEventsRepository extends Mock implements EventsRepository {}

class MockCategoriesRepository extends Mock implements CategoriesRepository {}

class MockTagsRepository extends Mock implements TagsRepository {}

class MockSettingsRepository extends Mock implements SettingsRepository {}

const description = 'A very long description that the grid card can only '
    'fade out, but that the detail sheet must show in full.';

final categories = [
  Category(
      id: 1,
      category: 'Dates',
      color: '#ffff60',
      isLocked: true,
      kind: CategoryKind.date,
      tags: [Tag(id: 10, tag: 'MonthTag', idCategory: 1)]),
  Category(
      id: 2,
      category: 'Hobbies',
      color: '#f28b82',
      isLocked: false,
      kind: CategoryKind.custom,
      tags: [Tag(id: 2, tag: 'Football', idCategory: 2)]),
];

/// One date tag (category 1) and one regular tag. [endDate] makes a closed
/// period, [isOngoing] an open one, [date] moves the start.
Event eventWith({DateTime? date, DateTime? endDate, bool isOngoing = false}) =>
    Event(
        id: 1,
        description: description,
        date: date ?? DateTime(2026, 3, 15),
        endDate: endDate,
        isOngoing: isOngoing,
        tags: [
          Tag(id: 10, tag: 'MonthTag', idCategory: 1),
          Tag(id: 2, tag: 'Football', idCategory: 2),
        ]);

final event = eventWith();

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

  /// Swaps the event the list shows for [shown]; the cubit is rebuilt so it
  /// loads it (the one from setUp already holds the default event).
  Future<void> showEvent(Event shown) async {
    await homeCubit.close();
    when(() => eventsRepository.getCachedEvents())
        .thenAnswer((_) async => [shown]);
    when(() => eventsRepository.getEvents()).thenAnswer((_) async => [shown]);
    homeCubit = HomeCubit(settingsRepository, eventsRepository,
        categoriesRepository, tagsRepository, 'user');
  }

  Widget wrap() {
    return MaterialApp(
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

  Finder faIcon(FaIconData icon) =>
      find.byWidgetPredicate((w) => w is FaIcon && w.icon == icon.data);

  Future<void> openSheet(WidgetTester tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    await tester.tap(find.byType(EventCard));
    await tester.pumpAndSettle();
  }

  testWidgets('tapping a card opens the detail sheet with the full event',
      (tester) async {
    await openSheet(tester);

    expect(find.byType(BottomSheet), findsOneWidget);
    // Full description (card + sheet) and the regular tags. The date tags
    // are left out, as on the card: the header already carries the period,
    // and a long one would put a dozen month chips under it.
    expect(find.text(description), findsNWidgets(2));
    expect(
        find.descendant(
            of: find.byType(BottomSheet), matching: find.text('Football')),
        findsOneWidget);
    expect(
        find.descendant(
            of: find.byType(BottomSheet), matching: find.text('MonthTag')),
        findsNothing);
    expect(find.text('Sunday, March 15, 2026'), findsOneWidget);
    expect(find.textContaining('→'), findsNothing);
  });

  testWidgets('a closed period shows both dates and its length',
      (tester) async {
    await showEvent(eventWith(endDate: DateTime(2026, 3, 30)));
    await openSheet(tester);

    // 15 → 30 March, inclusive: 16 days.
    expect(find.text('Sunday, March 15, 2026'), findsOneWidget);
    expect(find.text('→ Monday, March 30, 2026 · 16 days'), findsOneWidget);
  });

  testWidgets('an open period reads as ongoing, with the time elapsed',
      (tester) async {
    await showEvent(eventWith(isOngoing: true));
    await openSheet(tester);

    // Started in March 2026; whenever this runs, months or years have gone by.
    expect(find.textContaining(RegExp(r'^→ Ongoing · for \d+ (months|years)$')),
        findsOneWidget);
  });

  testWidgets('an open period starting in the future has nothing elapsed',
      (tester) async {
    await showEvent(eventWith(date: DateTime(2100, 1, 1), isOngoing: true));
    await openSheet(tester);

    // No negative duration: just the flag, until the period has started.
    expect(find.text('→ Ongoing'), findsOneWidget);
  });

  testWidgets('the trash action asks for confirmation before deleting',
      (tester) async {
    when(() => eventsRepository.deleteEvent(1)).thenAnswer((_) async {});

    await openSheet(tester);
    await tester.tap(faIcon(FontAwesomeIcons.trash));
    await tester.pumpAndSettle();

    expect(find.text('Delete event?'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    verify(() => eventsRepository.deleteEvent(1)).called(1);
    // The deleted event's snapshot must not stay on screen.
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets('cancelling the confirmation keeps the event', (tester) async {
    await openSheet(tester);
    await tester.tap(faIcon(FontAwesomeIcons.trash));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    verifyNever(() => eventsRepository.deleteEvent(any()));
    expect(find.byType(BottomSheet), findsOneWidget);
  });

  testWidgets('the pen action opens the prefilled edit form', (tester) async {
    await openSheet(tester);
    await tester.tap(faIcon(FontAwesomeIcons.pen));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsNothing);
    expect(find.byType(EditEventPage), findsOneWidget);
    expect(find.widgetWithText(TextFormField, description), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    // The regular tag is chipped; the backend-managed month/year tag is not.
    expect(find.text('Football'), findsOneWidget);
    expect(find.text('MonthTag'), findsNothing);
  });

  testWidgets('erasing the description saves it and pops back to the list',
      (tester) async {
    when(() => eventsRepository.updateEvent(
        id: any(named: 'id'),
        description: any(named: 'description'),
        date: any(named: 'date'),
        endDate: any(named: 'endDate'),
        isOngoing: any(named: 'isOngoing'),
        tagsId: any(named: 'tagsId'))).thenAnswer((_) async {});

    await openSheet(tester);
    await tester.tap(faIcon(FontAwesomeIcons.pen));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, description), '');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    verify(() => eventsRepository.updateEvent(
        id: 1,
        description: '',
        date: any(named: 'date'),
        endDate: null,
        isOngoing: false,
        tagsId: any(named: 'tagsId'))).called(1);

    // Exactly one route is popped: losing the focus made the emptied field
    // notify its text again, which used to run the success branch twice and
    // pop the list route too, leaving a black screen.
    expect(find.byType(EditEventPage), findsNothing);
    expect(find.byType(ListPage), findsOneWidget);
    expect(find.text('Event updated'), findsOneWidget);
  });
}
