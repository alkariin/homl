import 'dart:ui' show Locale;

import 'package:intl/intl.dart';

import 'package:homl/l10n/app_localizations.dart';

/// English month names of the date tags. The backend builds them that way
/// (`event.DateTagNames`, read by `eventsService.buildDateTags`) and the
/// client mirrors it under E2EE, so an enable/disable round trip is stable.
/// The same list doubles as the tag blacklist (masterdata BLACKLIST_TAGS),
/// enforced client-side under E2EE because the server cannot read encrypted
/// tag names.
const dateTagMonths = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// The backend-managed date tag of an open period ("started, no end yet"):
/// stored in English like the month names, reserved like them, and what
/// "what is going on right now" filters on.
const dateTagOngoing = 'Ongoing';

/// Whether [name] is the Ongoing date tag, whatever its casing.
bool isOngoingTagName(String name) =>
    name.trim().toLowerCase() == dateTagOngoing.toLowerCase();

/// Names of the date tags an event's period is filed under — the mirror of
/// the backend `event.DateTagNames()`, which E2EE accounts need because the
/// server cannot derive them from what it stores for them: the English month
/// name and the year of every month from [date] to [endDate] (inclusive),
/// plus [dateTagOngoing] when [isOngoing]. An open period is tagged from its
/// start month only: it has no known end, and "today" would go stale
/// tomorrow. The result is a set — the order carries no meaning.
List<String> periodDateTagNames(
    {required DateTime date, DateTime? endDate, bool isOngoing = false}) {
  final end = endDate ?? date;
  final names = <String>[];
  void add(String name) {
    if (!names.contains(name)) names.add(name);
  }

  // Month by month, both bounds pinned to the first of their month so a
  // start on the 31st cannot skip February on its way to March.
  var cursor = DateTime.utc(date.year, date.month);
  final last = DateTime.utc(end.year, end.month);
  while (!cursor.isAfter(last)) {
    add(dateTagMonths[cursor.month - 1]);
    add(cursor.year.toString());
    cursor = DateTime.utc(cursor.year, cursor.month + 1);
  }

  if (isOngoing) add(dateTagOngoing);
  return names;
}

/// 1-based month of a month date tag, null when [name] is not one of the
/// English month names.
int? monthOfTagName(String name) {
  final trimmed = name.trim().toLowerCase();
  for (var index = 0; index < dateTagMonths.length; index++) {
    if (dateTagMonths[index].toLowerCase() == trimmed) return index + 1;
  }
  return null;
}

/// Month name in [locale] ("juillet" in fr, "Juli" in de), as `intl` spells
/// it — including its casing, which is not the same in every language.
String monthLabel(int month, String locale) =>
    DateFormat.MMMM(locale).format(DateTime(2000, month));

/// Display name of the Ongoing tag in [locale] — the same word as the card
/// badge, taken from the app strings since `intl` has nothing for it, unlike
/// the months. [locale] is what `Localizations.localeOf(context).toString()`
/// gives ("fr", "en_US"): only its language part selects the strings.
String ongoingLabel(String locale) =>
    lookupAppLocalizations(Locale(locale.split('_').first)).event_ongoing;

/// Label to display for the tag [name]: the stored name, except for a date
/// tag — a month name or Ongoing — which is translated to the app locale. The
/// date tags are stored in English for every user (they are keys shared with
/// the backend), so the translation only ever happens on the way to the
/// screen: the stored name is what the callbacks report and what the
/// requests carry.
String localizedTagName(String name, String locale) {
  if (isOngoingTagName(name)) return ongoingLabel(locale);
  final month = monthOfTagName(name);
  return month == null ? name : monthLabel(month, locale);
}
