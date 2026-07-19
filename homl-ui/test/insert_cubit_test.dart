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
        tagsId: [2])).thenAnswer((_) async {});

    final cubit = InsertCubit(eventsRepository, tagsRepository,
        editing: editedEvent, dateCategoryIds: {1});
    await cubit.submitEvent(categories, knownTags);

    verify(() => eventsRepository.updateEvent(
        id: 7,
        description: 'a long description',
        date: DateTime(2026, 3, 15),
        tagsId: [2])).called(1);
    verifyNever(() => eventsRepository.createEvent(
        description: any(named: 'description'),
        date: any(named: 'date'),
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
        tagsId: any(named: 'tagsId'))).thenAnswer((_) async {});

    final cubit = InsertCubit(eventsRepository, tagsRepository);
    cubit.addTag('Football');
    cubit.updateDescription('created');
    await cubit.submitEvent(categories, knownTags);

    verify(() => eventsRepository.createEvent(
        description: 'created',
        date: any(named: 'date'),
        tagsId: [2])).called(1);
    verifyNever(() => eventsRepository.updateEvent(
        id: any(named: 'id'),
        description: any(named: 'description'),
        date: any(named: 'date'),
        tagsId: any(named: 'tagsId')));

    // The form resets for the next event.
    expect(cubit.state.status, InsertStatus.success);
    expect(cubit.state.editingEventId, isNull);
    expect(cubit.state.tagNames, isEmpty);
    expect(cubit.state.description, isEmpty);
  });
}
