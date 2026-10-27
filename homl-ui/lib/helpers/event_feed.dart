import 'package:homl/data/models/event.dart';

/// One entry of the event list on the Search tab: a month heading, or an
/// event under it.
sealed class FeedItem {
  const FeedItem();
}

/// The heading of a month: its first day, and how many events start in it.
class FeedMonth extends FeedItem {
  final DateTime month;
  final int count;

  const FeedMonth(this.month, this.count);
}

/// An event, with its place in its month: the rail of the list runs from the
/// first event of a month to its last.
class FeedEvent extends FeedItem {
  final Event event;
  final bool first;
  final bool last;

  const FeedEvent(this.event, {required this.first, required this.last});
}

/// [events], newest first as the list holds them, under a heading for each
/// month: an event sits under the month it starts in, the day the list prints
/// for it. Consecutive events of the same month share their heading, so an
/// unsorted list would only repeat a month, never lose an event.
List<FeedItem> eventFeed(List<Event> events) {
  final items = <FeedItem>[];
  var start = 0;
  while (start < events.length) {
    final month = _monthOf(events[start].date);
    var end = start + 1;
    while (end < events.length && _monthOf(events[end].date) == month) {
      end++;
    }
    items.add(FeedMonth(month, end - start));
    for (var i = start; i < end; i++) {
      items.add(FeedEvent(events[i], first: i == start, last: i == end - 1));
    }
    start = end;
  }
  return items;
}

DateTime _monthOf(DateTime date) => DateTime(date.year, date.month);
