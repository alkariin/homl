import 'package:homl/data/models/event.dart';
import 'package:homl/helpers/event_period.dart';

/// An event that started on today's month and day, in an earlier year.
class Memory {
  final Event event;

  /// Whole years since the event started, 1 or more.
  final int yearsAgo;

  const Memory(this.event, this.yearsAgo);
}

/// The events that started on [today]'s month and day in an earlier year, the
/// most recent first.
///
/// Only the start counts: a period comes back on the anniversary of its first
/// day, never on every day it covers — a five-year period would otherwise
/// fill the strip every day for five years. An event of 29 February comes
/// back on 28 February in the years without one. Events of the current year,
/// today's included, are not memories yet.
List<Memory> eventsOnThisDay(List<Event> events, DateTime today) {
  final now = dayOf(today);
  final leapDayFallback =
      now.month == DateTime.february && now.day == 28 && !_isLeapYear(now.year);

  final memories = <Memory>[];
  for (final event in events) {
    final start = dayOf(event.date);
    if (start.year >= now.year) continue;

    final sameDay = start.month == now.month && start.day == now.day;
    final leapDay =
        leapDayFallback && start.month == DateTime.february && start.day == 29;
    if (sameDay || leapDay) {
      memories.add(Memory(event, now.year - start.year));
    }
  }

  // Ties (same year) keep a stable order: the oldest record first.
  memories.sort((a, b) {
    final byYear = a.yearsAgo.compareTo(b.yearsAgo);
    return byYear != 0 ? byYear : a.event.id.compareTo(b.event.id);
  });
  return memories;
}

bool _isLeapYear(int year) =>
    year % 4 == 0 && (year % 100 != 0 || year % 400 == 0);
