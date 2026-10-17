import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:homl/data/models/event.dart';
import 'package:homl/helpers/last_time.dart';
import 'package:homl/helpers/localizations.dart';
import 'package:homl/l10n/app_localizations.dart';
import 'package:homl/pages/list/view/last_time_summary.dart';

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

void main() {
  final today = DateTime(2026, 10, 17, 21, 30);

  group('lastTimeOf', () {
    test('nothing to say without a past event', () {
      expect(lastTimeOf([], today), isNull);
      expect(lastTimeOf([eventOn(1, DateTime(2026, 12, 24))], today), isNull);
    });

    test('the most recent day, whatever the list order', () {
      expect(
          lastTimeOf([
            eventOn(1, DateTime(2024, 3, 1)),
            eventOn(2, DateTime(2025, 8, 12)),
            eventOn(3, DateTime(2026, 2, 3)),
            eventOn(4, DateTime(2023, 5, 9)),
          ], today),
          LastTime(lastDay: DateTime.utc(2026, 2, 3), total: 4, thisYear: 1));
    });

    test('a closed period counts from its last day', () {
      expect(
          lastTimeOf([
            eventOn(1, DateTime(2026, 7, 1), endDate: DateTime(2026, 7, 15)),
            eventOn(2, DateTime(2026, 7, 10)),
          ], today)
              ?.lastDay,
          DateTime.utc(2026, 7, 15));
    });

    test('an event today is today, not now', () {
      final lastTime = lastTimeOf([eventOn(1, DateTime(2026, 10, 17))], today);
      expect(lastTime?.lastDay, DateTime.utc(2026, 10, 17));
      expect(lastTime?.isNow, isFalse);
    });

    test('an open period started in the past is going on now', () {
      final lastTime = lastTimeOf([
        eventOn(1, DateTime(2026, 9, 1)),
        eventOn(2, DateTime(2021, 4, 1), isOngoing: true),
      ], today);
      expect(lastTime?.isNow, isTrue);
      expect(lastTime?.total, 2);
    });

    test('so is a closed period not over yet, ending today included', () {
      expect(
          lastTimeOf([
            eventOn(1, DateTime(2026, 10, 10), endDate: DateTime(2026, 10, 20)),
          ], today)
              ?.isNow,
          isTrue);
      expect(
          lastTimeOf([
            eventOn(1, DateTime(2026, 10, 10), endDate: DateTime(2026, 10, 17)),
          ], today)
              ?.isNow,
          isTrue);
    });

    test('a plan is neither a last time nor counted', () {
      expect(
          lastTimeOf([
            eventOn(1, DateTime(2026, 3, 4)),
            eventOn(2, DateTime(2026, 11, 2)),
            eventOn(3, DateTime(2026, 12, 1), isOngoing: true),
          ], today),
          LastTime(lastDay: DateTime.utc(2026, 3, 4), total: 1, thisYear: 1));
    });

    test('this year counts by the start, from 1 January', () {
      expect(
          lastTimeOf([
            eventOn(1, DateTime(2025, 12, 20), endDate: DateTime(2026, 1, 5)),
            eventOn(2, DateTime(2026, 1, 1)),
            eventOn(3, DateTime(2026, 6, 30)),
          ], today),
          LastTime(lastDay: DateTime.utc(2026, 6, 30), total: 3, thisYear: 2));
    });
  });

  group('LastTimeSummary', () {
    Future<void> pumpSummary(WidgetTester tester, LastTime lastTime,
        {Locale locale = const Locale('en')}) async {
      await tester.pumpWidget(MaterialApp(
        locale: locale,
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: LastTimeSummary(lastTime: lastTime, today: today),
        ),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('how long ago, the day, then how often', (tester) async {
      await pumpSummary(tester,
          LastTime(lastDay: DateTime.utc(2025, 8, 12), total: 23, thisYear: 6));

      expect(
          find.text('Last time: 14 months ago · Aug 12, 2025',
              findRichText: true),
          findsOneWidget);
      expect(find.text('23 events · 6 this year'), findsOneWidget);
    });

    testWidgets('right now while one is going on', (tester) async {
      await pumpSummary(tester, const LastTime(total: 1, thisYear: 0));

      expect(find.text('Last time: right now', findRichText: true),
          findsOneWidget);
      expect(find.text('1 event · none this year'), findsOneWidget);
    });

    testWidgets('in French', (tester) async {
      await pumpSummary(tester,
          LastTime(lastDay: DateTime.utc(2026, 10, 16), total: 2, thisYear: 0),
          locale: const Locale('fr'));

      expect(find.textContaining('Dernière fois : hier · ', findRichText: true),
          findsOneWidget);
      expect(find.text('2 événements · aucun cette année'), findsOneWidget);
    });
  });
}
