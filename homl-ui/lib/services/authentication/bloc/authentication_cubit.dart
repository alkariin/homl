import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:homl/data/models/settings.dart';
import 'package:homl/data/repositories/settings.repository.dart';
import 'package:homl/data/repositories/api.dart';
import 'package:homl/helpers/e2ee.dart';

part 'authentication_state.dart';

class AuthenticationCubit extends Cubit<AuthenticationState> {
  final Api _apiInstance = Api();

  AuthenticationCubit(SettingsRepository settingsRepository)
      : _settingsRepository = settingsRepository,
        super(const AuthenticationState.unknown()) {
    _authenticationStatusSubscription = _apiInstance.status.listen((status) {
      if (state.status != status) {
        _statusChanged(status);
      }
    });
  }

  final SettingsRepository _settingsRepository;
  late StreamSubscription<AuthenticationStatus>
      _authenticationStatusSubscription;

  Future<void> _statusChanged(AuthenticationStatus status) async {
    switch (status) {
      case AuthenticationStatus.unauthenticated:
        return emit(const AuthenticationState.unauthenticated());
      case AuthenticationStatus.accountDeleted:
        return emit(const AuthenticationState.accountDeleted());
      case AuthenticationStatus.authenticated:
        // We do it directly now to know asap the default screen of the user
        final settings = await _settingsRepository.getSettings();
        // E2EE gate: an end-to-end encrypted account without a matching
        // local key must not reach the data screens (they would only show
        // ciphertext) — block on the restore-or-purge screen instead.
        if (!await E2ee().unlock(settings)) {
          return emit(const AuthenticationState.e2eeLocked());
        }
        return emit(const AuthenticationState.authenticated());
      case AuthenticationStatus.e2eeLocked:
        return emit(const AuthenticationState.e2eeLocked());
      case AuthenticationStatus.unknown:
        return emit(const AuthenticationState.unknown());
      case AuthenticationStatus.pinCheck:
        return emit(const AuthenticationState.pinCheck());
      case AuthenticationStatus.pinLocked:
        return emit(const AuthenticationState.pinLocked());
      case AuthenticationStatus.biometricCheck:
        return emit(const AuthenticationState.biometricCheck());
    }
  }

  /// Re-runs the post-authentication gate. Called by the E2EE restore screen
  /// after a successful key restore or purge, so the app proceeds to home.
  Future<void> recheckAuthenticated() =>
      _statusChanged(AuthenticationStatus.authenticated);

  @override
  Future<void> close() {
    _authenticationStatusSubscription.cancel();
    return super.close();
  }
}
