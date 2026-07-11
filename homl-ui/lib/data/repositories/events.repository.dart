import 'dart:async';

import 'package:dio/dio.dart';
import 'package:homl/data/models/event.dart';
import 'package:homl/data/repositories/api.dart';

/// Exception thrown when an events request fails
class EventsRequestFailure implements Exception {}

/// Exception thrown when the events payload is empty
class EventsNotFoundFailure implements Exception {}

class EventsRepository {
  final apiInstance = Api();

  final StreamController<void> _changesController =
      StreamController<void>.broadcast();

  /// Fires whenever this repository changed the events on the backend, so
  /// interested blocs can refresh without being coupled to each other.
  Stream<void> get changes => _changesController.stream;

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
        throw EventsNotFoundFailure();
      }
    } on DioException catch (_) {
      throw EventsRequestFailure();
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
      throw EventsRequestFailure();
    }

    _changesController.add(null);
  }

  void dispose() {
    _changesController.close();
  }
}
