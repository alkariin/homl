part of 'app_bloc.dart';

class AppState extends Equatable {
  final Language locale; // only language used when unlogged
  final String? errorModal;

  const AppState({required this.locale, this.errorModal});

  AppState copyWith({Language? locale, String? errorModal}) {
    return AppState(
      locale: locale ?? this.locale,
      errorModal: errorModal ?? this.errorModal,
    );
  }

  @override
  List<Object> get props => [locale];
}
