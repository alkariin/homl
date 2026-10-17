import 'package:homl/data/models/event.dart';
import 'package:homl/helpers/event_period.dart';

/// What a search says about the past: when it last happened and how often.
class LastTime {
  /// Last day one of the events covered: the day of a single-day event, the
  /// end of a closed period. Null while one of them is still going on
  /// ([isNow]).
  final DateTime? lastDay;

  /// Number of the events that started on or before today.
  final int total;

  /// How many of those started this calendar year.
  final int thisYear;

  const LastTime({this.lastDay, required this.total, required this.thisYear});

  /// One of the events is going on today: an open period, or a closed one
  /// that has not ended yet.
  bool get isNow => lastDay == null;

  @override
  bool operator ==(Object other) =>
      other is LastTime &&
      other.lastDay == lastDay &&
      other.total == total &&
      other.thisYear == thisYear;

  @override
  int get hashCode => Object.hash(lastDay, total, thisYear);

  @override
  String toString() =>
      'LastTime(${isNow ? 'now' : lastDay}, $total, $thisYear this year)';
}

/// Sums up [events] — the results of a search — as of [today], or null when
/// none of them has started yet. Only the past counts: an event dated after
/// today is a plan, not a last time, and is left out of the counts too.
LastTime? lastTimeOf(List<Event> events, DateTime today) {
  final now = dayOf(today);

  DateTime? lastDay;
  var isNow = false;
  var total = 0;
  var thisYear = 0;
  for (final event in events) {
    final start = dayOf(event.date);
    if (start.isAfter(now)) continue;

    total++;
    if (start.year == now.year) thisYear++;

    final end = event.isOngoing ? null : dayOf(event.endDate ?? event.date);
    if (end == null || (event.endDate != null && !end.isBefore(now))) {
      isNow = true;
    } else if (lastDay == null || end.isAfter(lastDay)) {
      lastDay = end;
    }
  }

  if (total == 0) return null;
  return LastTime(
      lastDay: isNow ? null : lastDay, total: total, thisYear: thisYear);
}
