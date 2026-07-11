import 'dart:async';
import 'dart:developer';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:homl/data/models/settings.dart';
import 'package:homl/data/repositories/settings.repository.dart';
import 'package:homl/helpers/app_message.dart';
import 'package:homl/helpers/language.dart';

part 'settings_state.dart';

class SettingsCubit extends Cubit<SettingsState> {
  final SettingsRepository settingsRepository;
  late StreamSubscription<Settings> _settingsSubscription;

  SettingsCubit(this.settingsRepository)
      : super(const SettingsState.initial()) {
    _settingsSubscription =
        settingsRepository.settingsStream.listen((settings) {
      log('Settings received from stream', name: 'SettingsCubit');
      emit(state.copyWith(settings: settings));
    }, onError: (error) {
      errorModal(AppMessage.unexpectedError);
    });
  }

  Future<void> updateLanguage(Language language) async {
    final settings = state.settings;
    if (settings == null) return; // never loaded, nothing to update
    final Settings newSettings = settings.copyWith(language: language);
    await settingsRepository.setSettings(newSettings);
  }

  Future<void> updateDefaultScreen(bool defaultScreen) async {
    final settings = state.settings;
    if (settings == null) return; // never loaded, nothing to update
    final Settings newSettings =
        settings.copyWith(defaultScreen: defaultScreen);
    await settingsRepository.setSettings(newSettings);
  }

  void errorModal(AppMessage error) {
    emit(state.copyWith(errorModal: error));
  }

  void endModal() {
    emit(state.copyWith(clearErrorModal: true));
  }

  @override
  Future<void> close() {
    log('Closing settings subscription', name: 'SettingsCubit');
    _settingsSubscription.cancel();
    return super.close();
  }
}
