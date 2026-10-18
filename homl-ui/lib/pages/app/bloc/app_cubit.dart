import 'dart:async';
import 'dart:developer';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import 'package:homl/data/models/settings.dart';
import 'package:homl/data/repositories/settings.repository.dart';
import 'package:homl/helpers/app_message.dart';
import 'package:homl/helpers/language.dart';
import 'package:homl/helpers/local_storage_manager.dart';

part 'app_state.dart';

class AppCubit extends Cubit<AppState> {
  final SettingsRepository settingsRepository;
  late StreamSubscription<Settings> _settingsSubscription;

  AppCubit(Language defaultLanguage, this.settingsRepository,
      {ThemeMode themeMode = ThemeMode.system})
      : super(AppState(locale: defaultLanguage, themeMode: themeMode)) {
    _settingsSubscription =
        settingsRepository.settingsStream.listen((settings) {
      log('Settings received from stream', name: 'AppCubit');
      if (state.locale != settings.language) {
        log('Updating locale from settings', name: 'AppCubit');
        updateLocale(settings.language);
      }
    }, onError: (error) {
      log('Failed to retrieve settings stream event',
          name: 'AppCubit', error: error);
      errorModal(AppMessage.requestFailed);
    });
  }

  void updateLocale(Language locale) {
    emit(state.copyWith(locale: locale));
  }

  /// The appearance saved on this device; [ThemeMode.system] when none was
  /// picked yet. Read before the first frame (main.dart), so a dark choice on
  /// a light system does not flash light first.
  static Future<ThemeMode> loadThemeMode() async {
    try {
      final saved =
          await LocalStorageManager.getValue(LocalStorageKey.themeMode);
      return ThemeMode.values.asNameMap()[saved] ?? ThemeMode.system;
    } catch (error) {
      log('Failed to read the theme mode', name: 'AppCubit', error: error);
      return ThemeMode.system;
    }
  }

  /// Switches the appearance at once and saves it on this device.
  Future<void> updateThemeMode(ThemeMode themeMode) async {
    emit(state.copyWith(themeMode: themeMode));
    try {
      await LocalStorageManager.setValue(
          LocalStorageKey.themeMode, themeMode.name);
    } catch (error) {
      log('Failed to save the theme mode', name: 'AppCubit', error: error);
    }
  }

  void errorModal(AppMessage error) {
    emit(state.copyWith(errorModal: error));
  }

  void endErrorModal() {
    emit(state.copyWith(clearErrorModal: true));
  }

  @override
  Future<void> close() {
    log('Closing settings subscription', name: 'AppCubit');
    _settingsSubscription.cancel();
    return super.close();
  }
}
