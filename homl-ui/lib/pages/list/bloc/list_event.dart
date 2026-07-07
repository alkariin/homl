part of 'list_bloc.dart';

sealed class ListEvent extends Equatable {
  const ListEvent();

  @override
  List<Object> get props => [];
}

/// Fetches the events with the current filters.
class FetchEvents extends ListEvent {}

class AddFilterTag extends ListEvent {
  final String name;

  const AddFilterTag(this.name);

  @override
  List<Object> get props => [name];
}

class RemoveFilterTag extends ListEvent {
  final String name;

  const RemoveFilterTag(this.name);

  @override
  List<Object> get props => [name];
}

class EndListModal extends ListEvent {}
