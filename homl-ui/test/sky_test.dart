import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:homl/components/sky_background.dart';
import 'package:homl/data/models/event.dart';
import 'package:homl/data/models/tag.dart';
import 'package:homl/helpers/date_tags.dart';
import 'package:homl/helpers/sky.dart';
import 'package:homl/helpers/theme.dart';

final today = DateTime(2026, 11, 16);

var _tagIds = 0;
final _tagIdOf = <String, int>{};

/// An event on [date] carrying [tags] (the same name, the same tag) plus
/// the date tags of its month, as the backend files it.
Event eventOn(int id, DateTime date, [List<String> tags = const []]) => Event(
      id: id,
      description: '',
      date: date,
      isOngoing: false,
      tags: [
        for (final name in [
          ...tags,
          dateTagMonths[date.month - 1],
          '${date.year}',
        ])
          Tag(id: _tagIdOf.putIfAbsent(name, () => ++_tagIds), tag: name),
      ],
    );

SkyMonth monthOf(Sky sky, int year, int month) =>
    sky.months.singleWhere((m) => m.month == DateTime(year, month));

void main() {
  test('the date tags are told by their name', () {
    for (final name in ['July', 'december ', '2026', 'Ongoing', 'ongoing']) {
      expect(isDateTagName(name), isTrue, reason: name);
    }
    for (final name in ['Football', 'Julyy', '123', '20266', 'Juillet']) {
      expect(isDateTagName(name), isFalse, reason: name);
    }
  });

  group('buildSky', () {
    test('a constellation per month, the current one last', () {
      final sky = buildSky([
        eventOn(1, DateTime(2026, 11, 2)),
        eventOn(2, DateTime(2026, 9, 14)),
        eventOn(3, DateTime(2026, 12, 1)), // after today
        eventOn(4, DateTime(2024, 11, 30)), // 24 months back: out
      ], today);

      expect(sky.months.length, skyMaxMonths);
      expect(sky.months.first.month, DateTime(2024, 12));
      expect(sky.months.last.month, DateTime(2026, 11));
      expect(sky.months.last.stars.map((s) => s.eventId), [1]);
      // A quiet month keeps its place, as a gap in the sky.
      expect(monthOf(sky, 2026, 10).stars, isEmpty);
      expect(monthOf(sky, 2026, 10).bright, -1);
      expect(monthOf(sky, 2026, 9).stars.map((s) => s.eventId), [2]);
      expect(sky.months.expand((m) => m.stars).length, 2);
    });

    test('the limit is on the stars, not on the months', () {
      final sky = buildSky([
        for (var i = 0; i < 3; i++) eventOn(10 + i, DateTime(2026, 11, 1 + i)),
        for (var i = 0; i < 2; i++) eventOn(20 + i, DateTime(2026, 10, 1 + i)),
        eventOn(30, DateTime(2026, 9, 1)),
      ], today, maxStars: 5);

      // November (3) and October (2) spend the five stars: September has no
      // room left, and the sky stops there.
      expect(sky.months.map((m) => m.month),
          [DateTime(2026, 10), DateTime(2026, 11)]);
    });

    test('a busy month shows its events with the most tags', () {
      final sky = buildSky([
        for (var i = 0; i < 14; i++)
          eventOn(100 + i, DateTime(2026, 11, 1 + i),
              i == 12 || i == 13 ? ['Alice', 'Bob', 'Lausanne'] : ['Alice']),
      ], today);

      final shown = sky.months.last.stars.map((s) => s.eventId).toSet();
      expect(shown.length, skyStarsPerMonth);
      // The two richest are kept, the two newest of the others left out.
      expect(shown, containsAll([112, 113]));
      expect(shown, isNot(contains(111)));
      expect(shown, isNot(contains(110)));
    });

    test('a new event never moves the stars already there', () {
      final events = [
        for (var i = 0; i < 6; i++)
          eventOn(40 + i, DateTime(2026, 11, 1 + i), ['Alice'])
      ];
      final before = buildSky(events, today).months.last.stars;
      final after = buildSky([
        ...events,
        eventOn(99, DateTime(2026, 11, 15), ['Bob'])
      ], today)
          .months
          .last
          .stars;

      expect(after.length, before.length + 1);
      for (final star in before) {
        expect(after.singleWhere((s) => s.eventId == star.eventId).at, star.at);
      }
    });

    test('the bright star shares the most tags, the date ones left out', () {
      final sky = buildSky([
        eventOn(1, DateTime(2026, 11, 1), ['Alice', 'Football']),
        eventOn(2, DateTime(2026, 11, 2), ['Alice']),
        eventOn(3, DateTime(2026, 11, 3), ['Football']),
        // Only date tags: they would link these two to everything.
        eventOn(4, DateTime(2026, 11, 4), ['Ongoing']),
        eventOn(5, DateTime(2026, 11, 5)),
      ], today);

      final month = sky.months.last;
      expect(month.stars[month.bright].eventId, 1);
      // Its own tags only make a star bigger.
      expect(month.stars.map((s) => s.tags), [2, 1, 1, 0, 0]);
    });

    test('the lines join every star of a month, without a loop', () {
      final sky = buildSky([
        for (var i = 0; i < 9; i++) eventOn(60 + i, DateTime(2026, 11, 1 + i))
      ], today);
      final month = sky.months.last;

      expect(month.links.length, month.stars.length - 1);
      final reached = {0};
      var grew = true;
      while (grew) {
        grew = false;
        for (final (a, b) in month.links) {
          if (reached.contains(a) && reached.add(b)) grew = true;
          if (reached.contains(b) && reached.add(a)) grew = true;
        }
      }
      expect(reached.length, month.stars.length);
      // Every star in the unit disc of its constellation.
      for (final star in month.stars) {
        expect(star.at.distance, lessThanOrEqualTo(1.0));
      }
    });
  });

  group('SkyGeometry', () {
    test('the months never overlap, the current one bottom-right', () {
      for (final size in const [
        Size(546, 788),
        Size(390, 640),
        Size(1120, 420),
      ]) {
        for (var months = 1; months <= skyMaxMonths; months++) {
          final geometry = SkyGeometry(months, size);
          expect(
              geometry.columns * geometry.rows, greaterThanOrEqualTo(months));
          final last = geometry.cellOf(months - 1);
          expect(last.right, closeTo(size.width, 1e-6));
          expect(last.bottom, closeTo(size.height, 1e-6));

          // The discs drifted as far as they go, every way.
          for (final drift in const [
            Offset(1, 1),
            Offset(-1, -1),
            Offset(1, -1),
            Offset(-1, 1),
          ]) {
            final discs = [
              for (var i = 0; i < months; i++) geometry.discOf(i, drift)
            ];
            for (var i = 0; i < months; i++) {
              final (center, radius) = discs[i];
              final cell = geometry.cellOf(i);
              expect(center.dx - radius, greaterThanOrEqualTo(cell.left));
              expect(center.dx + radius, lessThanOrEqualTo(cell.right + 1e-6));
              expect(center.dy - radius, greaterThanOrEqualTo(cell.top));
              expect(center.dy + radius, lessThanOrEqualTo(cell.bottom + 1e-6));
              for (var j = i + 1; j < months; j++) {
                final (other, otherRadius) = discs[j];
                expect((center - other).distance,
                    greaterThanOrEqualTo(radius + otherRadius),
                    reason: '$size, $months months: $i and $j');
              }
            }
          }
        }
      }
    });
  });

  testWidgets('the sky paints in both themes', (tester) async {
    final sky = buildSky([
      for (var i = 0; i < 30; i++)
        eventOn(200 + i, DateTime(2026, 11 - i ~/ 5, 1 + i % 5), ['Alice'])
    ], today);
    for (final brightness in Brightness.values) {
      await tester.pumpWidget(MaterialApp(
        theme: homlTheme(brightness: brightness),
        home: Scaffold(body: SkyBackground(sky: sky)),
      ));
      expect(tester.takeException(), isNull);
      expect(find.byType(SkyBackground), findsOneWidget);
    }
  });
}
