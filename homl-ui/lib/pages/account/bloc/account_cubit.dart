import 'dart:developer';

import 'package:biometric_storage/biometric_storage.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:homl/data/models/user.dart';

import 'package:homl/data/repositories/users.repository.dart';
import 'package:homl/helpers/app_message.dart';
import 'package:homl/helpers/biometric_storage.dart';
import 'package:homl/helpers/encryption.dart' as encryption;
import 'package:homl/helpers/local_storage_manager.dart';

part 'account_state.dart';

class AccountCubit extends Cubit<AccountState> {
  final UsersRepository usersRepository;

  AccountCubit(this.usersRepository) : super(const AccountState.initial()) {
    init();
  }

  Future<void> init() async {
    final isFingerprintEnabled = await LocalStorageManager.getBool(
        LocalStorageKey.isFingerprintEnabled);
    final pinKeypair =
        await LocalStorageManager.getValue(LocalStorageKey.pinKeypair);
    log(
      'Init account toggles: isFingerprintEnabled=$isFingerprintEnabled, isPinEnabled=${pinKeypair != null}',
      name: 'AccountCubit',
    );
    emit(state.copyWith(
        user: User(
            isFingerprintEnabled: isFingerprintEnabled,
            isPinEnabled: pinKeypair != null)));
  }

  void resetPasswordDialogState() {
    emit(state.copyWith(
      clearResponseError: true,
      isFormSubmitted: false,
    ));
  }

  Future<void> submit(String oldPassword, String newPassword) async {
    try {
      await usersRepository.updatePassword(oldPassword, newPassword);
      emit(state.copyWith(
        clearResponseError: true,
        isFormSubmitted: true,
      ));
    } on UserRequestFailure catch (_) {
      emit(state.copyWith(
        responseError: AppMessage.passwordIncorrect,
        isFormSubmitted: true,
      ));
    } catch (err) {
      emit(state.copyWith(
        responseError: AppMessage.passwordUpdateError,
        isFormSubmitted: true,
      ));
    }
  }

  Future<void> updateIsFingerprintEnabled(bool isFingerprintEnabled) async {
    if (isFingerprintEnabled) {
      try {
        final publicKey = await generateKeyPair();
        // We store it in local storage as well because during the next login process, we should know if it's activated and at this moment the user is not logged in, so no api request
        await LocalStorageManager.setBool(
            LocalStorageKey.isFingerprintEnabled, true);
        await LocalStorageManager.remove(LocalStorageKey.pinKeypair);

        final User newUser = state.user!
            .copyWith(isFingerprintEnabled: true, pin: null, pkey: publicKey);

        final res = await usersRepository.secureAuth(newUser);
        emit(state.copyWith(user: res));
      } on AuthException catch (e) {
        final modal = e.message == BiometricErrors.noBiometric.toString()
            ? AppMessage.fingerprintUnavailable
            : AppMessage.unexpectedError;
        emit(state.copyWith(modal: modal));
      } catch (e) {
        emit(state.copyWith(modal: AppMessage.unexpectedError));
      }
    } else {
      try {
        await removeStorageFile();
        await LocalStorageManager.remove(LocalStorageKey.isFingerprintEnabled);

        final User newAccount =
            state.user!.copyWith(isFingerprintEnabled: false);

        final res = await usersRepository.secureAuth(newAccount);
        emit(state.copyWith(user: res));
      } catch (e) {
        emit(state.copyWith(modal: AppMessage.unexpectedError));
      }
    }
  }

  Future<void> submitPin(String? pin) async {
    if (pin != null) {
      try {
        var (publicKey, keyPairJson) = await encryption.generateKeyPair();
        // Allow us to know at the start of the app if the user has enabled the PIN, as well as retrieve the keypair
        await LocalStorageManager.setValue(
            LocalStorageKey.pinKeypair, keyPairJson);
        await LocalStorageManager.remove(LocalStorageKey.isFingerprintEnabled);

        final User newUser = state.user!.copyWith(
            isFingerprintEnabled: false,
            isPinEnabled: true,
            pin: pin,
            pkey: publicKey);

        final res = await usersRepository.secureAuth(newUser);
        emit(state.copyWith(user: res, modal: AppMessage.pinEnabled));
      } catch (e) {
        emit(state.copyWith(modal: AppMessage.unexpectedError));
      }
    } else {
      try {
        final User newUser = state.user!
            .copyWith(isPinEnabled: false); // it will put "pin" as null
        await LocalStorageManager.remove(LocalStorageKey.pinKeypair);
        final res = await usersRepository.secureAuth(newUser);
        emit(state.copyWith(user: res, modal: AppMessage.pinDisabled));
      } catch (e) {
        emit(state.copyWith(modal: AppMessage.unexpectedError));
      }
    }
  }

  void resetPinViewState() {
    emit(state.copyWith(
      clearModal: true,
      isFormSubmitted: false,
    ));
  }

  void endModal() {
    emit(state.copyWith(clearModal: true));
  }
}
