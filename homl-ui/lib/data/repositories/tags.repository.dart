import 'package:dio/dio.dart';
import 'package:homl/data/models/tag.dart';
import 'package:homl/data/repositories/api.dart';

class TagsRepository {
  final apiInstance = Api();

  Future<Tag> createTag(String text, int idCategory) async {
    late Response<Tag> response;
    try {
      response = await apiInstance.api.post<Tag>('/tags', data: {
        'tag': text,
        'idCategory': idCategory,
      });

      if (response.data == null) {
        throw Exception();
      }
    } on DioException catch (_) {
      throw Exception();
    }

    return response.data!;
  }

  Future<Tag> updateTag(int id, String text, int idCategory) async {
    late Response<Tag> response;
    try {
      response = await apiInstance.api.patch<Tag>('/tags/$id', data: {
        'tag': text,
        'idCategory': idCategory,
      });

      if (response.data == null) {
        throw Exception();
      }
    } on DioException catch (_) {
      throw Exception();
    }

    return response.data!;
  }

  Future<void> deleteTag(int id) async {
    try {
      await apiInstance.api.post<Tag>('/tags/$id');
    } on DioException catch (_) {
      throw Exception();
    }
  }
}
