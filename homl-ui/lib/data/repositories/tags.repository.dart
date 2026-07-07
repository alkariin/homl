import 'package:dio/dio.dart';
import 'package:homl/data/repositories/api.dart';

class TagsRepository {
  final apiInstance = Api();

  /// Returns the id of the created tag. Pass [idParentTag] to create the tag
  /// as a synonym of an existing main tag of the same category.
  Future<int> createTag(String text, int idCategory, {int? idParentTag}) async {
    late Response<Map<String, dynamic>> response;
    try {
      response = await apiInstance.api.post<Map<String, dynamic>>('/tags', data: {
        'tag': text,
        'idCategory': idCategory,
        if (idParentTag != null) 'idParentTag': idParentTag,
      });

      if (response.data == null) {
        throw Exception();
      }
    } on DioException catch (_) {
      throw Exception();
    }

    return response.data!['id'] as int;
  }

  /// Full-state update: omitting [idParentTag] detaches the tag from its
  /// parent (it becomes a main tag again).
  Future<void> updateTag(int id, String text, int idCategory,
      {int? idParentTag}) async {
    try {
      await apiInstance.api.patch<void>('/tags/$id', data: {
        'tag': text,
        'idCategory': idCategory,
        if (idParentTag != null) 'idParentTag': idParentTag,
      });
    } on DioException catch (_) {
      throw Exception();
    }
  }

  Future<void> deleteTag(int id) async {
    try {
      await apiInstance.api.delete<void>('/tags/$id');
    } on DioException catch (_) {
      throw Exception();
    }
  }
}
