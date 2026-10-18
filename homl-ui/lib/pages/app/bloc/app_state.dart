part of 'app_cubit.dart';

class AppState extends Equatable {
  final Language locale; // only language used when unlogged
  final AppMessage? errorModal;

  /// Light, dark or as the system: a preference of this device, not of the
  /// account (see [AppCubit.updateThemeMode]).
  final ThemeMode themeMode;

  const AppState(
      {required this.locale,
      this.errorModal,
      this.themeMode = ThemeMode.system});

  AppState copyWith(
      {Language? locale,
      AppMessage? errorModal,
      bool clearErrorModal = false,
      ThemeMode? themeMode}) {
    return AppState(
      locale: locale ?? this.locale,
      errorModal: clearErrorModal ? null : (errorModal ?? this.errorModal),
      themeMode: themeMode ?? this.themeMode,
    );
  }

  @override
  List<Object?> get props => [locale, errorModal, themeMode];
}
