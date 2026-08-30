part of 'settings_cubit.dart';

class SettingsState extends Equatable {
  final Settings? settings;
  final AppMessage? errorModal;
  final bool isFormSubmitted;

  /// "0.1.0+1" from the installed package; null until read.
  final String? appVersion;

  /// Backend build from /healthz; null until fetched, or unreachable once
  /// [versionsLoaded] is true.
  final String? serverVersion;
  final bool versionsLoaded;

  const SettingsState(
      {this.settings,
      this.errorModal,
      required this.isFormSubmitted,
      this.appVersion,
      this.serverVersion,
      this.versionsLoaded = false});

  const SettingsState.initial() : this(isFormSubmitted: false);

  SettingsState copyWith(
      {Settings? settings,
      AppMessage? errorModal,
      bool? isFormSubmitted,
      bool clearErrorModal = false,
      String? appVersion,
      String? serverVersion,
      bool? versionsLoaded}) {
    return SettingsState(
      settings: settings ?? this.settings,
      errorModal: clearErrorModal ? null : (errorModal ?? this.errorModal),
      isFormSubmitted: isFormSubmitted ?? this.isFormSubmitted,
      appVersion: appVersion ?? this.appVersion,
      serverVersion: serverVersion ?? this.serverVersion,
      versionsLoaded: versionsLoaded ?? this.versionsLoaded,
    );
  }

  @override
  List<Object?> get props => [
        settings,
        errorModal,
        isFormSubmitted,
        appVersion,
        serverVersion,
        versionsLoaded
      ];
}
