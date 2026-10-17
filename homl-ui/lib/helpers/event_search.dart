import 'package:equatable/equatable.dart';
import 'package:homl/data/models/category.dart';
import 'package:homl/data/models/event.dart';
import 'package:homl/helpers/event_period.dart';

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

/// A term typed in the Search tab field. It stands for a tag when one bears
/// its name (a synonym included), and is otherwise looked up in the
/// descriptions. That is settled at search time, never when the term is
/// typed: a term set before the categories load, or before its tag exists,
/// still finds what it names.
class SearchTerm extends Equatable {
  /// What was typed, without its leading '-' and its quotes.
  final String text;

  /// Typed with a leading '-': the events it matches are left out.
  final bool exclude;

  /// Typed in quotes: always looked up in the descriptions, even when a tag
  /// bears the name.
  final bool quoted;

  const SearchTerm(this.text, {this.exclude = false, this.quoted = false});

  /// Reads a typed term: `-Bob` excludes, `"Paris"` searches the
  /// descriptions only, `-"Paris"` does both. The closing quote may be left
  /// out, and the typographic quotes a phone keyboard puts in work too. Null
  /// when nothing is left to search.
  static SearchTerm? parse(String typed) {
    var text = typed.trim().replaceAll(_spaces, ' ');
    var exclude = false;
    if (text.startsWith('-')) {
      exclude = true;
      text = text.substring(1).trim();
    }

    var quoted = false;
    if (text.isNotEmpty && _openingQuotes.contains(text[0])) {
      quoted = true;
      text = text.substring(1);
      if (text.isNotEmpty && _closingQuotes.contains(text[text.length - 1])) {
        text = text.substring(0, text.length - 1);
      }
      text = text.trim();
    }

    if (text.isEmpty) return null;
    return SearchTerm(text, exclude: exclude, quoted: quoted);
  }

  /// Name of the tag the term stands for when one bears it, in the stored
  /// casing; null for a quoted term, which is never a tag.
  String? get tagName => quoted ? null : normalizeTagName(text);

  /// The term as typed: what its chip is called, and how the field tells it
  /// is already chipped.
  String get typed => '${exclude ? '-' : ''}${quoted ? '"$text"' : text}';

  /// Same search, whether it includes or excludes.
  bool sameAs(SearchTerm other) =>
      other.quoted == quoted && other.text.toLowerCase() == text.toLowerCase();

  @override
  List<Object?> get props => [text, exclude, quoted];
}

/// An inclusive span of calendar days narrowing a search.
class DayRange extends Equatable {
  final DateTime first;
  final DateTime last;

  DayRange(DateTime first, DateTime last)
      : first = dayOf(first),
        last = dayOf(last);

  /// Whether [event] took place on one of the days at least. An open period
  /// runs until [today].
  bool overlaps(Event event, DateTime today) {
    final start = dayOf(event.date);
    var end = dayOf(event.endDate ?? event.date);
    if (event.isOngoing) {
      final now = dayOf(today);
      if (now.isAfter(end)) end = now;
    }
    return !start.isAfter(last) && !end.isBefore(first);
  }

  @override
  List<Object?> get props => [first, last];
}

/// The Search tab, run on the local data: the events matching every term and
/// taking place in [range].
///
/// A term naming a tag matches the way the backend search does
/// (FindEventsWithTags): through its whole synonym group (group root =
/// idParentTag ?? id), and through every homonym's group when several
/// categories have a tag of that name. Any other term is looked up in the
/// descriptions (see [foldForSearch]). A term with [SearchTerm.exclude]
/// keeps the events it does not match.
List<Event> searchEvents(List<Event> events, List<Category> categories,
    {List<SearchTerm> terms = const [],
    DayRange? range,
    required DateTime today}) {
  if (terms.isEmpty && range == null) {
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

  // Folded once per event, however many text terms there are.
  final folded = Map<Event, String>.identity();
  String descriptionOf(Event event) =>
      folded.putIfAbsent(event, () => foldForSearch(event.description));

  final matchers = terms.map((term) {
    final groups = groupsByName[term.tagName];
    final bool Function(Event) matches;
    if (groups != null) {
      matches = (event) =>
          event.tags.any((tag) => groups.contains(tag.idParentTag ?? tag.id));
    } else {
      final needle = foldForSearch(term.text);
      matches = (event) => descriptionOf(event).contains(needle);
    }
    return term.exclude ? (Event event) => !matches(event) : matches;
  }).toList();

  return events
      .where((event) =>
          (range == null || range.overlaps(event, today)) &&
          matchers.every((matches) => matches(event)))
      .toList();
}

/// [text] as the description search compares it: lower-cased, the accents
/// of the Latin letters dropped, curly apostrophes made straight and any run
/// of spaces made one, so "Ete", "l'ete" or two spaces typed by mistake still
/// find what was written with accents, a phone apostrophe or a line break.
String foldForSearch(String text) {
  final buffer = StringBuffer();
  for (final rune in text.toLowerCase().runes) {
    buffer.write(_folds[rune] ?? String.fromCharCode(rune));
  }
  return buffer.toString().replaceAll(_spaces, ' ');
}

final _spaces = RegExp(r'\s+');

/// Straight and typographic quotes (English, French and German keyboards).
const _openingQuotes = '"\u201c\u201e\u00ab';
const _closingQuotes = '"\u201d\u201c\u00bb';

/// Lower-case accented letters (escaped, so the source stays ASCII) and what
/// they fold to.
const _accents = {
  'a': '\u00e0\u00e1\u00e2\u00e3\u00e4\u00e5',
  'ae': '\u00e6',
  'c': '\u00e7',
  'e': '\u00e8\u00e9\u00ea\u00eb',
  'i': '\u00ec\u00ed\u00ee\u00ef',
  'n': '\u00f1',
  'o': '\u00f2\u00f3\u00f4\u00f5\u00f6\u00f8',
  'oe': '\u0153',
  'ss': '\u00df',
  'u': '\u00f9\u00fa\u00fb\u00fc',
  'y': '\u00fd\u00ff',
  "'": '\u2019\u02bc',
};

final _folds = {
  for (final entry in _accents.entries)
    for (final rune in entry.value.runes) rune: entry.key,
};
