import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:homl/components/event_card.dart';
import 'package:homl/components/tag.dart' as components;
import 'package:homl/data/models/event.dart';
import 'package:homl/data/models/tag.dart';

/// Size of a grid cell on a phone (two columns, see the ListPage delegate).
const cardWidth = 165.0;
const cardHeight = 170.0;

const description = 'A description long enough for the card to fade it out '
    'instead of showing it whole.';

/// Category 1 holds the month/year date tags, category 2 the regular ones.
Event eventWith({required List<String> tags, String text = description}) {
  return Event(
      id: 1,
      description: text,
      date: DateTime(2026, 3, 15),
      tags: [
        Tag(id: 10, tag: 'March', idCategory: 1),
        Tag(id: 11, tag: '2026', idCategory: 1),
        for (var index = 0; index < tags.length; index++)
          Tag(id: 100 + index, tag: tags[index], idCategory: 2),
      ]);
}

void main() {
  Future<void> pumpCard(WidgetTester tester, Event event) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: cardWidth,
            height: cardHeight,
            child: EventCard(
              event: event,
              tagColorResolver: (_) => '#f28b82',
              isDateTag: (tag) => tag.idCategory == 1,
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  /// Chips whose row is fully inside the tags area, i.e. the ones the user
  /// actually sees (the rows that do not fit are clipped away).
  List<Rect> visibleTagRects(WidgetTester tester, {required double maxBottom}) {
    return tester
        .widgetList<components.Tag>(find.byType(components.Tag))
        .map((tag) => tester.getRect(find.byWidget(tag)))
        .where((rect) => rect.bottom <= maxBottom + 0.5)
        .toList();
  }

  Set<double> rowTops(Iterable<Rect> rects) =>
      rects.map((rect) => rect.top).toSet();

  testWidgets('the month and year tags are left out of the card',
      (tester) async {
    await pumpCard(tester, eventWith(tags: ['Football']));

    // The date is already printed at the top of the card.
    expect(find.text('Mar 15, 2026'), findsOneWidget);
    expect(find.text('March'), findsNothing);
    expect(find.text('2026'), findsNothing);
    expect(find.text('Football'), findsOneWidget);
  });

  testWidgets('a tag wider than the card is truncated, not overflowed',
      (tester) async {
    await pumpCard(tester, eventWith(tags: ['aTagWithAReallyVeryLongText']));

    final chip = tester.getRect(find.byType(components.Tag));
    // 12 of padding on each side of the card content.
    expect(chip.width, lessThanOrEqualTo(cardWidth - 24));
    expect(find.text('aTagWithAReallyVeryLongText'), findsOneWidget);
  });

  testWidgets('the description slides down to give the tags a second row',
      (tester) async {
    await pumpCard(
        tester, eventWith(tags: ['Alpha', 'Bravo', 'Charlie', 'Delta']));

    final descriptionRect = tester.getRect(find.text(description));
    final visible = visibleTagRects(tester, maxBottom: descriptionRect.top);

    expect(rowTops(visible).length, 2);
    // Never hidden: the description keeps a line inside the card.
    final card = tester.getRect(find.byType(EventCard));
    expect(descriptionRect.bottom, lessThanOrEqualTo(card.bottom + 0.5));
    expect(descriptionRect.height, greaterThan(0));
  });

  testWidgets('tags that still do not fit are dropped, description stays',
      (tester) async {
    await pumpCard(tester,
        eventWith(tags: ['Alpha', 'Bravo', 'Charlie', 'Delta', 'Echo', 'Foxtrot']));

    final descriptionRect = tester.getRect(find.text(description));
    final visible = visibleTagRects(tester, maxBottom: descriptionRect.top);

    expect(rowTops(visible).length, 2);
    expect(visible.length, lessThan(6));
    expect(descriptionRect.height, greaterThan(0));
  });

  testWidgets('a single tag row leaves the description its full room',
      (tester) async {
    await pumpCard(tester, eventWith(tags: ['Alpha']));

    final descriptionRect = tester.getRect(find.text(description));
    final visible = visibleTagRects(tester, maxBottom: descriptionRect.top);

    expect(rowTops(visible).length, 1);
    // Two rows would have pushed the description about a chip height lower.
    expect(descriptionRect.top - visible.first.bottom, lessThan(28));
  });
}
