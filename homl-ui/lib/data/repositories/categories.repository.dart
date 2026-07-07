import 'package:dio/dio.dart';
import 'package:homl/data/models/category.dart';
import 'package:homl/data/repositories/api.dart';

class CategoriesRepository {
  final apiInstance = Api();

  Future<List<Category>> getCategories() async {
    late Response<List<dynamic>> response;
    try {
      response = await apiInstance.api.get<List<dynamic>>('/categories');

      if (response.data == null) {
        throw Exception();
      }
    } on DioException catch (_) {
      throw Exception();
    }

    return response.data!
        .map((e) => Category.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> createCategory(String category, String color) async {
    try {
      await apiInstance.api.post<void>('/categories', data: {
        'category': category,
        'color': color,
      });
    } on DioException catch (_) {
      throw Exception();
    }
  }

  Future<void> updateCategory(int id, String category, String color) async {
    try {
      await apiInstance.api.patch<void>('/categories/$id', data: {
        'category': category,
        'color': color,
      });
    } on DioException catch (_) {
      throw Exception();
    }
  }

  Future<void> deleteCategory(int id, {bool moveTags = false}) async {
    try {
      await apiInstance.api.delete<void>('/categories/$id', data: {
        'moveTags': moveTags,
      });
    } on DioException catch (_) {
      throw Exception();
    }
  }
}
