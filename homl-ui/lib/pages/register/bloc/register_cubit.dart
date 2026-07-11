import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:developer';
import 'package:homl/data/repositories/users.repository.dart';
import 'package:homl/helpers/language.dart';

part 'register_state.dart';

class RegisterCubit extends Cubit<RegisterState> {
  final UsersRepository _usersRepository;
  final Language _language;

  RegisterCubit(this._usersRepository, this._language)
      : super(const RegisterState());

  void usernameChanged(String username) {
    emit(state.update(username: username));
  }

  void passwordChanged(String password) {
    emit(state.update(password: password));
  }

  Future<void> submit() async {
    if (state.status == RegisterStatus.submitting) return;
    if (state.username.isNotEmpty && state.password.isNotEmpty) {
      // Reset the flag so a second failed attempt re-triggers the listener.
      emit(state.update(
          isRegisterIncorrect: false, status: RegisterStatus.submitting));
      try {
        await _usersRepository.register(
            state.username, state.password, _language);
        emit(state.update(status: RegisterStatus.editing));
      } on UserRequestFailure catch (err) {
        log('Registration request failed', name: 'RegisterCubit', error: err);
        emit(state.update(
            isRegisterIncorrect: true, status: RegisterStatus.editing));
      } on UserNotFoundFailure catch (err) {
        log('Registration failed: user not found',
            name: 'RegisterCubit', error: err);
        emit(state.update(
            isRegisterIncorrect: true, status: RegisterStatus.editing));
      } catch (err) {
        log('Unexpected registration error',
            name: 'RegisterCubit', error: err);
        emit(state.update(
            isRegisterIncorrect: true, status: RegisterStatus.editing));
      }
    }
  }
}
