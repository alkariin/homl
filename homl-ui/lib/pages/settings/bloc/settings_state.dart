part of 'settings_bloc.dart';

class SettingsState extends Equatable {
  final Settings? settings;
  final String? errorModal;
  final bool isFormSubmitted;

  const SettingsState(
      {this.settings, this.errorModal, required this.isFormSubmitted});

  const SettingsState.initial() : this(isFormSubmitted: false);

  SettingsState copyWith(
      {Settings? settings, String? errorModal, bool? isFormSubmitted}) {
    return SettingsState(
      settings: settings ?? this.settings,
      errorModal: errorModal ?? this.errorModal,
      isFormSubmitted: isFormSubmitted ?? this.isFormSubmitted,
    );
  }

  @override
  List<Object?> get props => [settings, errorModal];
}
