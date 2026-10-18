import 'dart:async';
import 'dart:developer';
import 'package:dio/dio.dart';
import 'package:rxdart/rxdart.dart';

import 'package:homl/data/models/settings.dart';
import 'package:homl/data/store/local_store.dart';
import 'package:homl/helpers/version.dart';

import 'api.dart';

/// Exception thrown when login fails
class SettingsRequestFailure implements Exception {}

/// Exception thrown when the content is empty
class SettingsNotFoundFailure implements Exception {}

class SettingsRepository {
  final Api? _injectedApi;

  /// The Api singleton's client by default; injectable so the tests can drive
  /// the repository against a fake HTTP adapter (see Api.internal).
  late final Dio api = (_injectedApi ?? Api()).api;

  SettingsRepository({Api? api}) : _injectedApi = api;

  final BehaviorSubject<Settings> _settingsController = BehaviorSubject();
  Stream<Settings> get settingsStream => _settingsController.stream;

  /// Last settings fetched from the backend, if any.
  Settings? get current => _settingsController.valueOrNull;

  /// Fetches the settings, pushes them on [settingsStream] and returns them.
  /// Each successful payload is saved in the local store, and served
  /// instead when the request fails, so an offline start still knows the
  /// language, the default screen and the E2EE key check. Null when neither
  /// is available.
  Future<Settings?> getSettings() async {
    try {
      final response = await api.get<Map<String, dynamic>>('/settings');

      if (response.data == null) {
        _settingsController.addError(SettingsNotFoundFailure());
        return null;
      }

      Settings result = Settings.fromJson(response.data!);
      await LocalStore.instance.save(StoreEntry.settings, response.data);
      _settingsController.add(result);
      return result;
    } on DioException catch (_) {
      final cached = await getCachedSettings();
      if (cached != null) {
        _settingsController.add(cached);
        return cached;
      }
      _settingsController.addError(SettingsRequestFailure());
      return null;
    }
  }

  /// The last settings payload fetched from the backend, or null when none
  /// usable was saved yet.
  Future<Settings?> getCachedSettings() async {
    final stored = await LocalStore.instance.load(StoreEntry.settings);
    if (stored == null) return null;
    try {
      return Settings.fromJson(stored.payload as Map<String, dynamic>);
    } catch (_) {
      // A payload that no longer parses (model change) is just dropped.
      await LocalStore.instance.remove(StoreEntry.settings);
      return null;
    }
  }

  Future<void> setSettings(Settings settings) async {
    try {
      final response = await api.put('/settings', data: settings.toJson());

      if (response.data == null) {
        _settingsController.addError(SettingsNotFoundFailure());
        return;
      }

      Settings result = Settings.fromJson(response.data!);
      await LocalStore.instance.save(StoreEntry.settings, response.data);
      _settingsController.add(result);
    } on DioException catch (_) {
      _settingsController.addError(SettingsRequestFailure());
    }
  }

  /// Version of the backend answering [Api.baseUrl], read from its `/healthz`
  /// (see homl-web/internal/version). Null when the request fails — the About
  /// row then says the server is unreachable rather than hiding.
  Future<String?> getServerVersion() async {
    try {
      final response = await api.get<Map<String, dynamic>>(
          healthzUrl(api.options.baseUrl),
          // /healthz answers 503 with the same body when a dependency is
          // down; the build identity is still worth showing then.
          options: Options(
              validateStatus: (status) => status != null && status < 600));
      final version = response.data?['version'];
      return version is String && version.isNotEmpty ? version : null;
    } on DioException catch (_) {
      return null;
    }
  }

  void dispose() {
    log('Closing settings stream controller', name: 'SettingsRepository');
    _settingsController.close();
  }
}
