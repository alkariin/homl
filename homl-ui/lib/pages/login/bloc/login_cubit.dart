import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:developer';

import 'package:homl/data/repositories/users.repository.dart';

part 'login_state.dart';

class LoginCubit extends Cubit<LoginState> {
  final UsersRepository _usersRepository;

  // Dev-only prefill, injected with --dart-define (see run-local.sh). Both
  // default to the empty string in regular builds, keeping the fields blank.
  static const _devUsername = String.fromEnvironment('DEV_USERNAME');
  static const _devPassword = String.fromEnvironment('DEV_PASSWORD');

  LoginCubit(this._usersRepository)
      : super(const LoginState(
            username: _devUsername, password: _devPassword));

  void usernameChanged(String username) {
    emit(state.update(username: username));
  }

  void passwordChanged(String password) {
    emit(state.update(password: password));
  }

  Future<void> submit() async {
    if (state.status == LoginStatus.submitting) return;
    if (state.username.isNotEmpty && state.password.isNotEmpty) {
      // Reset the flag so a second failed attempt re-triggers the listener.
      emit(state.update(
          isLoginIncorrect: false, status: LoginStatus.submitting));
      try {
        await _usersRepository.login(state.username, state.password);
        emit(state.update(status: LoginStatus.editing));
      } on UserRequestFailure catch (err) {
        log('Login request failed', name: 'LoginCubit', error: err);
        emit(state.update(
            isLoginIncorrect: true, status: LoginStatus.editing));
      } on UserNotFoundFailure catch (err) {
        log('Login failed: user not found', name: 'LoginCubit', error: err);
        emit(state.update(
            isLoginIncorrect: true, status: LoginStatus.editing));
      } catch (err) {
        log('Unexpected login error', name: 'LoginCubit', error: err);
        emit(state.update(
            isLoginIncorrect: true, status: LoginStatus.editing));
      }
    }
  }
}
