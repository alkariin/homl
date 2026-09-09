import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:homl/components/tag.dart' as components;
import 'package:homl/data/models/category.dart';
import 'package:homl/data/models/settings.dart';
import 'package:homl/data/models/tag.dart';
import 'package:homl/data/models/usage.dart';
import 'package:homl/data/repositories/categories.repository.dart';
import 'package:homl/data/repositories/events.repository.dart';
import 'package:homl/data/repositories/settings.repository.dart';
import 'package:homl/data/repositories/tags.repository.dart';
import 'package:homl/helpers/app_message.dart';
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

  testWidgets('the default categories are shown in the app language',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('fr'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: BlocProvider.value(
        value: cubit,
        child: const Scaffold(body: CategoryManagementBody()),
      ),
    ));
    await tester.pumpAndSettle();

    // Stored in English by the backend, translated on screen only.
    expect(find.text('Autres'), findsOneWidget);
    expect(find.text('Others'), findsNothing);
    expect(find.text('Hobbies'), findsOneWidget);
  });

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
            body:
                CategoryManagementBody(onTagSelected: (tag) => selected = tag)),
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

  testWidgets(
      'deleting a tag always asks about its events, keeping them by default',
      (tester) async {
    // Every event of the tag also carries another tag (exclusiveEvents 0):
    // the choice must still be offered, since deleting removes them all.
    when(() => tagsRepository.getTagUsage(4))
        .thenAnswer((_) async => TagUsage(events: 2, exclusiveEvents: 0));
    when(() => tagsRepository.deleteTag(any(),
        deleteEvents: any(named: 'deleteEvents'))).thenAnswer((_) async {});

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Others'));
    await tester.pumpAndSettle();
    await tester.longPress(find.text('Fondue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete tag'));
    await tester.pumpAndSettle();

    expect(find.text('2 events use this tag.'), findsOneWidget);
    expect(find.text('Keep these events, remove the tag'), findsOneWidget);
    expect(find.text('Delete these events'), findsOneWidget);
    // No date-only warning when every event keeps another tag.
    expect(find.textContaining('date only'), findsNothing);

    // A hasty confirm keeps the events.
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    verify(() => tagsRepository.deleteTag(4, deleteEvents: false)).called(1);
  });

  testWidgets('choosing to delete the events sends deleteEvents',
      (tester) async {
    when(() => tagsRepository.getTagUsage(4))
        .thenAnswer((_) async => TagUsage(events: 3, exclusiveEvents: 1));
    when(() => tagsRepository.deleteTag(any(),
        deleteEvents: any(named: 'deleteEvents'))).thenAnswer((_) async {});

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Others'));
    await tester.pumpAndSettle();
    await tester.longPress(find.text('Fondue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete tag'));
    await tester.pumpAndSettle();

    expect(find.text('1 of them will be left with its date only.'),
        findsOneWidget);

    await tester.tap(find.text('Delete these events'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    verify(() => tagsRepository.deleteTag(4, deleteEvents: true)).called(1);
  });

  /* --------------------------- Deleting a category ------------------------ */

  // The dialog offers three mutually exclusive outcomes, each sending its own
  // pair of flags. Getting the pair wrong destroys data the user asked to
  // keep, so every option is pinned here.
  group('deleting a category', () {
    void stubUsage({int tags = 2, int events = 3, int exclusiveEvents = 1}) {
      when(() => categoriesRepository.getCategoryUsage(2)).thenAnswer(
          (_) async => CategoryUsage(
              tags: tags, events: events, exclusiveEvents: exclusiveEvents));
      when(() => categoriesRepository.deleteCategory(any(),
              moveTags: any(named: 'moveTags'),
              deleteEvents: any(named: 'deleteEvents')))
          .thenAnswer((_) async {});
    }

    /// Opens the delete dialog of the Hobbies category through its ⋮ menu.
    Future<void> openDialog(WidgetTester tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      // Only the unlocked Hobbies category carries a menu.
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
    }

    testWidgets('shows the tag and event counts with the three options',
        (tester) async {
      stubUsage();
      await openDialog(tester);

      expect(find.text('Delete category?'), findsOneWidget);
      expect(find.text('This category has 2 tags.'), findsOneWidget);
      expect(find.text('3 events use them.'), findsOneWidget);
      expect(find.text('Move the tags to the Others category'), findsOneWidget);
      expect(find.text('Delete the tags, keep the events'), findsOneWidget);
      expect(find.text('Delete the tags and their events'), findsOneWidget);
      expect(find.text('3 events use these tags and will be deleted.'),
          findsOneWidget);
    });

    testWidgets('a hasty confirm moves the tags instead of deleting anything',
        (tester) async {
      stubUsage();
      await openDialog(tester);

      // No option touched: the default must be the one that loses nothing.
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      verify(() => categoriesRepository.deleteCategory(2,
          moveTags: true, deleteEvents: false)).called(1);
    });

    testWidgets('keeping the events deletes the tags alone', (tester) async {
      stubUsage();
      await openDialog(tester);

      await tester.tap(find.text('Delete the tags, keep the events'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      verify(() => categoriesRepository.deleteCategory(2,
          moveTags: false, deleteEvents: false)).called(1);
    });

    testWidgets('choosing to delete the events sends deleteEvents',
        (tester) async {
      stubUsage();
      await openDialog(tester);

      await tester.tap(find.text('Delete the tags and their events'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      verify(() => categoriesRepository.deleteCategory(2,
          moveTags: false, deleteEvents: true)).called(1);
    });

    testWidgets('an option picked then changed back sends the last choice',
        (tester) async {
      stubUsage();
      await openDialog(tester);

      await tester.tap(find.text('Delete the tags and their events'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Move the tags to the Others category'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      verify(() => categoriesRepository.deleteCategory(2,
          moveTags: true, deleteEvents: false)).called(1);
    });

    testWidgets('the destructive option is hidden when no event is affected',
        (tester) async {
      stubUsage(tags: 2, events: 0, exclusiveEvents: 0);
      await openDialog(tester);

      expect(find.text('No event uses them.'), findsOneWidget);
      expect(find.text('Move the tags to the Others category'), findsOneWidget);
      expect(find.text('Delete the tags, keep the events'), findsOneWidget);
      // Nothing to delete: the option must not be offered at all.
      expect(find.text('Delete the tags and their events'), findsNothing);
    });

    testWidgets('an empty category is deleted without asking anything',
        (tester) async {
      stubUsage(tags: 0, events: 0, exclusiveEvents: 0);
      await openDialog(tester);

      expect(find.text('This category has no tags.'), findsOneWidget);
      // Nothing to move, nothing to lose: no option is offered.
      expect(find.text('Move the tags to the Others category'), findsNothing);
      expect(find.text('Delete the tags, keep the events'), findsNothing);
      expect(find.text('Delete the tags and their events'), findsNothing);

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      verify(() => categoriesRepository.deleteCategory(2,
          moveTags: true, deleteEvents: false)).called(1);
    });

    testWidgets('cancelling deletes nothing', (tester) async {
      stubUsage();
      await openDialog(tester);

      await tester.tap(find.text('Delete the tags and their events'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Delete category?'), findsNothing);
      verifyNever(() => categoriesRepository.deleteCategory(any(),
          moveTags: any(named: 'moveTags'),
          deleteEvents: any(named: 'deleteEvents')));
    });

    testWidgets('a failing usage request opens no dialog', (tester) async {
      // Without the counts the options would be a guess: better no dialog
      // than one offering to delete an unknown number of events.
      when(() => categoriesRepository.getCategoryUsage(2))
          .thenThrow(CategoriesRequestFailure());

      await openDialog(tester);

      expect(find.text('Delete category?'), findsNothing);
      expect(cubit.state.modal, AppMessage.unexpectedError);
      verifyNever(() => categoriesRepository.deleteCategory(any(),
          moveTags: any(named: 'moveTags'),
          deleteEvents: any(named: 'deleteEvents')));
    });

    testWidgets('the locked categories offer no delete affordance',
        (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      // Dates and Others are locked: only Hobbies may be renamed or deleted.
      expect(find.byType(PopupMenuButton<String>), findsOneWidget);
    });
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
