import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:homl/components/tag.dart' as components;
import 'package:homl/data/models/event.dart';
import 'package:homl/data/models/tag.dart';
import 'package:homl/helpers/event_feed.dart';
import 'package:homl/helpers/localizations.dart';
import 'package:homl/l10n/app_localizations.dart';
import 'package:homl/pages/list/view/event_feed.dart';

/// Category 1 holds the date tags, category 2 the regular ones.
Event eventOn(DateTime date,
    {int id = 1,
    List<String> tags = const ['Climbing'],
    String description = '',
    DateTime? endDate,
    bool isOngoing = false,
    bool isPending = false}) {
  return Event(
      id: id,
      description: description,
      date: date,
      endDate: endDate,
      isOngoing: isOngoing,
      isPending: isPending,
      tags: [
        Tag(id: 10, tag: 'October', idCategory: 1),
        Tag(id: 11, tag: '2026', idCategory: 1),
        for (var index = 0; index < tags.length; index++)
          Tag(id: 100 + index, tag: tags[index], idCategory: 2),
      ]);
}

void main() {
  group('eventFeed', () {
    test('puts a heading over each month, with its count', () {
      final events = [
        eventOn(DateTime(2026, 10, 25), id: 1),
        eventOn(DateTime(2026, 10, 18), id: 2),
        eventOn(DateTime(2026, 10, 5), id: 3),
        eventOn(DateTime(2026, 9, 28), id: 4),
        eventOn(DateTime(2025, 10, 12), id: 5),
        eventOn(DateTime(2025, 10, 1), id: 6),
      ];

      final feed = eventFeed(events);

      String describe(FeedItem item) => switch (item) {
            FeedMonth(:final month, :final count) =>
              '${month.year}-${month.month}:$count',
            FeedEvent(:final event, :final first, :final last) =>
              '${event.id}${first ? 'F' : ''}${last ? 'L' : ''}',
          };
      // The same month a year apart stays two headings.
      expect(feed.map(describe), [
        '2026-10:3', '1F', '2', '3L', //
        '2026-9:1', '4FL',
        '2025-10:2', '5F', '6L',
      ]);
    });

    test('an empty list has no heading', () {
      expect(eventFeed(const []), isEmpty);
    });
  });

  group('the list widgets', () {
    Future<void> pump(WidgetTester tester, Widget child,
        {String locale = 'en'}) async {
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: Locale(locale),
        home: Scaffold(body: ListView(children: [child])),
      ));
      await tester.pumpAndSettle();
    }

    EventRow rowOf(Event event, {VoidCallback? onTap}) => EventRow(
          event: event,
          first: true,
          last: true,
          tagColorResolver: (_) => '#ccff90',
          isDateTag: (tag) => tag.idCategory == 1,
          onTap: onTap,
        );

    testWidgets('a month heading starts with a capital and counts its events',
        (tester) async {
      await pump(tester, MonthHeader(month: DateTime(2026, 10), count: 5),
          locale: 'fr');
      expect(find.text('Octobre 2026'), findsOneWidget);
      expect(find.text('5 événements'), findsOneWidget);

      await pump(tester, MonthHeader(month: DateTime(2026, 9), count: 1));
      expect(find.text('September 2026'), findsOneWidget);
      expect(find.text('1 event'), findsOneWidget);
    });

    testWidgets('a row shows the day, every tag but the date ones',
        (tester) async {
      final tags = ['Climbing', 'Tom', 'Bouldering gym', 'Friends', 'Evening'];
      await pump(
          tester,
          rowOf(eventOn(DateTime(2026, 10, 25),
              tags: tags, description: 'First 6a, forearms on fire.')));

      expect(find.text('25'), findsOneWidget);
      expect(find.text('SUN'), findsOneWidget);
      for (final tag in tags) {
        expect(find.widgetWithText(components.Tag, tag), findsOneWidget);
      }
      // The heading above already says the month and the year.
      expect(find.text('October'), findsNothing);
      expect(find.text('2026'), findsNothing);
      expect(find.text('First 6a, forearms on fire.'), findsOneWidget);
    });

    testWidgets('a period says where it ends, and how long it lasts',
        (tester) async {
      await pump(
          tester,
          rowOf(eventOn(DateTime(2026, 10, 12),
              endDate: DateTime(2026, 10, 18))));
      expect(find.text('→ Oct 18 · 7 days'), findsOneWidget);

      // The year only when the end is in another one.
      await pump(
          tester,
          rowOf(
              eventOn(DateTime(2026, 12, 28), endDate: DateTime(2027, 1, 3))));
      expect(find.text('→ Jan 3, 2027 · 7 days'), findsOneWidget);
    });

    testWidgets('an open period reads as ongoing', (tester) async {
      await pump(
          tester, rowOf(eventOn(DateTime(2026, 10, 5), isOngoing: true)));
      expect(find.textContaining('→ Ongoing'), findsOneWidget);
    });

    testWidgets('a change made offline wears the clock, and a tap opens it',
        (tester) async {
      var tapped = 0;
      await pump(
          tester,
          rowOf(eventOn(DateTime(2026, 9, 2), isPending: true),
              onTap: () => tapped++));
      expect(find.byIcon(Icons.schedule), findsOneWidget);

      await tester.tap(find.widgetWithText(components.Tag, 'Climbing'));
      expect(tapped, 1);
    });
  });
}
