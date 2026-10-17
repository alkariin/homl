import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

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

  Future<void> pumpPage(WidgetTester tester, List<Event> events) async {
    homeCubit = MockHomeCubit();
    whenListen(homeCubit, const Stream<HomeState>.empty(),
        initialState: HomeState.initial('user').copyWith(
            events: events,
            categories: categories,
            allTagsMap: {
              for (final tag in [dentist, cinema])
                tag.tag: TagView(tag.id, '#e8eaed', tag.tag, 2),
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
}
