import 'package:flutter_test/flutter_test.dart';

import 'package:homl/data/models/event.dart';
import 'package:homl/helpers/timeline.dart';

Event eventOn(int id, DateTime date,
    {DateTime? endDate, bool isOngoing = false}) {
  return Event(
      id: id,
      description: 'Event $id',
      date: date,
      endDate: endDate,
      isOngoing: isOngoing,
      tags: const []);
}

void main() {
  final today = DateTime(2026, 10, 17, 21, 30);

  group('timelineOf', () {
    test('keeps the periods, counts the single days', () {
      final timeline = timelineOf([
        eventOn(1, DateTime(2020, 1, 1)),
        eventOn(2, DateTime(2019, 3, 1), endDate: DateTime(2021, 6, 30)),
        eventOn(3, DateTime(2024, 5, 1), isOngoing: true),
        eventOn(4, DateTime(2025, 2, 2)),
      ], today);

      expect(timeline.spans.map((span) => span.event.id), [3, 2]);
      expect(timeline.singleDays, 2);
    });

    test('newest first: by start, then by end, then the latest record', () {
      final timeline = timelineOf([
        eventOn(1, DateTime(2020, 1, 1), endDate: DateTime(2020, 2, 1)),
        eventOn(2, DateTime(2022, 1, 1), endDate: DateTime(2022, 2, 1)),
        eventOn(3, DateTime(2020, 1, 1), endDate: DateTime(2020, 6, 1)),
        eventOn(4, DateTime(2020, 1, 1), endDate: DateTime(2020, 2, 1)),
      ], today);

      expect(timeline.spans.map((span) => span.event.id), [2, 3, 4, 1]);
    });

    test('an open period runs until today', () {
      final span = timelineOf([
        eventOn(1, DateTime(2024, 5, 1), isOngoing: true),
      ], today)
          .spans
          .single;

      expect(span.isOngoing, isTrue);
      expect(span.start, DateTime.utc(2024, 5, 1));
      expect(span.end, DateTime.utc(2026, 10, 17));
    });

    test('an open period starting later is its first day so far', () {
      final span = timelineOf([
        eventOn(1, DateTime(2027, 1, 10), isOngoing: true),
      ], today)
          .spans
          .single;

      expect(span.end, span.start);
    });

    test('the axis spans whole years, today included for an open period', () {
      final timeline = timelineOf([
        eventOn(1, DateTime(2014, 9, 1), endDate: DateTime(2018, 2, 28)),
        eventOn(2, DateTime(2022, 10, 1), isOngoing: true),
      ], today);

      expect(timeline.axisStart, DateTime.utc(2014));
      expect(timeline.axisEnd, DateTime.utc(2027));
    });

    test('no period: empty, on the current year', () {
      final timeline = timelineOf([eventOn(1, DateTime(2020, 1, 1))], today);

      expect(timeline.isEmpty, isTrue);
      expect(timeline.singleDays, 1);
      expect(timeline.axisStart, DateTime.utc(2026));
      expect(timeline.axisEnd, DateTime.utc(2027));
    });

    test('the server UTC midnight and a local date are the same day', () {
      final timeline = timelineOf([
        eventOn(1, DateTime.utc(2020, 1, 1), endDate: DateTime(2020, 12, 31)),
      ], today);

      expect(timeline.spans.single.start, DateTime.utc(2020, 1, 1));
      expect(timeline.spans.single.end, DateTime.utc(2020, 12, 31));
    });
  });

  group('positions', () {
    final timeline = timelineOf([
      eventOn(1, DateTime(2020, 1, 1), endDate: DateTime(2021, 12, 31)),
    ], today);

    test('from 0 at the start of the axis to 1 at its end', () {
      expect(timeline.positionOf(DateTime(2020, 1, 1)), 0);
      expect(timeline.positionOf(DateTime(2022, 1, 1)), 1);
      expect(timeline.positionOf(DateTime(2021, 1, 1)), closeTo(0.5, 0.01));
    });

    test('a span stops at the end of its last day', () {
      final (from, to) = timeline.extentOf(timeline.spans.single);
      expect(from, 0);
      expect(to, 1);
    });
  });

  group('tickYears', () {
    Timeline over(int firstYear, int lastYear) => timelineOf([
          eventOn(1, DateTime(firstYear, 1, 1),
              endDate: DateTime(lastYear, 12, 31)),
        ], today);

    test('every year when they fit', () {
      expect(over(2020, 2024).tickYears(6), [2020, 2021, 2022, 2023, 2024]);
    });

    test('otherwise the smallest round step that fits', () {
      expect(over(2009, 2026).tickYears(6), [2010, 2015, 2020, 2025]);
      expect(over(2011, 2026).tickYears(10),
          [2012, 2014, 2016, 2018, 2020, 2022, 2024, 2026]);
      expect(over(1950, 2026).tickYears(6), [1960, 1980, 2000, 2020]);
    });
  });
}
