import 'dart:async';
import 'dart:developer';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:homl/data/models/settings.dart';
import 'package:homl/data/repositories/settings.repository.dart';
import 'package:homl/helpers/app_message.dart';
import 'package:homl/helpers/language.dart';

part 'settings_event.dart';
part 'settings_state.dart';

class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  final SettingsRepository settingsRepository;
  late StreamSubscription<Settings> _settingsSubscription;

  SettingsBloc(this.settingsRepository)
      : super(const SettingsState.initial()) {
    on<UpdateLanguage>(_onUpdateLanguage);
    on<UpdateDefaultScreen>(_onUpdateDefaultScreen);
    on<UpdateSettings>(_onUpdateSettings);
    on<EndModal>(_onEndModal);
    on<ErrorModal>(_onErrorModal);

    _settingsSubscription =
        settingsRepository.settingsStream.listen((settings) {
      log('Settings received from stream', name: 'SettingsBloc');
      add(UpdateSettings(settings));
    }, onError: (error) {
      add(const ErrorModal(AppMessage.unexpectedError));
    });
  }

  Future<void> _onUpdateLanguage(
      UpdateLanguage event, Emitter<SettingsState> emit) async {
    final settings = state.settings;
    if (settings == null) return; // never loaded, nothing to update
    final Settings newSettings = settings.copyWith(language: event.language);
    await settingsRepository.setSettings(newSettings);
  }

  Future<void> _onUpdateDefaultScreen(
      UpdateDefaultScreen event, Emitter<SettingsState> emit) async {
    final settings = state.settings;
    if (settings == null) return; // never loaded, nothing to update
    final Settings newSettings =
        settings.copyWith(defaultScreen: event.defaultScreen);
    await settingsRepository.setSettings(newSettings);
  }

  void _onErrorModal(ErrorModal event, Emitter<SettingsState> emit) {
    emit(state.copyWith(errorModal: event.error));
  }

  void _onEndModal(EndModal event, Emitter<SettingsState> emit) {
    emit(state.copyWith(clearErrorModal: true));
  }

  void _onUpdateSettings(UpdateSettings event, Emitter<SettingsState> emit) {
    emit(state.copyWith(settings: event.settings));
  }

  @override
  Future<void> close() {
    log('Closing settings subscription', name: 'SettingsBloc');
    _settingsSubscription.cancel();
    return super.close();
  }
}
