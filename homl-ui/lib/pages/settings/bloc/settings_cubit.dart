import 'dart:async';
import 'dart:developer';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:homl/data/models/settings.dart';
import 'package:homl/data/repositories/settings.repository.dart';
import 'package:homl/helpers/app_message.dart';
import 'package:homl/helpers/language.dart';
import 'package:package_info_plus/package_info_plus.dart';

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
    unawaited(loadVersions());
  }

  /// Reads the installed app version and asks the backend for its build; both
  /// land in the About row. Failures are not errors here: the row shows what
  /// it could learn.
  Future<void> loadVersions() async {
    String? appVersion;
    try {
      final info = await PackageInfo.fromPlatform();
      appVersion = info.buildNumber.isEmpty
          ? info.version
          : '${info.version}+${info.buildNumber}';
    } catch (e) {
      log('Package info unavailable: $e', name: 'SettingsCubit');
    }
    final serverVersion = await settingsRepository.getServerVersion();
    if (isClosed) return;
    emit(state.copyWith(
        appVersion: appVersion,
        serverVersion: serverVersion,
        versionsLoaded: true));
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
