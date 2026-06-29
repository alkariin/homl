part of 'list_bloc.dart';

sealed class ListEvent extends Equatable {
  const ListEvent();

  @override
  List<Object> get props => [];
}

class AddTagToHeader extends ListEvent {
  final String text;
  final int idCategory;

  const AddTagToHeader(this.text, this.idCategory);
}

class RemoveTagFromHeader extends ListEvent {
  final int id;

  const RemoveTagFromHeader(this.id);
}
