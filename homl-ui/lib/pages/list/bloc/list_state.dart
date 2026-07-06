part of 'list_bloc.dart';

class ListState extends Equatable {
  /// Tag names used to filter the events (AND semantics, synonym-aware).
  final List<String> filters;
  final List<Event> events;
  final bool loading;
  final String? modal;

  const ListState(
      {required this.filters,
      required this.events,
      required this.loading,
      this.modal});

  ListState.initial() : this(filters: [], events: [], loading: false);

  ListState copyWith(
      {List<String>? filters,
      List<Event>? events,
      bool? loading,
      String? modal,
      bool clearModal = false}) {
    return ListState(
      filters: filters ?? this.filters,
      events: events ?? this.events,
      loading: loading ?? this.loading,
      modal: clearModal ? null : (modal ?? this.modal),
    );
  }

  @override
  List<Object?> get props => [filters, events, loading, modal];
}
