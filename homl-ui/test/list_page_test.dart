import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:homl/components/event_card.dart';
import 'package:homl/components/tag.dart' as components;
import 'package:homl/data/models/category.dart';
import 'package:homl/data/models/event.dart';
import 'package:homl/data/models/tag.dart';
import 'package:homl/helpers/event_search.dart';
import 'package:homl/helpers/localizations.dart';
import 'package:homl/l10n/app_localizations.dart';
import 'package:homl/pages/home/bloc/home_cubit.dart';
import 'package:homl/pages/list/bloc/list_cubit.dart';
import 'package:homl/pages/list/list.dart';
import 'package:homl/pages/list/view/last_time_summary.dart';
import 'package:homl/pages/list/view/on_this_day_strip.dart';
import 'package:homl/pages/list/view/period_timeline.dart';

class MockHomeCubit extends MockCubit<HomeState> implements HomeCubit {}

/// The page reads the real clock: the dates are built around it. On 29
/// February the anniversary is four years back, the only one that keeps it.
final now = DateTime.now();
final anniversary = DateTime(
    now.month == 2 && now.day == 29 ? now.year - 4 : now.year - 2,
    now.month,
    now.day);

final dentist = Tag(id: 1, tag: 'Dentist', idCategory: 2);
final cinema = Tag(id: 2, tag: 'Cinema', idCategory: 2);

Event eventOn(int id, DateTime date, List<Tag> tags) => Event(
    id: id, description: 'Event $id', date: date, isOngoing: false, tags: tags);

void main() {
  final categories = [
    Category(
        id: 2,
        category: 'Others',
        color: '#e8eaed',
        isLocked: true,
        kind: CategoryKind.other,
        tags: [dentist, cinema]),
  ];

  late MockHomeCubit homeCubit;
  late ListCubit listCubit;

  Future<void> pumpPage(WidgetTester tester, List<Event> events,
      {List<Category>? withCategories}) async {
    final shown = withCategories ?? categories;
    homeCubit = MockHomeCubit();
    whenListen(homeCubit, const Stream<HomeState>.empty(),
        initialState: HomeState.initial('user').copyWith(
            events: events,
            categories: shown,
            allTagsMap: {
              for (final category in shown)
                for (final tag in category.tags)
                  tag.tag:
                      TagView(tag.id, category.color, tag.tag, category.id),
            },
            initialized: true));
    listCubit = ListCubit(homeCubit);

    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: MultiBlocProvider(
          providers: [
            BlocProvider<HomeCubit>.value(value: homeCubit),
            BlocProvider<ListCubit>.value(value: listCubit),
          ],
          child: const ListPage(),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  tearDown(() => listCubit.close());

  testWidgets('the whole list opens on the events of this day', (tester) async {
    await pumpPage(tester, [
      eventOn(1, anniversary, [cinema]),
      eventOn(2, DateTime(2001, 1, 1), [dentist]),
    ]);

    expect(find.byType(OnThisDayStrip), findsOneWidget);
    expect(find.text('On this day'), findsOneWidget);
    // Once in the strip, once in the grid below it.
    expect(find.text('Event 1'), findsNWidgets(2));
    expect(find.byType(LastTimeSummary), findsNothing);
  });

  testWidgets('no strip without a memory', (tester) async {
    await pumpPage(tester, [
      eventOn(2, DateTime(2001, 1, 1), [dentist])
    ]);

    expect(find.byType(OnThisDayStrip), findsNothing);
  });

  testWidgets('a search trades the strip for its last time', (tester) async {
    await pumpPage(tester, [
      eventOn(1, anniversary, [cinema]),
      eventOn(2, DateTime(2001, 1, 1), [dentist]),
      eventOn(3, DateTime(2003, 6, 2), [dentist]),
    ]);

    listCubit.addTypedTerm('dentist');
    await tester.pumpAndSettle();

    expect(find.byType(OnThisDayStrip), findsNothing);
    expect(find.byType(LastTimeSummary), findsOneWidget);
    expect(find.text('2 events · none this year'), findsOneWidget);
  });

  testWidgets('a search with no past result says nothing', (tester) async {
    await pumpPage(tester, [
      eventOn(4, DateTime(now.year + 1, 1, 1), [dentist]),
    ]);

    listCubit.addTypedTerm('Dentist');
    await tester.pumpAndSettle();

    expect(find.text('Event 4'), findsOneWidget);
    expect(find.byType(LastTimeSummary), findsNothing);
  });

  group('the search field', () {
    final events = [
      eventOn(1, DateTime(2001, 1, 1), [dentist]),
      eventOn(2, DateTime(2003, 6, 2), [cinema]),
    ];

    components.Tag chipLabelled(WidgetTester tester, String label) =>
        tester.widget<components.Tag>(find.ancestor(
            of: find.text(label), matching: find.byType(components.Tag)));

    testWidgets('a typed - excludes the tag', (tester) async {
      await pumpPage(tester, events);

      await tester.enterText(find.byType(TextField), '-dentist');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(
          listCubit.state.terms, [const SearchTerm('Dentist', exclude: true)]);
      expect(chipLabelled(tester, 'Dentist').excluded, isTrue);
      expect(find.text('Event 1'), findsNothing);
      expect(find.text('Event 2'), findsOneWidget);
    });

    testWidgets('a term naming no tag is a text chip, in quotes',
        (tester) async {
      await pumpPage(tester, events);

      await tester.enterText(find.byType(TextField), 'event 2');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      final chip = chipLabelled(tester, '\u201cevent 2\u201d');
      expect(chip.color, '#e8eaed');
      expect(chip.excluded, isFalse);
      // The description matched, not a tag.
      expect(find.text('Event 2'), findsOneWidget);
      expect(find.text('Event 1'), findsNothing);

      // A tap on the chip takes the term away.
      await tester.tap(find.text('\u201cevent 2\u201d'));
      await tester.pumpAndSettle();
      expect(listCubit.state.terms, isEmpty);
    });

    testWidgets('the range is a chip of its own, a tap lifts it',
        (tester) async {
      await pumpPage(tester, events);

      listCubit
          .setRange(DayRange(DateTime(2003, 1, 1), DateTime(2003, 12, 31)));
      await tester.pumpAndSettle();

      final label = find.text('Jan 1, 2003 \u2013 Dec 31, 2003');
      expect(label, findsOneWidget);
      expect(chipLabelled(tester, 'Jan 1, 2003 \u2013 Dec 31, 2003').isDate,
          isTrue);
      expect(find.text('Event 1'), findsNothing);
      expect(find.text('Event 2'), findsOneWidget);

      await tester.tap(label);
      await tester.pumpAndSettle();
      expect(listCubit.state.range, isNull);
      expect(find.text('Event 1'), findsOneWidget);
    });

    testWidgets('the calendar button picks the range', (tester) async {
      await pumpPage(tester, events);

      await tester.tap(find.byTooltip('Filter by dates'));
      await tester.pumpAndSettle();
      expect(find.byType(DateRangePickerDialog), findsOneWidget);

      // Typed in, rather than scrolled to in the calendar.
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();
      final fields = find.byType(TextField);
      await tester.enterText(
          fields.at(fields.evaluate().length - 2), '6/1/2003');
      await tester.enterText(fields.last, '6/30/2003');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(listCubit.state.range,
          DayRange(DateTime(2003, 6, 1), DateTime(2003, 6, 30)));
      expect(find.text('Event 2'), findsOneWidget);
      expect(find.text('Event 1'), findsNothing);
    });
  });

  group('the timeline', () {
    // A Dates category first, as on a real account: the date tags are told
    // apart by their category.
    final dates = Category(
        id: 1,
        category: 'Dates',
        color: '#D3A934',
        isLocked: true,
        kind: CategoryKind.date,
        tags: []);
    final lisbon = Tag(id: 5, tag: 'Lisbon', idCategory: 3);
    final places = Category(
        id: 3,
        category: 'Places',
        color: '#ccff90',
        isLocked: false,
        kind: CategoryKind.custom,
        tags: [lisbon]);
    final withPlaces = [dates, places, ...categories];

    Event period(int id, DateTime date, List<Tag> tags,
            {DateTime? end, bool ongoing = false, String text = ''}) =>
        Event(
            id: id,
            description: text,
            date: date,
            endDate: end,
            isOngoing: ongoing,
            tags: tags);

    Future<void> pumpTimeline(WidgetTester tester, List<Event> events) async {
      await pumpPage(tester, events, withCategories: withPlaces);
      listCubit.toggleTimeline();
      await tester.pumpAndSettle();
    }

    testWidgets('takes the place of the grid and of the strip', (tester) async {
      await pumpTimeline(tester, [
        eventOn(1, anniversary, [cinema]),
        period(2, DateTime(2019, 3, 1), [lisbon],
            end: DateTime(2021, 6, 30), text: 'Moved'),
      ]);

      expect(find.byType(PeriodTimeline), findsOneWidget);
      expect(find.byType(OnThisDayStrip), findsNothing);
      expect(find.byType(EventCard), findsNothing);
      expect(find.text('Lisbon'), findsOneWidget);
      expect(find.text('2 years'), findsOneWidget);
      expect(find.text('1 single-day event is not shown'), findsOneWidget);

      // And back.
      listCubit.toggleTimeline();
      await tester.pumpAndSettle();
      expect(find.byType(PeriodTimeline), findsNothing);
      expect(find.byType(OnThisDayStrip), findsOneWidget);
    });

    testWidgets('a row is called by its tags, its description, its dates',
        (tester) async {
      await pumpTimeline(tester, [
        period(1, DateTime(2019, 3, 1), [lisbon], end: DateTime(2021, 6, 30)),
        period(2, DateTime(2015, 9, 1), [],
            end: DateTime(2016, 6, 30), text: 'Gap year\nthen more'),
        period(3, DateTime(2021, 3, 3), [], end: DateTime(2021, 6, 1)),
        period(4, DateTime(2024, 5, 1), [], ongoing: true),
      ]);

      expect(find.text('Lisbon'), findsOneWidget);
      expect(find.text('Gap year'), findsOneWidget);
      expect(find.text('Mar 2021 – Jun 2021'), findsOneWidget);
      expect(find.text('May 2024 – Ongoing'), findsOneWidget);
      expect(find.textContaining('single-day'), findsNothing);
    });

    testWidgets('a tap on a row opens its event', (tester) async {
      await pumpTimeline(tester, [
        period(1, DateTime(2019, 3, 1), [lisbon],
            end: DateTime(2021, 6, 30), text: 'Moved for the job'),
      ]);
      expect(find.text('Moved for the job'), findsNothing);

      await tester.tap(find.text('Lisbon'));
      await tester.pumpAndSettle();

      expect(find.text('Moved for the job'), findsOneWidget);
    });

    testWidgets('follows the search', (tester) async {
      await pumpTimeline(tester, [
        period(1, DateTime(2019, 3, 1), [lisbon], end: DateTime(2021, 6, 30)),
        period(2, DateTime(2010, 1, 1), [cinema], end: DateTime(2012, 1, 1)),
      ]);
      expect(find.text('Cinema'), findsOneWidget);

      listCubit.addTypedTerm('Lisbon');
      await tester.pumpAndSettle();

      expect(find.text('Lisbon'), findsWidgets);
      expect(find.text('Cinema'), findsNothing);
    });

    testWidgets('without a period, says what makes one', (tester) async {
      await pumpTimeline(tester, [
        eventOn(1, DateTime(2001, 1, 1), [cinema])
      ]);

      expect(
          find.text('No period here. An event with an end date, or still '
              'ongoing, shows up on the timeline.'),
          findsOneWidget);
    });
  });
}
