part of 'account_cubit.dart';

class AccountState extends Equatable {
  final User? user;
  final AppMessage? modal;
  final AppMessage? responseError;
  final bool isFormSubmitted;

  const AccountState(
      {this.user,
      this.modal,
      this.responseError,
      required this.isFormSubmitted});

  const AccountState.initial() : this(isFormSubmitted: false);

  AccountState copyWith(
      {User? user,
      AppMessage? modal,
      AppMessage? responseError,
      bool? isFormSubmitted,
      bool clearModal = false,
      bool clearResponseError = false}) {
    return AccountState(
      user: user ?? this.user,
      modal: clearModal ? null : (modal ?? this.modal),
      responseError:
          clearResponseError ? null : (responseError ?? this.responseError),
      isFormSubmitted: isFormSubmitted ?? this.isFormSubmitted,
    );
  }

  @override
  List<Object?> get props => [user, modal, responseError, isFormSubmitted];
}
