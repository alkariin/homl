import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:rxdart/rxdart.dart';

import 'package:homl/data/store/local_store.dart';
import 'package:homl/helpers/server_reachability.dart';

/// What an [OutboxOp] does once sent.
enum OpKind { createTag, createEvent, updateEvent, deleteEvent }

/// Why an op is held back until the user decides (see the pending changes
/// sheet). A parked op is never sent and never dropped on its own.
enum ParkReason {
  /// The server refused it (validation, a category gone…).
  refused,

  /// It uses a tag whose own creation could not be sent.
  missingTag,

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

  /// The event or tag the op is about. Negative: created offline, not on the
  /// server yet (replaced by the real id once its creation is sent).
  int target;

  /// The request body: event fields with `tagsId`, or tag fields.
  Map<String, dynamic> body;

  /// For an update or a delete of an event the server already had: the event
  /// as the server last sent it before the first offline change, to tell what
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

  bool get createsSomething =>
      kind == OpKind.createTag || kind == OpKind.createEvent;

  /// Temporary tag ids this op needs on the server first.
  Iterable<int> get tagDependencies =>
      ((body['tagsId'] as List?) ?? const []).cast<int>().where((id) => id < 0);
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

  /// Temporary ids already replaced by server ids: a screen opened on an
  /// event created offline may still hold its temporary id.
  final Map<int, int> _remap = {};

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

  /// The server id an id created offline became, or [id] itself.
  int resolve(int id) => _remap[id] ?? id;

  int _newTempId() => _nextTempId--;

  /// Queues the creation of a tag and returns its temporary id.
  Future<int> createTag(Map<String, dynamic> body,
          {String? keyCheck, String? generation}) =>
      _mutate((ops) {
        final id = _newTempId();
        ops.add(OutboxOp(
            id: newClientId(),
            kind: OpKind.createTag,
            target: id,
            body: body,
            keyCheck: keyCheck,
            generation: generation));
        return id;
      });

  /// Queues the creation of an event and returns its temporary id. [clientId]:
  /// the one a direct attempt already used (its answer may have been lost).
  Future<int> createEvent(Map<String, dynamic> body,
          {String? clientId, String? keyCheck, String? generation}) =>
      _mutate((ops) {
        final id = _newTempId();
        ops.add(OutboxOp(
            id: clientId ?? newClientId(),
            kind: OpKind.createEvent,
            target: id,
            body: body,
            keyCheck: keyCheck,
            generation: generation));
        return id;
      });

  /// Queues a full-state update of event [id]. [base]: the event as the server
  /// last sent it (ignored when an earlier change of this event waits: its
  /// base is the one that counts).
  Future<void> updateEvent(int id, Map<String, dynamic> body,
          {Map<String, dynamic>? base, String? keyCheck, String? generation}) =>
      _mutate((ops) {
        final target = resolve(id);
        for (final op in ops) {
          if (op.target != target || op.id == _sending || op.parked != null) {
            continue;
          }
          if (op.kind == OpKind.createEvent || op.kind == OpKind.updateEvent) {
            // Not sent yet: the creation (or the earlier edit) simply carries
            // the new state.
            op.body = {...op.body, ...body};
            return;
          }
        }
        ops.add(OutboxOp(
            id: newClientId(),
            kind: OpKind.updateEvent,
            target: target,
            body: body,
            base: _earliestBase(ops, target) ?? base,
            keyCheck: keyCheck,
            generation: generation));
      });

  /// Queues the deletion of event [id]. An event created offline and not
  /// sent yet just disappears from the outbox, with its pending edits.
  Future<void> deleteEvent(int id,
          {Map<String, dynamic>? base, String? keyCheck, String? generation}) =>
      _mutate((ops) {
        final target = resolve(id);
        final earliestBase = _earliestBase(ops, target) ?? base;
        final createWaits = ops.any((op) =>
            op.target == target &&
            op.kind == OpKind.createEvent &&
            op.id != _sending);
        // Every waiting change of this event goes: the deletion replaces it.
        ops.removeWhere((op) =>
            op.target == target &&
            op.id != _sending &&
            op.kind != OpKind.createTag);
        if (createWaits) return;
        ops.add(OutboxOp(
            id: newClientId(),
            kind: OpKind.deleteEvent,
            target: target,
            body: const {},
            base: earliestBase,
            keyCheck: keyCheck,
            generation: generation));
      });

  Map<String, dynamic>? _earliestBase(List<OutboxOp> ops, int target) {
    for (final op in ops) {
      if (op.target == target && op.base != null) return op.base;
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
          _rewrite(ops, op.target, serverId);
        }
      });

  /// Points every waiting op at [to] instead of [from] (a creation got its
  /// server id, or an event deleted elsewhere was created again).
  void _rewrite(List<OutboxOp> ops, int from, int to) {
    _remap[from] = to;
    _remap.updateAll((_, value) => value == from ? to : value);
    for (final op in ops) {
      if (op.target == from) op.target = to;
      final tags = op.body['tagsId'];
      if (tags is List && tags.contains(from)) {
        op.body = {
          ...op.body,
          'tagsId': [for (final id in tags) id == from ? to : id],
        };
      }
    }
  }

  /// Holds [op] back for [reason], and with it every waiting op that needs
  /// what it creates.
  Future<void> park(OutboxOp op, ParkReason reason) => _mutate((ops) {
        _sending = null;
        final blocked = <int>{};
        for (final candidate in ops) {
          final dependsOnBlocked = blocked.contains(candidate.target) ||
              candidate.tagDependencies.any(blocked.contains);
          if (candidate.id == op.id) {
            candidate.parked = reason;
            if (candidate.createsSomething) blocked.add(candidate.target);
          } else if (dependsOnBlocked && candidate.parked == null) {
            candidate.parked = candidate.kind == OpKind.createTag ||
                    candidate.tagDependencies.any(blocked.contains)
                ? ParkReason.missingTag
                : reason;
            if (candidate.createsSomething) blocked.add(candidate.target);
          }
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
  /// what it creates.
  Future<void> discard(String opId) => _mutate((ops) {
        final gone = <int>{};
        for (final op in ops) {
          if (op.id == opId && op.createsSomething) gone.add(op.target);
        }
        ops.removeWhere((op) =>
            op.id == opId ||
            gone.contains(op.target) ||
            op.tagDependencies.any(gone.contains));
      });

  /// Drops every waiting change (logout confirmed by the user).
  Future<void> discardAll() => _mutate((ops) => ops.clear());

  /// Forgets the in-memory copy: the session ended, the next account loads
  /// its own (the store keeps or wipes what is persisted).
  void forget() {
    _ops = null;
    _sending = null;
    _remap.clear();
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
