import 'package:dio/dio.dart';
import 'package:homl/data/models/category.dart';
import 'package:homl/data/repositories/api.dart';

class CategoriesRepository {
  final apiInstance = Api();

  Future<List<Category>> getCategories() async {
    late Response<List<Category>> response;
    try {
      response = await apiInstance.api.get<List<Category>>('/categories');

      if (response.data == null) {
        throw Exception();
      }
    } on DioException catch (_) {
      throw Exception();
    }

    return response.data!;
  }
}
