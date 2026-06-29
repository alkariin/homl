part of 'account_bloc.dart';

class AccountState extends Equatable {
  final User? user;
  final String? modal;
  final String responseError;
  final bool isFormSubmitted;

  const AccountState(
      {this.user,
      this.modal,
      required this.responseError,
      required this.isFormSubmitted});

  const AccountState.initial()
      : this(responseError: "", isFormSubmitted: false);

  AccountState copyWith(
      {User? user,
      String? modal,
      String? responseError,
      bool? isFormSubmitted}) {
    return AccountState(
      user: user ?? this.user,
      modal: modal ?? this.modal,
      responseError: responseError ?? this.responseError,
      isFormSubmitted: isFormSubmitted ?? this.isFormSubmitted,
    );
  }

  @override
  List<Object?> get props => [user, modal, responseError, isFormSubmitted];
}
