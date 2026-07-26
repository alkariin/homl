import 'package:dio/dio.dart';

import 'package:homl/data/repositories/api.dart';
import 'package:homl/helpers/e2ee.dart';
import 'package:homl/helpers/local_storage_manager.dart';

/// Exception thrown when an E2EE request fails
class E2eeRequestFailure implements Exception {}

/// Repository of the E2EE lifecycle endpoints (homl-web/docs/e2ee.md):
/// the atomic whole-dataset migration and the lost-key purge.
class E2eeRepository {
  final apiInstance = Api();

  /// The migrate endpoint conflicts (409) when the dataset changed between
  /// the fetch and the commit: the payload is simply rebuilt and resent.
  static const _migrateAttempts = 3;

  /// Runs the enable migration. [E2ee.prepareEnable] must have been called
  /// first (the derived keys encrypt the payload); the caller commits or
  /// aborts the pending key depending on the outcome.
  Future<void> enable() => _migrate(enable: true);

  /// Runs the disable migration: the payload carries plaintext, the server
  /// re-encrypts at rest. The caller wipes the key on success.
  Future<void> disable() => _migrate(enable: false);

  /// Lost-key escape hatch: deletes every event, tag and category server-side
  /// and turns E2EE off. Destructive and irreversible.
  Future<void> purge() async {
    try {
      await apiInstance.api.post<void>('/e2ee/purge');
      await LocalStorageManager.clearDataCaches();
    } on DioException catch (_) {
      throw E2eeRequestFailure();
    }
  }

  Future<void> _migrate({required bool enable}) async {
    for (var attempt = 1; attempt <= _migrateAttempts; attempt++) {
      final payload = await _buildPayload(enable: enable);
      try {
        await apiInstance.api.post<void>('/e2ee/migrate',
            data: payload,
            options: Options(
              // The whole dataset travels in one request: give it more room
              // than the regular API calls.
              sendTimeout: const Duration(minutes: 2),
              receiveTimeout: const Duration(minutes: 2),
            ));
        // The caches hold the pre-migration payloads: drop them so the next
        // fetch stores the new representation.
        await LocalStorageManager.clearDataCaches();
        return;
      } on DioException catch (e) {
        if (e.response?.statusCode == 409) {
          // A commit whose response was lost still applied server-side: the
          // retry then conflicts on the direction. Trust the server flag
          // before giving up, or the enable path would discard a key the
          // server already migrated to.
          if (await _serverFlagMatches(enable)) {
            await LocalStorageManager.clearDataCaches();
            return;
          }
          // Otherwise the dataset moved between fetch and commit: refetch
          // and try again.
          if (attempt < _migrateAttempts) continue;
        }
        throw E2eeRequestFailure();
      }
    }
  }

  Future<bool> _serverFlagMatches(bool enable) async {
    try {
      final response =
          await apiInstance.api.get<Map<String, dynamic>>('/settings');
      return response.data?['isE2eeEnabled'] == enable;
    } on DioException catch (_) {
      return false;
    }
  }

  /// Fetches the raw dataset and rebuilds it for the requested direction.
  /// On enable the server still returns plaintext (last decryption) and the
  /// client encrypts; on disable it returns blobs and the client decrypts.
  Future<Map<String, dynamic>> _buildPayload({required bool enable}) async {
    final e2ee = E2ee();

    late Response<List<dynamic>> categoriesResponse;
    late Response<List<dynamic>> eventsResponse;
    try {
      categoriesResponse =
          await apiInstance.api.get<List<dynamic>>('/categories');
      eventsResponse = await apiInstance.api.get<List<dynamic>>('/events');
    } on DioException catch (_) {
      throw E2eeRequestFailure();
    }
    final rawCategories = categoriesResponse.data ?? [];
    final rawEvents = eventsResponse.data ?? [];

    Future<String> outgoing(String value) =>
        enable ? e2ee.encrypt(value) : e2ee.decrypt(value);

    final categories = <Map<String, dynamic>>[];
    final tags = <Map<String, dynamic>>[];
    for (final raw in rawCategories) {
      final category = raw as Map<String, dynamic>;
      categories.add({
        'id': category['id'],
        'category': await outgoing(category['category'] as String),
      });
      for (final rawTag in (category['tags'] as List<dynamic>? ?? [])) {
        final tag = rawTag as Map<String, dynamic>;
        final name = tag['tag'] as String;
        tags.add({
          'id': tag['id'],
          'tag': await outgoing(name),
          if (enable) 'tagIndex': await e2ee.tagIndex(name),
        });
      }
    }

    final events = <Map<String, dynamic>>[];
    for (final raw in rawEvents) {
      final event = raw as Map<String, dynamic>;
      final description = (event['description'] as String?) ?? '';
      events.add({
        'id': event['id'],
        // An empty description stays empty in both modes.
        'description': description.isEmpty ? '' : await outgoing(description),
      });
    }

    return {
      'direction': enable ? 'enable' : 'disable',
      if (enable) 'keyCheck': await e2ee.keyCheck(),
      'categories': categories,
      'tags': tags,
      'events': events,
    };
  }
}
