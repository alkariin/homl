part of 'home_bloc.dart';

@immutable
sealed class HomeEvent extends Equatable {
  const HomeEvent();

  @override
  List<Object> get props => [];
}

// ----

class UpdateSettings extends HomeEvent {
  const UpdateSettings(this.settings);

  final Settings settings;
}

// ----

class ErrorModal extends HomeEvent {
  const ErrorModal(this.error);

  final String error;
}

// ----

class EndModal extends HomeEvent {}

class Init extends HomeEvent {}

class CreateTag extends HomeEvent {}

class UpdateTag extends HomeEvent {}

class DeleteTag extends HomeEvent {}
