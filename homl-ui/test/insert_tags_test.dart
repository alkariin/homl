import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:homl/components/tag.dart' as components;
import 'package:homl/components/tag_input.dart';
import 'package:homl/data/models/category.dart';
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
      tags: []),
  Category(
      id: 2,
      category: 'Hobbies',
      color: '#f28b82',
      isLocked: false,
      kind: CategoryKind.custom,
      tags: [Tag(id: 2, tag: 'Football', idCategory: 2)]),
  Category(
      id: 3,
      category: 'Others',
      color: '#999999',
      isLocked: true,
      kind: CategoryKind.other,
      tags: []),
];

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
    when(() => eventsRepository.getCachedEvents()).thenAnswer((_) async => []);
    when(() => eventsRepository.getEvents()).thenAnswer((_) async => []);
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
      home: MultiRepositoryProvider(
        providers: [
          RepositoryProvider<EventsRepository>.value(value: eventsRepository),
          RepositoryProvider<TagsRepository>.value(value: tagsRepository),
        ],
        child: MultiBlocProvider(
          providers: [
            BlocProvider.value(value: homeCubit),
            // Provided by the home page in the app, so the app bar mark can
            // read the tags being written.
            BlocProvider(
                create: (_) => InsertCubit(eventsRepository, tagsRepository)),
          ],
          child: const Scaffold(body: InsertView()),
        ),
      ),
    );
  }

  Finder tagField() => find.descendant(
      of: find.byType(TagInput), matching: find.byType(TextFormField));

  testWidgets(
      'a name no tag matches offers the categories, creates and chips it',
      (tester) async {
    when(() => tagsRepository.createTag('Roadtrip', 2,
        idParentTag: any(named: 'idParentTag'))).thenAnswer((_) async => 42);

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.enterText(tagField(), 'Roadtrip');
    await tester.pumpAndSettle();

    // The panel opens on its own under the field and lists every category
    // except Dates, whose tags the backend owns.
    expect(find.text('New tag "Roadtrip": choose a category'), findsOneWidget);
    expect(find.text('Dates'), findsNothing);

    await tester.tap(find.text('Hobbies'));
    await tester.pumpAndSettle();

    verify(() => tagsRepository.createTag('Roadtrip', 2)).called(1);
    // The tag is chipped on the event and the field is cleared, which closes
    // the panel.
    expect(find.text('Roadtrip'), findsOneWidget);
    expect(tester.widget<TextFormField>(tagField()).controller?.text, isEmpty);
    expect(find.textContaining('choose a category'), findsNothing);
  });

  testWidgets('a pending free tag wears the Others category grey',
      (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.enterText(tagField(), 'Freetag');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    // Not created yet: it will land in Others on submit, so its chip
    // already wears that category's color.
    final chip = tester
        .widget<components.Tag>(find.widgetWithText(components.Tag, 'Freetag'));
    expect(chip.color, '#999999');
  });

  testWidgets('a tag that already exists offers no categories', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    // "Football" is suggested by the autocomplete, which owns the room under
    // the field: the panel must stay out of its way.
    await tester.enterText(tagField(), 'football');
    await tester.pumpAndSettle();

    expect(find.textContaining('choose a category'), findsNothing);
  });

  testWidgets('a name reserved for the date tags offers no categories',
      (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    // A year is a date tag the backend builds from the event period and
    // refuses as a user tag: offering to create it would only lead to an
    // error toast.
    await tester.enterText(tagField(), '2027');
    await tester.pumpAndSettle();

    expect(find.textContaining('choose a category'), findsNothing);
  });

  testWidgets('the browse button opens the tag picker sheet', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Browse tags'));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('Choose a tag'), findsOneWidget);
    // The Dates category is not offered here: the event is filed under the
    // date tags the backend derives from its period, so there is nothing to
    // pick.
    expect(find.text('Dates'), findsNothing);
    await tester.tap(find.text('Hobbies'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Football'));
    await tester.pumpAndSettle();

    // The sheet closed and the tag landed on the event as a chip.
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('Football'), findsOneWidget);
  });
}
