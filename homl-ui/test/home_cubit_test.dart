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
import 'package:homl/pages/home/bloc/home_cubit.dart';

class MockEventsRepository extends Mock implements EventsRepository {}

class MockCategoriesRepository extends Mock implements CategoriesRepository {}

class MockTagsRepository extends Mock implements TagsRepository {}

class MockSettingsRepository extends Mock implements SettingsRepository {}

void main() {
  final cachedEvents = [
    Event(id: 1, description: 'cached', date: DateTime(2026), tags: [
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

  setUp(() {
    eventsRepository = MockEventsRepository();
    categoriesRepository = MockCategoriesRepository();
    settingsRepository = MockSettingsRepository();

    when(() => settingsRepository.settingsStream)
        .thenAnswer((_) => const Stream<Settings>.empty());
    when(() => eventsRepository.changes)
        .thenAnswer((_) => const Stream<void>.empty());
  });

  HomeCubit buildCubit() => HomeCubit(settingsRepository, eventsRepository,
      categoriesRepository, MockTagsRepository(), 'user');

  test('serves the cached snapshot when the network is unavailable', () async {
    when(() => eventsRepository.getCachedEvents())
        .thenAnswer((_) async => cachedEvents);
    when(() => categoriesRepository.getCachedCategories())
        .thenAnswer((_) async => cachedCategories);
    when(() => eventsRepository.getEvents()).thenThrow(EventsRequestFailure());
    when(() => categoriesRepository.getCategories())
        .thenThrow(CategoriesRequestFailure());

    final cubit = buildCubit();
    await expectLater(cubit.stream,
        emitsThrough(predicate<HomeState>((s) => s.initialized)));

    // Offline with a cache: usable data, no error modal.
    expect(cubit.state.events, cachedEvents);
    expect(cubit.state.categories, cachedCategories);
    expect(cubit.state.allTagsMap.containsKey('Football'), isTrue);
    expect(cubit.state.modal, isNull);

    await cubit.close();
  });

  test('surfaces an error when there is no cache and no network', () async {
    when(() => eventsRepository.getCachedEvents()).thenAnswer((_) async => null);
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

  test('refreshes the cached snapshot from the network when it lands',
      () async {
    final freshEvents = [
      Event(id: 2, description: 'fresh', date: DateTime(2026), tags: [
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
    await expectLater(
        cubit.stream,
        emitsThrough(
            predicate<HomeState>((s) => s.events == freshEvents)));

    expect(cubit.state.modal, isNull);

    await cubit.close();
  });
}
