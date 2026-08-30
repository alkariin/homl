import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:homl/data/models/event.dart';
import 'package:homl/data/models/tag.dart';
import 'package:homl/data/repositories/api.dart';
import 'package:homl/helpers/e2ee.dart';
import 'package:homl/helpers/local_storage_manager.dart';

/// Exception thrown when an events request fails
class EventsRequestFailure implements Exception {}

/// Exception thrown when the events payload is empty
class EventsNotFoundFailure implements Exception {}

class EventsRepository {
  final Api? _injectedApi;
  late final Api apiInstance = _injectedApi ?? Api();

  EventsRepository({Api? api}) : _injectedApi = api;

  final StreamController<void> _changesController =
      StreamController<void>.broadcast();

  /// Fires whenever this repository changed the events on the backend, so
  /// interested blocs can refresh without being coupled to each other.
  Stream<void> get changes => _changesController.stream;

  /// Returns all the user's events. Each successful payload is cached in the
  /// secure storage (encrypted at rest) so the app keeps working offline:
  /// when the request fails, the cached copy is returned instead when one
  /// exists. Tag filtering happens locally (see helpers/event_search.dart).
  Future<List<Event>> getEvents() async {
    late Response<List<dynamic>> response;
    try {
      response = await apiInstance.api.get<List<dynamic>>('/events');

      if (response.data == null) {
        throw EventsNotFoundFailure();
      }
    } on DioException catch (_) {
      final cached = await getCachedEvents();
      if (cached != null) {
        return cached;
      }
      throw EventsRequestFailure();
    }

    final events = response.data!
        .map((e) => Event.fromJson(e as Map<String, dynamic>))
        .toList();

    // The cache is written BEFORE decryption on purpose: for E2EE users it
    // must only ever hold ciphertext (homl-web/docs/e2ee.md).
    await LocalStorageManager.setValue(
        LocalStorageKey.eventsCache, jsonEncode(response.data));

    return _decryptEvents(events);
  }

  /// Decrypts E2EE payloads at the repository boundary, so every model
  /// handed to the app (and the local tag search) carries plaintext.
  Future<List<Event>> _decryptEvents(List<Event> events) async {
    final e2ee = E2ee();
    if (!e2ee.enabled) return events;

    return Future.wait(events.map((event) async => Event(
          id: event.id,
          description: await e2ee.decrypt(event.description),
          date: event.date,
          tags: await Future.wait(event.tags.map((tag) async => Tag(
                id: tag.id,
                tag: await e2ee.decrypt(tag.tag),
                idCategory: tag.idCategory,
                idParentTag: tag.idParentTag,
              ))),
        )));
  }

  /// Returns the last events payload fetched from the backend, or null when
  /// nothing usable was cached yet.
  Future<List<Event>?> getCachedEvents() async {
    final raw = await LocalStorageManager.getValue(LocalStorageKey.eventsCache);
    if (raw == null) {
      return null;
    }

    try {
      final events = (jsonDecode(raw) as List<dynamic>)
          .map((e) => Event.fromJson(e as Map<String, dynamic>))
          .toList();
      return await _decryptEvents(events);
    } catch (_) {
      // A cache that no longer parses (model change) is just dropped.
      await LocalStorageManager.remove(LocalStorageKey.eventsCache);
      return null;
    }
  }

  Future<void> createEvent({
    String? description,
    required DateTime date,
    required List<int> tagsId,
  }) async {
    try {
      await apiInstance.api.post<void>('/events', data: {
        if (description != null && description.isNotEmpty)
          'description': await _outgoingDescription(description),
        'date': serializeDate(date),
        'tagsId': tagsId,
      });
    } on DioException catch (_) {
      throw EventsRequestFailure();
    }

    _changesController.add(null);
  }

  /// Serializes an event date for the backend. The `date` column is a plain
  /// calendar day (MySQL `DATE`), so only the year/month/day fields matter:
  /// they are sent as UTC midnight, mirroring what `GET /events` returns.
  ///
  /// Never `toUtc()` here: the date picker yields the picked day at *local*
  /// midnight, which east of UTC becomes 22:00 the day before once converted,
  /// and MySQL then truncates it to that previous day. Editing an event to
  /// "tomorrow" silently stored "today".
  static String serializeDate(DateTime date) =>
      DateTime.utc(date.year, date.month, date.day).toIso8601String();

  /// Encrypts an outgoing description for E2EE users; the empty string stays
  /// empty in both modes.
  Future<String> _outgoingDescription(String description) async {
    if (!E2ee().enabled || description.isEmpty) return description;
    return E2ee().encrypt(description);
  }

  /// The backend PATCH is full-state: the description is always sent (an
  /// empty string clears it) and the month/year date tags are rebuilt from
  /// [date] server-side, so [tagsId] must only carry the regular tags.
  Future<void> updateEvent({
    required int id,
    String? description,
    required DateTime date,
    required List<int> tagsId,
  }) async {
    try {
      await apiInstance.api.patch<void>('/events/$id', data: {
        'description': await _outgoingDescription(description ?? ''),
        'date': serializeDate(date),
        'tagsId': tagsId,
      });
    } on DioException catch (_) {
      throw EventsRequestFailure();
    }

    _changesController.add(null);
  }

  Future<void> deleteEvent(int id) async {
    try {
      await apiInstance.api.delete<void>('/events/$id');
    } on DioException catch (_) {
      throw EventsRequestFailure();
    }

    _changesController.add(null);
  }

  void dispose() {
    _changesController.close();
  }
}
