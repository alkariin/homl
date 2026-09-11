import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:homl/data/models/category.dart';
import 'package:homl/data/models/event.dart';
import 'package:homl/data/models/tag.dart';
import 'package:homl/data/repositories/events.repository.dart';
import 'package:homl/data/repositories/tags.repository.dart';
import 'package:homl/pages/home/bloc/home_cubit.dart' show TagView;
import 'package:homl/pages/insert/bloc/insert_cubit.dart';

class MockEventsRepository extends Mock implements EventsRepository {}

class MockTagsRepository extends Mock implements TagsRepository {}

void main() {
  final categories = [
    Category(
        id: 1,
        category: 'Dates',
        color: '#ffff60',
        isLocked: true,
        kind: CategoryKind.date,
        tags: [Tag(id: 10, tag: 'March', idCategory: 1)]),
    Category(
        id: 2,
        category: 'Hobbies',
        color: '#f28b82',
        isLocked: false,
        kind: CategoryKind.custom,
        tags: [Tag(id: 2, tag: 'Football', idCategory: 2)]),
  ];
  final knownTags = {
    'Football': const TagView(2, '#f28b82', 'Football', 2),
  };
  final editedEvent = Event(
      id: 7,
      description: 'a long description',
      date: DateTime(2026, 3, 15),
      isOngoing: false,
      tags: [
        Tag(id: 10, tag: 'March', idCategory: 1),
        Tag(id: 2, tag: 'Football', idCategory: 2),
      ]);

  late MockEventsRepository eventsRepository;
  late MockTagsRepository tagsRepository;

  setUpAll(() {
    registerFallbackValue(DateTime(2000));
  });

  setUp(() {
    eventsRepository = MockEventsRepository();
    tagsRepository = MockTagsRepository();
  });

  test('edit mode seeds the form from the event, without the date tags', () {
    final cubit = InsertCubit(eventsRepository, tagsRepository,
        editing: editedEvent, dateCategoryIds: {1});

    // The month/year tags are backend-managed: rebuilt from the date on
    // every update, so they must not land in the editable chips.
    expect(cubit.state.tagNames, ['Football']);
    expect(cubit.state.date, DateTime(2026, 3, 15));
    expect(cubit.state.description, 'a long description');
    expect(cubit.state.editingEventId, 7);
  });

  test('submitEvent in edit mode patches the event instead of creating one',
      () async {
    when(() => eventsRepository.updateEvent(
        id: 7,
        description: 'a long description',
        date: DateTime(2026, 3, 15),
        endDate: null,
        isOngoing: false,
        tagsId: [2])).thenAnswer((_) async {});

    final cubit = InsertCubit(eventsRepository, tagsRepository,
        editing: editedEvent, dateCategoryIds: {1});
    await cubit.submitEvent(categories, knownTags);

    verify(() => eventsRepository.updateEvent(
        id: 7,
        description: 'a long description',
        date: DateTime(2026, 3, 15),
        endDate: null,
        isOngoing: false,
        tagsId: [2])).called(1);
    verifyNever(() => eventsRepository.createEvent(
        description: any(named: 'description'),
        date: any(named: 'date'),
        endDate: any(named: 'endDate'),
        isOngoing: any(named: 'isOngoing'),
        tagsId: any(named: 'tagsId')));

    // The view pops on success in edit mode, keyed by the id kept in state.
    expect(cubit.state.status, InsertStatus.success);
    expect(cubit.state.editingEventId, 7);
  });

  test('submitEvent without an edited event still creates and resets',
      () async {
    when(() => eventsRepository.createEvent(
        description: any(named: 'description'),
        date: any(named: 'date'),
        endDate: any(named: 'endDate'),
        isOngoing: any(named: 'isOngoing'),
        tagsId: any(named: 'tagsId'))).thenAnswer((_) async {});

    final cubit = InsertCubit(eventsRepository, tagsRepository);
    cubit.addTag('Football');
    cubit.updateDescription('created');
    await cubit.submitEvent(categories, knownTags);

    verify(() => eventsRepository.createEvent(
        description: 'created',
        date: any(named: 'date'),
        endDate: null,
        isOngoing: false,
        tagsId: [2])).called(1);
    verifyNever(() => eventsRepository.updateEvent(
        id: any(named: 'id'),
        description: any(named: 'description'),
        date: any(named: 'date'),
        endDate: any(named: 'endDate'),
        isOngoing: any(named: 'isOngoing'),
        tagsId: any(named: 'tagsId')));

    // The form resets for the next event.
    expect(cubit.state.status, InsertStatus.success);
    expect(cubit.state.editingEventId, isNull);
    expect(cubit.state.tagNames, isEmpty);
    expect(cubit.state.description, isEmpty);
  });

  group('period', () {
    final end = DateTime(2026, 3, 30);

    test('edit mode seeds the period', () {
      final closed = InsertCubit(eventsRepository, tagsRepository,
          editing: Event(
              id: 7,
              description: '',
              date: DateTime(2026, 3, 15),
              endDate: end,
              isOngoing: false,
              tags: []),
          dateCategoryIds: {1});
      expect(closed.state.endDate, end);
      expect(closed.state.shape, PeriodShape.closed);

      final open = InsertCubit(eventsRepository, tagsRepository,
          editing: Event(
              id: 8,
              description: '',
              date: DateTime(2026, 3, 15),
              isOngoing: true,
              tags: []),
          dateCategoryIds: {1});
      expect(open.state.endDate, isNull);
      expect(open.state.shape, PeriodShape.ongoing);
    });

    test('the shape is derived from the end date and the flag', () {
      final cubit = InsertCubit(eventsRepository, tagsRepository,
          editing: editedEvent, dateCategoryIds: {1});
      expect(cubit.state.shape, PeriodShape.singleDay);

      cubit.updateEndDate(end);
      expect(cubit.state.shape, PeriodShape.closed);
      expect(cubit.state.endDate, end);
      expect(cubit.state.isOngoing, isFalse);

      // Ongoing and an end date exclude each other.
      cubit.setOngoing();
      expect(cubit.state.shape, PeriodShape.ongoing);
      expect(cubit.state.endDate, isNull);

      cubit.updateEndDate(end);
      expect(cubit.state.shape, PeriodShape.closed);
      expect(cubit.state.isOngoing, isFalse);

      cubit.setSingleDay();
      expect(cubit.state.shape, PeriodShape.singleDay);
      expect(cubit.state.endDate, isNull);
      expect(cubit.state.isOngoing, isFalse);
    });

    test('moving the start past the end drops the end', () {
      final cubit = InsertCubit(eventsRepository, tagsRepository,
          editing: editedEvent, dateCategoryIds: {1});
      cubit.updateEndDate(end);

      // An earlier start keeps the end...
      cubit.updateDate(DateTime(2026, 3, 10));
      expect(cubit.state.endDate, end);

      // ...a start on the end day too (a one-day period, normalized by the
      // backend)...
      cubit.updateDate(DateTime(2026, 3, 30));
      expect(cubit.state.endDate, end);

      // ...but a start after it leaves no valid end: back to a single day
      // rather than an invalid pair waiting for submit.
      cubit.updateDate(DateTime(2026, 4, 2));
      expect(cubit.state.endDate, isNull);
      expect(cubit.state.shape, PeriodShape.singleDay);
    });

    test('submitEvent sends the period', () async {
      when(() => eventsRepository.updateEvent(
          id: any(named: 'id'),
          description: any(named: 'description'),
          date: any(named: 'date'),
          endDate: any(named: 'endDate'),
          isOngoing: any(named: 'isOngoing'),
          tagsId: any(named: 'tagsId'))).thenAnswer((_) async {});

      final cubit = InsertCubit(eventsRepository, tagsRepository,
          editing: editedEvent, dateCategoryIds: {1});
      cubit.updateEndDate(end);
      await cubit.submitEvent(categories, knownTags);

      verify(() => eventsRepository.updateEvent(
          id: 7,
          description: 'a long description',
          date: DateTime(2026, 3, 15),
          endDate: end,
          isOngoing: false,
          tagsId: [2])).called(1);

      cubit.setOngoing();
      await cubit.submitEvent(categories, knownTags);

      verify(() => eventsRepository.updateEvent(
          id: 7,
          description: 'a long description',
          date: DateTime(2026, 3, 15),
          endDate: null,
          isOngoing: true,
          tagsId: [2])).called(1);
    });
  });
}
