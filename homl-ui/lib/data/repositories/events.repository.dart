import 'package:dio/dio.dart';
import 'package:homl/data/models/event.dart';
import 'package:homl/data/repositories/api.dart';

class EventsRepository {
  final apiInstance = Api();

  /// When [tags] is provided, only the events containing ALL the given tags
  /// (or one of their synonyms) are returned. The filter is sent as query
  /// parameters because browsers cannot send a GET body.
  Future<List<Event>> getEvents({List<String>? tags}) async {
    late Response<List<dynamic>> response;
    try {
      response = await apiInstance.api.get<List<dynamic>>(
        '/events',
        queryParameters:
            (tags != null && tags.isNotEmpty) ? {'tags': tags} : null,
      );

      if (response.data == null) {
        throw Exception();
      }
    } on DioException catch (_) {
      throw Exception();
    }

    return response.data!
        .map((e) => Event.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> createEvent({
    String? description,
    required DateTime date,
    required List<int> tagsId,
  }) async {
    try {
      await apiInstance.api.post<void>('/events', data: {
        if (description != null && description.isNotEmpty)
          'description': description,
        'date': date.toUtc().toIso8601String(),
        'tagsId': tagsId,
      });
    } on DioException catch (_) {
      throw Exception();
    }
  }
}
