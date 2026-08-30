import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homl/data/repositories/api.dart';
import 'package:homl/data/repositories/events.repository.dart';

/// Answers POST /events and PATCH /events/:id with an empty success, recording
/// the JSON body that was sent.
class _EventsAdapter implements HttpClientAdapter {
  final bodies = <Map<String, dynamic>>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    if (options.path.contains('/events')) {
      bodies.add((options.data as Map).cast<String, dynamic>());
      return ResponseBody.fromString('', options.method == 'POST' ? 201 : 204);
    }
    return ResponseBody.fromString(jsonEncode({'error': 'unexpected'}), 404);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _EventsAdapter adapter;
  late EventsRepository repository;

  setUp(() {
    final api = Api.internal(
        baseUrlOverride: 'https://api.test', initFromStorage: false);
    adapter = _EventsAdapter();
    api.api.httpClientAdapter = adapter;
    api.accessToken = 'an-access-token';
    repository = EventsRepository(api: api);
  });

  group('serializeDate', () {
    test('keeps the calendar day of a local midnight (date picker output)', () {
      // Whatever the test machine's timezone, a local DateTime must never
      // shift to the previous/next day through a UTC conversion: the backend
      // stores a plain DATE and truncates the time part.
      final picked = DateTime(2026, 8, 31);
      expect(
          EventsRepository.serializeDate(picked), '2026-08-31T00:00:00.000Z');
    });

    test('keeps the calendar day of a UTC midnight (backend output)', () {
      final fromBackend = DateTime.parse('2026-08-31T00:00:00Z');
      expect(EventsRepository.serializeDate(fromBackend),
          '2026-08-31T00:00:00.000Z');
    });

    test('drops the time of day', () {
      final now = DateTime(2026, 8, 31, 23, 59, 59);
      expect(EventsRepository.serializeDate(now), '2026-08-31T00:00:00.000Z');
    });
  });

  test('createEvent sends the picked day at UTC midnight', () async {
    await repository.createEvent(date: DateTime(2026, 8, 31), tagsId: [1]);

    expect(adapter.bodies.single['date'], '2026-08-31T00:00:00.000Z');
  });

  test('updateEvent sends the picked day at UTC midnight', () async {
    // Regression: editing an event to the next day used to send
    // <day-1>T22:00:00Z east of UTC, which the backend stored as <day-1>, so
    // the change looked like a no-op in the app.
    await repository
        .updateEvent(id: 7, date: DateTime(2026, 9, 1), tagsId: [1]);

    expect(adapter.bodies.single['date'], '2026-09-01T00:00:00.000Z');
    expect(adapter.bodies.single['description'], '');
  });
}
