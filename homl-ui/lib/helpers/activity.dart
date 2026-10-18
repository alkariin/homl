import 'package:homl/data/models/event.dart';
import 'package:homl/helpers/event_period.dart';

/// The span an activity calendar shows: whole weeks, Monday to Sunday,
/// covering [first] to [last] (calendar days, UTC like [dayOf]).
class ActivityWindow {
  final DateTime first;
  final DateTime last;

  ActivityWindow(DateTime first, DateTime last)
      : first = dayOf(first),
        last = dayOf(last);

  /// The twelve months up to [today], like GitHub's: from the day after the
  /// same date a year ago.
  factory ActivityWindow.lastYear(DateTime today) {
    final end = dayOf(today);
    return ActivityWindow(
        DateTime.utc(end.year - 1, end.month, end.day + 1), end);
  }

  /// The calendar year [year], up to [today] when it is the current one.
  factory ActivityWindow.year(int year, DateTime today) {
    final now = dayOf(today);
    final end = DateTime.utc(year, 12, 31);
    return ActivityWindow(
        DateTime.utc(year), end.isAfter(now) && year == now.year ? now : end);
  }

  /// The Monday on or before [first]: where the first column starts.
  DateTime get gridStart =>
      first.subtract(Duration(days: first.weekday - DateTime.monday));

  /// The number of week columns, the last one holding [last].
  int get weeks => last.difference(gridStart).inDays ~/ 7 + 1;

  /// The day in column [week], row [weekday] (0 = Monday).
  DateTime dayAt(int week, int weekday) =>
      gridStart.add(Duration(days: week * 7 + weekday));

  bool contains(DateTime day) => !day.isBefore(first) && !day.isAfter(last);
}

/// How many of [events] took place on each day of [window]: a single-day
/// event on its day, a period on every day it covers — an open one until
/// [today]. Days without any are left out.
Map<DateTime, int> dailyActivity(
    List<Event> events, ActivityWindow window, DateTime today) {
  final now = dayOf(today);
  final counts = <DateTime, int>{};
  for (final event in events) {
    var start = dayOf(event.date);
    var end = event.isOngoing
        ? (now.isAfter(start) ? now : start)
        : dayOf(event.endDate ?? event.date);
    if (start.isBefore(window.first)) start = window.first;
    if (end.isAfter(window.last)) end = window.last;
    for (var day = start;
        !day.isAfter(end);
        day = DateTime.utc(day.year, day.month, day.day + 1)) {
      counts[day] = (counts[day] ?? 0) + 1;
    }
  }
  return counts;
}

/// The years [events] took place in, newest first, up to [today]'s: the
/// ones an activity calendar can be turned to.
List<int> activeYears(List<Event> events, DateTime today) {
  final now = dayOf(today);
  final years = <int>{};
  for (final event in events) {
    final start = dayOf(event.date);
    if (start.isAfter(now)) continue;
    final end = event.isOngoing ? now : dayOf(event.endDate ?? event.date);
    final last = end.isAfter(now) ? now.year : end.year;
    for (var year = start.year; year <= last; year++) {
      years.add(year);
    }
  }
  return years.toList()..sort((a, b) => b.compareTo(a));
}

/// The shade of a day with [count] events, from 0 (none) to 4 (four or
/// more): a journal's days rarely hold many, so each one shows.
int activityLevel(int count) => count < 4 ? count : 4;
