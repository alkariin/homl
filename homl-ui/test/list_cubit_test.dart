import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:homl/data/models/category.dart';
import 'package:homl/data/models/event.dart';
import 'package:homl/data/models/tag.dart';
import 'package:homl/helpers/event_search.dart';
import 'package:homl/pages/home/bloc/home_cubit.dart';
import 'package:homl/pages/list/bloc/list_cubit.dart';

class MockHomeCubit extends MockCubit<HomeState> implements HomeCubit {}

Tag tag(int id, String name, {int? parent}) =>
    Tag(id: id, tag: name, idCategory: 1, idParentTag: parent);

Event event(int id, List<Tag> tags) => Event(
    id: id,
    description: 'event $id',
    date: DateTime(2026),
    isOngoing: false,
    tags: tags);

void main() {
  final categories = [
    Category(id: 1, category: 'Others', color: '#fff', isLocked: true, tags: [
      tag(1, 'Football'),
      tag(2, 'Foot', parent: 1),
      tag(3, 'Movie Night'),
    ]),
  ];
  final football = event(1, [tag(1, 'Football')]);
  final foot = event(2, [tag(2, 'Foot', parent: 1)]);
  final movie = event(3, [tag(3, 'Movie Night')]);

  HomeState loadedState() => HomeState.initial('user').copyWith(
      events: [football, foot, movie],
      categories: categories,
      initialized: true);

  late MockHomeCubit homeCubit;

  test('stays loading until the shared events are initialized', () {
    homeCubit = MockHomeCubit();
    whenListen(homeCubit, const Stream<HomeState>.empty(),
        initialState: HomeState.initial('user'));

    final cubit = ListCubit(homeCubit);

    expect(cubit.state.loading, isTrue);
    expect(cubit.state.events, isEmpty);
  });

  test('serves every event once the home state is loaded', () {
    homeCubit = MockHomeCubit();
    whenListen(homeCubit, const Stream<HomeState>.empty(),
        initialState: loadedState());

    final cubit = ListCubit(homeCubit);

    expect(cubit.state.loading, isFalse);
    expect(cubit.state.events, [football, foot, movie]);
  });

  test('filters locally, case-insensitively and through synonyms', () {
    homeCubit = MockHomeCubit();
    whenListen(homeCubit, const Stream<HomeState>.empty(),
        initialState: loadedState());

    final cubit = ListCubit(homeCubit);
    cubit.addTypedTerm('  foot ');

    // The synonym group matches, and the mark gets the stored casing.
    expect(cubit.state.terms, [const SearchTerm('foot')]);
    expect(cubit.state.chosenTagNames, ['Foot']);
    expect(cubit.state.events, [football, foot]);

    cubit.removeTerm(const SearchTerm('foot'));
    expect(cubit.state.terms, isEmpty);
    expect(cubit.state.isSearching, isFalse);
    expect(cubit.state.events, [football, foot, movie]);
  });

  test('ignores duplicated filters whatever their casing', () {
    homeCubit = MockHomeCubit();
    whenListen(homeCubit, const Stream<HomeState>.empty(),
        initialState: loadedState());

    final cubit = ListCubit(homeCubit);
    cubit.addTypedTerm('movie night');
    cubit.addTypedTerm('MOVIE NIGHT');
    cubit.addTag('Movie Night');

    expect(cubit.state.terms, [const SearchTerm('movie night')]);
    expect(cubit.state.events, [movie]);
  });

  test('the same term the other way round turns over in place', () {
    homeCubit = MockHomeCubit();
    whenListen(homeCubit, const Stream<HomeState>.empty(),
        initialState: loadedState());

    final cubit = ListCubit(homeCubit);
    cubit.addTypedTerm('Movie Night');
    cubit.addTypedTerm('Foot');
    cubit.addTypedTerm('-movie night');

    expect(cubit.state.terms, [
      const SearchTerm('movie night', exclude: true),
      const SearchTerm('Foot'),
    ]);
    expect(cubit.state.events, [football, foot]);
    // An excluded tag is no tag the mark wears.
    expect(cubit.state.chosenTagNames, ['Foot']);

    // A tag picked in the sheet asks for it again.
    cubit.addTag('Movie Night');
    expect(cubit.state.terms.first, const SearchTerm('Movie Night'));
    expect(cubit.state.events, isEmpty);
  });

  test('a quoted term stays apart from the tag of the same name', () {
    homeCubit = MockHomeCubit();
    whenListen(homeCubit, const Stream<HomeState>.empty(),
        initialState: loadedState());

    final cubit = ListCubit(homeCubit);
    cubit.addTypedTerm('Football');
    cubit.addTypedTerm('"football"');

    expect(cubit.state.terms, hasLength(2));
    expect(cubit.state.chosenTagNames, ['Football']);
  });

  test('a picked tag is taken as it is named', () {
    homeCubit = MockHomeCubit();
    whenListen(homeCubit, const Stream<HomeState>.empty(),
        initialState: loadedState());

    final cubit = ListCubit(homeCubit);
    cubit.addTag('-Odd');
    cubit.addTypedTerm('  ');
    cubit.addTypedTerm('-');

    expect(cubit.state.terms, [const SearchTerm('-Odd')]);
  });

  test('a range narrows the search, a new one replaces it', () {
    homeCubit = MockHomeCubit();
    whenListen(homeCubit, const Stream<HomeState>.empty(),
        initialState: loadedState().copyWith(events: [
          football,
          Event(
              id: 4,
              description: 'still at it',
              date: DateTime(2020, 3, 1),
              isOngoing: true,
              tags: const []),
        ]));

    final cubit = ListCubit(homeCubit, now: () => DateTime(2026, 10, 17));
    cubit.setRange(DayRange(DateTime(2025, 1, 1), DateTime(2025, 12, 31)));
    expect(cubit.state.isSearching, isTrue);
    expect(cubit.state.events.map((e) => e.id), [4]);

    cubit.setRange(DayRange(DateTime(2026, 1, 1), DateTime(2026, 1, 1)));
    expect(cubit.state.range,
        DayRange(DateTime(2026, 1, 1), DateTime(2026, 1, 1)));
    expect(cubit.state.events.map((e) => e.id), [1, 4]);

    cubit.setRange(null);
    expect(cubit.state.isSearching, isFalse);
  });

  test('re-applies the filters when the shared events change', () async {
    homeCubit = MockHomeCubit();
    final controller = StreamController<HomeState>();
    whenListen(homeCubit, controller.stream,
        initialState: HomeState.initial('user'));

    final cubit = ListCubit(homeCubit);
    // Set before the categories load: it becomes the tag once they do.
    cubit.addTypedTerm('football');
    expect(cubit.state.events, isEmpty);

    controller.add(loadedState());
    await expectLater(
      cubit.stream,
      emitsThrough(
          predicate<ListState>((s) => !s.loading && s.events.length == 2)),
    );

    await cubit.close();
    await controller.close();
  });
}
