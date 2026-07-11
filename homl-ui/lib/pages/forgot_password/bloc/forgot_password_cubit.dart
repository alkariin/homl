import 'dart:developer';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:homl/data/repositories/users.repository.dart';

part 'forgot_password_state.dart';

class ForgotPasswordCubit extends Cubit<ForgotPasswordState> {
  final UsersRepository _usersRepository;

  ForgotPasswordCubit(this._usersRepository)
      : super(const ForgotPasswordState());

  void emailChanged(String email) {
    emit(state.update(email: email));
  }

  void codeChanged(String code) {
    emit(state.update(code: code));
  }

  void newPasswordChanged(String newPassword) {
    emit(state.update(newPassword: newPassword));
  }

  void confirmPasswordChanged(String confirmPassword) {
    emit(state.update(confirmPassword: confirmPassword));
  }

  /// Requests the reset code. Always moves to the code-entry step, even on a
  /// server error, so the response cannot be used to enumerate accounts.
  Future<void> sendCode() async {
    if (state.status == ForgotPasswordStatus.submitting) return;
    if (state.email.isEmpty) return;

    emit(state.update(
        status: ForgotPasswordStatus.submitting,
        message: ForgotPasswordMessage.none));
    try {
      await _usersRepository.requestPasswordReset(state.email);
    } catch (err) {
      log('Password reset request failed',
          name: 'ForgotPasswordCubit', error: err);
    }
    emit(state.update(
        status: ForgotPasswordStatus.editing,
        step: ForgotPasswordStep.codeEntry));
  }

  Future<void> submit() async {
    if (state.status == ForgotPasswordStatus.submitting) return;
    if (state.code.isEmpty || state.newPassword.isEmpty) return;

    emit(state.update(
        status: ForgotPasswordStatus.submitting,
        message: ForgotPasswordMessage.none));
    try {
      await _usersRepository.confirmPasswordReset(
          state.email, state.code, state.newPassword);
      // On success the repository emits `authenticated` and the AppView
      // navigates home: nothing more to do here.
      emit(state.update(status: ForgotPasswordStatus.editing));
    } on ResetCodeInvalidFailure catch (err) {
      log('Password reset code rejected',
          name: 'ForgotPasswordCubit', error: err);
      emit(state.update(
          status: ForgotPasswordStatus.editing,
          message: ForgotPasswordMessage.invalidCode));
    } catch (err) {
      log('Unexpected password reset error',
          name: 'ForgotPasswordCubit', error: err);
      emit(state.update(
          status: ForgotPasswordStatus.editing,
          message: ForgotPasswordMessage.error));
    }
  }
}
