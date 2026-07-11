part of 'settings_cubit.dart';

class SettingsState extends Equatable {
  final Settings? settings;
  final AppMessage? errorModal;
  final bool isFormSubmitted;

  const SettingsState(
      {this.settings, this.errorModal, required this.isFormSubmitted});

  const SettingsState.initial() : this(isFormSubmitted: false);

  SettingsState copyWith(
      {Settings? settings,
      AppMessage? errorModal,
      bool? isFormSubmitted,
      bool clearErrorModal = false}) {
    return SettingsState(
      settings: settings ?? this.settings,
      errorModal: clearErrorModal ? null : (errorModal ?? this.errorModal),
      isFormSubmitted: isFormSubmitted ?? this.isFormSubmitted,
    );
  }

  @override
  List<Object?> get props => [settings, errorModal, isFormSubmitted];
}
