import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:homl/data/models/event.dart';
import 'package:homl/helpers/activity.dart';
import 'package:homl/helpers/event_search.dart';
import 'package:homl/helpers/localizations.dart';
import 'package:homl/l10n/app_localizations.dart';
import 'package:homl/pages/list/view/activity_calendar.dart';

Event eventOn(int id, DateTime date,
        {DateTime? endDate, bool isOngoing = false}) =>
    Event(
        id: id,
        description: 'Event $id',
        date: date,
        endDate: endDate,
        isOngoing: isOngoing,
        tags: const []);

void main() {
  // A Saturday.
  final today = DateTime(2026, 10, 17, 21, 30);

  group('ActivityWindow', () {
    test('the last twelve months, in whole weeks from a Monday', () {
      final window = ActivityWindow.lastYear(today);

      expect(window.first, DateTime.utc(2025, 10, 18));
      expect(window.last, DateTime.utc(2026, 10, 17));
      expect(window.gridStart, DateTime.utc(2025, 10, 13));
      expect(window.gridStart.weekday, DateTime.monday);
      expect(window.dayAt(window.weeks - 1, 5), window.last);
    });

    test('a past year whole, the current one up to today', () {
      expect(ActivityWindow.year(2024, today).last, DateTime.utc(2024, 12, 31));
      expect(ActivityWindow.year(2026, today).last, DateTime.utc(2026, 10, 17));
      expect(ActivityWindow.year(2026, today).first, DateTime.utc(2026, 1, 1));
    });
  });

  group('dailyActivity', () {
    final window = ActivityWindow.lastYear(today);

    test('counts the events of each day', () {
      final counts = dailyActivity([
        eventOn(1, DateTime(2026, 3, 4)),
        eventOn(2, DateTime(2026, 3, 4)),
        eventOn(3, DateTime.utc(2026, 5, 1)),
      ], window, today);

      expect(counts, {
        DateTime.utc(2026, 3, 4): 2,
        DateTime.utc(2026, 5, 1): 1,
      });
    });

    test('a period counts on every day it covers, an open one until today', () {
      final counts = dailyActivity([
        eventOn(1, DateTime(2026, 7, 1), endDate: DateTime(2026, 7, 3)),
        eventOn(2, DateTime(2026, 10, 15), isOngoing: true),
      ], window, today);

      expect(counts.keys, [
        DateTime.utc(2026, 7, 1),
        DateTime.utc(2026, 7, 2),
        DateTime.utc(2026, 7, 3),
        DateTime.utc(2026, 10, 15),
        DateTime.utc(2026, 10, 16),
        DateTime.utc(2026, 10, 17),
      ]);
    });

    test('only the days of the window', () {
      final counts = dailyActivity([
        eventOn(1, DateTime(2020, 1, 1), endDate: DateTime(2025, 10, 19)),
        eventOn(2, DateTime(2027, 1, 1)),
      ], window, today);

      expect(counts.keys,
          [DateTime.utc(2025, 10, 18), DateTime.utc(2025, 10, 19)]);
    });
  });

  test('activeYears: every year reached, newest first, never the future', () {
    expect(
        activeYears([
          eventOn(1, DateTime(2019, 6, 1)),
          eventOn(2, DateTime(2022, 12, 30), endDate: DateTime(2023, 1, 2)),
          eventOn(3, DateTime(2024, 5, 1), isOngoing: true),
          eventOn(4, DateTime(2027, 1, 1)),
        ], today),
        [2026, 2025, 2024, 2023, 2022, 2019]);
  });

  test('activityLevel: one shade per event, four and more alike', () {
    expect([0, 1, 2, 3, 4, 9].map(activityLevel), [0, 1, 2, 3, 4, 4]);
  });

  group('ActivityCalendar', () {
    // The day squares: their tooltip names a day (the year picker has one
    // too).
    Finder daySquares() => find.byWidgetPredicate((widget) =>
        widget is Tooltip && (widget.message ?? '').contains(', 20'));

    Future<void> pump(WidgetTester tester, List<Event> events,
        {DayRange? selected, void Function(DateTime)? onDayTap}) async {
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ActivityCalendar(
            events: events,
            today: today,
            color: '#f28b82',
            selected: selected,
            onDayTap: onDayTap ?? (_) {},
          ),
        ),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('a square per day of the last twelve months', (tester) async {
      await pump(tester, [eventOn(1, DateTime(2026, 10, 12))]);

      expect(find.text('Activity'), findsOneWidget);
      expect(find.text('Last 12 months'), findsOneWidget);
      expect(daySquares(), findsNWidgets(365));
      expect(find.byTooltip('1 event · Mon, Oct 12, 2026'), findsOneWidget);
    });

    testWidgets('a tap hands the day over', (tester) async {
      DateTime? tapped;
      await pump(tester, [eventOn(1, DateTime(2026, 10, 12))],
          onDayTap: (day) => tapped = day);

      await tester.tap(find.byTooltip('1 event · Mon, Oct 12, 2026'));

      expect(tapped, DateTime.utc(2026, 10, 12));
    });

    testWidgets('the selected days are outlined', (tester) async {
      await pump(tester, const [],
          selected: DayRange(DateTime(2026, 10, 12), DateTime(2026, 10, 13)));

      final outlined = tester
          .widgetList<Container>(find.byType(Container))
          .where((container) =>
              (container.decoration as BoxDecoration?)?.border != null);
      expect(outlined, hasLength(2));
    });

    testWidgets('turns to a year with results', (tester) async {
      await pump(tester, [
        eventOn(1, DateTime(2024, 2, 29)),
        eventOn(2, DateTime(2026, 10, 12)),
      ]);

      await tester.tap(find.text('Last 12 months'));
      await tester.pumpAndSettle();
      expect(find.text('2024'), findsOneWidget);
      expect(find.text('2025'), findsNothing, reason: 'no result in 2025');
      await tester.tap(find.text('2024'));
      await tester.pumpAndSettle();

      // A leap year, whole.
      expect(daySquares(), findsNWidgets(366));
      expect(find.byTooltip('1 event · Thu, Feb 29, 2024'), findsOneWidget);
    });
  });
}
