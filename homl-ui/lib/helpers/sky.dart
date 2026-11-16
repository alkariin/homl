import 'dart:math' as math;
import 'dart:ui' show Offset, Rect, Size;

import 'package:homl/data/models/event.dart';
import 'package:homl/helpers/date_tags.dart';

/// The sky behind the home tabs (lib/components/sky_background.dart): one
/// constellation per month, one star per event. This file decides what the
/// sky shows, independently of the screen; [SkyGeometry] places it on one.

/// At most this many stars in the whole sky: the months are taken from the
/// current one backwards while their stars fit, so a busy life shows fewer
/// months and a quiet one more — never a crowded sky.
const skyMaxStars = 100;

/// At most this many stars per month: the events with the most tags.
const skyStarsPerMonth = 12;

/// The sky never goes further back than this, however quiet the months.
const skyMaxMonths = 24;

/// An event in its month's constellation.
class SkyStar {
  final int eventId;

  /// Where the star sits in the unit disc of its constellation.
  final Offset at;

  /// How many tags of its own the event has (the date tags left out): the
  /// more, the bigger the star.
  final int tags;

  const SkyStar(this.eventId, this.at, this.tags);
}

/// The constellation of a month.
class SkyMonth {
  final DateTime month;

  /// Ordered by event id: a star's place depends on the ones before it only.
  final List<SkyStar> stars;

  /// The lines, as pairs of indexes into [stars]: their minimum spanning
  /// tree, the way constellations are drawn (each star to its nearest, no
  /// loop).
  final List<(int, int)> links;

  /// Index of the star that shines (in gold): the event sharing the most
  /// tags with the others of its month. -1 for an empty month.
  final int bright;

  /// Where the constellation sits in its cell: each axis in [-1, 1] of the
  /// room left around its disc, so the months do not line up as a table.
  final Offset drift;

  const SkyMonth(this.month, this.stars, this.links, this.bright, this.drift);
}

/// What the sky shows: its months, oldest first, the last one being the
/// current month. An empty month keeps its place, as a gap in the sky.
class Sky {
  final List<SkyMonth> months;

  const Sky(this.months);
}

/// The sky of [events] as of [today]: from the current month backwards, a
/// month at a time while its stars fit in [maxStars] (at most [perMonth]
/// each, the events with the most tags), and never more than [maxMonths]
/// months. An empty month keeps its cell — a quiet month is a gap in the
/// sky — until the stars are spent. An event belongs to the month it starts
/// in; one dated after [today] is left out.
Sky buildSky(List<Event> events, DateTime today,
    {int maxStars = skyMaxStars,
    int perMonth = skyStarsPerMonth,
    int maxMonths = skyMaxMonths}) {
  int keyOf(DateTime date) => date.year * 12 + date.month - 1;
  final current = keyOf(today);

  final byMonth = <int, List<Event>>{};
  for (final event in events) {
    final key = keyOf(event.date);
    if (key > current || key <= current - maxMonths) continue;
    (byMonth[key] ??= []).add(event);
  }

  final months = <SkyMonth>[];
  var budget = maxStars;
  // Once the stars are spent, older months — even empty ones — have no
  // room left: the sky stops there.
  for (var key = current; key > current - maxMonths && budget > 0; key--) {
    var inMonth = [...?byMonth[key]];
    if (inMonth.length > perMonth) {
      inMonth.sort((a, b) {
        final byTags = _ownTags(b).length.compareTo(_ownTags(a).length);
        return byTags != 0 ? byTags : a.id.compareTo(b.id);
      });
      inMonth = inMonth.take(perMonth).toList();
    }
    if (inMonth.length > budget) break;
    budget -= inMonth.length;
    months.add(_constellation(DateTime(key ~/ 12, key % 12 + 1), inMonth));
  }
  return Sky(months.reversed.toList());
}

/// The tags of [event] that link it to others: no date tag (they say when
/// an event is, not what it is), and a synonym counts as the tag it stands
/// for.
Set<int> _ownTags(Event event) => {
      for (final tag in event.tags)
        if (!isDateTagName(tag.tag)) tag.idParentTag ?? tag.id,
    };

SkyMonth _constellation(DateTime month, List<Event> events) {
  final sorted = [...events]..sort((a, b) => a.id.compareTo(b.id));
  final tags = [for (final event in sorted) _ownTags(event)];

  // Each star drawn from its event id, the best of a few candidates: the
  // one furthest from the stars already placed. Ids only grow, so a new
  // event never moves the others.
  final points = <Offset>[];
  for (final event in sorted) {
    final random = math.Random(event.id * 7919 + 13);
    Offset? best;
    var bestDistance = -1.0;
    for (var attempt = 0; attempt < (points.isEmpty ? 1 : 6); attempt++) {
      final candidate = Offset.fromDirection(random.nextDouble() * 2 * math.pi,
          math.sqrt(0.05 + 0.95 * random.nextDouble()));
      final distance = points.isEmpty
          ? 0.0
          : points.map((p) => (p - candidate).distance).reduce(math.min);
      if (distance > bestDistance) {
        bestDistance = distance;
        best = candidate;
      }
    }
    points.add(best!);
  }

  // Prim's minimum spanning tree: at most a dozen stars.
  final links = <(int, int)>[];
  final linked = {if (points.isNotEmpty) 0};
  while (linked.length < points.length) {
    (int, int)? nearest;
    var nearestDistance = double.infinity;
    for (final from in linked) {
      for (var to = 0; to < points.length; to++) {
        if (linked.contains(to)) continue;
        final distance = (points[from] - points[to]).distanceSquared;
        if (distance < nearestDistance) {
          nearestDistance = distance;
          nearest = (from, to);
        }
      }
    }
    links.add(nearest!);
    linked.add(nearest.$2);
  }

  // The bright star: the most tags shared with the rest of the month, then
  // the most tags, then the oldest.
  int shared(int i) => [
        for (var j = 0; j < tags.length; j++)
          if (j != i) tags[i].intersection(tags[j]).length
      ].fold(0, (a, b) => a + b);
  var bright = sorted.isEmpty ? -1 : 0;
  for (var i = 1; i < sorted.length; i++) {
    final si = shared(i), sb = shared(bright);
    if (si > sb || (si == sb && tags[i].length > tags[bright].length)) {
      bright = i;
    }
  }

  final drift = math.Random(month.year * 12 + month.month);
  return SkyMonth(
    month,
    [
      for (var i = 0; i < sorted.length; i++)
        SkyStar(sorted[i].id, points[i], tags[i].length)
    ],
    links,
    bright,
    Offset(drift.nextDouble() * 2 - 1, drift.nextDouble() * 2 - 1),
  );
}

/// The sky laid on an area of [size]: a grid fitted to the number of months
/// (cells as square as the area allows), the oldest month top-left and the
/// current one in the last cell, bottom-right — the cells left over are the
/// first ones. Each constellation stays in a disc inside its cell, so two
/// months never overlap.
class SkyGeometry {
  /// Room kept between a disc and the edge of its cell.
  static const margin = 12.0;

  /// The disc takes this share of the room its cell offers; the rest lets
  /// it drift ([SkyMonth.drift]).
  static const discShare = 0.82;

  final int months;
  final int columns;
  final int rows;
  final Size cell;

  factory SkyGeometry(int months, Size size) {
    if (months == 0 || size.isEmpty) {
      return SkyGeometry._(months, 0, 0, Size.zero);
    }
    final columns =
        math.sqrt(months * size.width / size.height).round().clamp(1, months);
    final rows = (months / columns).ceil();
    return SkyGeometry._(
        months, columns, rows, Size(size.width / columns, size.height / rows));
  }

  const SkyGeometry._(this.months, this.columns, this.rows, this.cell);

  /// The cell of the month at [index] (oldest first).
  Rect cellOf(int index) {
    final slot = index + columns * rows - months;
    return Rect.fromLTWH((slot % columns) * cell.width,
        (slot ~/ columns) * cell.height, cell.width, cell.height);
  }

  /// Centre and radius of the disc of the month at [index], [drift] being
  /// its [SkyMonth.drift]. A radius of 0: no room for it.
  (Offset, double) discOf(int index, Offset drift) {
    final room = math.max(0.0, math.min(cell.width, cell.height) / 2 - margin);
    final radius = room * discShare;
    final slack = room - radius;
    return (
      cellOf(index).center + Offset(drift.dx * slack, drift.dy * slack),
      radius
    );
  }
}
