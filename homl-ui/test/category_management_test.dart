import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:homl/components/tag.dart' as components;
import 'package:homl/data/models/category.dart';
import 'package:homl/data/models/settings.dart';
import 'package:homl/data/models/tag.dart';
import 'package:homl/data/repositories/categories.repository.dart';
import 'package:homl/data/repositories/events.repository.dart';
import 'package:homl/data/repositories/settings.repository.dart';
import 'package:homl/data/repositories/tags.repository.dart';
import 'package:homl/l10n/app_localizations.dart';
import 'package:homl/pages/categories/view/category_management.dart';
import 'package:homl/pages/home/bloc/home_cubit.dart';

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
      tags: [Tag(id: 1, tag: '2026', idCategory: 1)]),
  Category(
      id: 2,
      category: 'Hobbies',
      color: '#f28b82',
      isLocked: false,
      kind: CategoryKind.custom,
      tags: [
        Tag(id: 2, tag: 'Football', idCategory: 2),
        Tag(id: 3, tag: 'Foot', idCategory: 2, idParentTag: 2),
      ]),
  Category(
      id: 3,
      category: 'Others',
      color: '#999999',
      isLocked: true,
      kind: CategoryKind.other,
      tags: [Tag(id: 4, tag: 'Fondue', idCategory: 3)]),
];

void main() {
  late MockEventsRepository eventsRepository;
  late MockCategoriesRepository categoriesRepository;
  late MockTagsRepository tagsRepository;
  late MockSettingsRepository settingsRepository;
  late HomeCubit cubit;

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

    cubit = HomeCubit(settingsRepository, eventsRepository,
        categoriesRepository, tagsRepository, 'user');
  });

  tearDown(() => cubit.close());

  Widget wrap() {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: BlocProvider.value(
        value: cubit,
        child: const Scaffold(body: CategoryManagementBody()),
      ),
    );
  }

  testWidgets('tapping a main tag opens the management menu', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Hobbies'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Football'));
    await tester.pumpAndSettle();

    expect(find.text('Rename tag'), findsOneWidget);
    expect(find.text('Add a synonym'), findsOneWidget);
    expect(find.text('Move to another category'), findsOneWidget);
    expect(find.text('Delete tag'), findsOneWidget);
  });

  testWidgets('chips carry the category color, synonyms included',
      (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Hobbies'));
    await tester.pumpAndSettle();

    final mainChip = tester.widget<components.Tag>(
        find.widgetWithText(components.Tag, 'Football'));
    final synonymChip = tester
        .widget<components.Tag>(find.widgetWithText(components.Tag, 'Foot'));
    expect(mainChip.color, '#f28b82');
    expect(synonymChip.color, '#f28b82');
  });

  testWidgets('long press on a main tag opens the same menu', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Hobbies'));
    await tester.pumpAndSettle();
    await tester.longPress(find.text('Football'));
    await tester.pumpAndSettle();

    expect(find.text('Rename tag'), findsOneWidget);
  });

  testWidgets('picker mode selects on tap instead of opening the menu',
      (tester) async {
    TagView? selected;

    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: BlocProvider.value(
        value: cubit,
        child: Scaffold(
            body: CategoryManagementBody(
                onTagSelected: (tag) => selected = tag)),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Hobbies'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Football'));
    await tester.pumpAndSettle();

    expect(selected?.tagName, 'Football');
    expect(find.text('Rename tag'), findsNothing);
    // No management affordances in picker mode.
    expect(find.text('New tag'), findsNothing);
    expect(find.byIcon(Icons.add), findsNothing);
  });

  testWidgets('tags of the Others category are manageable and movable',
      (tester) async {
    when(() => tagsRepository.updateTag(any(), any(), any(),
        idParentTag: any(named: 'idParentTag'))).thenAnswer((_) async {});

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Others'));
    await tester.pumpAndSettle();
    await tester.longPress(find.text('Fondue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Move to another category'));
    await tester.pumpAndSettle();

    // Move targets: every category except Dates and the current one.
    expect(find.text('Hobbies'), findsWidgets);
    expect(find.text('Dates'), findsOneWidget); // the collapsed tile only

    await tester.tap(find.text('Hobbies').last);
    await tester.pumpAndSettle();

    verify(() => tagsRepository.updateTag(4, 'Fondue', 2)).called(1);
  });

  testWidgets('date tags stay read-only', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Dates'));
    await tester.pumpAndSettle();
    await tester.longPress(find.text('2026'));
    await tester.pumpAndSettle();

    expect(find.text('Rename tag'), findsNothing);
    expect(find.byType(SimpleDialog), findsNothing);
  });
}
