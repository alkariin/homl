import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:homl/components/logo.dart';
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
        child: BlocProvider.value(
          value: homeCubit,
          child: const Scaffold(body: InsertPage()),
        ),
      ),
    );
  }

  Finder tagField() => find.descendant(
      of: find.byType(TagInput), matching: find.byType(TextFormField));

  testWidgets('logo with a new tag typed: pick a category, create and chip it',
      (tester) async {
    when(() => tagsRepository.createTag('Roadtrip', 2,
        idParentTag: any(named: 'idParentTag'))).thenAnswer((_) async => 42);

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.enterText(tagField(), 'Roadtrip');
    await tester.tap(find.byType(HomlLogo));
    await tester.pumpAndSettle();

    // The category picker lists everything except Dates.
    expect(find.text('New tag "Roadtrip": choose a category'), findsOneWidget);
    expect(find.text('Dates'), findsNothing);

    await tester.tap(find.text('Hobbies'));
    await tester.pumpAndSettle();

    verify(() => tagsRepository.createTag('Roadtrip', 2)).called(1);
    // The tag is chipped on the event and the field is cleared.
    expect(find.text('Roadtrip'), findsOneWidget);
    expect(
        tester.widget<TextFormField>(tagField()).controller?.text, isEmpty);
  });

  testWidgets('logo with an existing tag typed does nothing', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.enterText(tagField(), 'football');
    await tester.tap(find.byType(HomlLogo));
    await tester.pumpAndSettle();

    expect(find.byType(SimpleDialog), findsNothing);
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets('logo with an empty field opens the tag picker sheet',
      (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.byType(HomlLogo));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsOneWidget);
    await tester.tap(find.text('Hobbies'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Football'));
    await tester.pumpAndSettle();

    // The sheet closed and the tag landed on the event as a chip.
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('Football'), findsOneWidget);
  });
}
