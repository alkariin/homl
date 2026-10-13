import 'package:dio/dio.dart';
import 'package:homl/data/models/usage.dart';
import 'package:homl/data/repositories/api.dart';
import 'package:homl/data/sync/offline_writes.dart';
import 'package:homl/data/sync/outbox.dart';
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

/// Exception thrown when a tag created offline is renamed, moved or deleted
/// before the server has it: only its creation can wait in the outbox.
class TagPendingFailure implements Exception {}

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
      'idCategory': idCategory,
      if (idParentTag != null) 'idParentTag': Outbox.instance.resolve(idParentTag),
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

    if ((body['idParentTag'] as int? ?? 0) < 0 ||
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

  /// The server id of [id], or [TagPendingFailure] for a tag created offline
  /// that the server does not have yet.
  int _onServer(int id) {
    final resolved = Outbox.instance.resolve(id);
    if (resolved < 0) throw TagPendingFailure();
    return resolved;
  }

  /// Full-state update: omitting [idParentTag] detaches the tag from its
  /// parent (it becomes a main tag again).
  Future<void> updateTag(int id, String text, int idCategory,
      {int? idParentTag}) async {
    final target = _onServer(id);
    final parent = idParentTag == null ? null : _onServer(idParentTag);
    try {
      await apiInstance.api.patch<void>('/tags/$target', data: {
        ...await _outgoingTag(text),
        'idCategory': idCategory,
        if (parent != null) 'idParentTag': parent,
      });
    } on DioException catch (err) {
      throw _tagFailure(err);
    }
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
  /// tag deletes its whole synonym group; [deleteEvents] also deletes the
  /// events whose only non-date tags belonged to the group.
  Future<void> deleteTag(int id, {bool deleteEvents = false}) async {
    final target = _onServer(id);
    try {
      await apiInstance.api.delete<void>('/tags/$target', data: {
        'deleteEvents': deleteEvents,
      });
    } on DioException catch (_) {
      throw TagsRequestFailure();
    }
  }

  /// Event counts for the tag's synonym group, for the delete dialog.
  Future<TagUsage> getTagUsage(int id) async {
    final target = _onServer(id);
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
