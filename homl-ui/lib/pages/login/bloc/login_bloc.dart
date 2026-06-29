import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:developer';

import 'package:homl/data/repositories/users.repository.dart';

part 'login_event.dart';
part 'login_state.dart';

class LoginBloc extends Bloc<LoginEvent, LoginState> {
  final UsersRepository _usersRepository;

  LoginBloc(this._usersRepository) : super(const LoginState()) {
    on<LoginUsernameChanged>(_onUsernameChanged);
    on<LoginPasswordChanged>(_onPasswordChanged);
    on<LoginSubmitted>(_onSubmitted);
  }

  void _onUsernameChanged(
      LoginUsernameChanged event, Emitter<LoginState> emit) {
    emit(
      state.update(
        username: event.username,
      ),
    );
  }

  void _onPasswordChanged(
      LoginPasswordChanged event, Emitter<LoginState> emit) {
    emit(
      state.update(
        password: event.password,
      ),
    );
  }

  Future<void> _onSubmitted(
      LoginSubmitted event, Emitter<LoginState> emit) async {
    if (state.username.isNotEmpty && state.password.isNotEmpty) {
      try {
        await _usersRepository.login(state.username, state.password);
        emit(state.update(isLoginIncorrect: false));

        // emit(state.copyWith(status: FormzStatus.submissionSuccess));
      } on UserRequestFailure catch (err) {
        log('Login request failed', name: 'LoginBloc', error: err);
        // emit(state.copyWith(status: FormzStatus.submissionFailure));
      } on UserNotFoundFailure catch (err) {
        log('Login failed: user not found', name: 'LoginBloc', error: err);
      } catch (err) {
        log('Unexpected login error', name: 'LoginBloc', error: err);
      }
    }
  }
}
