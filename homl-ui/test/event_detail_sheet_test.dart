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

final event = Event(
    id: 1,
    description: description,
    date: DateTime(2026, 3, 15),
    tags: [
      Tag(id: 10, tag: 'MonthTag', idCategory: 1),
      Tag(id: 2, tag: 'Football', idCategory: 2),
    ]);

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
    // Full description (card + sheet) and every tag, date ones included.
    expect(find.text(description), findsNWidgets(2));
    expect(find.descendant(
            of: find.byType(BottomSheet), matching: find.text('Football')),
        findsOneWidget);
    expect(find.descendant(
            of: find.byType(BottomSheet), matching: find.text('MonthTag')),
        findsOneWidget);
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
        tagsId: any(named: 'tagsId'))).thenAnswer((_) async {});

    await openSheet(tester);
    await tester.tap(faIcon(FontAwesomeIcons.pen));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextFormField, description), '');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    verify(() => eventsRepository.updateEvent(
        id: 1,
        description: '',
        date: any(named: 'date'),
        tagsId: any(named: 'tagsId'))).called(1);

    // Exactly one route is popped: losing the focus made the emptied field
    // notify its text again, which used to run the success branch twice and
    // pop the list route too, leaving a black screen.
    expect(find.byType(EditEventPage), findsNothing);
    expect(find.byType(ListPage), findsOneWidget);
    expect(find.text('Event updated'), findsOneWidget);
  });
}
