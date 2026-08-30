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

  /// True while the account deletion request is in flight: the dialog buttons
  /// are disabled and a progress indicator shows.
  final bool deleteBusy;

  /// Error of the last deletion attempt, shown inline in the delete dialog.
  /// Kept apart from [responseError] so it cannot trip the password-update
  /// toast or the auto-pop of the password dialog.
  final AppMessage? deleteError;

  const AccountState(
      {this.user,
      this.modal,
      this.responseError,
      required this.isFormSubmitted,
      this.isE2eeEnabled = false,
      this.e2eeBusy = false,
      this.deleteBusy = false,
      this.deleteError});

  const AccountState.initial() : this(isFormSubmitted: false);

  AccountState copyWith(
      {User? user,
      AppMessage? modal,
      AppMessage? responseError,
      bool? isFormSubmitted,
      bool? isE2eeEnabled,
      bool? e2eeBusy,
      bool? deleteBusy,
      AppMessage? deleteError,
      bool clearModal = false,
      bool clearResponseError = false,
      bool clearDeleteError = false}) {
    return AccountState(
      user: user ?? this.user,
      modal: clearModal ? null : (modal ?? this.modal),
      responseError:
          clearResponseError ? null : (responseError ?? this.responseError),
      isFormSubmitted: isFormSubmitted ?? this.isFormSubmitted,
      isE2eeEnabled: isE2eeEnabled ?? this.isE2eeEnabled,
      e2eeBusy: e2eeBusy ?? this.e2eeBusy,
      deleteBusy: deleteBusy ?? this.deleteBusy,
      deleteError: clearDeleteError ? null : (deleteError ?? this.deleteError),
    );
  }

  @override
  List<Object?> get props => [
        user,
        modal,
        responseError,
        isFormSubmitted,
        isE2eeEnabled,
        e2eeBusy,
        deleteBusy,
        deleteError
      ];
}
