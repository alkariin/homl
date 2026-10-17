import 'package:flutter_test/flutter_test.dart';

import 'package:homl/data/models/category.dart';
import 'package:homl/data/models/event.dart';
import 'package:homl/data/models/tag.dart';
import 'package:homl/helpers/event_search.dart';

Tag tag(int id, String name, {int? parent}) =>
    Tag(id: id, tag: name, idCategory: 1, idParentTag: parent);

Event event(int id, List<Tag> tags) => Event(
    id: id,
    description: 'event $id',
    date: DateTime(2026),
    isOngoing: false,
    tags: tags);

Category cat(int id, List<Tag> tags) => Category(
    id: id,
    category: 'Category $id',
    color: '#fff',
    isLocked: false,
    tags: tags);

void main() {
  group('normalizeTagName', () {
    test('mirrors the backend title-case normalization', () {
      expect(normalizeTagName('movie night'), 'Movie Night');
      expect(normalizeTagName('MOVIE NIGHT'), 'Movie Night');
      expect(normalizeTagName('jean-PIERRE'), 'Jean-Pierre');
      expect(normalizeTagName('Already Fine'), 'Already Fine');
      expect(normalizeTagName(''), '');
    });
  });

  group('SearchTerm.parse', () {
    test('a plain term', () {
      expect(SearchTerm.parse('  movie   night '),
          const SearchTerm('movie night'));
    });

    test('a leading - excludes', () {
      expect(SearchTerm.parse('-Bob'), const SearchTerm('Bob', exclude: true));
      expect(SearchTerm.parse('- Bob'), const SearchTerm('Bob', exclude: true));
    });

    test('quotes search the descriptions only, closing one optional', () {
      expect(
          SearchTerm.parse('"Paris"'), const SearchTerm('Paris', quoted: true));
      expect(
          SearchTerm.parse('"Paris'), const SearchTerm('Paris', quoted: true));
      expect(SearchTerm.parse('-"a beach"'),
          const SearchTerm('a beach', exclude: true, quoted: true));
    });

    test('typographic quotes from a phone keyboard', () {
      for (final typed in [
        '\u201cParis\u201d',
        '\u201eParis\u201c',
        '\u00ab Paris \u00bb',
      ]) {
        expect(SearchTerm.parse(typed), const SearchTerm('Paris', quoted: true),
            reason: typed);
      }
    });

    test('nothing left to search', () {
      for (final typed in ['', '  ', '-', '""', '- " "']) {
        expect(SearchTerm.parse(typed), isNull, reason: typed);
      }
    });

    test('typed back the way its chip is named', () {
      expect(SearchTerm.parse('-"a beach"')!.typed, '-"a beach"');
      expect(SearchTerm.parse('Bob')!.typed, 'Bob');
    });

    test('a quoted term names no tag', () {
      expect(const SearchTerm('movie night').tagName, 'Movie Night');
      expect(const SearchTerm('Paris', quoted: true).tagName, isNull);
    });
  });

  group('foldForSearch', () {
    test('drops case, accents and curly apostrophes', () {
      expect(foldForSearch('CAF\u00c9 NA\u00cfVE, Zo\u00eb\u2019s'),
          "cafe naive, zoe's");
      expect(foldForSearch('Man\u0153uvre, Encyclop\u00e6dia, Gro\u00df'),
          'manoeuvre, encyclopaedia, gross');
    });

    test('any run of spaces is one', () {
      expect(foldForSearch('a  \n b'), 'a b');
    });
  });

  group('searchEvents', () {
    // Football(1) has the synonym Foot(2); Movie Night(3) stands alone.
    final categories = [
      cat(1, [
        tag(1, 'Football'),
        tag(2, 'Foot', parent: 1),
        tag(3, 'Movie Night'),
      ]),
    ];
    final football = event(1, [tag(1, 'Football')]);
    final foot = event(2, [tag(2, 'Foot', parent: 1)]);
    final movie = event(3, [tag(3, 'Movie Night')]);
    final all = [football, foot, movie];
    final today = DateTime(2026, 10, 17);

    List<Event> search(List<Event> events, List<String> typed,
            {DayRange? range}) =>
        searchEvents(events, categories,
            terms: typed.map((t) => SearchTerm.parse(t)!).toList(),
            range: range,
            today: today);

    test('returns every event when nothing is set', () {
      expect(search(all, []), all);
    });

    test('matches whatever casing the user typed', () {
      expect(search(all, ['movie NIGHT']), [movie]);
    });

    test('matches through the whole synonym group, both directions', () {
      expect(search(all, ['foot']), [football, foot]);
      expect(search(all, ['Football']), [football, foot]);
    });

    test('uses AND semantics across terms', () {
      final both = event(4, [tag(1, 'Football'), tag(3, 'Movie Night')]);
      expect(search([...all, both], ['football', 'movie night']), [both]);
    });

    test('an exclusion leaves out the whole synonym group', () {
      final both = event(4, [tag(1, 'Football'), tag(3, 'Movie Night')]);
      expect(search([...all, both], ['-foot']), [movie]);
      expect(search([...all, both], ['movie night', '-football']), [movie]);
    });

    group('a term naming no tag', () {
      Event described(int id, String text, [List<Tag> tags = const []]) =>
          Event(
              id: id,
              description: text,
              date: DateTime(2026),
              isOngoing: false,
              tags: tags);
      final beach = described(5, 'A day at the BEACH with Alice.');
      final cafe = described(6, 'Caf\u00e9 by the sea', [tag(1, 'Football')]);
      final film = described(7, 'Saw a football movie');
      final texts = [beach, cafe, film];

      test('is looked up in the descriptions', () {
        expect(search(texts, ['beach']), [beach]);
        expect(search(texts, ['day at the']), [beach]);
        expect(search(texts, ['Nowhere']), isEmpty);
      });

      test('ignoring case and accents', () {
        expect(search(texts, ['cafe by']), [cafe]);
        expect(search(texts, ['CAF\u00c9']), [cafe]);
      });

      test('can be excluded', () {
        expect(search(texts, ['-beach']), [cafe, film]);
      });

      test('quoted, a tag name is a text too', () {
        expect(search(texts, ['football']), [cafe]);
        expect(search(texts, ['"football"']), [film]);
        expect(search(texts, ['-"football"']), [beach, cafe]);
      });

      test('mixes with the tags', () {
        expect(search(texts, ['football', 'sea']), [cafe]);
      });
    });

    group('a day range', () {
      Event on(int id, DateTime date, {DateTime? end, bool ongoing = false}) =>
          Event(
              id: id,
              description: '',
              date: date,
              endDate: end,
              isOngoing: ongoing,
              tags: const []);
      final before = on(1, DateTime(2018, 12, 31));
      final first = on(2, DateTime(2019, 1, 1));
      final last = on(3, DateTime(2021, 12, 31));
      final after = on(4, DateTime(2022, 1, 1));
      final across = on(5, DateTime(2018, 6, 1), end: DateTime(2019, 2, 1));
      final around = on(6, DateTime(2010, 1, 1), end: DateTime(2030, 1, 1));
      final open = on(7, DateTime(2015, 1, 1), ongoing: true);
      final openLater = on(8, DateTime(2024, 1, 1), ongoing: true);
      final events = [
        before,
        first,
        last,
        after,
        across,
        around,
        open,
        openLater
      ];

      test('keeps what took place on one of its days, both ends included', () {
        expect(
            search(events, [],
                range: DayRange(DateTime(2019, 1, 1), DateTime(2021, 12, 31))),
            [first, last, across, around, open]);
      });

      test('an open period runs until today', () {
        expect(
            search(events, [],
                range: DayRange(DateTime(2026, 1, 1), DateTime(2026, 12, 31))),
            [around, open, openLater]);
        expect(
            search(events, [],
                range: DayRange(DateTime(2027, 1, 1), DateTime(2027, 12, 31))),
            [around]);
      });

      test('a single day', () {
        expect(
            search(events, [],
                range: DayRange(DateTime(2022, 1, 1), DateTime(2022, 1, 1))),
            [after, around, open]);
      });

      test('the server UTC midnight and a picked local day agree', () {
        final utc = on(9, DateTime.utc(2019, 1, 1));
        expect(
            search([utc], [],
                range: DayRange(DateTime(2019, 1, 1), DateTime(2019, 1, 1))),
            [utc]);
      });

      test('narrows the terms', () {
        final tagged = Event(
            id: 10,
            description: '',
            date: DateTime(2020, 5, 5),
            isOngoing: false,
            tags: [tag(3, 'Movie Night')]);
        expect(
            search([...events, tagged, movie], ['movie night'],
                range: DayRange(DateTime(2019, 1, 1), DateTime(2021, 12, 31))),
            [tagged]);
      });
    });
  });
}
