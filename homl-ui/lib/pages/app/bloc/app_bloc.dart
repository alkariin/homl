import 'dart:async';
import 'dart:developer';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/material.dart';

import 'package:homl/data/models/settings.dart';
import 'package:homl/data/repositories/settings.repository.dart';
import 'package:homl/helpers/app_message.dart';
import 'package:homl/helpers/language.dart';

part 'app_event.dart';
part 'app_state.dart';

class AppBloc extends Bloc<AppEvent, AppState> {
  final SettingsRepository settingsRepository;
  late StreamSubscription<Settings> _settingsSubscription;

  AppBloc(Language defaultLanguage, this.settingsRepository)
      : super(AppState(locale: defaultLanguage)) {
    on<UpdateLocale>(_onUpdateLocale);
    on<ErrorModal>(_onErrorModal);
    on<EndErrorModal>(_onEndErrorModal);

    _settingsSubscription =
        settingsRepository.settingsStream.listen((settings) {
      log('Settings received from stream', name: 'AppBloc');
      if (state.locale != settings.language) {
        log('Updating locale from settings', name: 'AppBloc');
        add(UpdateLocale(settings.language));
      }
    }, onError: (error) {
      log('Failed to retrieve settings stream event',
          name: 'AppBloc', error: error);
      add(const ErrorModal(AppMessage.unexpectedError));
    });
  }

  void _onUpdateLocale(UpdateLocale event, Emitter<AppState> emit) {
    emit(state.copyWith(locale: event.locale));
  }

  void _onErrorModal(ErrorModal event, Emitter<AppState> emit) {
    emit(state.copyWith(errorModal: event.error));
  }

  void _onEndErrorModal(EndErrorModal event, Emitter<AppState> emit) {
    emit(state.copyWith(clearErrorModal: true));
  }

  @override
  Future<void> close() {
    log('Closing settings subscription', name: 'AppBloc');
    _settingsSubscription.cancel();
    return super.close();
  }
}
