import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:homl/data/models/event.dart';
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
            cardBuilder: (event) => GestureDetector(
              onTap: () => onTap?.call(event),
              child: Text(event.description),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('titles the strip and says how long ago each card was',
        (tester) async {
      await pumpStrip(tester, [
        Memory(eventOn(1, DateTime(2025, 10, 17)), 1),
        Memory(eventOn(2, DateTime(2016, 10, 17)), 10),
      ]);

      expect(find.text('On this day'), findsOneWidget);
      expect(find.text('1 year ago'), findsOneWidget);
      expect(find.text('10 years ago'), findsOneWidget);
      expect(find.text('Event 1'), findsOneWidget);
      expect(find.text('Event 2'), findsOneWidget);
    });

    testWidgets('a card is the one the builder made, taps included',
        (tester) async {
      Event? tapped;
      await pumpStrip(tester, [Memory(eventOn(3, DateTime(2024, 10, 17)), 2)],
          onTap: (event) => tapped = event);

      await tester.tap(find.text('Event 3'));
      expect(tapped?.id, 3);
    });

    testWidgets('in French', (tester) async {
      await pumpStrip(tester, [Memory(eventOn(1, DateTime(2024, 10, 17)), 2)],
          locale: const Locale('fr'));

      expect(find.text('Ce jour-là'), findsOneWidget);
      expect(find.text('il y a 2 ans'), findsOneWidget);
    });
  });
}
