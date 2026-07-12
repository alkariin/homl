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
  late final StreamSubscription<HomeState> _homeSubscription;

  ListCubit(this.homeCubit) : super(ListState.initial()) {
    // Follow the shared events/categories: an insert or a lost/recovered
    // connection re-applies the current filters automatically.
    _homeSubscription = homeCubit.stream.listen((_) {
      _applyFilters(state.filters);
    });

    _applyFilters(state.filters);
  }

  void _applyFilters(List<String> filters) {
    final home = homeCubit.state;
    emit(state.copyWith(
      filters: filters,
      events: filterEventsByTags(home.events, home.categories, filters),
      loading: !home.initialized,
    ));
  }

  void addFilterTag(String name) {
    // Normalized like the backend stores tags, so matching is
    // case-insensitive and the chip shows the canonical casing.
    final normalized = normalizeTagName(name.trim());
    if (normalized.isEmpty || state.filters.contains(normalized)) {
      return;
    }

    _applyFilters([...state.filters, normalized]);
  }

  void removeFilterTag(String name) {
    final normalized = normalizeTagName(name.trim());
    _applyFilters(state.filters.where((f) => f != normalized).toList());
  }

  @override
  Future<void> close() {
    _homeSubscription.cancel();
    return super.close();
  }
}
