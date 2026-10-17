
import 'package:dio/dio.dart';
import 'package:homl/data/models/category.dart';
import 'package:homl/data/models/tag.dart';
import 'package:homl/data/models/tag_group.dart';
import 'package:homl/data/models/usage.dart';
import 'package:homl/data/repositories/api.dart';
import 'package:homl/data/repositories/tags.repository.dart';
import 'package:homl/data/store/local_store.dart';
import 'package:homl/data/sync/outbox.dart';
import 'package:homl/data/sync/projection.dart';
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
  Future<List<Category>> getCategories({bool cacheFallback = true}) async {
    late Response<List<dynamic>> response;
    try {
      response = await apiInstance.api.get<List<dynamic>>('/categories');

      if (response.data == null) {
        throw CategoriesNotFoundFailure();
      }
    } on DioException catch (_) {
      final cached = cacheFallback ? await getCachedCategories() : null;
      if (cached != null) {
        return cached;
      }
      throw CategoriesRequestFailure();
    }

    // The store gets the payload BEFORE decryption on purpose: for E2EE users
    // it must only ever hold ciphertext (homl-web/docs/e2ee.md).
    await LocalStore.instance.save(StoreEntry.categories, response.data);

    return _decryptCategories(await _project(response.data!));
  }

  /// The server payload with the tags created offline in their category.
  Future<List<Category>> _project(List<dynamic> payload) async {
    List<OutboxOp> ops;
    try {
      ops = await Outbox.instance.ops();
    } catch (_) {
      ops = const [];
    }
    final projected =
        ops.isEmpty ? payload : projectCategories(payload, ops);
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

  /// Returns the id of the created category.
  Future<int> createCategory(String category, String color) async {
    late Response<Map<String, dynamic>> response;
    try {
      response = await apiInstance.api
          .post<Map<String, dynamic>>('/categories', data: {
        'category': await _outgoingName(category),
        'color': color,
      });
    } on DioException catch (_) {
      throw CategoriesRequestFailure();
    }

    final id = response.data?['id'];
    if (id is! int) throw CategoriesNotFoundFailure();
    return id;
  }

  Future<void> updateCategory(int id, String category, String color) async {
    try {
      await apiInstance.api.patch<void>('/categories/$id', data: {
        'category': await _outgoingName(category),
        'color': color,
      });
    } on DioException catch (_) {
      throw CategoriesRequestFailure();
    }
  }

  /// Encrypts an outgoing category name for E2EE users.
  Future<String> _outgoingName(String category) async {
    if (!E2ee().enabled) return category;
    return E2ee().encrypt(category);
  }

  /// [moveTags] moves the tags to the Other category; otherwise the tags are
  /// deleted and [deleteEvents] also deletes the events whose only non-date
  /// tags lived in this category.
  Future<void> deleteCategory(int id,
      {bool moveTags = false, bool deleteEvents = false}) async {
    try {
      await apiInstance.api.delete<void>('/categories/$id', data: {
        'moveTags': moveTags,
        'deleteEvents': deleteEvents,
      });
    } on DioException catch (err) {
      // Keyed off the code, never the message string: the backend refuses a
      // move whose tag name is already taken in Others, and nothing was
      // deleted (the whole delete is one transaction).
      if (err.response?.data?['error']?['code'] == 'TAG_NAME_CONFLICT') {
        throw CategoryTagNameConflictFailure();
      }
      throw CategoriesRequestFailure();
    }
  }

  /// Returns the id of the created tag group. Online only, like every
  /// category change: an unreachable server is a [CategoriesRequestFailure].
  Future<int> createTagGroup(
      String name, int idCategory, List<int> members) async {
    final body = {
      ...await _outgoingGroup(name, members),
      'idCategory': idCategory,
    };
    late Response<Map<String, dynamic>> response;
    try {
      response = await apiInstance.api
          .post<Map<String, dynamic>>('/tagGroups', data: body);
    } on DioException catch (err) {
      throw _groupFailure(err);
    }

    final id = response.data?['id'];
    if (id is! int) throw CategoriesNotFoundFailure();
    return id;
  }

  /// Full-state update: [members] replaces the stored list. A group never
  /// changes category.
  Future<void> updateTagGroup(int id, String name, List<int> members) async {
    final body = await _outgoingGroup(name, members);
    try {
      await apiInstance.api.patch<void>('/tagGroups/$id', data: body);
    } on DioException catch (err) {
      throw _groupFailure(err);
    }
  }

  /// Deletes the group only: its tags and their events stay.
  Future<void> deleteTagGroup(int id) async {
    try {
      await apiInstance.api.delete<void>('/tagGroups/$id');
    } on DioException catch (_) {
      throw CategoriesRequestFailure();
    }
  }

  /// The name and member fields of a group write. Members are server ids: a
  /// tag created offline and not sent yet is a [TagPendingFailure]. For E2EE
  /// users the name is encrypted, its blind index sent alongside, and the
  /// reserved date names refused here (the server cannot read the name).
  Future<Map<String, dynamic>> _outgoingGroup(
      String name, List<int> members) async {
    final ids = members.map(Outbox.instance.resolve).toList();
    if (ids.any((id) => id < 0)) throw TagPendingFailure();

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

  /// Tag/event counts for the category, for the delete dialog.
  Future<CategoryUsage> getCategoryUsage(int id) async {
    try {
      final response = await apiInstance.api
          .get<Map<String, dynamic>>('/categories/$id/usage');
      if (response.data == null) {
        throw CategoriesNotFoundFailure();
      }
      return CategoryUsage.fromJson(response.data!);
    } on DioException catch (_) {
      throw CategoriesRequestFailure();
    }
  }
}
