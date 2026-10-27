import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:homl/data/models/event.dart';
import 'package:homl/helpers/event_search.dart';
import 'package:homl/pages/home/bloc/home_cubit.dart';

part 'list_state.dart';

/// Filters the events held by [HomeCubit] locally: the full list is already
/// in memory (and cached offline), so the search is instant and needs no
/// network round-trip.
class ListCubit extends Cubit<ListState> {
  final HomeCubit homeCubit;

  /// Today, for the open periods a range has to reach (tests pin it).
  final DateTime Function() _now;
  late final StreamSubscription<HomeState> _homeSubscription;

  ListCubit(this.homeCubit, {DateTime Function()? now})
      : _now = now ?? DateTime.now,
        super(ListState.initial()) {
    // Follow the shared events/categories: an insert or a lost/recovered
    // connection re-applies the current search automatically.
    _homeSubscription = homeCubit.stream.listen((_) {
      _search(state.terms, state.range);
    });

    _search(state.terms, state.range);
  }

  void _search(List<SearchTerm> terms, DayRange? range) {
    final home = homeCubit.state;
    emit(ListState(
      terms: terms,
      range: range,
      events: searchEvents(home.events, home.categories,
          terms: terms, range: range, today: _now()),
      loading: !home.initialized,
      timeline: state.timeline,
    ));
  }

  /// A term typed in the field: a leading '-' excludes, quotes search the
  /// descriptions only (see [SearchTerm.parse]).
  void addTypedTerm(String typed) {
    final term = SearchTerm.parse(typed);
    if (term != null) _addTerm(term);
  }

  /// A tag picked in the tag sheet, taken as it is named.
  void addTag(String name) {
    final text = name.trim();
    if (text.isNotEmpty) _addTerm(SearchTerm(text));
  }

  /// Adds [term] unless it is there already. The same term the other way
  /// round ("-Bob" while "Bob" is set) turns over in place, since asking for
  /// both could only ever find nothing.
  void _addTerm(SearchTerm term) {
    final index = state.terms.indexWhere(term.sameAs);
    if (index == -1) {
      _search([...state.terms, term], state.range);
    } else if (state.terms[index].exclude != term.exclude) {
      _search([...state.terms]..[index] = term, state.range);
    }
  }

  void removeTerm(SearchTerm term) {
    _search(state.terms.where((t) => t != term).toList(), state.range);
  }

  /// Narrows the search to [range], replacing the one set before; null lifts
  /// it.
  void setRange(DayRange? range) => _search(state.terms, range);

  /// Switches between the event list and the timeline of the periods.
  /// The search stays as it is: both views show the same results.
  void toggleTimeline() {
    emit(ListState(
      terms: state.terms,
      range: state.range,
      events: state.events,
      loading: state.loading,
      timeline: !state.timeline,
    ));
  }

  @override
  Future<void> close() {
    _homeSubscription.cancel();
    return super.close();
  }
}
