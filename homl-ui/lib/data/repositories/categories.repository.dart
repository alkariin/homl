import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:homl/data/models/category.dart';
import 'package:homl/data/repositories/api.dart';
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

    await LocalStorageManager.setValue(
        LocalStorageKey.categoriesCache, jsonEncode(response.data));

    return categories;
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
      return (jsonDecode(raw) as List<dynamic>)
          .map((e) => Category.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      // A cache that no longer parses (model change) is just dropped.
      await LocalStorageManager.remove(LocalStorageKey.categoriesCache);
      return null;
    }
  }

  Future<void> createCategory(String category, String color) async {
    try {
      await apiInstance.api.post<void>('/categories', data: {
        'category': category,
        'color': color,
      });
    } on DioException catch (_) {
      throw CategoriesRequestFailure();
    }
  }

  Future<void> updateCategory(int id, String category, String color) async {
    try {
      await apiInstance.api.patch<void>('/categories/$id', data: {
        'category': category,
        'color': color,
      });
    } on DioException catch (_) {
      throw CategoriesRequestFailure();
    }
  }

  Future<void> deleteCategory(int id, {bool moveTags = false}) async {
    try {
      await apiInstance.api.delete<void>('/categories/$id', data: {
        'moveTags': moveTags,
      });
    } on DioException catch (_) {
      throw CategoriesRequestFailure();
    }
  }
}
