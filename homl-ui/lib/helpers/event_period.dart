import 'package:homl/l10n/app_localizations.dart';

/// Unit a period's length is shown in. Rescaled so the badge stays readable:
/// "847 days" is noise, "2 years" is information.
enum PeriodUnit { days, months, years }

/// Length of a period in its display unit.
class PeriodLength {
  final int count;
  final PeriodUnit unit;

  const PeriodLength(this.count, this.unit);

  @override
  bool operator ==(Object other) =>
      other is PeriodLength && other.count == count && other.unit == unit;

  @override
  int get hashCode => Object.hash(count, unit);

  @override
  String toString() => '$count ${unit.name}';
}

/// Spans of at least this many days are counted in months.
const int monthsFromDays = 31;

/// Spans of at least this many calendar months are counted in years. A full
/// year therefore reads "12 months": years only take over once "1 year"
/// would no longer hide a meaningful remainder.
const int yearsFromMonths = 24;

/// Calendar day of [t] — the time of day and the timezone dropped, so that
/// the picker's local midnight and the backend's UTC midnight are the same
/// day and day arithmetic never crosses a DST change.
DateTime dayOf(DateTime t) => DateTime.utc(t.year, t.month, t.day);

/// Length of the inclusive span [start, endInclusive].
///
/// Months are counted on the calendar and on the *exclusive* end
/// `E = endInclusive + 1 day`, so that the month count agrees with the
/// inclusive day count: 1 → 31 March is exactly one month and 1 January →
/// 31 December twelve; run on the inclusive end itself those come out as 0
/// and 11. With the exclusive end the months branch cannot yield 0 for a span
/// that reached [monthsFromDays] (a same-month span is at most 30 days, a
/// next-month span with `E.day < start.day` is shorter than a month); the
/// clamp only guards the arithmetic.
PeriodLength periodLength(DateTime start, DateTime endInclusive) {
  final first = dayOf(start);
  final exclusiveEnd = dayOf(endInclusive).add(const Duration(days: 1));

  final days = exclusiveEnd.difference(first).inDays;
  if (days < monthsFromDays) return PeriodLength(days, PeriodUnit.days);

  var months = (exclusiveEnd.year - first.year) * 12 +
      (exclusiveEnd.month - first.month);
  if (exclusiveEnd.day < first.day) months -= 1;
  if (months < 1) months = 1;
  if (months < yearsFromMonths) return PeriodLength(months, PeriodUnit.months);

  return PeriodLength(months ~/ 12, PeriodUnit.years);
}

/// Elapsed length of an open period started on [start], as of [today]: the
/// full days gone by, or null when none has — on the start day there is
/// nothing to say "since" about yet, and a start still in the future must
/// never read as a negative duration.
PeriodLength? ongoingLength(DateTime start, DateTime today) {
  final first = dayOf(start);
  final now = dayOf(today);
  if (!now.isAfter(first)) return null;
  return periodLength(first, now.subtract(const Duration(days: 1)));
}

/// "16 days", "3 months", "2 years" in the app language.
String periodLengthLabel(AppLocalizations l10n, PeriodLength length) {
  switch (length.unit) {
    case PeriodUnit.days:
      return l10n.event_durationDays(length.count);
    case PeriodUnit.months:
      return l10n.event_durationMonths(length.count);
    case PeriodUnit.years:
      return l10n.event_durationYears(length.count);
  }
}

/// "for 2 years" / "depuis 2 ans" / "seit 2 Jahren": the elapsed length of an
/// open period. One key per unit rather than a composed string, because
/// German declines the noun after "seit".
String sinceLabel(AppLocalizations l10n, PeriodLength length) {
  switch (length.unit) {
    case PeriodUnit.days:
      return l10n.event_sinceDays(length.count);
    case PeriodUnit.months:
      return l10n.event_sinceMonths(length.count);
    case PeriodUnit.years:
      return l10n.event_sinceYears(length.count);
  }
}
