part of 'app_cubit.dart';

class AppState extends Equatable {
  final Language locale; // only language used when unlogged
  final AppMessage? errorModal;

  const AppState({required this.locale, this.errorModal});

  AppState copyWith(
      {Language? locale, AppMessage? errorModal, bool clearErrorModal = false}) {
    return AppState(
      locale: locale ?? this.locale,
      errorModal: clearErrorModal ? null : (errorModal ?? this.errorModal),
    );
  }

  @override
  List<Object?> get props => [locale, errorModal];
}
