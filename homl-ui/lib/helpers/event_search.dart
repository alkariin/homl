import 'package:homl/data/models/category.dart';
import 'package:homl/data/models/event.dart';

final _wordChar = RegExp(r'[\p{L}\p{N}]', unicode: true);

/// Mirrors the backend tag normalization (application.titleCase): the first
/// letter of every word is upper-cased and the rest lower-cased, a word
/// starting after any non-letter/non-digit rune ("MOVIE night" -> "Movie
/// Night", "jean-PIERRE" -> "Jean-Pierre"). Tags are stored in this canonical
/// form, so local matching must normalize the exact same way.
String normalizeTagName(String name) {
  final buffer = StringBuffer();
  var prevIsWordChar = false;
  for (final rune in name.runes) {
    final char = String.fromCharCode(rune);
    buffer.write(prevIsWordChar ? char.toLowerCase() : char.toUpperCase());
    prevIsWordChar = _wordChar.hasMatch(char);
  }
  return buffer.toString();
}

/// Replicates the backend search (FindEventsWithTags) on the local data:
/// AND semantics across [filters], each name matching through its whole
/// synonym group (group root = idParentTag ?? id). A name that exists in
/// several categories matches through every homonym's group. A name that
/// matches no tag matches no event, like the backend's HAVING count.
List<Event> filterEventsByTags(
    List<Event> events, List<Category> categories, List<String> filters) {
  if (filters.isEmpty) {
    return events;
  }

  // Tag name -> synonym-group roots of every tag carrying that name.
  final groupsByName = <String, Set<int>>{};
  for (final category in categories) {
    for (final tag in category.tags) {
      groupsByName
          .putIfAbsent(tag.tag, () => {})
          .add(tag.idParentTag ?? tag.id);
    }
  }

  final filterGroups = filters
      .map((f) => groupsByName[normalizeTagName(f.trim())] ?? const <int>{})
      .toList();

  return events.where((event) {
    final eventGroups = event.tags.map((t) => t.idParentTag ?? t.id).toSet();
    return filterGroups.every((groups) => groups.any(eventGroups.contains));
  }).toList();
}
