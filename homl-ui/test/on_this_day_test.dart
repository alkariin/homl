import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:homl/data/models/event.dart';
import 'package:homl/data/models/tag.dart';
import 'package:homl/helpers/localizations.dart';
import 'package:homl/helpers/on_this_day.dart';
import 'package:homl/l10n/app_localizations.dart';
import 'package:homl/pages/list/view/on_this_day_strip.dart';

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

List<int> idsOf(List<Memory> memories) =>
    memories.map((memory) => memory.event.id).toList();

void main() {
  group('eventsOnThisDay', () {
    final today = DateTime(2026, 10, 17, 21, 30);

    test('same month and day in earlier years, the most recent first', () {
      final memories = eventsOnThisDay([
        eventOn(1, DateTime(2016, 10, 17)),
        eventOn(2, DateTime(2025, 10, 17)),
        eventOn(3, DateTime(2025, 10, 18)),
        eventOn(4, DateTime(2023, 9, 17)),
      ], today);

      expect(idsOf(memories), [2, 1]);
      expect(memories.map((memory) => memory.yearsAgo), [1, 10]);
    });

    test('this year and the future are not memories', () {
      expect(
          eventsOnThisDay([
            eventOn(1, DateTime(2026, 10, 17)),
            eventOn(2, DateTime(2027, 10, 17)),
          ], today),
          isEmpty);
    });

    test('a period comes back on its first day only', () {
      final memories = eventsOnThisDay([
        eventOn(1, DateTime(2024, 10, 17), endDate: DateTime(2024, 10, 30)),
        eventOn(2, DateTime(2024, 10, 1), endDate: DateTime(2024, 10, 30)),
        eventOn(3, DateTime(2020, 10, 17), isOngoing: true),
        eventOn(4, DateTime(2019, 1, 1), isOngoing: true),
      ], today);

      expect(idsOf(memories), [1, 3]);
    });

    test('same year: the oldest record first', () {
      final memories = eventsOnThisDay([
        eventOn(7, DateTime(2024, 10, 17)),
        eventOn(5, DateTime(2024, 10, 17)),
      ], today);

      expect(idsOf(memories), [5, 7]);
    });

    test('the server UTC midnight and a local date are the same day', () {
      final memories = eventsOnThisDay([
        eventOn(1, DateTime.utc(2024, 10, 17)),
        eventOn(2, DateTime(2023, 10, 17)),
      ], today);

      expect(idsOf(memories), [1, 2]);
    });

    group('29 February', () {
      final leapDay = eventOn(1, DateTime(2024, 2, 29));
      final lastDay = eventOn(2, DateTime(2023, 2, 28));

      test('comes back on 28 February in a year without one', () {
        expect(
            idsOf(eventsOnThisDay([leapDay, lastDay], DateTime(2025, 2, 28))),
            [leapDay.id, lastDay.id]);
      });

      test('keeps its own day in a leap year', () {
        expect(
            idsOf(eventsOnThisDay([leapDay, lastDay], DateTime(2028, 2, 28))),
            [lastDay.id]);
        expect(
            idsOf(eventsOnThisDay([leapDay, lastDay], DateTime(2028, 2, 29))),
            [leapDay.id]);
      });

      test('never on 1 March', () {
        expect(eventsOnThisDay([leapDay], DateTime(2025, 3, 1)), isEmpty);
      });
    });
  });

  group('OnThisDayStrip', () {
    final today = DateTime(2026, 10, 17);
    final cinema = Tag(id: 1, tag: 'Cinema', idCategory: 1);
    final october = Tag(id: 2, tag: 'October', idCategory: 9);

    Future<void> pumpStrip(WidgetTester tester, List<Memory> memories,
        {Locale locale = const Locale('en'),
        void Function(Event)? onTap}) async {
      await tester.pumpWidget(MaterialApp(
        locale: locale,
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: OnThisDayStrip(
            memories: memories,
            tagColorResolver: (_) => null,
            isDateTag: (tag) => tag.idCategory == 9,
            onTap: (event) => onTap?.call(event),
            today: today,
          ),
        ),
      ));
      await tester.pumpAndSettle();
    }

    /// The pager dots, by position: true for the wide one, the memory shown.
    List<bool> dots(WidgetTester tester) {
      final widths = [
        for (final element in find.byType(AnimatedContainer).evaluate())
          tester.getSize(find.byWidget(element.widget)).width,
      ];
      final widest = widths.reduce((a, b) => a > b ? a : b);
      return [for (final width in widths) width == widest];
    }

    testWidgets('titles the panel with the day and shows one memory at a time',
        (tester) async {
      await pumpStrip(tester, [
        Memory(eventOn(1, DateTime(2025, 10, 17)), 1),
        Memory(eventOn(2, DateTime(2016, 10, 17)), 10),
      ]);

      expect(find.text('On this day'), findsOneWidget);
      expect(find.text('October 17'), findsOneWidget);
      expect(find.text('2025'), findsOneWidget);
      expect(find.text('1 year ago'), findsOneWidget);
      expect(find.text('Event 1'), findsOneWidget);
      expect(find.text('Event 2'), findsNothing);
      expect(dots(tester), [true, false]);

      await tester.drag(find.byType(PageView), const Offset(-400, 0));
      await tester.pumpAndSettle();

      expect(find.text('2016'), findsOneWidget);
      expect(find.text('10 years ago'), findsOneWidget);
      expect(find.text('Event 2'), findsOneWidget);
      expect(dots(tester), [false, true]);
    });

    testWidgets('a single memory has no dots', (tester) async {
      await pumpStrip(tester, [Memory(eventOn(1, DateTime(2025, 10, 17)), 1)]);

      expect(find.byType(AnimatedContainer), findsNothing);
    });

    testWidgets('a tap opens the memory', (tester) async {
      Event? tapped;
      await pumpStrip(tester, [Memory(eventOn(3, DateTime(2024, 10, 17)), 2)],
          onTap: (event) => tapped = event);

      await tester.tap(find.text('Event 3'));
      expect(tapped?.id, 3);
    });

    testWidgets('the period and the tags, but not the date tags',
        (tester) async {
      final trip = Event(
          id: 4,
          description: 'Trip',
          date: DateTime(2025, 10, 17),
          endDate: DateTime(2025, 10, 24),
          isOngoing: false,
          tags: [cinema, october]);
      await pumpStrip(tester, [Memory(trip, 1)]);

      expect(find.text('→ Oct 24 · 8 days'), findsOneWidget);
      expect(find.text('Cinema'), findsOneWidget);
      expect(find.text('October'), findsNothing);
    });

    testWidgets('many tags and a long description stay inside the panel',
        (tester) async {
      final busy = Event(
          id: 5,
          description: List.filled(40, 'A long day.').join(' '),
          date: DateTime(2025, 10, 17),
          isOngoing: false,
          tags: [
            for (var i = 0; i < 12; i++)
              Tag(id: 10 + i, tag: 'Tag number $i', idCategory: 1),
          ]);
      await pumpStrip(tester, [Memory(busy, 1)]);

      expect(tester.takeException(), isNull);
      final description = tester.widget<Text>(find.textContaining('A long'));
      expect(description.maxLines, lessThanOrEqualTo(3));
    });

    testWidgets('a memory made offline wears a clock', (tester) async {
      final pending = Event(
          id: -2,
          description: 'note',
          date: DateTime(2025, 10, 17),
          isOngoing: false,
          tags: const [],
          isPending: true);
      await pumpStrip(tester, [Memory(pending, 1)]);

      expect(find.byIcon(Icons.schedule), findsOneWidget);
    });

    testWidgets('in French', (tester) async {
      await pumpStrip(tester, [Memory(eventOn(1, DateTime(2024, 10, 17)), 2)],
          locale: const Locale('fr'));

      expect(find.text('Ce jour-là'), findsOneWidget);
      expect(find.text('17 octobre'), findsOneWidget);
      expect(find.text('il y a 2 ans'), findsOneWidget);
    });
  });
}
