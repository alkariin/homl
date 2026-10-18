import 'dart:async';
import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'package:homl/data/repositories/api.dart';
import 'package:homl/data/store/conditional_get.dart';
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

  /// Things deleted here and edited on another device: kept (the edit wins).
  final int kept;

  /// Tags, categories or groups edited here and deleted on another device:
  /// the change was dropped (the deletion wins — the server already took
  /// the tag off its events).
  final int dropped;

  /// Events where the same field changed here and elsewhere: this device's
  /// value won.
  final int conflicts;

  /// Changes held back until the user decides (see the pending sheet).
  final int parked;

  const SyncReport(
      {this.sent = 0,
      this.restored = 0,
      this.kept = 0,
      this.dropped = 0,
      this.conflicts = 0,
      this.parked = 0});

  bool get isEmpty =>
      sent == 0 &&
      restored == 0 &&
      kept == 0 &&
      dropped == 0 &&
      conflicts == 0 &&
      parked == 0;
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

  /// Tag [id] and the category holding it.
  (Map<String, dynamic>, Map<String, dynamic>)? tag(Object? id) {
    for (final category in categories) {
      for (final tag in category['tags'] as List) {
        if ((tag as Map)['id'] == id) {
          return (category, tag as Map<String, dynamic>);
        }
      }
    }
    return null;
  }

  /// Tag group [id] and the category holding it.
  (Map<String, dynamic>, Map<String, dynamic>)? group(Object? id) {
    for (final category in categories) {
      for (final group in (category['groups'] as List?) ?? const []) {
        if ((group as Map)['id'] == id) {
          return (category, group as Map<String, dynamic>);
        }
      }
    }
    return null;
  }

  /// Takes [next]'s state: a deletion on the server changed more than the
  /// op itself (tags off events, synonyms with their main tag…).
  void replaceWith(_Fresh next) {
    settings
      ..clear()
      ..addAll(next.settings);
    categories
      ..clear()
      ..addAll(next.categories);
    events
      ..clear()
      ..addAll(next.events);
  }

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

    var sent = 0, restored = 0, kept = 0, dropped = 0, conflicts = 0;
    final parkedBefore = Outbox.instance.currentCounts.parked;

    await _parkStale(ops, fresh);

    while (true) {
      final op = await Outbox.instance.nextToSend();
      if (op == null) break;

      final (step, effect) = await _send(op, fresh);
      // A stop may follow a change that went through (the server went away
      // right after it): it counts all the same.
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
        case _Effect.dropped:
          dropped++;
        case _Effect.none:
          break;
      }
      if (step == _Step.stop) {
        Outbox.instance.abortSend();
        break;
      }
    }

    final parked = Outbox.instance.currentCounts.parked - parkedBefore;
    final report = SyncReport(
        sent: sent,
        restored: restored,
        kept: kept,
        dropped: dropped,
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
      // Conditional: unchanged since the saved copy, the server sends none.
      final categories =
          await fetchSaved(_dio, '/categories', StoreEntry.categories);
      final events = await fetchSaved(_dio, '/events', StoreEntry.events);
      return _Fresh(
          Map<String, dynamic>.from(settings.data as Map),
          [
            for (final category in categories)
              {
                ...Map<String, dynamic>.from(category as Map),
                'tags': [
                  for (final tag in (category['tags'] as List?) ?? const [])
                    Map<String, dynamic>.from(tag as Map)
                ],
                // Copied too: the engine keeps them up to date as ops land.
                'groups': [
                  for (final group in (category['groups'] as List?) ?? const [])
                    {
                      ...Map<String, dynamic>.from(group as Map),
                      'members': [...(group['members'] as List? ?? const [])],
                    }
                ],
              }
          ],
          {
            for (final event in events)
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
    // A tag, category or group change needing something created offline
    // that never reached the server (its creation is parked or was
    // discarded): it could only fail.
    if (op.kind.entity != OpEntity.event && op.dependencies.isNotEmpty) {
      final missingTag = op.tagDependencies.isNotEmpty ||
          (op.kind.entity == OpEntity.tag && op.target < 0);
      await Outbox.instance.park(
          op, missingTag ? ParkReason.missingTag : ParkReason.missingParent);
      return (_Step.parked, _Effect.none);
    }
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
        case OpKind.updateTag:
          return await _updateTag(op, fresh);
        case OpKind.deleteTag:
          return await _deleteTag(op, fresh);
        case OpKind.createCategory:
          return await _createCategory(op, fresh);
        case OpKind.updateCategory:
          return await _updateCategory(op, fresh);
        case OpKind.deleteCategory:
          return await _deleteCategory(op, fresh);
        case OpKind.createGroup:
          return await _createGroup(op, fresh);
        case OpKind.updateGroup:
          return await _updateGroup(op, fresh);
        case OpKind.deleteGroup:
          return await _deleteGroup(op, fresh);
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

  /// Reads the server again after a change that did more than itself (a
  /// deletion taking tags off events, a move taking synonyms along). False
  /// when it cannot: the sync stops, the rest goes next time.
  Future<bool> _reload(_Fresh fresh) async {
    final next = await _readServer();
    if (next == null) return false;
    fresh.replaceWith(next);
    return true;
  }

  /// [op] went through, and the server state was read again after it; a
  /// failed read stops the sync after counting the change.
  Future<(_Step, _Effect)> _doneReloading(
      OutboxOp op, _Fresh fresh, _Effect effect) async {
    await Outbox.instance.complete(op);
    return (await _reload(fresh) ? _Step.done : _Step.stop, effect);
  }

  /// The change was about something deleted on another device: the
  /// deletion wins, the change is dropped.
  Future<(_Step, _Effect)> _dropped(OutboxOp op) async {
    await Outbox.instance.complete(op);
    return (_Step.done, _Effect.dropped);
  }

  /// Whether this device's value of a field wins against the server's: it
  /// changed here since [before]. Both sides changing it to different values
  /// is a conflict, which this device wins too ([onConflict] is called).
  static bool _mine(Object? before, Object? theirs, Object? ours,
      void Function() onConflict) {
    final oursChanged = ours != before;
    if (oursChanged && theirs != before && ours != theirs) onConflict();
    return oursChanged;
  }

  /// Sends a category created offline, under its op id as `clientId`: a
  /// replay after a lost answer gets the first one back.
  Future<(_Step, _Effect)> _createCategory(OutboxOp op, _Fresh fresh) async {
    final response = await _dio
        .post<dynamic>('/categories', data: {...op.body, 'clientId': op.id});
    final data = response.data;
    final id = data is Map ? data['id'] as int? : null;
    if (id == null) {
      await Outbox.instance.park(op, ParkReason.refused);
      return (_Step.parked, _Effect.none);
    }
    fresh.categories.add({
      'id': id,
      'category': op.body['category'],
      'color': op.body['color'],
      'isLocked': false,
      'kind': 'custom',
      'tags': <Map<String, dynamic>>[],
      'groups': <Map<String, dynamic>>[],
    });
    await Outbox.instance.complete(op, serverId: id);
    return (_Step.done, _Effect.sent);
  }

  /// A name and color change, merged field by field with what changed
  /// elsewhere.
  Future<(_Step, _Effect)> _updateCategory(OutboxOp op, _Fresh fresh) async {
    final server = fresh.category(op.target);
    if (server == null) return _dropped(op);

    final base = op.base;
    var conflict = false;
    void onConflict() => conflict = true;
    final nameMine = base == null ||
        _mine(await _plain(base['category']), await _plain(server['category']),
            await _plain(op.body['category']), onConflict);
    final colorMine = base == null ||
        _mine(base['color'], server['color'], op.body['color'], onConflict);
    final body = {
      'category': nameMine ? op.body['category'] : server['category'],
      'color': colorMine ? op.body['color'] : server['color'],
    };

    try {
      await _dio.patch<dynamic>('/categories/${op.target}', data: body);
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) return _dropped(op);
      rethrow;
    }
    server.addAll(body);
    await Outbox.instance.complete(op);
    return (_Step.done, conflict ? _Effect.sentWithConflict : _Effect.sent);
  }

  /// A category deletion, unless the category changed elsewhere since this
  /// device last saw it — renamed, recolored, or given a tag this device
  /// never showed: the edit wins, it stays. Never with its events: those
  /// were deleted one by one before (DeleteEventsOfflineFailure).
  Future<(_Step, _Effect)> _deleteCategory(OutboxOp op, _Fresh fresh) async {
    final server = fresh.category(op.target);
    if (server == null) {
      await Outbox.instance.complete(op);
      return (_Step.done, _Effect.none);
    }
    final base = op.base;
    if (base != null) {
      final known = ((base['tags'] as List?) ?? const []).toSet();
      final edited =
          await _plain(base['category']) != await _plain(server['category']) ||
              base['color'] != server['color'] ||
              (server['tags'] as List)
                  .any((tag) => !known.contains((tag as Map)['id']));
      if (edited) {
        await Outbox.instance.complete(op);
        return (_Step.done, _Effect.kept);
      }
    }

    try {
      await _dio.delete<dynamic>('/categories/${op.target}', data: {
        'moveTags': op.body['moveTags'] == true,
        'deleteEvents': false,
      });
    } on DioException catch (error) {
      // Gone already: done. A move refused for a name taken in Others is a
      // refusal like any other: parked.
      if (error.response?.statusCode != 404) rethrow;
    }
    return _doneReloading(op, fresh, _Effect.sent);
  }

  /// A rename, a move or a synonym link change, merged field by field with
  /// what changed elsewhere. A destination category or main tag deleted
  /// elsewhere meanwhile cannot be reached: parked.
  Future<(_Step, _Effect)> _updateTag(OutboxOp op, _Fresh fresh) async {
    final found = fresh.tag(op.target);
    if (found == null) return _dropped(op);
    final (category, server) = found;

    final local = op.body;
    final base = op.base;
    var conflict = false;
    void onConflict() => conflict = true;
    final nameMine = base == null ||
        _mine(await _plain(base['tag']), await _plain(server['tag']),
            await _plain(local['tag']), onConflict);
    final categoryMine = base == null ||
        _mine(base['idCategory'], category['id'], local['idCategory'],
            onConflict);
    final parentMine = base == null ||
        _mine(base['idParentTag'], server['idParentTag'], local['idParentTag'],
            onConflict);

    final idCategory = categoryMine ? local['idCategory'] : category['id'];
    final idParentTag =
        parentMine ? local['idParentTag'] : server['idParentTag'];
    if (fresh.category(idCategory) == null ||
        (idParentTag != null && fresh.tag(idParentTag) == null)) {
      await Outbox.instance.park(op, ParkReason.refused);
      return (_Step.parked, _Effect.none);
    }

    final names = nameMine ? local : server;
    final body = {
      'tag': names['tag'],
      if (names['tagIndex'] != null) 'tagIndex': names['tagIndex'],
      'idCategory': idCategory,
      if (idParentTag != null) 'idParentTag': idParentTag,
    };
    try {
      await _dio.patch<dynamic>('/tags/${op.target}', data: body);
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) return _dropped(op);
      // A name taken in the category meanwhile: parked, the user decides.
      rethrow;
    }
    return _doneReloading(
        op, fresh, conflict ? _Effect.sentWithConflict : _Effect.sent);
  }

  /// A tag deletion — which keeps the events, those deleted with it went
  /// one by one before — unless the tag changed elsewhere since this device
  /// last saw it: the edit wins, it stays.
  Future<(_Step, _Effect)> _deleteTag(OutboxOp op, _Fresh fresh) async {
    final found = fresh.tag(op.target);
    if (found == null) {
      await Outbox.instance.complete(op);
      return (_Step.done, _Effect.none);
    }
    final (category, server) = found;
    final base = op.base;
    if (base != null &&
        (await _plain(base['tag']) != await _plain(server['tag']) ||
            base['idCategory'] != category['id'] ||
            base['idParentTag'] != server['idParentTag'])) {
      await Outbox.instance.complete(op);
      return (_Step.done, _Effect.kept);
    }

    try {
      await _dio
          .delete<dynamic>('/tags/${op.target}', data: {'deleteEvents': false});
    } on DioException catch (error) {
      if (error.response?.statusCode != 404) rethrow;
    }
    return _doneReloading(op, fresh, _Effect.sent);
  }

  /// The members of a group body still on the server as main tags of
  /// [category] (one deleted, moved or turned synonym elsewhere is left out:
  /// the server would refuse it).
  static List<int> _membersStillThere(
      Map<String, dynamic> body, Map<String, dynamic> category) {
    final mainTags = {
      for (final tag in category['tags'] as List)
        if ((tag as Map)['idParentTag'] == null) tag['id'] as int,
    };
    return [
      for (final id in ((body['members'] as List?) ?? const []).cast<int>())
        if (mainTags.contains(id)) id,
    ];
  }

  /// The id of the group of [category] named like [name] (both may be
  /// ciphertext: compared in clear, case-insensitively).
  Future<int?> _groupNamed(Map<String, dynamic> category, Object? name) async {
    final wanted = (await _plain(name)).toLowerCase();
    for (final group in (category['groups'] as List?) ?? const []) {
      if ((await _plain((group as Map)['name'])).toLowerCase() == wanted) {
        return group['id'] as int;
      }
    }
    return null;
  }

  /// Sends a group created offline. A group of that name in the category
  /// (created meanwhile, or this very op whose answer was lost) is used
  /// instead, like a tag.
  Future<(_Step, _Effect)> _createGroup(OutboxOp op, _Fresh fresh) async {
    final category = fresh.category(op.body['idCategory']);
    final members = category == null
        ? const <int>[]
        : _membersStillThere(op.body, category);
    if (category == null || members.isEmpty) {
      // Its category was deleted elsewhere, or none of its tags is left.
      await Outbox.instance.park(op, ParkReason.refused);
      return (_Step.parked, _Effect.none);
    }

    final existing = await _groupNamed(category, op.body['name']);
    if (existing != null) {
      await Outbox.instance.complete(op, serverId: existing);
      return (_Step.done, _Effect.none);
    }

    try {
      final response = await _dio
          .post<dynamic>('/tagGroups', data: {...op.body, 'members': members});
      final id = (response.data as Map)['id'] as int;
      ((category['groups'] as List?) ?? (category['groups'] = [])).add({
        'id': id,
        'name': op.body['name'],
        'members': members,
      });
      await Outbox.instance.complete(op, serverId: id);
      return (_Step.done, _Effect.sent);
    } on DioException catch (error) {
      final data = error.response?.data;
      final body = data is Map ? data['error'] : null;
      if ((body is Map ? body['code'] : null) != 'TAG_NAME_CONFLICT') rethrow;
      if (!await _reload(fresh)) return (_Step.stop, _Effect.none);
      final created = fresh.category(op.body['idCategory']);
      final id =
          created == null ? null : await _groupNamed(created, op.body['name']);
      if (id == null) rethrow;
      await Outbox.instance.complete(op, serverId: id);
      return (_Step.done, _Effect.none);
    }
  }

  /// A name and members change, merged with what changed elsewhere (the
  /// members as a whole, like the tags of an event).
  Future<(_Step, _Effect)> _updateGroup(OutboxOp op, _Fresh fresh) async {
    final found = fresh.group(op.target);
    if (found == null) return _dropped(op);
    final (category, server) = found;

    final local = op.body;
    final base = op.base;
    var conflict = false;
    void onConflict() => conflict = true;
    final nameMine = base == null ||
        _mine(await _plain(base['name']), await _plain(server['name']),
            await _plain(local['name']), onConflict);
    final membersMine = base == null ||
        _mine(_setKey(_ids(base['members'])), _setKey(_ids(server['members'])),
            _setKey(_ids(local['members'])), onConflict);

    final names = nameMine ? local : server;
    final members = _membersStillThere(
        {'members': membersMine ? local['members'] : server['members']},
        category);
    if (members.isEmpty) {
      await Outbox.instance.park(op, ParkReason.refused);
      return (_Step.parked, _Effect.none);
    }
    final body = {
      'name': names['name'],
      if (names['nameIndex'] != null) 'nameIndex': names['nameIndex'],
      'members': members,
    };
    try {
      await _dio.patch<dynamic>('/tagGroups/${op.target}', data: body);
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) return _dropped(op);
      rethrow;
    }
    server
      ..['name'] = body['name']
      ..['members'] = members;
    await Outbox.instance.complete(op);
    return (_Step.done, conflict ? _Effect.sentWithConflict : _Effect.sent);
  }

  /// A group deletion, unless it changed elsewhere since this device last
  /// saw it: the edit wins, it stays.
  Future<(_Step, _Effect)> _deleteGroup(OutboxOp op, _Fresh fresh) async {
    final found = fresh.group(op.target);
    if (found == null) {
      await Outbox.instance.complete(op);
      return (_Step.done, _Effect.none);
    }
    final (category, server) = found;
    final base = op.base;
    if (base != null &&
        (await _plain(base['name']) != await _plain(server['name']) ||
            _setKey(_ids(base['members'])) !=
                _setKey(_ids(server['members'])))) {
      await Outbox.instance.complete(op);
      return (_Step.done, _Effect.kept);
    }

    try {
      await _dio.delete<dynamic>('/tagGroups/${op.target}');
    } on DioException catch (error) {
      if (error.response?.statusCode != 404) rethrow;
    }
    (category['groups'] as List)
        .removeWhere((group) => (group as Map)['id'] == op.target);
    await Outbox.instance.complete(op);
    return (_Step.done, _Effect.sent);
  }

  static Set<int> _ids(Object? list) =>
      {...((list as List?) ?? const []).cast<int>()};

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
      // Saved by the conditional reads themselves, with their ETag.
      await fetchSaved(_dio, '/categories', StoreEntry.categories);
      await fetchSaved(_dio, '/events', StoreEntry.events);
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

enum _Effect { none, sent, sentWithConflict, restored, kept, dropped }

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
