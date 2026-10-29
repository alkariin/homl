import 'package:dio/dio.dart';
import 'package:homl/data/models/category.dart';
import 'package:homl/data/models/tag.dart';
import 'package:homl/data/models/tag_group.dart';
import 'package:homl/data/models/usage.dart';
import 'package:homl/data/repositories/api.dart';
import 'package:homl/data/repositories/tags.repository.dart';
import 'package:homl/data/store/conditional_get.dart';
import 'package:homl/data/store/local_store.dart';
import 'package:homl/data/sync/offline_writes.dart';
import 'package:homl/data/sync/outbox.dart';
import 'package:homl/data/sync/projection.dart';
import 'package:homl/data/sync/sync_engine.dart';
import 'package:homl/helpers/e2ee.dart';
import 'package:homl/helpers/event_search.dart' show normalizeTagName;

/// Exception thrown when a categories request fails
class CategoriesRequestFailure implements Exception {}

/// Exception thrown when the categories payload is empty
class CategoriesNotFoundFailure implements Exception {}

/// Exception thrown when moving a category's tags to Others is refused
/// because one of the names is already taken there (tag names are unique per
/// category). The other two delete options remain available.
class CategoryTagNameConflictFailure implements Exception {}

/// Exception thrown when another tag group of the category already has the
/// name (group names are unique per category). Nothing was written.
class TagGroupNameConflictFailure implements Exception {}

class CategoriesRepository {
  final Api? _injectedApi;
  late final Api apiInstance = _injectedApi ?? Api();

  CategoriesRepository({Api? api}) : _injectedApi = api;

  /// Returns the user's categories with their tags. Each successful payload
  /// is saved in the local store (sealed on the device) so the app keeps
  /// working offline: when the request fails, the saved copy is returned
  /// instead when there is one — unless [cacheFallback] is false, for a
  /// caller that must compare against the server itself (the import).
  ///
  /// The request is conditional (data/store/conditional_get.dart): when
  /// nothing changed since the saved copy, the server answers with no body
  /// and the saved copy is used.
  Future<List<Category>> getCategories({bool cacheFallback = true}) async {
    late List<dynamic> payload;
    try {
      // The store gets the payload BEFORE decryption on purpose: for E2EE
      // users it must only ever hold ciphertext (homl-web/docs/e2ee.md).
      payload = await fetchSaved(
          apiInstance.api, '/categories', StoreEntry.categories);
    } on DioException catch (_) {
      final cached = cacheFallback ? await getCachedCategories() : null;
      if (cached != null) {
        return cached;
      }
      throw CategoriesRequestFailure();
    }

    return _decryptCategories(await _project(payload));
  }

  /// The server payload with the category, tag and group changes made
  /// offline applied.
  Future<List<Category>> _project(List<dynamic> payload) async {
    List<OutboxOp> ops;
    try {
      ops = await Outbox.instance.ops();
    } catch (_) {
      ops = const [];
    }
    final projected = ops.isEmpty ? payload : projectCategories(payload, ops);
    return projected
        .map((e) => Category.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Decrypts E2EE payloads at the repository boundary, so every model
  /// handed to the app (and the local tag search) carries plaintext.
  Future<List<Category>> _decryptCategories(List<Category> categories) async {
    final e2ee = E2ee();
    if (!e2ee.enabled) return categories;

    return Future.wait(categories.map((category) async => Category(
          id: category.id,
          category: await e2ee.decrypt(category.category),
          color: category.color,
          isLocked: category.isLocked,
          kind: category.kind,
          tags: await Future.wait(category.tags.map((tag) async => Tag(
                id: tag.id,
                tag: await e2ee.decrypt(tag.tag),
                idCategory: tag.idCategory,
                idParentTag: tag.idParentTag,
              ))),
          groups: await Future.wait(category.groups.map((group) async =>
              TagGroup(
                  id: group.id,
                  name: await e2ee.decrypt(group.name),
                  members: group.members))),
        )));
  }

  /// Returns the last categories payload fetched from the backend, or null
  /// when nothing usable was saved yet.
  Future<List<Category>?> getCachedCategories() async {
    final stored = await LocalStore.instance.load(StoreEntry.categories);
    if (stored == null) {
      return null;
    }

    try {
      return await _decryptCategories(
          await _project(stored.payload as List<dynamic>));
    } catch (_) {
      // A payload that no longer parses (model change) is just dropped.
      await LocalStore.instance.remove(StoreEntry.categories);
      return null;
    }
  }

  /// Saves a change in the outbox and lets the engine try to send it.
  Future<WriteOutcome> _queue(
      Future<void> Function(({String? keyCheck, String? generation}) stamps)
          enqueue) async {
    try {
      await enqueue(await writeStamps());
    } catch (_) {
      // Not even saved on the device: the write failed.
      throw CategoriesRequestFailure();
    }
    SyncEngine.instance.kick();
    return WriteOutcome.queued;
  }

  /// Returns the id of the created category: a temporary (negative) one
  /// when it waits in the outbox, the server out of reach. Tags and groups
  /// can be created in it right away.
  Future<int> createCategory(String category, String color) async {
    final body = {
      'category': await _outgoingName(category),
      'color': color,
    };
    // Sent with the id the outbox would replay it under: an answer lost on
    // the way back must not end up as two categories (names are not unique).
    final clientId = newClientId();

    Future<int> queue() async {
      late int id;
      await _queue((stamps) async => id = await Outbox.instance.createCategory(
          body,
          clientId: clientId,
          keyCheck: stamps.keyCheck,
          generation: stamps.generation));
      return id;
    }

    if (await Outbox.instance.shouldQueue()) return queue();

    late Response<Map<String, dynamic>> response;
    try {
      response = await apiInstance.api.post<Map<String, dynamic>>('/categories',
          data: {...body, 'clientId': clientId});
    } on DioException catch (err) {
      if (Api.isUnreachable(err)) return queue();
      throw CategoriesRequestFailure();
    }

    final id = response.data?['id'];
    if (id is! int) throw CategoriesNotFoundFailure();
    return id;
  }

  Future<WriteOutcome> updateCategory(
      int id, String category, String color) async {
    final target = Outbox.instance.resolve(id);
    final body = {
      'category': await _outgoingName(category),
      'color': color,
    };

    Future<WriteOutcome> queue() async {
      final base = target > 0 ? await serverCategory(target) : null;
      return _queue((stamps) => Outbox.instance.updateCategory(target, body,
          base: base,
          keyCheck: stamps.keyCheck,
          generation: stamps.generation));
    }

    if (target < 0 || await Outbox.instance.shouldQueue()) return queue();

    try {
      await apiInstance.api.patch<void>('/categories/$target', data: body);
    } on DioException catch (err) {
      if (Api.isUnreachable(err)) return queue();
      throw CategoriesRequestFailure();
    }
    return WriteOutcome.sent;
  }

  /// The name of a category write, in the canonical form of the tag names
  /// ("my TRIPS" → "My Trips", see [normalizeTagName]), on a create and on a
  /// rename: the backend title-cases a plaintext name itself, but an E2EE
  /// one is a blob to it, and a write waiting in the outbox shows the name
  /// as sent. Encrypted for E2EE users.
  Future<String> _outgoingName(String category) async {
    final name = normalizeTagName(category);
    if (!E2ee().enabled) return name;
    return E2ee().encrypt(name);
  }

  /// [moveTags] moves the tags to the Other category; otherwise the tags are
  /// deleted and [deleteEvents] also deletes every event tagged with one of
  /// them.
  ///
  /// When it has to wait in the outbox, a deletion with [deleteEvents] is
  /// refused with [DeleteEventsOfflineFailure] before anything is queued:
  /// the caller deletes the events it knows, then the category alone.
  Future<WriteOutcome> deleteCategory(int id,
      {bool moveTags = false, bool deleteEvents = false}) async {
    final target = Outbox.instance.resolve(id);

    Future<WriteOutcome> queue() async {
      if (deleteEvents && !moveTags) throw DeleteEventsOfflineFailure();
      final base = target > 0 ? await serverCategory(target) : null;
      return _queue((stamps) => Outbox.instance.deleteCategory(
          target, {'moveTags': moveTags},
          base: base,
          keyCheck: stamps.keyCheck,
          generation: stamps.generation));
    }

    if (target < 0 || await Outbox.instance.shouldQueue()) return queue();

    try {
      await apiInstance.api.delete<void>('/categories/$target', data: {
        'moveTags': moveTags,
        'deleteEvents': deleteEvents,
      });
    } on DioException catch (err) {
      if (Api.isUnreachable(err)) return queue();
      // Keyed off the code, never the message string: the backend refuses a
      // move whose tag name is already taken in Others, and nothing was
      // deleted (the whole delete is one transaction).
      if (err.response?.data?['error']?['code'] == 'TAG_NAME_CONFLICT') {
        throw CategoryTagNameConflictFailure();
      }
      throw CategoriesRequestFailure();
    }
    return WriteOutcome.sent;
  }

  /// Returns the id of the created tag group: a temporary (negative) one
  /// when it waits in the outbox — the server out of reach, or its category
  /// or one of its tags created offline.
  Future<int> createTagGroup(
      String name, int idCategory, List<int> members) async {
    final body = {
      ...await _outgoingGroup(name, members),
      'idCategory': Outbox.instance.resolve(idCategory),
    };

    Future<int> queue() async {
      late int id;
      await _queue((stamps) async => id = await Outbox.instance.createGroup(
          body,
          keyCheck: stamps.keyCheck,
          generation: stamps.generation));
      return id;
    }

    if ((body['idCategory'] as int) < 0 ||
        _hasPendingMember(body) ||
        await Outbox.instance.shouldQueue()) {
      return queue();
    }

    late Response<Map<String, dynamic>> response;
    try {
      response = await apiInstance.api
          .post<Map<String, dynamic>>('/tagGroups', data: body);
    } on DioException catch (err) {
      if (Api.isUnreachable(err)) return queue();
      throw _groupFailure(err);
    }

    final id = response.data?['id'];
    if (id is! int) throw CategoriesNotFoundFailure();
    return id;
  }

  /// Full-state update: [members] replaces the stored list. A group never
  /// changes category.
  Future<WriteOutcome> updateTagGroup(
      int id, String name, List<int> members) async {
    final target = Outbox.instance.resolve(id);
    final body = await _outgoingGroup(name, members);

    Future<WriteOutcome> queue() async {
      final base = target > 0 ? await serverGroup(target) : null;
      return _queue((stamps) => Outbox.instance.updateGroup(target, body,
          base: base,
          keyCheck: stamps.keyCheck,
          generation: stamps.generation));
    }

    if (target < 0 ||
        _hasPendingMember(body) ||
        await Outbox.instance.shouldQueue()) {
      return queue();
    }

    try {
      await apiInstance.api.patch<void>('/tagGroups/$target', data: body);
    } on DioException catch (err) {
      if (Api.isUnreachable(err)) return queue();
      throw _groupFailure(err);
    }
    return WriteOutcome.sent;
  }

  /// Deletes the group only: its tags and their events stay.
  Future<WriteOutcome> deleteTagGroup(int id) async {
    final target = Outbox.instance.resolve(id);

    Future<WriteOutcome> queue() async {
      final base = target > 0 ? await serverGroup(target) : null;
      return _queue((stamps) => Outbox.instance.deleteGroup(target,
          base: base,
          keyCheck: stamps.keyCheck,
          generation: stamps.generation));
    }

    if (target < 0 || await Outbox.instance.shouldQueue()) return queue();

    try {
      await apiInstance.api.delete<void>('/tagGroups/$target');
    } on DioException catch (err) {
      if (Api.isUnreachable(err)) return queue();
      throw CategoriesRequestFailure();
    }
    return WriteOutcome.sent;
  }

  static bool _hasPendingMember(Map<String, dynamic> body) =>
      (body['members'] as List).cast<int>().any((id) => id < 0);

  /// The name and member fields of a group write. Members created offline
  /// keep their temporary id: the group then waits behind them in the
  /// outbox. For E2EE users the name is encrypted, its blind index sent
  /// alongside, and the reserved date names refused here (the server cannot
  /// read the name).
  Future<Map<String, dynamic>> _outgoingGroup(
      String name, List<int> members) async {
    final ids = members.map(Outbox.instance.resolve).toList();

    final e2ee = E2ee();
    if (!e2ee.enabled) return {'name': name, 'members': ids};

    if (e2ee.isBlacklistedTag(name)) throw TagsBlacklistedFailure();
    return {
      'name': await e2ee.encrypt(normalizeTagName(name)),
      'nameIndex': await e2ee.tagIndex(name),
      'members': ids,
    };
  }

  /// Tells a taken group name apart from any other failure, keyed off the
  /// code like the tag writes.
  Exception _groupFailure(DioException err) {
    if (err.response?.data?['error']?['code'] == 'TAG_NAME_CONFLICT') {
      return TagGroupNameConflictFailure();
    }
    return CategoriesRequestFailure();
  }

  /// Tag/event counts for the category, for the delete dialog. Only for a
  /// category the server has: offline, the counts come from the data on the
  /// device (HomeCubit.fetchCategoryUsage).
  Future<CategoryUsage> getCategoryUsage(int id) async {
    final target = Outbox.instance.resolve(id);
    if (target < 0) throw CategoriesRequestFailure();
    try {
      final response = await apiInstance.api
          .get<Map<String, dynamic>>('/categories/$target/usage');
      if (response.data == null) {
        throw CategoriesNotFoundFailure();
      }
      return CategoryUsage.fromJson(response.data!);
    } on DioException catch (_) {
      throw CategoriesRequestFailure();
    }
  }
}
