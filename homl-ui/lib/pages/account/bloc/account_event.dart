part of 'account_bloc.dart';

sealed class AccountEvent extends Equatable {
  const AccountEvent();

  @override
  List<Object> get props => [];
}

class Submit extends AccountEvent {
  const Submit(this.oldPassword, this.newPassword);

  final String oldPassword;
  final String newPassword;

  @override
  List<Object> get props => [oldPassword, newPassword];
}

class ResetPasswordDialogState extends AccountEvent {}

class UpdateIsFingerprintEnabled extends AccountEvent {
  const UpdateIsFingerprintEnabled(this.isFingerprintEnabled);

  final bool isFingerprintEnabled;
}

class SubmitPin extends AccountEvent {
  const SubmitPin(this.pin);

  final String? pin;
}

class ResetPinViewState extends AccountEvent {}

class InitValues extends AccountEvent {}
