import 'package:dio/dio.dart';
import 'package:homl/data/models/usage.dart';
import 'package:homl/data/repositories/api.dart';
import 'package:homl/data/store/local_store.dart';
import 'package:homl/data/sync/offline_writes.dart';
import 'package:homl/data/sync/outbox.dart';
import 'package:homl/data/sync/projection.dart';
import 'package:homl/data/sync/sync_engine.dart';
import 'package:homl/helpers/e2ee.dart';

/// Exception thrown when a tags request fails
class TagsRequestFailure implements Exception {}

/// Exception thrown when the created tag payload is empty
class TagsNotFoundFailure implements Exception {}

/// Exception thrown when the tag name is reserved for the date tags (E2EE
/// mode mirror of the backend masterdata blacklist).
class TagsBlacklistedFailure implements Exception {}

/// Exception thrown when a write would put two tags of the same name in one
/// category (names are unique per category). Nothing was written.
class TagNameConflictFailure implements Exception {}

class TagsRepository {
  final Api? _injectedApi;
  late final Api apiInstance = _injectedApi ?? Api();

  TagsRepository({Api? api}) : _injectedApi = api;

  /// Returns the id of the created tag. Pass [idParentTag] to create the tag
  /// as a synonym of an existing main tag of the same category. In E2EE mode
  /// the name is encrypted and its blind index sent alongside; [isDateTag]
  /// lifts the blacklist for the client-managed month/year tags.
  ///
  /// When the server is out of reach the creation waits in the outbox and a
  /// temporary (negative) id comes back: events can use it right away.
  Future<int> createTag(String text, int idCategory,
      {int? idParentTag, bool isDateTag = false}) async {
    final body = {
      ...await _outgoingTag(text, isDateTag: isDateTag),
      'idCategory': Outbox.instance.resolve(idCategory),
      if (idParentTag != null)
        'idParentTag': Outbox.instance.resolve(idParentTag),
    };

    Future<int> queue() async {
      final int id;
      try {
        final stamps = await writeStamps();
        id = await Outbox.instance.createTag(body,
            keyCheck: stamps.keyCheck, generation: stamps.generation);
      } catch (_) {
        throw TagsRequestFailure();
      }
      SyncEngine.instance.kick();
      return id;
    }

    // A category or a main tag created offline: the server does not have it
    // yet, the tag waits behind it.
    if ((body['idCategory'] as int) < 0 ||
        (body['idParentTag'] as int? ?? 0) < 0 ||
        await Outbox.instance.shouldQueue()) {
      return queue();
    }

    late Response<Map<String, dynamic>> response;
    try {
      response =
          await apiInstance.api.post<Map<String, dynamic>>('/tags', data: body);

      if (response.data == null) {
        throw TagsNotFoundFailure();
      }
    } on DioException catch (err) {
      if (Api.isUnreachable(err)) return queue();
      throw _tagFailure(err);
    }

    return response.data!['id'] as int;
  }

  /// Saves a change in the outbox and lets the engine try to send it.
  Future<WriteOutcome> _queue(
      Future<void> Function(({String? keyCheck, String? generation}) stamps)
          enqueue) async {
    try {
      await enqueue(await writeStamps());
    } catch (_) {
      // Not even saved on the device: the write failed.
      throw TagsRequestFailure();
    }
    SyncEngine.instance.kick();
    return WriteOutcome.queued;
  }

  /// Full-state update: a null [idParentTag] detaches the tag from its
  /// parent (it becomes a main tag again). Waits in the outbox when the
  /// server is out of reach, or when it needs something created offline.
  Future<WriteOutcome> updateTag(int id, String text, int idCategory,
      {int? idParentTag}) async {
    final target = Outbox.instance.resolve(id);
    final body = {
      ...await _outgoingTag(text),
      'idCategory': Outbox.instance.resolve(idCategory),
      // Explicit, even null: the outbox folds edits by merging bodies, and
      // a missing key would keep the main tag of an earlier state.
      'idParentTag':
          idParentTag == null ? null : Outbox.instance.resolve(idParentTag),
    };

    Future<WriteOutcome> queue() async {
      final base = target > 0 ? await serverTag(target) : null;
      return _queue((stamps) => Outbox.instance.updateTag(target, body,
          base: base,
          keyCheck: stamps.keyCheck,
          generation: stamps.generation));
    }

    if (target < 0 ||
        (body['idCategory'] as int) < 0 ||
        ((body['idParentTag'] as int?) ?? 0) < 0 ||
        await Outbox.instance.shouldQueue()) {
      return queue();
    }

    try {
      await apiInstance.api.patch<void>('/tags/$target', data: {
        for (final entry in body.entries)
          if (entry.value != null) entry.key: entry.value,
      });
    } on DioException catch (err) {
      if (Api.isUnreachable(err)) return queue();
      throw _tagFailure(err);
    }
    return WriteOutcome.sent;
  }

  /// Tells a taken tag name apart from any other failure. Keyed off the
  /// machine-readable code, never the message string.
  Exception _tagFailure(DioException err) {
    if (err.response?.data?['error']?['code'] == 'TAG_NAME_CONFLICT') {
      return TagNameConflictFailure();
    }
    return TagsRequestFailure();
  }

  /// Builds the tag fields of a write payload. Plaintext name as-is for
  /// regular users; encrypted name + blind index for E2EE users, with the
  /// blacklist enforced client-side (the server cannot read the name).
  Future<Map<String, dynamic>> _outgoingTag(String text,
      {bool isDateTag = false}) async {
    final e2ee = E2ee();
    if (!e2ee.enabled) return {'tag': text};

    if (!isDateTag && e2ee.isBlacklistedTag(text)) {
      throw TagsBlacklistedFailure();
    }

    return {
      'tag': await e2ee.encrypt(text),
      'tagIndex': await e2ee.tagIndex(text),
    };
  }

  /// Deleting a synonym repoints its events to the main tag. Deleting a main
  /// tag deletes its whole synonym group; [deleteEvents] also deletes every
  /// event tagged with the group.
  ///
  /// When it has to wait in the outbox, a deletion with [deleteEvents] is
  /// refused with [DeleteEventsOfflineFailure] before anything is queued:
  /// the caller deletes the events it knows, then the tag alone.
  Future<WriteOutcome> deleteTag(int id, {bool deleteEvents = false}) async {
    final target = Outbox.instance.resolve(id);

    Future<WriteOutcome> queue() async {
      if (deleteEvents) throw DeleteEventsOfflineFailure();
      final base = target > 0 ? await serverTag(target) : null;
      // The main tag the screens hand a deleted synonym's events to.
      final parent = (await _shownTag(target))?['idParentTag'];
      return _queue((stamps) => Outbox.instance.deleteTag(
          target, {'idParentTag': parent},
          base: base,
          keyCheck: stamps.keyCheck,
          generation: stamps.generation));
    }

    if (target < 0 || await Outbox.instance.shouldQueue()) return queue();

    try {
      await apiInstance.api.delete<void>('/tags/$target', data: {
        'deleteEvents': deleteEvents,
      });
    } on DioException catch (err) {
      if (Api.isUnreachable(err)) return queue();
      throw TagsRequestFailure();
    }
    return WriteOutcome.sent;
  }

  /// Tag [id] as the screens show it: the saved categories with the waiting
  /// changes applied.
  Future<Map<String, dynamic>?> _shownTag(int id) async {
    final stored = await LocalStore.instance.load(StoreEntry.categories);
    final payload = stored?.payload;
    final categories = projectCategories(
        payload is List ? payload : const [], await Outbox.instance.ops());
    for (final category in categories) {
      for (final tag in category['tags'] as List) {
        if ((tag as Map)['id'] == id) return Map<String, dynamic>.from(tag);
      }
    }
    return null;
  }

  /// Event counts for the tag's synonym group, for the delete dialog. Only
  /// for a tag the server has: offline, the counts come from the events on
  /// the device (HomeCubit.fetchTagUsage).
  Future<TagUsage> getTagUsage(int id) async {
    final target = Outbox.instance.resolve(id);
    if (target < 0) throw TagsRequestFailure();
    try {
      final response = await apiInstance.api
          .get<Map<String, dynamic>>('/tags/$target/usage');
      if (response.data == null) {
        throw TagsNotFoundFailure();
      }
      return TagUsage.fromJson(response.data!);
    } on DioException catch (_) {
      throw TagsRequestFailure();
    }
  }
}
