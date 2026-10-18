import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:homl/data/models/category.dart';
import 'package:homl/data/models/event.dart';
import 'package:homl/data/models/settings.dart';
import 'package:homl/data/models/tag.dart';
import 'package:homl/data/repositories/categories.repository.dart';
import 'package:homl/data/repositories/events.repository.dart';
import 'package:homl/data/sync/offline_writes.dart';
import 'package:homl/data/repositories/settings.repository.dart';
import 'package:homl/data/repositories/tags.repository.dart';
import 'package:homl/helpers/app_message.dart';
import 'package:homl/helpers/server_reachability.dart';
import 'package:homl/data/sync/sync_engine.dart';
import 'package:homl/pages/home/bloc/home_cubit.dart';

class MockEventsRepository extends Mock implements EventsRepository {}

class MockCategoriesRepository extends Mock implements CategoriesRepository {}

class MockTagsRepository extends Mock implements TagsRepository {}

class MockSettingsRepository extends Mock implements SettingsRepository {}

void main() {
  final cachedEvents = [
    Event(
        id: 1,
        description: 'cached',
        date: DateTime(2026),
        isOngoing: false,
        tags: [
          Tag(id: 1, tag: 'Football', idCategory: 1),
        ]),
  ];
  final cachedCategories = [
    Category(id: 1, category: 'Others', color: '#fff', isLocked: true, tags: [
      Tag(id: 1, tag: 'Football', idCategory: 1),
    ]),
  ];

  late MockEventsRepository eventsRepository;
  late MockCategoriesRepository categoriesRepository;
  late MockSettingsRepository settingsRepository;
  late MockTagsRepository tagsRepository;

  setUp(() {
    ServerReachability.instance.reset();
    eventsRepository = MockEventsRepository();
    categoriesRepository = MockCategoriesRepository();
    settingsRepository = MockSettingsRepository();
    tagsRepository = MockTagsRepository();

    when(() => settingsRepository.settingsStream)
        .thenAnswer((_) => const Stream<Settings>.empty());
    when(() => eventsRepository.changes)
        .thenAnswer((_) => const Stream<void>.empty());
  });

  HomeCubit buildCubit() => HomeCubit(settingsRepository, eventsRepository,
      categoriesRepository, tagsRepository, 'user');

  /// Stubs the initial load so the cubit reaches its initialized state.
  void stubInitialLoad() {
    when(() => eventsRepository.getCachedEvents())
        .thenAnswer((_) async => cachedEvents);
    when(() => categoriesRepository.getCachedCategories())
        .thenAnswer((_) async => cachedCategories);
    when(() => eventsRepository.getEvents())
        .thenAnswer((_) async => cachedEvents);
    when(() => categoriesRepository.getCategories())
        .thenAnswer((_) async => cachedCategories);
  }

  group('freshness', () {
    Future<HomeCubit> loaded({DateTime? syncedAt}) async {
      stubInitialLoad();
      when(() => eventsRepository.lastSyncedAt).thenReturn(syncedAt);
      final cubit = buildCubit();
      await expectLater(cubit.stream,
          emitsThrough(predicate<HomeState>((s) => s.initialized)));
      // Let the network refresh of init() land too.
      await Future<void>.delayed(Duration.zero);
      return cubit;
    }

    test('carries the date the data on screen was fetched', () async {
      final syncedAt = DateTime(2026, 10, 13, 18, 21);
      final cubit = await loaded(syncedAt: syncedAt);

      expect(cubit.state.lastSyncedAt, syncedAt);

      await cubit.close();
    });

    test('a pull to refresh says when the server is unreachable', () async {
      final cubit = await loaded(syncedAt: DateTime.now());
      ServerReachability.instance.markOffline();

      await cubit.refresh();

      expect(cubit.state.modal, AppMessage.serverUnreachable);
      await cubit.close();
    });

    test('back in the foreground, only stale data is fetched again',
        () async {
      final cubit = await loaded(syncedAt: DateTime.now());
      clearInteractions(eventsRepository);

      await cubit.refreshIfStale();
      verifyNever(() => eventsRepository.getEvents());

      when(() => eventsRepository.lastSyncedAt).thenReturn(
          DateTime.now().subtract(const Duration(minutes: 10)));
      await cubit.refresh();
      clearInteractions(eventsRepository);
      await cubit.refreshIfStale();
      verify(() => eventsRepository.getEvents()).called(1);

      // Offline: the reconnection reloads, not the resume.
      ServerReachability.instance.markOffline();
      clearInteractions(eventsRepository);
      await cubit.refreshIfStale();
      verifyNever(() => eventsRepository.getEvents());

      await cubit.close();
    });
  });

  group('after a sync', () {
    Future<HomeCubit> loaded() async {
      stubInitialLoad();
      final cubit = buildCubit();
      await expectLater(cubit.stream,
          emitsThrough(predicate<HomeState>((s) => s.initialized)));
      return cubit;
    }

    for (final (report, message) in [
      (const SyncReport(sent: 2), AppMessage.syncSent),
      (const SyncReport(sent: 1, conflicts: 1), AppMessage.syncConflicts),
      (const SyncReport(kept: 1, conflicts: 1), AppMessage.syncKept),
      (const SyncReport(restored: 1, kept: 1), AppMessage.syncRestored),
      (const SyncReport(dropped: 1, kept: 1), AppMessage.syncDropped),
      (const SyncReport(restored: 1, dropped: 1), AppMessage.syncRestored),
      (const SyncReport(sent: 3, parked: 1, restored: 1), AppMessage.syncParked),
    ]) {
      test('reloads and says ${message.name}', () async {
        final cubit = await loaded();
        clearInteractions(eventsRepository);

        final said = expectLater(cubit.stream,
            emitsThrough(predicate<HomeState>((s) => s.modal == message)));
        SyncEngine.instance.emitReport(report);
        await said;

        verify(() => eventsRepository.getEvents()).called(1);
        await cubit.close();
      });
    }
  });

  test('serves the cached snapshot when the network is unavailable', () async {
    when(() => eventsRepository.getCachedEvents())
        .thenAnswer((_) async => cachedEvents);
    when(() => categoriesRepository.getCachedCategories())
        .thenAnswer((_) async => cachedCategories);
    when(() => eventsRepository.getEvents()).thenThrow(EventsRequestFailure());
    when(() => categoriesRepository.getCategories())
        .thenThrow(CategoriesRequestFailure());

    final cubit = buildCubit();
    await expectLater(
        cubit.stream, emitsThrough(predicate<HomeState>((s) => s.initialized)));

    // Offline with a cache: usable data, no error modal.
    expect(cubit.state.events, cachedEvents);
    expect(cubit.state.categories, cachedCategories);
    expect(cubit.state.allTagsMap.containsKey('Football'), isTrue);
    expect(cubit.state.modal, isNull);

    await cubit.close();
  });

  test('surfaces an error when there is no cache and no network', () async {
    when(() => eventsRepository.getCachedEvents())
        .thenAnswer((_) async => null);
    when(() => categoriesRepository.getCachedCategories())
        .thenAnswer((_) async => null);
    when(() => eventsRepository.getEvents()).thenThrow(EventsRequestFailure());
    when(() => categoriesRepository.getCategories())
        .thenThrow(CategoriesRequestFailure());

    final cubit = buildCubit();
    await expectLater(
        cubit.stream,
        emitsThrough(predicate<HomeState>(
            (s) => s.modal == AppMessage.unexpectedError)));

    expect(cubit.state.initialized, isFalse);

    await cubit.close();
  });

  test('deleteEvent delegates to the repository without an error modal',
      () async {
    when(() => eventsRepository.getCachedEvents())
        .thenAnswer((_) async => cachedEvents);
    when(() => categoriesRepository.getCachedCategories())
        .thenAnswer((_) async => cachedCategories);
    when(() => eventsRepository.getEvents())
        .thenAnswer((_) async => cachedEvents);
    when(() => categoriesRepository.getCategories())
        .thenAnswer((_) async => cachedCategories);
    when(() => eventsRepository.deleteEvent(1)).thenAnswer((_) async => WriteOutcome.sent);

    final cubit = buildCubit();
    await expectLater(
        cubit.stream, emitsThrough(predicate<HomeState>((s) => s.initialized)));
    await cubit.deleteEvent(1);

    // The refresh itself rides on the repository changes stream.
    verify(() => eventsRepository.deleteEvent(1)).called(1);
    expect(cubit.state.modal, isNull);

    await cubit.close();
  });

  test('deleteEvent surfaces an error modal when the request fails', () async {
    when(() => eventsRepository.getCachedEvents())
        .thenAnswer((_) async => cachedEvents);
    when(() => categoriesRepository.getCachedCategories())
        .thenAnswer((_) async => cachedCategories);
    when(() => eventsRepository.getEvents())
        .thenAnswer((_) async => cachedEvents);
    when(() => categoriesRepository.getCategories())
        .thenAnswer((_) async => cachedCategories);
    when(() => eventsRepository.deleteEvent(1))
        .thenThrow(EventsRequestFailure());

    final cubit = buildCubit();
    await expectLater(
        cubit.stream, emitsThrough(predicate<HomeState>((s) => s.initialized)));
    await cubit.deleteEvent(1);

    expect(cubit.state.modal, AppMessage.unexpectedError);

    await cubit.close();
  });

  // Deleting a category changes the events too — they are deleted, or merely
  // stripped of the removed tags — so the cubit must refresh both lists, not
  // just the categories.
  test('deleteCategory refreshes the events as well as the categories',
      () async {
    final leftovers = [
      Event(
          id: 1,
          description: 'cached',
          date: DateTime(2026),
          isOngoing: false,
          tags: []),
    ];
    when(() => eventsRepository.getCachedEvents())
        .thenAnswer((_) async => cachedEvents);
    when(() => categoriesRepository.getCachedCategories())
        .thenAnswer((_) async => cachedCategories);
    when(() => eventsRepository.getEvents())
        .thenAnswer((_) async => cachedEvents);
    when(() => categoriesRepository.getCategories())
        .thenAnswer((_) async => cachedCategories);
    when(() => categoriesRepository.deleteCategory(any(),
        moveTags: any(named: 'moveTags'),
        deleteEvents: any(named: 'deleteEvents'))).thenAnswer((_) async => WriteOutcome.sent);

    final cubit = buildCubit();
    await expectLater(
        cubit.stream, emitsThrough(predicate<HomeState>((s) => s.initialized)));

    // The category is gone on the backend: both lists come back changed.
    when(() => eventsRepository.getEvents()).thenAnswer((_) async => leftovers);
    when(() => categoriesRepository.getCategories())
        .thenAnswer((_) async => []);

    await cubit.deleteCategory(2, moveTags: false, deleteEvents: true);

    verify(() => categoriesRepository.deleteCategory(2,
        moveTags: false, deleteEvents: true)).called(1);
    expect(cubit.state.events, leftovers);
    expect(cubit.state.categories, isEmpty);
    expect(cubit.state.allTagsMap, isEmpty);
    expect(cubit.state.modal, isNull);

    await cubit.close();
  });

  // A move refused because Others already holds one of the tag names deleted
  // nothing: the user gets told why instead of a generic failure.
  test('deleteCategory explains a taken tag name', () async {
    when(() => eventsRepository.getCachedEvents())
        .thenAnswer((_) async => cachedEvents);
    when(() => categoriesRepository.getCachedCategories())
        .thenAnswer((_) async => cachedCategories);
    when(() => eventsRepository.getEvents())
        .thenAnswer((_) async => cachedEvents);
    when(() => categoriesRepository.getCategories())
        .thenAnswer((_) async => cachedCategories);
    when(() => categoriesRepository.deleteCategory(any(),
            moveTags: any(named: 'moveTags'),
            deleteEvents: any(named: 'deleteEvents')))
        .thenThrow(CategoryTagNameConflictFailure());

    final cubit = buildCubit();
    await expectLater(
        cubit.stream, emitsThrough(predicate<HomeState>((s) => s.initialized)));
    await cubit.deleteCategory(2, moveTags: true);

    expect(cubit.state.modal, AppMessage.categoryTagNameConflict);
    // Nothing was deleted, so the screen keeps what it had.
    expect(cubit.state.categories, cachedCategories);
    expect(cubit.state.events, cachedEvents);

    await cubit.close();
  });

  test('deleteCategory surfaces an error modal when the request fails',
      () async {
    when(() => eventsRepository.getCachedEvents())
        .thenAnswer((_) async => cachedEvents);
    when(() => categoriesRepository.getCachedCategories())
        .thenAnswer((_) async => cachedCategories);
    when(() => eventsRepository.getEvents())
        .thenAnswer((_) async => cachedEvents);
    when(() => categoriesRepository.getCategories())
        .thenAnswer((_) async => cachedCategories);
    when(() => categoriesRepository.deleteCategory(any(),
            moveTags: any(named: 'moveTags'),
            deleteEvents: any(named: 'deleteEvents')))
        .thenThrow(CategoriesRequestFailure());

    final cubit = buildCubit();
    await expectLater(
        cubit.stream, emitsThrough(predicate<HomeState>((s) => s.initialized)));
    await cubit.deleteCategory(2, moveTags: true);

    expect(cubit.state.modal, AppMessage.unexpectedError);
    // The screen keeps showing what it had: nothing was refreshed.
    expect(cubit.state.categories, cachedCategories);

    await cubit.close();
  });

  // Tag names are unique per category: a write that would duplicate one is
  // refused and nothing is stored, so the user is told to pick another name
  // rather than left with a generic failure.
  test('createTag explains a taken tag name', () async {
    stubInitialLoad();
    when(() => tagsRepository.createTag(any(), any(),
            idParentTag: any(named: 'idParentTag')))
        .thenThrow(TagNameConflictFailure());

    final cubit = buildCubit();
    await expectLater(
        cubit.stream, emitsThrough(predicate<HomeState>((s) => s.initialized)));
    final created = await cubit.createTag('Football', 2);

    expect(created, isFalse,
        reason: 'callers chaining on the creation must not proceed');
    expect(cubit.state.modal, AppMessage.tagNameConflict);

    await cubit.close();
  });

  test('updateTag explains a taken tag name', () async {
    stubInitialLoad();
    when(() => tagsRepository.updateTag(any(), any(), any(),
            idParentTag: any(named: 'idParentTag')))
        .thenThrow(TagNameConflictFailure());

    final cubit = buildCubit();
    await expectLater(
        cubit.stream, emitsThrough(predicate<HomeState>((s) => s.initialized)));
    await cubit.updateTag(12, 'Football', 2);

    expect(cubit.state.modal, AppMessage.tagNameConflict);
    // Nothing moved: the categories on screen are untouched.
    expect(cubit.state.categories, cachedCategories);

    await cubit.close();
  });

  test('any other tag failure stays the generic error', () async {
    stubInitialLoad();
    when(() => tagsRepository.updateTag(any(), any(), any(),
            idParentTag: any(named: 'idParentTag')))
        .thenThrow(TagsRequestFailure());

    final cubit = buildCubit();
    await expectLater(
        cubit.stream, emitsThrough(predicate<HomeState>((s) => s.initialized)));
    await cubit.updateTag(12, 'Football', 2);

    expect(cubit.state.modal, AppMessage.unexpectedError);

    await cubit.close();
  });

  test('refreshes the cached snapshot from the network when it lands',
      () async {
    final freshEvents = [
      Event(
          id: 2,
          description: 'fresh',
          date: DateTime(2026),
          isOngoing: false,
          tags: [
            Tag(id: 1, tag: 'Football', idCategory: 1),
          ]),
    ];

    when(() => eventsRepository.getCachedEvents())
        .thenAnswer((_) async => cachedEvents);
    when(() => categoriesRepository.getCachedCategories())
        .thenAnswer((_) async => cachedCategories);
    when(() => eventsRepository.getEvents())
        .thenAnswer((_) async => freshEvents);
    when(() => categoriesRepository.getCategories())
        .thenAnswer((_) async => cachedCategories);

    final cubit = buildCubit();
    await expectLater(cubit.stream,
        emitsThrough(predicate<HomeState>((s) => s.events == freshEvents)));

    expect(cubit.state.modal, isNull);

    await cubit.close();
  });

  group('managing offline', () {
    // Persons (2): Alice (20) with her synonym Ally (21), Bob (22). Event 7
    // has Ally, event 8 Bob, event 9 Alice and Bob.
    final persons = Category(
        id: 2,
        category: 'Persons',
        color: '#f28b82',
        isLocked: false,
        kind: CategoryKind.person,
        tags: [
          Tag(id: 20, tag: 'Alice', idCategory: 2),
          Tag(id: 21, tag: 'Ally', idCategory: 2, idParentTag: 20),
          Tag(id: 22, tag: 'Bob', idCategory: 2),
        ]);
    Event event(int id, List<Tag> tags) => Event(
        id: id,
        description: 'event $id',
        date: DateTime(2026),
        isOngoing: false,
        tags: tags);
    final people = [
      event(7, [persons.tags[1]]),
      event(8, [persons.tags[2]]),
      event(9, [persons.tags[0], persons.tags[2]]),
    ];

    Future<HomeCubit> loaded() async {
      when(() => eventsRepository.getCachedEvents())
          .thenAnswer((_) async => people);
      when(() => categoriesRepository.getCachedCategories())
          .thenAnswer((_) async => [persons]);
      when(() => eventsRepository.getEvents()).thenAnswer((_) async => people);
      when(() => categoriesRepository.getCategories())
          .thenAnswer((_) async => [persons]);
      when(() => eventsRepository.deleteEvent(any(),
          notify: any(named: 'notify'))).thenAnswer((_) async => WriteOutcome.queued);
      when(() => eventsRepository.notifyChanged()).thenReturn(null);
      final cubit = buildCubit();
      await expectLater(cubit.stream,
          emitsThrough(predicate<HomeState>((s) => s.initialized)));
      return cubit;
    }

    test('a tag deleted with its events offline: the shown events go first',
        () async {
      final cubit = await loaded();
      when(() => tagsRepository.deleteTag(20, deleteEvents: true))
          .thenThrow(DeleteEventsOfflineFailure());
      when(() => tagsRepository.deleteTag(20))
          .thenAnswer((_) async => WriteOutcome.queued);

      await cubit.deleteTag(20, deleteEvents: true);

      // Alice's synonym group is Alice and Ally: events 7 and 9, not 8.
      verify(() => eventsRepository.deleteEvent(7, notify: false)).called(1);
      verify(() => eventsRepository.deleteEvent(9, notify: false)).called(1);
      verifyNever(() => eventsRepository.deleteEvent(8,
          notify: any(named: 'notify')));
      verify(() => eventsRepository.notifyChanged()).called(1);
      verify(() => tagsRepository.deleteTag(20)).called(1);
      expect(cubit.state.modal, AppMessage.savedOffline);
    });

    test('a category deleted with its events offline: the same', () async {
      final cubit = await loaded();
      when(() => categoriesRepository.deleteCategory(2,
              moveTags: false, deleteEvents: true))
          .thenThrow(DeleteEventsOfflineFailure());
      when(() => categoriesRepository.deleteCategory(2))
          .thenAnswer((_) async => WriteOutcome.queued);

      await cubit.deleteCategory(2, deleteEvents: true);

      for (final id in [7, 8, 9]) {
        verify(() => eventsRepository.deleteEvent(id, notify: false))
            .called(1);
      }
      verify(() => categoriesRepository.deleteCategory(2)).called(1);
    });

    test('online, a deletion with its events is the server\'s', () async {
      final cubit = await loaded();
      when(() => tagsRepository.deleteTag(20, deleteEvents: true))
          .thenAnswer((_) async => WriteOutcome.sent);

      await cubit.deleteTag(20, deleteEvents: true);

      verifyNever(() => eventsRepository.deleteEvent(any(),
          notify: any(named: 'notify')));
      expect(cubit.state.modal, isNull);
    });

    test('offline, the delete dialog counts come from the device', () async {
      final cubit = await loaded();
      ServerReachability.instance.markOffline();

      final tag = await cubit.fetchTagUsage(20);
      final category = await cubit.fetchCategoryUsage(2);

      expect(tag!.events, 2);
      // Event 9 also has Bob: only event 7 would be left date-only.
      expect(tag.exclusiveEvents, 1);
      expect(category!.tags, 3);
      expect(category.events, 3);
      expect(category.exclusiveEvents, 3);
      verifyNever(() => tagsRepository.getTagUsage(any()));
    });

    test('a change waiting for the server is said to be saved', () async {
      final cubit = await loaded();
      when(() => categoriesRepository.updateCategory(any(), any(), any()))
          .thenAnswer((_) async => WriteOutcome.queued);
      when(() => categoriesRepository.createCategory(any(), any()))
          .thenAnswer((_) async => -3);

      await cubit.updateCategory(2, 'People', '#000000');
      expect(cubit.state.modal, AppMessage.savedOffline);

      cubit.endModal();
      await cubit.createCategory('Trips', '#a7ffeb');
      expect(cubit.state.modal, AppMessage.savedOffline);
    });
  });
}
