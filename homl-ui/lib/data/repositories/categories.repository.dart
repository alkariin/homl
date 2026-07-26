import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:homl/data/models/category.dart';
import 'package:homl/data/models/tag.dart';
import 'package:homl/data/models/usage.dart';
import 'package:homl/data/repositories/api.dart';
import 'package:homl/helpers/e2ee.dart';
import 'package:homl/helpers/local_storage_manager.dart';

/// Exception thrown when a categories request fails
class CategoriesRequestFailure implements Exception {}

/// Exception thrown when the categories payload is empty
class CategoriesNotFoundFailure implements Exception {}

class CategoriesRepository {
  final apiInstance = Api();

  /// Returns the user's categories with their tags. Each successful payload
  /// is cached in the secure storage (encrypted at rest) so the app keeps
  /// working offline: when the request fails, the cached copy is returned
  /// instead when one exists.
  Future<List<Category>> getCategories() async {
    late Response<List<dynamic>> response;
    try {
      response = await apiInstance.api.get<List<dynamic>>('/categories');

      if (response.data == null) {
        throw CategoriesNotFoundFailure();
      }
    } on DioException catch (_) {
      final cached = await getCachedCategories();
      if (cached != null) {
        return cached;
      }
      throw CategoriesRequestFailure();
    }

    final categories = response.data!
        .map((e) => Category.fromJson(e as Map<String, dynamic>))
        .toList();

    // The cache is written BEFORE decryption on purpose: for E2EE users it
    // must only ever hold ciphertext (homl-web/docs/e2ee.md).
    await LocalStorageManager.setValue(
        LocalStorageKey.categoriesCache, jsonEncode(response.data));

    return _decryptCategories(categories);
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
        )));
  }

  /// Returns the last categories payload fetched from the backend, or null
  /// when nothing usable was cached yet.
  Future<List<Category>?> getCachedCategories() async {
    final raw =
        await LocalStorageManager.getValue(LocalStorageKey.categoriesCache);
    if (raw == null) {
      return null;
    }

    try {
      final categories = (jsonDecode(raw) as List<dynamic>)
          .map((e) => Category.fromJson(e as Map<String, dynamic>))
          .toList();
      return await _decryptCategories(categories);
    } catch (_) {
      // A cache that no longer parses (model change) is just dropped.
      await LocalStorageManager.remove(LocalStorageKey.categoriesCache);
      return null;
    }
  }

  Future<void> createCategory(String category, String color) async {
    try {
      await apiInstance.api.post<void>('/categories', data: {
        'category': await _outgoingName(category),
        'color': color,
      });
    } on DioException catch (_) {
      throw CategoriesRequestFailure();
    }
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
    } on DioException catch (_) {
      throw CategoriesRequestFailure();
    }
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
