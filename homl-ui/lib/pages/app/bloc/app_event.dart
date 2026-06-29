part of 'app_bloc.dart';

@immutable
abstract class AppEvent extends Equatable {
  const AppEvent();

  @override
  List<Object> get props => [];
}

// ----

class UpdateLocale extends AppEvent {
  const UpdateLocale(this.locale);

  final Language locale;
}

// ----

class ErrorModal extends AppEvent {
  const ErrorModal(this.error);

  final String error;
}
