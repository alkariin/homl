part of 'account_cubit.dart';

class AccountState extends Equatable {
  final User? user;
  final AppMessage? modal;
  final AppMessage? responseError;
  final bool isFormSubmitted;
  final bool isE2eeEnabled;

  /// True while an E2EE migration (either direction) runs: the toggle is
  /// disabled and a progress indicator shows.
  final bool e2eeBusy;

  const AccountState(
      {this.user,
      this.modal,
      this.responseError,
      required this.isFormSubmitted,
      this.isE2eeEnabled = false,
      this.e2eeBusy = false});

  const AccountState.initial() : this(isFormSubmitted: false);

  AccountState copyWith(
      {User? user,
      AppMessage? modal,
      AppMessage? responseError,
      bool? isFormSubmitted,
      bool? isE2eeEnabled,
      bool? e2eeBusy,
      bool clearModal = false,
      bool clearResponseError = false}) {
    return AccountState(
      user: user ?? this.user,
      modal: clearModal ? null : (modal ?? this.modal),
      responseError:
          clearResponseError ? null : (responseError ?? this.responseError),
      isFormSubmitted: isFormSubmitted ?? this.isFormSubmitted,
      isE2eeEnabled: isE2eeEnabled ?? this.isE2eeEnabled,
      e2eeBusy: e2eeBusy ?? this.e2eeBusy,
    );
  }

  @override
  List<Object?> get props =>
      [user, modal, responseError, isFormSubmitted, isE2eeEnabled, e2eeBusy];
}
