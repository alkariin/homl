import 'dart:developer';

import 'package:biometric_storage/biometric_storage.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:homl/data/models/user.dart';

import 'package:homl/data/repositories/e2ee.repository.dart';
import 'package:homl/data/repositories/settings.repository.dart';
import 'package:homl/data/repositories/users.repository.dart';
import 'package:homl/helpers/app_message.dart';
import 'package:homl/helpers/biometric_storage.dart';
import 'package:homl/helpers/e2ee.dart';
import 'package:homl/helpers/encryption.dart' as encryption;
import 'package:homl/helpers/local_storage_manager.dart';

part 'account_state.dart';

class AccountCubit extends Cubit<AccountState> {
  final UsersRepository usersRepository;

  /// Both optional so the existing tests keep constructing the cubit with the
  /// users repository only. The E2EE repository is created lazily (it builds
  /// the Api singleton, which needs API_BASE_URL) so plain account tests do
  /// not depend on it. Production passes the app-level settings repository so
  /// the settings stream (HomeCubit, SettingsCubit) sees the new E2EE flag.
  final SettingsRepository? settingsRepository;
  E2eeRepository? _e2eeRepository;
  E2eeRepository get e2eeRepository =>
      _e2eeRepository ??= E2eeRepository();

  AccountCubit(this.usersRepository,
      {E2eeRepository? e2eeRepository, this.settingsRepository})
      : _e2eeRepository = e2eeRepository,
        super(const AccountState.initial()) {
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
            isPinEnabled: pinKeypair != null),
        isE2eeEnabled: E2ee().enabled));
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

  /// Step 1 of enabling E2EE: generates the key and returns the recovery
  /// phrase to show. Nothing is persisted or migrated yet — the view then
  /// calls [confirmEnableE2ee] or [cancelEnableE2ee].
  Future<String> startEnableE2ee() => E2ee().prepareEnable();

  /// Discards a pending enable attempt (user backed out of the dialog).
  void cancelEnableE2ee() => E2ee().abortEnable();

  /// Step 2 of enabling E2EE: runs the whole-dataset migration, persists the
  /// key on success, discards it on failure (nothing changed server-side).
  Future<void> confirmEnableE2ee() async {
    emit(state.copyWith(e2eeBusy: true));
    try {
      await e2eeRepository.enable();
      await E2ee().commitEnable();
      await settingsRepository?.getSettings();
      emit(state.copyWith(
          e2eeBusy: false, isE2eeEnabled: true, modal: AppMessage.e2eeEnabled));
    } catch (_) {
      E2ee().abortEnable();
      emit(state.copyWith(e2eeBusy: false, modal: AppMessage.e2eeError));
    }
  }

  /// Disables E2EE: the reverse migration re-uploads plaintext (the server
  /// re-encrypts at rest), then the local key is wiped.
  Future<void> disableE2ee() async {
    emit(state.copyWith(e2eeBusy: true));
    try {
      await e2eeRepository.disable();
      await E2ee().disable();
      await settingsRepository?.getSettings();
      emit(state.copyWith(
          e2eeBusy: false,
          isE2eeEnabled: false,
          modal: AppMessage.e2eeDisabled));
    } catch (_) {
      emit(state.copyWith(e2eeBusy: false, modal: AppMessage.e2eeError));
    }
  }

  /// Clears the delete dialog before it opens, so a previous failure is not
  /// still on screen.
  void resetDeleteDialogState() {
    emit(state.copyWith(deleteBusy: false, clearDeleteError: true));
  }

  /// Deletes the account and everything it owns. Success emits nothing: the
  /// repository flips the auth status to accountDeleted, the app navigates to
  /// the login screen and this cubit is disposed with the page.
  Future<void> deleteAccount(String password) async {
    emit(state.copyWith(deleteBusy: true, clearDeleteError: true));
    try {
      await usersRepository.deleteAccount(password);
    } on UserRequestFailure catch (_) {
      if (!isClosed) {
        emit(state.copyWith(
            deleteBusy: false, deleteError: AppMessage.passwordIncorrect));
      }
    } catch (_) {
      if (!isClosed) {
        emit(state.copyWith(
            deleteBusy: false, deleteError: AppMessage.accountDeleteError));
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
