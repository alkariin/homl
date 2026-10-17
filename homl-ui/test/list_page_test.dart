import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:homl/data/models/category.dart';
import 'package:homl/data/models/event.dart';
import 'package:homl/data/models/tag.dart';
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

    listCubit.addFilterTag('dentist');
    await tester.pumpAndSettle();

    expect(find.byType(OnThisDayStrip), findsNothing);
    expect(find.byType(LastTimeSummary), findsOneWidget);
    expect(find.text('2 events · none this year'), findsOneWidget);
  });

  testWidgets('a search with no past result says nothing', (tester) async {
    await pumpPage(tester, [
      eventOn(4, DateTime(now.year + 1, 1, 1), [dentist]),
    ]);

    listCubit.addFilterTag('Dentist');
    await tester.pumpAndSettle();

    expect(find.text('Event 4'), findsOneWidget);
    expect(find.byType(LastTimeSummary), findsNothing);
  });
}
