part of 'home_bloc.dart';

@immutable
sealed class HomeEvent extends Equatable {
  const HomeEvent();

  @override
  List<Object?> get props => [];
}

// ----

class UpdateSettings extends HomeEvent {
  const UpdateSettings(this.settings);

  final Settings settings;
}

// ----

class ErrorModal extends HomeEvent {
  const ErrorModal(this.error);

  final AppMessage error;

  @override
  List<Object?> get props => [error];
}

// ----

class EndModal extends HomeEvent {}

class Init extends HomeEvent {}

/// Re-fetches the events only (e.g. after an event creation).
class RefreshEvents extends HomeEvent {}

// ---- Tag CRUD

class CreateTag extends HomeEvent {
  final String text;
  final int idCategory;

  /// When set, the new tag is created as a synonym of this main tag.
  final int? idParentTag;

  const CreateTag(this.text, this.idCategory, {this.idParentTag});

  @override
  List<Object?> get props => [text, idCategory, idParentTag];
}

class UpdateTag extends HomeEvent {
  final int id;
  final String text;
  final int idCategory;

  /// Full-state: null detaches the tag from its parent.
  final int? idParentTag;

  const UpdateTag(this.id, this.text, this.idCategory, {this.idParentTag});

  @override
  List<Object?> get props => [id, text, idCategory, idParentTag];
}

class DeleteTag extends HomeEvent {
  final int id;

  const DeleteTag(this.id);

  @override
  List<Object?> get props => [id];
}

// ---- Category CRUD

class CreateCategory extends HomeEvent {
  final String name;
  final String color;

  const CreateCategory(this.name, this.color);

  @override
  List<Object?> get props => [name, color];
}

class UpdateCategory extends HomeEvent {
  final int id;
  final String name;
  final String color;

  const UpdateCategory(this.id, this.name, this.color);

  @override
  List<Object?> get props => [id, name, color];
}

class DeleteCategory extends HomeEvent {
  final int id;
  final bool moveTags;

  const DeleteCategory(this.id, {this.moveTags = false});

  @override
  List<Object?> get props => [id, moveTags];
}
