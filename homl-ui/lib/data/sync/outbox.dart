import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:rxdart/rxdart.dart';

import 'package:homl/data/store/local_store.dart';
import 'package:homl/helpers/server_reachability.dart';

/// What an [OutboxOp] does once sent.
enum OpKind {
  createTag,
  createEvent,
  updateEvent,
  deleteEvent,
  updateTag,
  deleteTag,
  createCategory,
  updateCategory,
  deleteCategory,
  createGroup,
  updateGroup,
  deleteGroup,
}

/// What an op is about. A server id only names one thing within one of
/// these (an event and a tag may both be number 12); the temporary ids are
/// unique across all of them, drawn from one counter.
enum OpEntity { event, tag, category, group }

extension OpKindTraits on OpKind {
  OpEntity get entity => switch (this) {
        OpKind.createEvent ||
        OpKind.updateEvent ||
        OpKind.deleteEvent =>
          OpEntity.event,
        OpKind.createTag ||
        OpKind.updateTag ||
        OpKind.deleteTag =>
          OpEntity.tag,
        OpKind.createCategory ||
        OpKind.updateCategory ||
        OpKind.deleteCategory =>
          OpEntity.category,
        OpKind.createGroup ||
        OpKind.updateGroup ||
        OpKind.deleteGroup =>
          OpEntity.group,
      };

  bool get isCreate =>
      this == OpKind.createEvent ||
      this == OpKind.createTag ||
      this == OpKind.createCategory ||
      this == OpKind.createGroup;

  bool get isUpdate =>
      this == OpKind.updateEvent ||
      this == OpKind.updateTag ||
      this == OpKind.updateCategory ||
      this == OpKind.updateGroup;
}

/// Why an op is held back until the user decides (see the pending changes
/// sheet). A parked op is never sent and never dropped on its own.
enum ParkReason {
  /// The server refused it (validation, a category gone…).
  refused,

  /// It uses a tag whose own creation could not be sent.
  missingTag,

  /// It needs a category or a tag group whose own creation could not be
  /// sent.
  missingParent,

  /// The account's end-to-end encryption changed since the op was written:
  /// its payload is encoded for the old state.
  encryptionChanged,

  /// The server data was replaced wholesale (restored from a backup,
  /// purged): the ids the op points at may no longer mean the same rows.
  dataReplaced,
}

/// One change made while the server was out of reach, in the wire format of
/// its request (encrypted at enqueue for an E2EE account, like any write).
class OutboxOp {
  /// Unique; doubles as the `clientId` of an event creation, so a replay after
  /// a lost answer cannot create the event twice.
  final String id;
  final OpKind kind;

  /// The event, tag, category or group the op is about ([OpKindTraits.entity]
  /// says which). Negative: created offline, not on the server yet (replaced
  /// by the real id once its creation is sent).
  int target;

  /// The request body: event fields with `tagsId`, tag fields, category
  /// fields, or group fields with `members`. A deletion keeps there what the
  /// screens need to show it (the parent of a deleted synonym, whether a
  /// category's tags move to Others); the engine builds its request itself.
  Map<String, dynamic> body;

  /// For an update or a delete of something the server already had: it as
  /// the server last sent it before the first offline change, to tell what
  /// changed on this device from what changed elsewhere.
  final Map<String, dynamic>? base;

  /// The account's encryption when the op was written: the E2EE key check,
  /// or null for a plain account.
  final String? keyCheck;

  /// The server data generation the op was written against.
  final String? generation;

  ParkReason? parked;

  OutboxOp({
    required this.id,
    required this.kind,
    required this.target,
    required this.body,
    this.base,
    this.keyCheck,
    this.generation,
    this.parked,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'target': target,
        'body': body,
        if (base != null) 'base': base,
        if (keyCheck != null) 'keyCheck': keyCheck,
        if (generation != null) 'generation': generation,
        if (parked != null) 'parked': parked!.name,
      };

  factory OutboxOp.fromJson(Map<String, dynamic> json) => OutboxOp(
        id: json['id'] as String,
        kind: OpKind.values.byName(json['kind'] as String),
        target: json['target'] as int,
        body: Map<String, dynamic>.from(json['body'] as Map),
        base: json['base'] == null
            ? null
            : Map<String, dynamic>.from(json['base'] as Map),
        keyCheck: json['keyCheck'] as String?,
        generation: json['generation'] as String?,
        parked: json['parked'] == null
            ? null
            : ParkReason.values.byName(json['parked'] as String),
      );

  bool get createsSomething => kind.isCreate;

  /// Temporary tag ids this op needs on the server first: the tags of an
  /// event, the members of a group, the main tag of a synonym.
  Iterable<int> get tagDependencies sync* {
    for (final key in const ['tagsId', 'members']) {
      for (final id in ((body[key] as List?) ?? const []).cast<int>()) {
        if (id < 0) yield id;
      }
    }
    final parent = body['idParentTag'];
    if (parent is int && parent < 0) yield parent;
  }

  /// Every temporary id this op needs on the server first: its tags, its
  /// category, and what it changes when that was created offline.
  Iterable<int> get dependencies sync* {
    if (!kind.isCreate && target < 0) yield target;
    yield* tagDependencies;
    final category = body['idCategory'];
    if (category is int && category < 0) yield category;
  }
}

/// How many changes wait, and how many of them are parked.
class OutboxCounts {
  final int pending;
  final int parked;

  const OutboxCounts(this.pending, this.parked);

  int get total => pending + parked;
}

/// The changes made offline, kept in order until the server has them
/// (homl-web/docs/offline-sync.md). Persisted in the [LocalStore] after every
/// change, strictly: a write that cannot be persisted fails instead of being
/// lost later.
///
/// Changes to the same thing are folded together while they wait: editing an
/// event created offline rewrites its creation, deleting it drops it, two
/// edits of one event make one. An op being sent ([nextToSend]) is never
/// rewritten — a later change becomes an op of its own.
class Outbox {
  Outbox();

  static Outbox instance = Outbox();

  List<OutboxOp>? _ops;
  int _nextTempId = -2;

  /// Temporary ids already replaced by server ids: a screen opened on
  /// something created offline may still hold its temporary id.
  final Map<int, int> _remap = {};

  /// Events deleted elsewhere and created again by an edit made here: the
  /// old server id points at the new one. Kept apart from [_remap] because a
  /// server id only names an event among events.
  final Map<int, int> _eventRemap = {};

  String? _sending;
  Future<void> _tail = Future.value();

  final BehaviorSubject<OutboxCounts> _counts =
      BehaviorSubject.seeded(const OutboxCounts(0, 0));

  /// The counts, for the badge of the app bar.
  Stream<OutboxCounts> get counts => _counts.stream;
  OutboxCounts get currentCounts => _counts.value;

  Future<T> _locked<T>(Future<T> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.then((_) {}, onError: (_) {});
    return result;
  }

  Future<List<OutboxOp>> _load() async {
    final loaded = _ops;
    if (loaded != null) return loaded;
    final stored =
        await LocalStore.instance.load(StoreEntry.outbox, strict: true);
    final json = stored?.payload as Map<String, dynamic>?;
    final ops = ((json?['ops'] as List?) ?? const [])
        .map((op) => OutboxOp.fromJson(Map<String, dynamic>.from(op as Map)))
        .toList();
    _nextTempId = (json?['nextTempId'] as int?) ?? -2;
    _ops = ops;
    _publish();
    return ops;
  }

  /// Version of the persisted shape. An app update that changes the shape
  /// of an op must upgrade what an older version left waiting, never drop it
  /// (homl-web/docs/offline-sync.md).
  static const _formatVersion = 1;

  Future<void> _persist() async {
    await LocalStore.instance.save(
        StoreEntry.outbox,
        {
          'v': _formatVersion,
          'ops': [for (final op in _ops!) op.toJson()],
          'nextTempId': _nextTempId,
        },
        strict: true);
    _publish();
  }

  void _publish() {
    final ops = _ops ?? const [];
    final parked = ops.where((op) => op.parked != null).length;
    _counts.add(OutboxCounts(ops.length - parked, parked));
  }

  /// Runs [change] on the ops and persists the result; on a storage failure
  /// the in-memory state is reloaded from the store, which still holds the
  /// last state that was persisted.
  Future<T> _mutate<T>(T Function(List<OutboxOp> ops) change) =>
      _locked(() async {
        final ops = await _load();
        final result = change(ops);
        try {
          await _persist();
        } catch (_) {
          _ops = null;
          rethrow;
        }
        return result;
      });

  /// Copies of the ops, in order.
  Future<List<OutboxOp>> ops() => _locked(() async =>
      [for (final op in await _load()) OutboxOp.fromJson(op.toJson())]);

  /// Whether a write must go through the outbox rather than straight to the
  /// server: the server is out of reach, or earlier changes still wait (a
  /// direct write could overtake them). Parked ops do not hold writes back.
  Future<bool> shouldQueue() async {
    if (ServerReachability.instance.isOffline) return true;
    try {
      return await _locked(
          () async => (await _load()).any((op) => op.parked == null));
    } catch (_) {
      // Unreadable right now: nothing can be queued anyway, go direct.
      return false;
    }
  }

  /// The server id a tag, category or group created offline became, or [id]
  /// itself. Not for events: see [resolveEvent].
  int resolve(int id) => id < 0 ? (_remap[id] ?? id) : id;

  /// The server id of event [id]: the one its offline creation got, or the
  /// one it was created again under after a deletion elsewhere.
  int resolveEvent(int id) =>
      id < 0 ? (_remap[id] ?? id) : (_eventRemap[id] ?? id);

  int _newTempId() => _nextTempId--;

  /// Queues a creation and returns its temporary id. [clientId]: the one a
  /// direct attempt already used (its answer may have been lost).
  Future<int> _create(OpKind kind, Map<String, dynamic> body,
          {String? clientId, String? keyCheck, String? generation}) =>
      _mutate((ops) {
        final id = _newTempId();
        _add(
            ops,
            OutboxOp(
                id: clientId ?? newClientId(),
                kind: kind,
                target: id,
                body: body,
                keyCheck: keyCheck,
                generation: generation));
        return id;
      });

  /// Adds [op], parked from the start when something it needs is held back
  /// already: sent, it could only fail.
  void _add(List<OutboxOp> ops, OutboxOp op) {
    final blocked = <int, ParkReason>{
      for (final other in ops)
        if (other.parked != null && other.kind.isCreate)
          other.target: other.parked!,
    };
    op.parked = _blockedReason(op, blocked);
    ops.add(op);
  }

  /// Why [op] cannot go while the creations in [blocked] are held back:
  /// the reason of what it changes, a missing tag, or a missing category or
  /// group. Null when it needs none of them.
  ParkReason? _blockedReason(OutboxOp op, Map<int, ParkReason> blocked) {
    if (!op.kind.isCreate && blocked.containsKey(op.target)) {
      return blocked[op.target];
    }
    if (op.tagDependencies.any(blocked.containsKey)) {
      return ParkReason.missingTag;
    }
    if (op.dependencies.any(blocked.containsKey)) {
      return ParkReason.missingParent;
    }
    return null;
  }

  /// Queues the creation of a tag and returns its temporary id.
  Future<int> createTag(Map<String, dynamic> body,
          {String? keyCheck, String? generation}) =>
      _create(OpKind.createTag, body,
          keyCheck: keyCheck, generation: generation);

  /// Queues the creation of an event and returns its temporary id. [clientId]:
  /// the one a direct attempt already used (its answer may have been lost).
  Future<int> createEvent(Map<String, dynamic> body,
          {String? clientId, String? keyCheck, String? generation}) =>
      _create(OpKind.createEvent, body,
          clientId: clientId, keyCheck: keyCheck, generation: generation);

  /// Queues the creation of a category and returns its temporary id. The op
  /// id is its `clientId`, so a replay after a lost answer finds the first
  /// one.
  Future<int> createCategory(Map<String, dynamic> body,
          {String? clientId, String? keyCheck, String? generation}) =>
      _create(OpKind.createCategory, body,
          clientId: clientId, keyCheck: keyCheck, generation: generation);

  /// Queues the creation of a tag group and returns its temporary id.
  Future<int> createGroup(Map<String, dynamic> body,
          {String? keyCheck, String? generation}) =>
      _create(OpKind.createGroup, body,
          keyCheck: keyCheck, generation: generation);

  /// Queues a full-state update of [id]. [base]: it as the server last sent
  /// it (ignored when an earlier change of it waits: its base is the one
  /// that counts).
  Future<void> _update(OpKind kind, int id, Map<String, dynamic> body,
          {Map<String, dynamic>? base, String? keyCheck, String? generation}) =>
      _mutate((ops) {
        final entity = kind.entity;
        final target =
            entity == OpEntity.event ? resolveEvent(id) : resolve(id);
        for (final op in ops) {
          if (op.kind.entity != entity ||
              op.target != target ||
              op.id == _sending ||
              op.parked != null) {
            continue;
          }
          if (op.kind.isCreate || op.kind.isUpdate) {
            // Not sent yet: the creation (or the earlier edit) simply carries
            // the new state.
            op.body = {...op.body, ...body};
            return;
          }
        }
        _add(
            ops,
            OutboxOp(
                id: newClientId(),
                kind: kind,
                target: target,
                body: body,
                base: _earliestBase(ops, target, entity) ?? base,
                keyCheck: keyCheck,
                generation: generation));
      });

  /// Queues a full-state update of event [id].
  Future<void> updateEvent(int id, Map<String, dynamic> body,
          {Map<String, dynamic>? base, String? keyCheck, String? generation}) =>
      _update(OpKind.updateEvent, id, body,
          base: base, keyCheck: keyCheck, generation: generation);

  /// Queues a full-state update of tag [id]: name, category and main tag,
  /// `idParentTag` null for a main tag.
  Future<void> updateTag(int id, Map<String, dynamic> body,
          {Map<String, dynamic>? base, String? keyCheck, String? generation}) =>
      _update(OpKind.updateTag, id, body,
          base: base, keyCheck: keyCheck, generation: generation);

  /// Queues a full-state update of category [id]: its name and color.
  Future<void> updateCategory(int id, Map<String, dynamic> body,
          {Map<String, dynamic>? base, String? keyCheck, String? generation}) =>
      _update(OpKind.updateCategory, id, body,
          base: base, keyCheck: keyCheck, generation: generation);

  /// Queues a full-state update of tag group [id]: its name and members.
  Future<void> updateGroup(int id, Map<String, dynamic> body,
          {Map<String, dynamic>? base, String? keyCheck, String? generation}) =>
      _update(OpKind.updateGroup, id, body,
          base: base, keyCheck: keyCheck, generation: generation);

  /// Queues the deletion of event [id]. An event created offline and not
  /// sent yet just disappears from the outbox, with its pending edits.
  Future<void> deleteEvent(int id,
          {Map<String, dynamic>? base, String? keyCheck, String? generation}) =>
      _mutate((ops) {
        final target = resolveEvent(id);
        final earliestBase = _earliestBase(ops, target, OpEntity.event) ?? base;
        bool isThisEvent(OutboxOp op) =>
            op.kind.entity == OpEntity.event &&
            op.target == target &&
            op.id != _sending;
        final createWaits =
            ops.any((op) => isThisEvent(op) && op.kind == OpKind.createEvent);
        // Every waiting change of this event goes: the deletion replaces it.
        ops.removeWhere(isThisEvent);
        if (createWaits) return;
        _add(
            ops,
            OutboxOp(
                id: newClientId(),
                kind: OpKind.deleteEvent,
                target: target,
                body: const {},
                base: earliestBase,
                keyCheck: keyCheck,
                generation: generation));
      });

  /// Queues the deletion of a tag, category or group. Its waiting edits go:
  /// the deletion replaces them. One created offline is still created first,
  /// then deleted: what was made with it meanwhile (tags in a category,
  /// events using a tag) gets the server's treatment of the deletion.
  Future<void> _delete(OpKind kind, int id, Map<String, dynamic> body,
          {Map<String, dynamic>? base, String? keyCheck, String? generation}) =>
      _mutate((ops) {
        final entity = kind.entity;
        final target = resolve(id);
        final earliestBase = _earliestBase(ops, target, entity) ?? base;
        ops.removeWhere((op) =>
            op.kind.entity == entity &&
            op.kind.isUpdate &&
            op.target == target &&
            op.id != _sending &&
            op.parked == null);
        _add(
            ops,
            OutboxOp(
                id: newClientId(),
                kind: kind,
                target: target,
                body: body,
                base: earliestBase,
                keyCheck: keyCheck,
                generation: generation));
      });

  /// Queues the deletion of tag [id], which keeps its events (a deletion
  /// with the events is split by the caller: see DeleteEventsOfflineFailure).
  /// [body] carries `idParentTag`: a deleted synonym hands its events to it.
  Future<void> deleteTag(int id, Map<String, dynamic> body,
          {Map<String, dynamic>? base, String? keyCheck, String? generation}) =>
      _delete(OpKind.deleteTag, id, body,
          base: base, keyCheck: keyCheck, generation: generation);

  /// Queues the deletion of category [id]; [body] carries `moveTags`.
  Future<void> deleteCategory(int id, Map<String, dynamic> body,
          {Map<String, dynamic>? base, String? keyCheck, String? generation}) =>
      _delete(OpKind.deleteCategory, id, body,
          base: base, keyCheck: keyCheck, generation: generation);

  /// Queues the deletion of tag group [id] (its tags and their events stay).
  Future<void> deleteGroup(int id,
          {Map<String, dynamic>? base, String? keyCheck, String? generation}) =>
      _delete(OpKind.deleteGroup, id, const {},
          base: base, keyCheck: keyCheck, generation: generation);

  Map<String, dynamic>? _earliestBase(
      List<OutboxOp> ops, int target, OpEntity entity) {
    for (final op in ops) {
      if (op.kind.entity == entity && op.target == target && op.base != null) {
        return op.base;
      }
    }
    return null;
  }

  /// The next op to send, in order, skipping the parked ones (whatever
  /// depends on a parked op is parked with it, so what is left can go). It
  /// is marked as being sent in the same step: from then on, later changes of
  /// the same thing no longer fold into it. Null when none.
  Future<OutboxOp?> nextToSend() => _locked(() async {
        final ops = await _load();
        for (final op in ops) {
          if (op.parked != null) continue;
          _sending = op.id;
          return OutboxOp.fromJson(op.toJson());
        }
        return null;
      });

  /// [op] reached the server (or needs no sending any more). [serverId]: the
  /// id a creation got — every waiting op pointing at the temporary id is
  /// rewritten, and the mapping kept for the screens still holding it.
  Future<void> complete(OutboxOp op, {int? serverId}) => _mutate((ops) {
        _sending = null;
        ops.removeWhere((candidate) => candidate.id == op.id);
        if (serverId != null && op.target != serverId) {
          _rewrite(ops, op.target, serverId, op.kind.entity);
        }
      });

  /// Points every waiting op at [to] instead of [from]: a creation got its
  /// server id (a temporary id, unique, rewritten wherever it is used), or
  /// an event deleted elsewhere was created again (a server id, rewritten in
  /// the event ops only).
  void _rewrite(List<OutboxOp> ops, int from, int to, OpEntity entity) {
    if (from < 0) {
      _remap[from] = to;
    } else {
      _eventRemap[from] = to;
      _eventRemap.updateAll((_, value) => value == from ? to : value);
    }
    for (final op in ops) {
      if (op.target == from && (from < 0 || op.kind.entity == entity)) {
        op.target = to;
      }
      if (from < 0) op.body = _rewriteBody(op.body, from, to);
    }
  }

  /// [body] with the temporary id [from] replaced by [to] wherever it is
  /// used: the tags of an event, the members of a group, the main tag of a
  /// synonym, the category of a tag or a group.
  static Map<String, dynamic> _rewriteBody(
      Map<String, dynamic> body, int from, int to) {
    var result = body;
    for (final key in const ['tagsId', 'members']) {
      final ids = result[key];
      if (ids is List && ids.contains(from)) {
        result = {
          ...result,
          key: [for (final id in ids) id == from ? to : id],
        };
      }
    }
    for (final key in const ['idParentTag', 'idCategory']) {
      if (result[key] == from) result = {...result, key: to};
    }
    return result;
  }

  /// Holds [op] back for [reason], and with it every waiting op that needs
  /// what it creates (a change of it keeps its reason; something using a
  /// tag it creates is a missing tag, anything else a missing parent).
  Future<void> park(OutboxOp op, ParkReason reason) => _mutate((ops) {
        _sending = null;
        final blocked = <int, ParkReason>{};
        for (final candidate in ops) {
          ParkReason? why;
          if (candidate.id == op.id) {
            why = reason;
          } else if (candidate.parked == null) {
            why = _blockedReason(candidate, blocked);
          }
          if (why == null) continue;
          candidate.parked = why;
          if (candidate.kind.isCreate) blocked[candidate.target] = why;
        }
      });

  /// Parks every waiting op for [reason] (the encryption or the data changed
  /// under all of them).
  Future<void> parkAll(ParkReason reason) => _mutate((ops) {
        _sending = null;
        for (final op in ops) {
          op.parked ??= reason;
        }
      });

  /// The engine stopped mid-way (the server went away): nothing changes, the
  /// op is sent again next time.
  void abortSend() => _sending = null;

  /// Gives parked ops another chance (the user asked to send again).
  Future<void> retryParked() => _mutate((ops) {
        for (final op in ops) {
          op.parked = null;
        }
      });

  /// Drops [opId] for good (the user discarded it), with the ops that need
  /// what it creates — and, in turn, what needs theirs.
  Future<void> discard(String opId) => _mutate((ops) {
        final gone = <int>{};
        final kept = <OutboxOp>[];
        // In order: what an op needs was queued before it.
        for (final op in ops) {
          if (op.id == opId || op.dependencies.any(gone.contains)) {
            if (op.kind.isCreate) gone.add(op.target);
          } else {
            kept.add(op);
          }
        }
        ops
          ..clear()
          ..addAll(kept);
      });

  /// Drops every waiting change (logout confirmed by the user).
  Future<void> discardAll() => _mutate((ops) => ops.clear());

  /// Forgets the in-memory copy: the session ended, the next account loads
  /// its own (the store keeps or wipes what is persisted).
  void forget() {
    _ops = null;
    _sending = null;
    _remap.clear();
    _eventRemap.clear();
    _nextTempId = -2;
    _counts.add(const OutboxCounts(0, 0));
  }

  /// Loads the persisted outbox (at app start, for the badge).
  Future<void> warmUp() => _locked(() async {
        try {
          await _load();
        } catch (_) {
          // Reported on the first write instead.
        }
      });

  @visibleForTesting
  static void resetForTesting() => instance = Outbox();
}

/// A random RFC 4122 version 4 UUID: the `clientId` of an event creation.
String newClientId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
