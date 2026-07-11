import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:homl/data/models/settings.dart';
import 'package:homl/data/repositories/settings.repository.dart';
import 'package:homl/data/repositories/api.dart';

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
      case AuthenticationStatus.authenticated:
        // We do it directly now to know asap the default screen of the user
        await _settingsRepository.getSettings();
        return emit(const AuthenticationState.authenticated());
      case AuthenticationStatus.unknown:
        return emit(const AuthenticationState.unknown());
      case AuthenticationStatus.pinCheck:
        return emit(const AuthenticationState.pinCheck());
    }
  }

  @override
  Future<void> close() {
    _authenticationStatusSubscription.cancel();
    return super.close();
  }
}
