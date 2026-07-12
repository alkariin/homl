import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:homl/data/models/category.dart';
import 'package:homl/data/models/event.dart';
import 'package:homl/data/models/tag.dart';
import 'package:homl/pages/home/bloc/home_cubit.dart';
import 'package:homl/pages/list/bloc/list_cubit.dart';

class MockHomeCubit extends MockCubit<HomeState> implements HomeCubit {}

Tag tag(int id, String name, {int? parent}) =>
    Tag(id: id, tag: name, idCategory: 1, idParentTag: parent);

Event event(int id, List<Tag> tags) =>
    Event(id: id, description: 'event $id', date: DateTime(2026), tags: tags);

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
    cubit.addFilterTag('  foot ');

    // The chip shows the canonical casing and the synonym group matches.
    expect(cubit.state.filters, ['Foot']);
    expect(cubit.state.events, [football, foot]);

    cubit.removeFilterTag('FOOT');
    expect(cubit.state.filters, isEmpty);
    expect(cubit.state.events, [football, foot, movie]);
  });

  test('ignores duplicated filters whatever their casing', () {
    homeCubit = MockHomeCubit();
    whenListen(homeCubit, const Stream<HomeState>.empty(),
        initialState: loadedState());

    final cubit = ListCubit(homeCubit);
    cubit.addFilterTag('movie night');
    cubit.addFilterTag('MOVIE NIGHT');

    expect(cubit.state.filters, ['Movie Night']);
    expect(cubit.state.events, [movie]);
  });

  test('re-applies the filters when the shared events change', () async {
    homeCubit = MockHomeCubit();
    final controller = StreamController<HomeState>();
    whenListen(homeCubit, controller.stream,
        initialState: HomeState.initial('user'));

    final cubit = ListCubit(homeCubit);
    cubit.addFilterTag('football');
    expect(cubit.state.events, isEmpty);

    controller.add(loadedState());
    await expectLater(
      cubit.stream,
      emitsThrough(predicate<ListState>(
          (s) => !s.loading && s.events.length == 2)),
    );

    await cubit.close();
    await controller.close();
  });
}
