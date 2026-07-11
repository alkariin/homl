import 'dart:async';
import 'dart:developer';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:homl/data/models/settings.dart';
import 'package:homl/data/repositories/settings.repository.dart';
import 'package:homl/helpers/app_message.dart';
import 'package:homl/helpers/language.dart';

part 'app_state.dart';

class AppCubit extends Cubit<AppState> {
  final SettingsRepository settingsRepository;
  late StreamSubscription<Settings> _settingsSubscription;

  AppCubit(Language defaultLanguage, this.settingsRepository)
      : super(AppState(locale: defaultLanguage)) {
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
      errorModal(AppMessage.unexpectedError);
    });
  }

  void updateLocale(Language locale) {
    emit(state.copyWith(locale: locale));
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
