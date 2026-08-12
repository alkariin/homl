import 'package:intl/intl.dart';

/// English month names of the date tags. The backend builds them that way
/// (`eventsService.buildDateTags`) and the client mirrors it under E2EE, so an
/// enable/disable round trip is stable. The same list doubles as the tag
/// blacklist (masterdata BLACKLIST_TAGS), enforced client-side under E2EE
/// because the server cannot read encrypted tag names.
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

/// Label to display for the tag [name]: the stored name, except for a month
/// date tag which is translated to the app locale. The date tags are stored
/// in English for every user (they are keys shared with the backend), so the
/// translation only ever happens on the way to the screen: the stored name is
/// what the callbacks report and what the requests carry.
String localizedTagName(String name, String locale) {
  final month = monthOfTagName(name);
  return month == null ? name : monthLabel(month, locale);
}
