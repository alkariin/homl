import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';

import 'package:homl/helpers/date_tags.dart';
import 'package:homl/helpers/event_period.dart';
import 'package:homl/l10n/app_localizations.dart';

const everyMonth = [
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

void main() {
  group('periodLength', () {
    test('short spans are counted in inclusive days', () {
      expect(periodLength(DateTime(2026, 6, 3), DateTime(2026, 6, 18)),
          const PeriodLength(16, PeriodUnit.days));
      expect(periodLength(DateTime(2026, 3, 1), DateTime(2026, 3, 30)),
          const PeriodLength(30, PeriodUnit.days));
      // A one-day period cannot reach the app (the backend normalizes it to
      // a single day), but the arithmetic is sound for it.
      expect(periodLength(DateTime(2026, 6, 3), DateTime(2026, 6, 3)),
          const PeriodLength(1, PeriodUnit.days));
    });

    test('from 31 days on, calendar months counted on the exclusive end', () {
      // 1 → 31 March is exactly one month; run on the inclusive end the
      // formula would say zero.
      expect(periodLength(DateTime(2026, 3, 1), DateTime(2026, 3, 31)),
          const PeriodLength(1, PeriodUnit.months));
      // 15 January → 14 February: 31 days, the exclusive end is 15 February.
      expect(periodLength(DateTime(2026, 1, 15), DateTime(2026, 2, 14)),
          const PeriodLength(1, PeriodUnit.months));
      // 1 January → 31 December is a full year of twelve months (the
      // inclusive end would give eleven), shown in months because years
      // only take over at yearsFromMonths.
      expect(periodLength(DateTime(2026, 1, 1), DateTime(2026, 12, 31)),
          const PeriodLength(12, PeriodUnit.months));
      expect(periodLength(DateTime(2024, 3, 1), DateTime(2026, 2, 27)),
          const PeriodLength(23, PeriodUnit.months));
    });

    test('from 24 months on, whole years', () {
      expect(periodLength(DateTime(2024, 3, 1), DateTime(2026, 2, 28)),
          const PeriodLength(2, PeriodUnit.years));
      expect(periodLength(DateTime(2024, 3, 1), DateTime(2026, 8, 31)),
          const PeriodLength(2, PeriodUnit.years));
      expect(periodLength(DateTime(2019, 6, 3), DateTime(2026, 6, 2)),
          const PeriodLength(7, PeriodUnit.years));
    });

    test('the time of day and the timezone are irrelevant', () {
      // A picker gives local midnight, the backend UTC midnight: both are
      // the same calendar day.
      expect(
          periodLength(DateTime(2026, 6, 3, 23, 59), DateTime.utc(2026, 6, 18)),
          const PeriodLength(16, PeriodUnit.days));
    });
  });

  group('ongoingLength', () {
    final start = DateTime(2026, 6, 3);

    test('nothing has elapsed on the start day or before it', () {
      expect(ongoingLength(start, DateTime(2026, 6, 3)), isNull);
      // A start still in the future must never read as a negative duration.
      expect(ongoingLength(start, DateTime(2026, 5, 20)), isNull);
    });

    test('counts the full days gone by', () {
      expect(ongoingLength(start, DateTime(2026, 6, 4)),
          const PeriodLength(1, PeriodUnit.days));
      expect(ongoingLength(start, DateTime(2026, 7, 4)),
          const PeriodLength(1, PeriodUnit.months));
      expect(ongoingLength(start, DateTime(2028, 6, 3)),
          const PeriodLength(2, PeriodUnit.years));
    });
  });

  group('labels', () {
    final en = lookupAppLocalizations(const Locale('en'));
    final fr = lookupAppLocalizations(const Locale('fr'));
    final de = lookupAppLocalizations(const Locale('de'));

    test('length, plural and unit in the app language', () {
      expect(periodLengthLabel(en, const PeriodLength(16, PeriodUnit.days)),
          '16 days');
      expect(periodLengthLabel(en, const PeriodLength(1, PeriodUnit.months)),
          '1 month');
      expect(periodLengthLabel(fr, const PeriodLength(2, PeriodUnit.years)),
          '2 ans');
      expect(periodLengthLabel(de, const PeriodLength(3, PeriodUnit.months)),
          '3 Monate');
    });

    test('elapsed time declines where the language does', () {
      expect(sinceLabel(en, const PeriodLength(2, PeriodUnit.years)),
          'for 2 years');
      expect(sinceLabel(fr, const PeriodLength(1, PeriodUnit.days)),
          'depuis 1 jour');
      // German puts the noun in the dative after "seit": one key per unit.
      expect(sinceLabel(de, const PeriodLength(2, PeriodUnit.years)),
          'seit 2 Jahren');
      expect(sinceLabel(de, const PeriodLength(3, PeriodUnit.months)),
          'seit 3 Monaten');
    });
  });

  group('periodDateTagNames', () {
    // The shared vectors of the design (§5.4): the backend's
    // event.DateTagNames test runs this very table, and the two must agree
    // since E2EE accounts build their date tags here. Compared as sets — the
    // order carries no meaning.
    test('single day', () {
      expect(periodDateTagNames(date: DateTime(2026, 6, 3)),
          unorderedEquals(['June', '2026']));
    });

    test('closed, same month', () {
      expect(
          periodDateTagNames(
              date: DateTime(2026, 6, 3), endDate: DateTime(2026, 6, 18)),
          unorderedEquals(['June', '2026']));
    });

    test('closed, two months', () {
      expect(
          periodDateTagNames(
              date: DateTime(2026, 6, 28), endDate: DateTime(2026, 7, 5)),
          unorderedEquals(['June', 'July', '2026']));
    });

    test('closed, year boundary', () {
      expect(
          periodDateTagNames(
              date: DateTime(2025, 12, 28), endDate: DateTime(2026, 1, 5)),
          unorderedEquals(['December', 'January', '2025', '2026']));
    });

    test('closed, over a year', () {
      expect(
          periodDateTagNames(
              date: DateTime(2024, 3, 1), endDate: DateTime(2026, 8, 31)),
          unorderedEquals([...everyMonth, '2024', '2025', '2026']));
    });

    test('open: the start month only, plus Ongoing', () {
      expect(periodDateTagNames(date: DateTime(2024, 6, 3), isOngoing: true),
          unorderedEquals(['June', '2024', dateTagOngoing]));
    });

    test('a start on the 31st does not skip February', () {
      expect(
          periodDateTagNames(
              date: DateTime(2026, 1, 31), endDate: DateTime(2026, 3, 1)),
          unorderedEquals(['January', 'February', 'March', '2026']));
    });
  });
}
