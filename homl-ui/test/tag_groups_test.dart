import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:homl/components/tag.dart' as components;
import 'package:homl/data/models/category.dart';
import 'package:homl/data/models/settings.dart';
import 'package:homl/data/models/tag.dart';
import 'package:homl/data/models/tag_group.dart';
import 'package:homl/data/repositories/categories.repository.dart';
import 'package:homl/data/repositories/events.repository.dart';
import 'package:homl/data/repositories/settings.repository.dart';
import 'package:homl/data/repositories/tags.repository.dart';
import 'package:homl/helpers/app_message.dart';
import 'package:homl/helpers/localizations.dart';
import 'package:homl/helpers/tag_groups.dart';
import 'package:homl/l10n/app_localizations.dart';
import 'package:homl/pages/categories/view/category_management.dart';
import 'package:homl/pages/home/bloc/home_cubit.dart';

class MockEventsRepository extends Mock implements EventsRepository {}

class MockCategoriesRepository extends Mock implements CategoriesRepository {}

class MockTagsRepository extends Mock implements TagsRepository {}

class MockSettingsRepository extends Mock implements SettingsRepository {}

/// Persons holds Alice (alias Ali), Bob and Carol, and a Family group of
/// Alice and Bob; Work has no tag yet; Others holds Fondue.
final categories = [
  Category(
      id: 1,
      category: 'Persons',
      color: '#60ccff',
      isLocked: false,
      kind: CategoryKind.person,
      tags: [
        Tag(id: 10, tag: 'Alice', idCategory: 1),
        Tag(id: 11, tag: 'Ali', idCategory: 1, idParentTag: 10),
        Tag(id: 12, tag: 'Bob', idCategory: 1),
        Tag(id: 13, tag: 'Carol', idCategory: 1),
      ],
      groups: [
        TagGroup(id: 5, name: 'Family', members: [10, 12])
      ]),
  Category(
      id: 2,
      category: 'Work',
      color: '#f28b82',
      isLocked: false,
      kind: CategoryKind.custom,
      tags: []),
  Category(
      id: 3,
      category: 'Others',
      color: '#999999',
      isLocked: true,
      kind: CategoryKind.other,
      tags: [Tag(id: 20, tag: 'Fondue', idCategory: 3)]),
];

void main() {
  late MockCategoriesRepository categoriesRepository;
  late HomeCubit cubit;

  setUp(() {
    final eventsRepository = MockEventsRepository();
    final settingsRepository = MockSettingsRepository();
    categoriesRepository = MockCategoriesRepository();

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
    when(() => categoriesRepository.createTagGroup(any(), any(), any()))
        .thenAnswer((_) async => 6);
    when(() => categoriesRepository.updateTagGroup(any(), any(), any()))
        .thenAnswer((_) async {});
    when(() => categoriesRepository.deleteTagGroup(any()))
        .thenAnswer((_) async {});

    cubit = HomeCubit(settingsRepository, eventsRepository,
        categoriesRepository, MockTagsRepository(), 'user');
  });

  tearDown(() => cubit.close());

  Widget wrap({Widget body = const CategoryManagementBody()}) {
    return MaterialApp(
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: BlocProvider.value(value: cubit, child: Scaffold(body: body)),
    );
  }

  Future<void> openPersons(WidgetTester tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Persons'));
    await tester.pumpAndSettle();
  }

  TextButton saveButton(WidgetTester tester) =>
      tester.widget<TextButton>(find.widgetWithText(TextButton, 'Save'));

  test('the member names follow the category, a deleted tag left out', () {
    final persons = categories.first;

    expect(
        tagGroupMemberNames(persons, persons.groups.first), ['Alice', 'Bob']);
    expect(
        tagGroupMemberNames(
            persons, TagGroup(id: 9, name: 'Gone', members: [12, 99])),
        ['Bob']);

    final suggestions = tagGroupSuggestions(categories);
    expect(suggestions, hasLength(1));
    expect(suggestions.single.name, 'Family');
    expect(suggestions.single.members, ['Alice', 'Bob']);
    expect(suggestions.single.highlightColor, '#60ccff');
  });

  testWidgets('a category lists its groups with the tags they hold',
      (tester) async {
    await openPersons(tester);

    expect(find.text('Groups'), findsOneWidget);
    final chip = tester
        .widget<components.Tag>(find.widgetWithText(components.Tag, 'Family'));
    expect(chip.isGroup, isTrue);
    expect(chip.color, '#60ccff');
    expect(find.text('Alice, Bob'), findsOneWidget);
  });

  testWidgets('a category without tags offers no new group', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Work'));
    await tester.pumpAndSettle();

    expect(find.text('New tag'), findsOneWidget);
    expect(find.text('New group'), findsNothing);
  });

  testWidgets('a new group needs a free name and at least one tag',
      (tester) async {
    await openPersons(tester);
    await tester.tap(find.text('New group'));
    await tester.pumpAndSettle();

    expect(saveButton(tester).onPressed, isNull);

    // A tag name of another category is taken: typed in the same field, the
    // two would clash.
    await tester.enterText(find.byType(TextField), 'fondue');
    await tester.tap(find.widgetWithText(FilterChip, 'Bob'));
    await tester.pumpAndSettle();
    expect(
        find.text('A tag or a group already has this name.'), findsOneWidget);
    expect(saveButton(tester).onPressed, isNull);

    // So is a date name.
    await tester.enterText(find.byType(TextField), 'july');
    await tester.pumpAndSettle();
    expect(find.text('This name is reserved for the dates.'), findsOneWidget);
    expect(saveButton(tester).onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'Siblings');
    await tester.pumpAndSettle();
    expect(saveButton(tester).onPressed, isNotNull);

    // Only main tags are offered: the synonym Ali stands for Alice.
    expect(find.widgetWithText(FilterChip, 'Ali'), findsNothing);
    await tester.tap(find.widgetWithText(FilterChip, 'Carol'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // Members in the category's order, whatever the order of the taps.
    verify(() => categoriesRepository.createTagGroup('Siblings', 1, [12, 13]))
        .called(1);
  });

  testWidgets('a group is edited from its chip, prefilled', (tester) async {
    await openPersons(tester);
    await tester.tap(find.widgetWithText(components.Tag, 'Family'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit group'));
    await tester.pumpAndSettle();

    // Its own name is not taken.
    expect(find.text('A tag or a group already has this name.'), findsNothing);
    expect(
        tester
            .widget<FilterChip>(find.widgetWithText(FilterChip, 'Alice'))
            .selected,
        isTrue);

    await tester.tap(find.widgetWithText(FilterChip, 'Alice'));
    await tester.tap(find.widgetWithText(FilterChip, 'Carol'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    verify(() => categoriesRepository.updateTagGroup(5, 'Family', [12, 13]))
        .called(1);
  });

  testWidgets('deleting a group asks first', (tester) async {
    await openPersons(tester);
    await tester.longPress(find.widgetWithText(components.Tag, 'Family'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete group'));
    await tester.pumpAndSettle();

    expect(find.text('Delete "Family"?'), findsOneWidget);
    expect(find.text('Only the group goes: its tags and their events stay.'),
        findsOneWidget);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    verify(() => categoriesRepository.deleteTagGroup(5)).called(1);
  });

  testWidgets('the picker hands over the tags of a tapped group',
      (tester) async {
    final picked = <String>[];
    await tester.pumpWidget(wrap(
        body: Builder(
            builder: (context) => TextButton(
                onPressed: () => showTagPickerSheet(context,
                    onTagSelected: (tag) => picked.add(tag.tagName)),
                child: const Text('Browse')))));
    await tester.tap(find.text('Browse'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Persons'));
    await tester.pumpAndSettle();

    expect(find.text('New group'), findsNothing);
    // The sheet is short: scroll down to the group.
    await tester.ensureVisible(find.widgetWithText(components.Tag, 'Family'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(components.Tag, 'Family'));
    await tester.pumpAndSettle();

    expect(picked, ['Alice', 'Bob']);
    // One pop for the whole group: the page under the sheet is still there.
    expect(find.text('Browse'), findsOneWidget);
  });

  test('a group name taken in the category is said', () async {
    when(() => categoriesRepository.createTagGroup(any(), any(), any()))
        .thenThrow(TagGroupNameConflictFailure());

    await cubit.createTagGroup('Family', 1, [10]);

    expect(cubit.state.modal, AppMessage.tagGroupNameConflict);
  });

  test('a member created offline is said to be pending', () async {
    when(() => categoriesRepository.updateTagGroup(any(), any(), any()))
        .thenThrow(TagPendingFailure());

    await cubit.updateTagGroup(5, 'Family', [-1]);

    expect(cubit.state.modal, AppMessage.tagPending);
  });
}
