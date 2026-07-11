part of 'insert_bloc.dart';

sealed class InsertEvent extends Equatable {
  const InsertEvent();

  @override
  List<Object> get props => [];
}

class AddTag extends InsertEvent {
  final String name;

  const AddTag(this.name);

  @override
  List<Object> get props => [name];
}

class RemoveTag extends InsertEvent {
  final String name;

  const RemoveTag(this.name);

  @override
  List<Object> get props => [name];
}

class UpdateDate extends InsertEvent {
  final DateTime date;

  const UpdateDate(this.date);

  @override
  List<Object> get props => [date];
}

class UpdateDescription extends InsertEvent {
  final String text;

  const UpdateDescription(this.text);

  @override
  List<Object> get props => [text];
}

class SubmitEvent extends InsertEvent {
  /// Current categories and known tags, provided by the view from the
  /// HomeBloc state so this bloc does not hold a reference to another bloc.
  final List<Category> categories;
  final Map<String, TagView> knownTags;

  const SubmitEvent(this.categories, this.knownTags);

  @override
  List<Object> get props => [categories];
}

class EndInsertModal extends InsertEvent {}
