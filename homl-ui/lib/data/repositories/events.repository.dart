import 'dart:async';

import 'package:dio/dio.dart';
import 'package:homl/data/models/event.dart';
import 'package:homl/data/models/tag.dart';
import 'package:homl/data/repositories/api.dart';
import 'package:homl/data/store/local_store.dart';
import 'package:homl/data/sync/offline_writes.dart';
import 'package:homl/data/sync/outbox.dart';
import 'package:homl/data/sync/projection.dart';
import 'package:homl/data/sync/sync_engine.dart';
import 'package:homl/helpers/e2ee.dart';

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

  /// When the events last handed out were fetched from the server: now for a
  /// fresh fetch, the save date for the copy saved on the device (null when
  /// unknown).
  DateTime? get lastSyncedAt => _lastSyncedAt;
  DateTime? _lastSyncedAt;

  /// Returns all the user's events, with the changes made offline that wait
  /// in the outbox applied (data/sync/projection.dart). Each successful
  /// payload is saved in the local store (sealed on the device, see
  /// data/store/local_store.dart) so the app keeps working offline: when the
  /// request fails, the saved copy is returned instead when there is one —
  /// unless [cacheFallback] is false, for a caller that must compare against
  /// the server itself (the import). Tag filtering happens locally (see
  /// helpers/event_search.dart).
  Future<List<Event>> getEvents({bool cacheFallback = true}) async {
    late Response<List<dynamic>> response;
    try {
      response = await apiInstance.api.get<List<dynamic>>('/events');

      if (response.data == null) {
        throw EventsNotFoundFailure();
      }
    } on DioException catch (_) {
      final cached = cacheFallback ? await getCachedEvents() : null;
      if (cached != null) {
        return cached;
      }
      throw EventsRequestFailure();
    }

    // The store gets the payload BEFORE decryption on purpose: for E2EE users
    // it must only ever hold ciphertext (homl-web/docs/e2ee.md).
    await LocalStore.instance.save(StoreEntry.events, response.data);
    _lastSyncedAt = DateTime.now();

    return _decryptEvents(await _project(response.data!));
  }

  /// The server payload with the waiting changes applied, parsed.
  Future<List<Event>> _project(List<dynamic> payload) async {
    List<OutboxOp> ops;
    try {
      ops = await Outbox.instance.ops();
    } catch (_) {
      ops = const [];
    }
    if (ops.isEmpty) {
      return payload
          .map((e) => Event.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    final categories = await LocalStore.instance.load(StoreEntry.categories);
    final projected = projectEvents(
        payload,
        projectCategories(
            (categories?.payload as List<dynamic>?) ?? const [], ops),
        ops,
        clientDateTags: E2ee().enabled);
    return projected.map(Event.fromJson).toList();
  }

  /// Decrypts E2EE payloads at the repository boundary, so every model
  /// handed to the app (and the local tag search) carries plaintext.
  Future<List<Event>> _decryptEvents(List<Event> events) async {
    final e2ee = E2ee();
    if (!e2ee.enabled) return events;

    // Every field is carried over by hand here: a new one on Event has to be
    // added, or E2EE users read it back empty (the period fields once did).
    return Future.wait(events.map((event) async => Event(
          id: event.id,
          description: await e2ee.decrypt(event.description),
          date: event.date,
          endDate: event.endDate,
          isOngoing: event.isOngoing,
          tags: await Future.wait(event.tags.map((tag) async => Tag(
                id: tag.id,
                tag: await e2ee.decrypt(tag.tag),
                idCategory: tag.idCategory,
                idParentTag: tag.idParentTag,
              ))),
          isPending: event.isPending,
        )));
  }

  /// Returns the last events payload fetched from the backend, or null when
  /// nothing usable was saved yet.
  Future<List<Event>?> getCachedEvents() async {
    final stored = await LocalStore.instance.load(StoreEntry.events);
    if (stored == null) {
      return null;
    }

    try {
      final decrypted =
          await _decryptEvents(await _project(stored.payload as List<dynamic>));
      _lastSyncedAt = stored.savedAt;
      return decrypted;
    } catch (_) {
      // A payload that no longer parses (model change) is just dropped.
      await LocalStore.instance.remove(StoreEntry.events);
      return null;
    }
  }

  /// [endDate] (inclusive) makes a closed period, [isOngoing] an open one;
  /// neither makes a single day. The pair is always sent, `null` included: the
  /// backend treats an omitted field as cleared, and an explicit value keeps
  /// the two sides honest about what was meant.
  ///
  /// Saved in the outbox instead when the server is out of reach (or earlier
  /// offline changes still wait): [WriteOutcome.queued]. [tagsId] may then
  /// hold tags created offline (negative ids).
  ///
  /// [notify] false keeps [changes] quiet, for a caller writing many events
  /// in a row: it calls [notifyChanged] once at the end instead of having
  /// the app reload after every one.
  Future<WriteOutcome> createEvent({
    String? description,
    required DateTime date,
    DateTime? endDate,
    bool isOngoing = false,
    required List<int> tagsId,
    bool notify = true,
  }) async {
    final body = {
      if (description != null && description.isNotEmpty)
        'description': await _outgoingDescription(description),
      'date': serializeDate(date),
      'endDate': endDate == null ? null : serializeDate(endDate),
      'isOngoing': isOngoing,
      'tagsId': tagsId,
    };

    if (await Outbox.instance.shouldQueue() || tagsId.any((id) => id < 0)) {
      return _queue((stamps) => Outbox.instance.createEvent(body,
          keyCheck: stamps.keyCheck, generation: stamps.generation));
    }

    // Sent with the id the outbox would replay it under: an answer lost on
    // the way back must not end up as two events.
    final clientId = newClientId();
    try {
      await apiInstance.api
          .post<dynamic>('/events', data: {...body, 'clientId': clientId});
    } on DioException catch (err) {
      if (Api.isUnreachable(err)) {
        return _queue((stamps) => Outbox.instance.createEvent(body,
            clientId: clientId,
            keyCheck: stamps.keyCheck,
            generation: stamps.generation));
      }
      throw EventsRequestFailure();
    }

    if (notify) _changesController.add(null);
    return WriteOutcome.sent;
  }

  /// Tells [changes] listeners the data changed, after a batch of writes made
  /// with `notify: false`.
  void notifyChanged() => _changesController.add(null);

  /// Saves a write in the outbox, shows it at once and lets the engine try to
  /// send it.
  Future<WriteOutcome> _queue(
      Future<void> Function(({String? keyCheck, String? generation}) stamps)
          enqueue) async {
    try {
      await enqueue(await writeStamps());
    } catch (_) {
      // Not even saved on the device: the write failed.
      throw EventsRequestFailure();
    }
    _changesController.add(null);
    SyncEngine.instance.kick();
    return WriteOutcome.queued;
  }

  /// The event as the server last sent it, to tell later which side changed
  /// what (see Outbox.updateEvent).
  Future<Map<String, dynamic>?> _serverCopy(int id) async {
    final stored = await LocalStore.instance.load(StoreEntry.events);
    final payload = stored?.payload;
    if (payload is! List) return null;
    for (final event in payload) {
      if (event is Map && event['id'] == id) {
        return Map<String, dynamic>.from(event);
      }
    }
    return null;
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
  /// empty string clears it), so are the period fields (a null [endDate] and
  /// a false [isOngoing] turn a period back into a single day), and the date
  /// tags are rebuilt from the period server-side, so [tagsId] must only
  /// carry the regular tags.
  Future<WriteOutcome> updateEvent({
    required int id,
    String? description,
    required DateTime date,
    DateTime? endDate,
    bool isOngoing = false,
    required List<int> tagsId,
  }) async {
    final body = {
      'description': await _outgoingDescription(description ?? ''),
      'date': serializeDate(date),
      'endDate': endDate == null ? null : serializeDate(endDate),
      'isOngoing': isOngoing,
      'tagsId': tagsId,
    };

    Future<WriteOutcome> queue(int target) async {
      final base = target > 0 ? await _serverCopy(target) : null;
      return _queue((stamps) => Outbox.instance.updateEvent(target, body,
          base: base, keyCheck: stamps.keyCheck, generation: stamps.generation));
    }

    // An id created offline may have been sent meanwhile.
    final target = Outbox.instance.resolve(id);
    if (target < 0 ||
        tagsId.any((tag) => tag < 0) ||
        await Outbox.instance.shouldQueue()) {
      return queue(target);
    }

    try {
      await apiInstance.api.patch<void>('/events/$target', data: body);
    } on DioException catch (err) {
      if (Api.isUnreachable(err)) return queue(target);
      throw EventsRequestFailure();
    }

    _changesController.add(null);
    return WriteOutcome.sent;
  }

  Future<WriteOutcome> deleteEvent(int id) async {
    Future<WriteOutcome> queue(int target) async {
      final base = target > 0 ? await _serverCopy(target) : null;
      return _queue((stamps) => Outbox.instance.deleteEvent(target,
          base: base, keyCheck: stamps.keyCheck, generation: stamps.generation));
    }

    final target = Outbox.instance.resolve(id);
    if (target < 0 || await Outbox.instance.shouldQueue()) {
      return queue(target);
    }

    try {
      await apiInstance.api.delete<void>('/events/$target');
    } on DioException catch (err) {
      if (Api.isUnreachable(err)) return queue(target);
      throw EventsRequestFailure();
    }

    _changesController.add(null);
    return WriteOutcome.sent;
  }

  void dispose() {
    _changesController.close();
  }
}
