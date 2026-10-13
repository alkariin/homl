import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:homl/data/models/category.dart';
import 'package:homl/data/models/event.dart';
import 'package:homl/data/models/settings.dart';
import 'package:homl/data/models/tag.dart';
import 'package:homl/data/repositories/categories.repository.dart';
import 'package:homl/data/repositories/events.repository.dart';
import 'package:homl/data/repositories/settings.repository.dart';
import 'package:homl/data/repositories/tags.repository.dart';
import 'package:homl/helpers/app_message.dart';
import 'package:homl/helpers/server_reachability.dart';
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
    when(() => eventsRepository.deleteEvent(1)).thenAnswer((_) async {});

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
        deleteEvents: any(named: 'deleteEvents'))).thenAnswer((_) async {});

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
}
