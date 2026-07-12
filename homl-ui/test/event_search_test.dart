import 'package:flutter_test/flutter_test.dart';

import 'package:homl/data/models/category.dart';
import 'package:homl/data/models/event.dart';
import 'package:homl/data/models/tag.dart';
import 'package:homl/helpers/event_search.dart';

Tag tag(int id, String name, {int? parent}) =>
    Tag(id: id, tag: name, idCategory: 1, idParentTag: parent);

Event event(int id, List<Tag> tags) =>
    Event(id: id, description: 'event $id', date: DateTime(2026), tags: tags);

Category cat(int id, List<Tag> tags) => Category(
    id: id, category: 'Category $id', color: '#fff', isLocked: false, tags: tags);

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

  group('filterEventsByTags', () {
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

    test('returns every event when no filter is set', () {
      expect(filterEventsByTags(all, categories, []), all);
    });

    test('matches whatever casing the user typed', () {
      expect(filterEventsByTags(all, categories, ['movie NIGHT']), [movie]);
    });

    test('matches through the whole synonym group, both directions', () {
      expect(filterEventsByTags(all, categories, ['foot']), [football, foot]);
      expect(
          filterEventsByTags(all, categories, ['Football']), [football, foot]);
    });

    test('uses AND semantics across filters', () {
      final both = event(4, [tag(1, 'Football'), tag(3, 'Movie Night')]);
      expect(
          filterEventsByTags(
              [...all, both], categories, ['football', 'movie night']),
          [both]);
    });

    test('matches no event for an unknown tag name', () {
      expect(filterEventsByTags(all, categories, ['Nowhere']), isEmpty);
    });
  });
}
