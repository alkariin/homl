part of 'settings_bloc.dart';

sealed class SettingsEvent extends Equatable {
  const SettingsEvent();

  @override
  List<Object> get props => [];
}

class UpdateLanguage extends SettingsEvent {
  const UpdateLanguage(this.language);

  final Language language;
}

class UpdateSettings extends SettingsEvent {
  const UpdateSettings(this.settings);

  final Settings settings;
}

class ErrorModal extends SettingsEvent {
  const ErrorModal(this.error);

  final String error;
}

class EndModal extends SettingsEvent {}
