import 'dart:async';
import 'dart:developer';
import 'package:dio/dio.dart';
import 'package:rxdart/rxdart.dart';

import 'package:homl/data/models/settings.dart';

import 'api.dart';

/// Exception thrown when login fails
class SettingsRequestFailure implements Exception {}

/// Exception thrown when the content is empty
class SettingsNotFoundFailure implements Exception {}

class SettingsRepository {
  final api = Api().api;
  final BehaviorSubject<Settings> _settingsController = BehaviorSubject();
  Stream<Settings> get settingsStream => _settingsController.stream;

  /// Last settings fetched from the backend, if any.
  Settings? get current => _settingsController.valueOrNull;

  /// Fetches the settings, pushes them on [settingsStream] and returns them
  /// (null when the request failed).
  Future<Settings?> getSettings() async {
    try {
      final response =
          await api.get<Map<String, dynamic>>('${Api.baseUrl}/settings');

      if (response.data == null) {
        _settingsController.addError(SettingsNotFoundFailure());
        return null;
      }

      Settings result = Settings.fromJson(response.data!);
      _settingsController.add(result);
      return result;
    } on DioException catch (_) {
      _settingsController.addError(SettingsRequestFailure());
      return null;
    }
  }

  Future<void> setSettings(Settings settings) async {
    try {
      final response =
          await api.put('${Api.baseUrl}/settings', data: settings.toJson());

      if (response.data == null) {
        _settingsController.addError(SettingsNotFoundFailure());
        return;
      }

      Settings result = Settings.fromJson(response.data!);
      _settingsController.add(result);
    } on DioException catch (_) {
      _settingsController.addError(SettingsRequestFailure());
    }
  }

  void dispose() {
    log('Closing settings stream controller', name: 'SettingsRepository');
    _settingsController.close();
  }
}
