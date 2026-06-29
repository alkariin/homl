import 'package:dio/dio.dart';
import 'package:homl/data/models/event.dart';
import 'package:homl/data/repositories/api.dart';

class EventsRepository {
  final apiInstance = Api();

  Future<List<Event>> getEvents() async {
    late Response<List<Event>> response;
    try {
      response = await apiInstance.api.get<List<Event>>('/events');

      if (response.data == null) {
        throw Exception();
      }
    } on DioException catch (_) {
      throw Exception();
    }

    return response.data!;
  }
}
