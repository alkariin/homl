import 'package:homl/data/models/event.dart';
import 'package:homl/helpers/event_period.dart';

/// A row of the timeline: an event with an end, or still going on.
class TimelineSpan {
  final Event event;

  /// First day of the period.
  final DateTime start;

  /// Last day it covers: the end of a closed period, today for an open one
  /// (its start, while that is still to come).
  final DateTime end;

  const TimelineSpan(this.event, this.start, this.end);

  bool get isOngoing => event.isOngoing;
}

/// The periods among some events, on a shared axis of whole years.
class Timeline {
  /// Newest first, like the grid.
  final List<TimelineSpan> spans;

  /// The axis: from 1 January of the earliest start to 1 January after the
  /// latest end, so every year it shows is whole.
  final DateTime axisStart;
  final DateTime axisEnd;

  /// The single-day events left out: they have no length to draw.
  final int singleDays;

  const Timeline(
      {required this.spans,
      required this.axisStart,
      required this.axisEnd,
      required this.singleDays});

  bool get isEmpty => spans.isEmpty;

  /// Where [day] falls on the axis, from 0 (its start) to 1 (its end).
  double positionOf(DateTime day) {
    final total = axisEnd.difference(axisStart).inDays;
    return dayOf(day).difference(axisStart).inDays / total;
  }

  /// Where [span] starts and stops on the axis. It stops at the end of its
  /// last day, so a one-month period is as wide as a month.
  (double, double) extentOf(TimelineSpan span) => (
        positionOf(span.start),
        positionOf(span.end.add(const Duration(days: 1))),
      );

  /// The years to label on the axis: every one when they fit, otherwise
  /// every 2, 5, 10… — the smallest step giving at most [maxTicks], on
  /// round years.
  List<int> tickYears(int maxTicks) {
    final firstYear = axisStart.year;
    final lastYear = axisEnd.year;
    final years = lastYear - firstYear;
    const steps = [1, 2, 5, 10, 20, 25, 50, 100];
    final step = steps.firstWhere((step) => years / step <= maxTicks,
        orElse: () => steps.last);
    final firstTick = (firstYear + step - 1) ~/ step * step;
    return [for (var year = firstTick; year < lastYear; year += step) year];
  }
}

/// The timeline of [events] as of [today]. Single-day events are counted,
/// not drawn. Without a period it is empty, on an axis of the current year.
Timeline timelineOf(List<Event> events, DateTime today) {
  final now = dayOf(today);
  final spans = <TimelineSpan>[];
  var singleDays = 0;
  for (final event in events) {
    if (event.endDate == null && !event.isOngoing) {
      singleDays++;
      continue;
    }
    final start = dayOf(event.date);
    var end = event.endDate == null ? now : dayOf(event.endDate!);
    if (end.isBefore(start)) end = start;
    spans.add(TimelineSpan(event, start, end));
  }

  spans.sort((a, b) {
    final byStart = b.start.compareTo(a.start);
    if (byStart != 0) return byStart;
    final byEnd = b.end.compareTo(a.end);
    return byEnd != 0 ? byEnd : b.event.id.compareTo(a.event.id);
  });

  if (spans.isEmpty) {
    return Timeline(
        spans: spans,
        axisStart: DateTime.utc(now.year),
        axisEnd: DateTime.utc(now.year + 1),
        singleDays: singleDays);
  }

  var firstYear = spans.first.start.year;
  var lastYear = spans.first.end.year;
  for (final span in spans) {
    if (span.start.year < firstYear) firstYear = span.start.year;
    if (span.end.year > lastYear) lastYear = span.end.year;
  }
  return Timeline(
      spans: spans,
      axisStart: DateTime.utc(firstYear),
      axisEnd: DateTime.utc(lastYear + 1),
      singleDays: singleDays);
}
