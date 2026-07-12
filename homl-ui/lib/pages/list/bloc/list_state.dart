part of 'list_cubit.dart';

class ListState extends Equatable {
  /// Tag names used to filter the events (AND semantics, synonym-aware),
  /// stored in their canonical title-cased form.
  final List<String> filters;
  final List<Event> events;

  /// True until the shared events were loaded at least once (cache or
  /// network); the filtering itself is synchronous.
  final bool loading;

  const ListState(
      {required this.filters, required this.events, required this.loading});

  ListState.initial() : this(filters: [], events: [], loading: true);

  ListState copyWith(
      {List<String>? filters, List<Event>? events, bool? loading}) {
    return ListState(
      filters: filters ?? this.filters,
      events: events ?? this.events,
      loading: loading ?? this.loading,
    );
  }

  @override
  List<Object?> get props => [filters, events, loading];
}
