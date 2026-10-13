import 'dart:async';
import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'package:homl/data/repositories/api.dart';
import 'package:homl/data/store/local_store.dart';
import 'package:homl/data/sync/outbox.dart';
import 'package:homl/helpers/e2ee.dart';
import 'package:homl/helpers/server_reachability.dart';

/// What a sync did, for the message shown afterwards.
class SyncReport {
  /// Changes the server took as they were.
  final int sent;

  /// Events deleted on another device and edited here: created again with
  /// the edit (the edit wins).
  final int restored;

  /// Events deleted here and edited on another device: kept (the edit wins).
  final int kept;

  /// Events where the same field changed here and elsewhere: this device's
  /// value won.
  final int conflicts;

  /// Changes held back until the user decides (see the pending sheet).
  final int parked;

  const SyncReport(
      {this.sent = 0,
      this.restored = 0,
      this.kept = 0,
      this.conflicts = 0,
      this.parked = 0});

  bool get isEmpty =>
      sent == 0 && restored == 0 && kept == 0 && conflicts == 0 && parked == 0;
}

/// What sending one op came to.
enum _Step { done, parked, stop }

/// The server's state at the start of a sync, kept up to date as ops land.
class _Fresh {
  final Map<String, dynamic> settings;
  final List<Map<String, dynamic>> categories;
  final Map<int, Map<String, dynamic>> events;

  _Fresh(this.settings, this.categories, this.events);

  Map<String, dynamic>? category(Object? id) {
    for (final category in categories) {
      if (category['id'] == id) return category;
    }
    return null;
  }

  Set<int> get tagIds => {
        for (final category in categories)
          for (final tag in category['tags'] as List) (tag as Map)['id'] as int
      };

  Set<int> get dateCategoryTagIds => {
        for (final category in categories)
          if (category['kind'] == 'date')
            for (final tag in category['tags'] as List)
              (tag as Map)['id'] as int
      };
}

/// Sends the outbox once the server answers (homl-web/docs/offline-sync.md).
///
/// A sync reads the server first (settings, categories, events), then sends
/// the waiting ops in order, one at a time, comparing each with what the
/// server has now:
///
/// - a creation goes out with its `clientId` (replayed safely after a lost
///   answer); a tag whose name now exists in its category is reused instead;
/// - an edit is merged field by field with what changed elsewhere since the
///   first offline change (description, period, tags): a field changed on one
///   side takes that side's value, a field changed on both takes this
///   device's (counted as a conflict);
/// - an edit of an event deleted elsewhere creates it again — the edit wins;
/// - a deletion of an event edited elsewhere is dropped — the edit wins;
/// - an op the server refuses, or written for an encryption or a data
///   generation the server no longer has, is parked for the user.
///
/// The server going away mid-way stops the sync; what is left is sent next
/// time, nothing is lost.
class SyncEngine {
  SyncEngine({Api? api}) : _injectedApi = api;

  static SyncEngine instance = SyncEngine();

  final Api? _injectedApi;
  Api get _apiInstance => _injectedApi ?? Api();
  Dio get _dio => _apiInstance.api;

  final StreamController<SyncReport> _reports =
      StreamController<SyncReport>.broadcast();

  /// One report per sync that did something.
  Stream<SyncReport> get reports => _reports.stream;

  Future<void>? _running;
  bool _again = false;
  StreamSubscription<Reachability>? _reachability;

  /// Follows the server's reachability: whenever it answers again, the outbox
  /// is sent.
  void start() {
    _reachability ??= ServerReachability.instance.stream
        .where((reachability) => reachability == Reachability.online)
        .listen((_) => kick());
  }

  /// Sends the outbox soon, unless the server is known to be unreachable.
  void kick() {
    if (ServerReachability.instance.isOffline) return;
    unawaited(sync());
  }

  /// Sends what the outbox holds; one sync at a time (a call during a sync
  /// runs one more afterwards).
  Future<void> sync() {
    final running = _running;
    if (running != null) {
      _again = true;
      return running;
    }
    final started = _loop().whenComplete(() => _running = null);
    _running = started;
    return started;
  }

  Future<void> _loop() async {
    do {
      _again = false;
      try {
        await _cycle();
      } catch (error) {
        log('Sync failed', name: 'SyncEngine', error: error);
        Outbox.instance.abortSend();
      }
    } while (_again && !ServerReachability.instance.isOffline);
  }

  Future<void> _cycle() async {
    final ops = await Outbox.instance.ops();
    if (ops.every((op) => op.parked != null)) return;

    final fresh = await _readServer();
    if (fresh == null) return;

    var sent = 0, restored = 0, kept = 0, conflicts = 0;
    final parkedBefore = Outbox.instance.currentCounts.parked;

    await _parkStale(ops, fresh);

    while (true) {
      final op = await Outbox.instance.nextToSend();
      if (op == null) break;

      final (step, effect) = await _send(op, fresh);
      if (step == _Step.stop) {
        Outbox.instance.abortSend();
        break;
      }
      if (step == _Step.done) {
        switch (effect) {
          case _Effect.sent:
            sent++;
          case _Effect.sentWithConflict:
            sent++;
            conflicts++;
          case _Effect.restored:
            restored++;
          case _Effect.kept:
            kept++;
          case _Effect.none:
            break;
        }
      }
    }

    final parked = Outbox.instance.currentCounts.parked - parkedBefore;
    final report = SyncReport(
        sent: sent,
        restored: restored,
        kept: kept,
        conflicts: conflicts,
        parked: parked > 0 ? parked : 0);
    if (report.isEmpty) return;

    await _saveSnapshot();
    _reports.add(report);
  }

  /// The server's current settings, categories and events; null when it
  /// cannot be read (the next sync tries again).
  Future<_Fresh?> _readServer() async {
    try {
      final settings = await _dio.get<dynamic>('/settings');
      final categories = await _dio.get<dynamic>('/categories');
      final events = await _dio.get<dynamic>('/events');
      return _Fresh(
          Map<String, dynamic>.from(settings.data as Map),
          [
            for (final category in categories.data as List)
              {
                ...Map<String, dynamic>.from(category as Map),
                'tags': [
                  for (final tag in (category['tags'] as List?) ?? const [])
                    Map<String, dynamic>.from(tag as Map)
                ],
              }
          ],
          {
            for (final event in events.data as List)
              (event as Map)['id'] as int: Map<String, dynamic>.from(event)
          });
    } catch (error) {
      log('Could not read the server state', name: 'SyncEngine', error: error);
      return null;
    }
  }

  /// Parks the ops written for an encryption or a data generation the server
  /// no longer has: sending them would write the wrong representation, or hit
  /// rows that no longer mean the same thing.
  Future<void> _parkStale(List<OutboxOp> ops, _Fresh fresh) async {
    final serverKeyCheck = fresh.settings['isE2eeEnabled'] == true
        ? fresh.settings['e2eeKeyCheck'] as String?
        : null;
    final serverGeneration = fresh.settings['dataGeneration'] as String?;
    for (final op in ops) {
      if (op.parked != null) continue;
      if (op.keyCheck != serverKeyCheck) {
        await Outbox.instance.park(op, ParkReason.encryptionChanged);
      } else if (op.generation != null &&
          serverGeneration != null &&
          op.generation != serverGeneration) {
        await Outbox.instance.park(op, ParkReason.dataReplaced);
      }
    }
  }

  Future<(_Step, _Effect)> _send(OutboxOp op, _Fresh fresh) async {
    try {
      switch (op.kind) {
        case OpKind.createTag:
          return await _createTag(op, fresh);
        case OpKind.createEvent:
          return await _createEvent(op, fresh, op.body, _Effect.sent);
        case OpKind.updateEvent:
          return await _updateEvent(op, fresh);
        case OpKind.deleteEvent:
          return await _deleteEvent(op, fresh);
      }
    } on DioException catch (error) {
      return (await _onRefusal(op, error), _Effect.none);
    }
  }

  /// A request that failed: the server away (or overloaded) stops the sync,
  /// a refusal parks the op.
  Future<_Step> _onRefusal(OutboxOp op, DioException error) async {
    final status = error.response?.statusCode;
    if (Api.isUnreachable(error) ||
        status == null ||
        status == 401 ||
        status == 429 ||
        status >= 500) {
      return _Step.stop;
    }
    log('Op refused ($status)', name: 'SyncEngine');
    await Outbox.instance.park(op, ParkReason.refused);
    return _Step.parked;
  }

  Future<(_Step, _Effect)> _createTag(OutboxOp op, _Fresh fresh) async {
    final category = fresh.category(op.body['idCategory']);
    if (category == null) {
      // Its category was deleted on another device.
      await Outbox.instance.park(op, ParkReason.refused);
      return (_Step.parked, _Effect.none);
    }

    final existing = await _tagNamed(category, op.body['tag']);
    if (existing != null) {
      await Outbox.instance.complete(op, serverId: existing);
      return (_Step.done, _Effect.none);
    }

    try {
      final response = await _dio.post<dynamic>('/tags', data: op.body);
      final id = (response.data as Map)['id'] as int;
      (category['tags'] as List).add({
        'id': id,
        'tag': op.body['tag'],
        if (op.body['idParentTag'] != null)
          'idParentTag': op.body['idParentTag'],
      });
      await Outbox.instance.complete(op, serverId: id);
      return (_Step.done, _Effect.sent);
    } on DioException catch (error) {
      final data = error.response?.data;
      final body = data is Map ? data['error'] : null;
      final code = body is Map ? body['code'] : null;
      if (code != 'TAG_NAME_CONFLICT') rethrow;
      // Created meanwhile (another device, or this very op whose answer was
      // lost): use that one.
      final categories = await _dio.get<dynamic>('/categories');
      for (final candidate in categories.data as List) {
        if ((candidate as Map)['id'] != category['id']) continue;
        final id = await _tagNamed(
            Map<String, dynamic>.from(candidate), op.body['tag']);
        if (id != null) {
          await Outbox.instance.complete(op, serverId: id);
          return (_Step.done, _Effect.none);
        }
      }
      rethrow;
    }
  }

  /// The id of the tag of [category] named like [name] (both may be
  /// ciphertext: compared in clear, case-insensitively).
  Future<int?> _tagNamed(Map<String, dynamic> category, Object? name) async {
    final wanted = (await _plain(name)).toLowerCase();
    for (final tag in category['tags'] as List) {
      if ((await _plain((tag as Map)['tag'])).toLowerCase() == wanted) {
        return tag['id'] as int;
      }
    }
    return null;
  }

  /// Creates an event from [body] (an op's creation, or an edit whose event
  /// was deleted elsewhere), under the op's id as `clientId`.
  Future<(_Step, _Effect)> _createEvent(OutboxOp op, _Fresh fresh,
      Map<String, dynamic> body, _Effect effect) async {
    final tagsId = _tagsStillThere(body, fresh);
    if (tagsId == null) {
      await Outbox.instance.park(op, ParkReason.missingTag);
      return (_Step.parked, _Effect.none);
    }

    final response = await _dio.post<dynamic>('/events',
        data: {...body, 'tagsId': tagsId, 'clientId': op.id});
    final data = response.data;
    final id = data is Map ? data['id'] as int? : null;
    if (id == null) {
      // A server that predates the ids in answers: the next pull shows the
      // event, nothing else can point at it meanwhile.
      await Outbox.instance.complete(op);
      return (_Step.done, effect);
    }
    fresh.events[id] = {...body, 'id': id, 'tagsId': tagsId};
    await Outbox.instance.complete(op, serverId: id);
    return (_Step.done, effect);
  }

  /// [body]'s tag ids, without the ones deleted on another device meanwhile.
  /// Null when one was created offline and is still not on the server.
  List<int>? _tagsStillThere(Map<String, dynamic> body, _Fresh fresh) {
    final tagsId = ((body['tagsId'] as List?) ?? const []).cast<int>();
    if (tagsId.any((id) => id < 0)) return null;
    final known = fresh.tagIds;
    return [
      for (final id in tagsId)
        if (known.contains(id)) id
    ];
  }

  Future<(_Step, _Effect)> _updateEvent(OutboxOp op, _Fresh fresh) async {
    final server = fresh.events[op.target];
    if (op.target < 0 || server == null) {
      // Deleted on another device: the edit wins, the event comes back.
      return _createEvent(op, fresh, op.body, _Effect.restored);
    }

    final (merged, conflict) = await _merge(op.base, server, op.body, fresh);
    try {
      await _dio.patch<dynamic>('/events/${op.target}', data: merged);
    } on DioException catch (error) {
      if (error.response?.statusCode != 404) rethrow;
      // Deleted between the read and the write.
      return _createEvent(op, fresh, op.body, _Effect.restored);
    }
    fresh.events[op.target] = {...merged, 'id': op.target};
    await Outbox.instance.complete(op);
    return (_Step.done, conflict ? _Effect.sentWithConflict : _Effect.sent);
  }

  Future<(_Step, _Effect)> _deleteEvent(OutboxOp op, _Fresh fresh) async {
    final server = fresh.events[op.target];
    if (op.target < 0 || server == null) {
      // Never reached the server, or already deleted there.
      await Outbox.instance.complete(op);
      return (_Step.done, _Effect.none);
    }
    if (op.base != null && await _editedSince(op.base!, server, fresh)) {
      // Edited on another device since: the edit wins, the event stays.
      await Outbox.instance.complete(op);
      return (_Step.done, _Effect.kept);
    }

    try {
      await _dio.delete<dynamic>('/events/${op.target}');
    } on DioException catch (error) {
      if (error.response?.statusCode != 404) rethrow;
    }
    fresh.events.remove(op.target);
    await Outbox.instance.complete(op);
    return (_Step.done, _Effect.sent);
  }

  /// The three things an edit can change, comparable whatever their shape (a
  /// server event, or a request body).
  Future<_Fields> _fields(Map<String, dynamic> event, _Fresh fresh) async {
    final dateTags = fresh.dateCategoryTagIds;
    final ids = event['tagsId'] != null
        ? (event['tagsId'] as List).cast<int>()
        : [
            for (final tag in (event['tags'] as List?) ?? const [])
              (tag as Map)['id'] as int
          ];
    return _Fields(
      description: await _plain(event['description']),
      period: [
        _day(event['date']),
        _day(event['endDate']),
        event['isOngoing'] == true,
      ].join('|'),
      tags: {
        for (final id in ids)
          if (!dateTags.contains(id)) id
      },
      dateTags: {
        for (final id in ids)
          if (dateTags.contains(id)) id
      },
    );
  }

  /// Merges this device's edit ([local]) with the server's current event,
  /// each field against [base] (the event before the first offline change):
  /// a field changed on one side only takes that side's value, a field
  /// changed on both takes this device's. Returns the body to send and
  /// whether a field changed on both sides.
  Future<(Map<String, dynamic>, bool)> _merge(
      Map<String, dynamic>? base,
      Map<String, dynamic> server,
      Map<String, dynamic> local,
      _Fresh fresh) async {
    if (base == null) return (Map<String, dynamic>.from(local), false);

    final was = await _fields(base, fresh);
    final now = await _fields(server, fresh);
    final mine = await _fields(local, fresh);
    var conflict = false;

    bool takeMine(Object before, Object theirs, Object ours) {
      final oursChanged = ours != before;
      final theirsChanged = theirs != before;
      if (oursChanged && theirsChanged && ours != theirs) conflict = true;
      return oursChanged;
    }

    final description =
        takeMine(was.description, now.description, mine.description);
    final period = takeMine(was.period, now.period, mine.period);
    final tags = takeMine(_setKey(was.tags), _setKey(now.tags),
        _setKey(mine.tags));

    final clientDateTags = E2ee().enabled;
    final dateTags = period ? mine.dateTags : now.dateTags;
    return (
      {
        'description': description
            ? local['description'] ?? ''
            : server['description'] ?? '',
        'date': period ? local['date'] : server['date'],
        'endDate': period ? local['endDate'] : server['endDate'],
        'isOngoing': period ? local['isOngoing'] : server['isOngoing'],
        'tagsId': [
          ...(tags ? mine.tags : now.tags),
          // Under E2EE the client owns the date tags: they follow the period
          // that won. Otherwise the server derives them.
          if (clientDateTags) ...dateTags,
        ],
      },
      conflict
    );
  }

  Future<bool> _editedSince(Map<String, dynamic> base,
      Map<String, dynamic> server, _Fresh fresh) async {
    final was = await _fields(base, fresh);
    final now = await _fields(server, fresh);
    return was.description != now.description ||
        was.period != now.period ||
        _setKey(was.tags) != _setKey(now.tags);
  }

  static String _setKey(Set<int> ids) => (ids.toList()..sort()).join(',');

  /// The calendar day of a wire date ("2026-10-13T00:00:00Z" from the server,
  /// "2026-10-13T00:00:00.000Z" from this app), or empty.
  static String _day(Object? value) {
    if (value is! String) return '';
    final date = DateTime.parse(value).toUtc();
    return '${date.year}-${date.month}-${date.day}';
  }

  /// [value] in clear: decrypted for an E2EE account (the same text encrypts
  /// differently each time, so only clear text compares).
  static Future<String> _plain(Object? value) async {
    if (value is! String) return '';
    try {
      return await E2ee().decrypt(value);
    } catch (_) {
      return value;
    }
  }

  /// Saves the server's state after the sync, so what was sent stays on
  /// screen until the next pull.
  Future<void> _saveSnapshot() async {
    try {
      final categories = await _dio.get<dynamic>('/categories');
      final events = await _dio.get<dynamic>('/events');
      await LocalStore.instance.save(StoreEntry.categories, categories.data);
      await LocalStore.instance.save(StoreEntry.events, events.data);
    } catch (error) {
      log('Could not refresh the saved data', name: 'SyncEngine', error: error);
    }
  }

  /// Publishes [report] as if a sync had produced it.
  @visibleForTesting
  void emitReport(SyncReport report) => _reports.add(report);

  @visibleForTesting
  Future<void> dispose() async {
    await _reachability?.cancel();
    _reachability = null;
  }
}

enum _Effect { none, sent, sentWithConflict, restored, kept }

class _Fields {
  final String description;
  final String period;
  final Set<int> tags;
  final Set<int> dateTags;

  const _Fields(
      {required this.description,
      required this.period,
      required this.tags,
      required this.dateTags});
}
