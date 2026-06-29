import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:developer';
import 'package:homl/data/repositories/users.repository.dart';
import 'package:homl/helpers/language.dart';

part 'register_event.dart';
part 'register_state.dart';

class RegisterBloc extends Bloc<RegisterEvent, RegisterState> {
  final UsersRepository _usersRepository;
  final Language _language;

  RegisterBloc(this._usersRepository, this._language)
      : super(const RegisterState()) {
    on<RegisterUsernameChanged>(_onUsernameChanged);
    on<RegisterPasswordChanged>(_onPasswordChanged);
    on<RegisterSubmitted>(_onSubmitted);
  }

  void _onUsernameChanged(
    RegisterUsernameChanged event,
    Emitter<RegisterState> emit,
  ) {
    emit(
      state.update(
        username: event.username,
      ),
    );
  }

  void _onPasswordChanged(
    RegisterPasswordChanged event,
    Emitter<RegisterState> emit,
  ) {
    emit(
      state.update(
        password: event.password,
      ),
    );
  }

  Future<void> _onSubmitted(
    RegisterSubmitted event,
    Emitter<RegisterState> emit,
  ) async {
    if (state.username.isNotEmpty && state.password.isNotEmpty) {
      try {
        await _usersRepository.register(
            state.username, state.password, _language);
        emit(state.update(isRegisterIncorrect: false));

        // emit(state.copyWith(status: FormzStatus.submissionSuccess));
      } on UserRequestFailure catch (err) {
        log('Registration request failed', name: 'RegisterBloc', error: err);
        // emit(state.copyWith(status: FormzStatus.submissionFailure));
      } on UserNotFoundFailure catch (err) {
        log('Registration failed: user not found',
            name: 'RegisterBloc', error: err);
      } catch (err) {
        log('Unexpected registration error', name: 'RegisterBloc', error: err);
      }
    }
  }
}
