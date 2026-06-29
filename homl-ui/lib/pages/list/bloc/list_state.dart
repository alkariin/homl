part of 'list_bloc.dart';

class ListState extends Equatable {
  final List<Tag> tags;
  final String modal;

  const ListState(this.tags, this.modal);

  ListState.initial() : this([], "");

  ListState copyWith({List<Tag>? tags, String? modal}) {
    return ListState(
      tags ?? this.tags,
      modal ?? this.modal,
    );
  }

  @override
  List<Object> get props => [tags, modal];
}
