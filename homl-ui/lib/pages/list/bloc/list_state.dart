part of 'list_cubit.dart';

class ListState extends Equatable {
  /// Terms typed or picked in the search field, in the order they were added
  /// (AND semantics, see [searchEvents]).
  final List<SearchTerm> terms;

  /// Days picked to narrow the search; null when none are.
  final DayRange? range;

  final List<Event> events;

  /// True until the shared events were loaded at least once (cache or
  /// network); the filtering itself is synchronous.
  final bool loading;

  const ListState(
      {required this.terms,
      this.range,
      required this.events,
      required this.loading});

  ListState.initial() : this(terms: [], events: [], loading: true);

  /// A term or a range narrows the list.
  bool get isSearching => terms.isNotEmpty || range != null;

  /// The tags the search asks for, in the stored casing: what the app bar
  /// mark follows. An excluded or quoted term is no tag to wear; a term
  /// naming no tag falls through the mark's own lookup.
  List<String> get chosenTagNames => [
        for (final term in terms)
          if (!term.exclude && term.tagName != null) term.tagName!,
      ];

  @override
  List<Object?> get props => [terms, range, events, loading];
}
