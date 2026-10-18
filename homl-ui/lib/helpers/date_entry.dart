import 'package:material_ui/material_ui.dart';

/// The calendar of the app's date pickers. The typed entry (the pencil)
/// also reads a date written with digits only — "18102026" for 18/10/2026 —
/// since a phone's number keyboard often has no "/" or "." to type the
/// locale's own format, which is still read as before.
class DigitsDateCalendarDelegate extends GregorianCalendarDelegate {
  const DigitsDateCalendarDelegate();

  @override
  DateTime? parseCompactDate(
      String? inputString, MaterialLocalizations localizations) {
    return parseDigitsDate(inputString, localizations) ??
        super.parseCompactDate(inputString, localizations);
  }
}

final _eightDigits = RegExp(r'^\d{8}$');

/// [input] as eight digits — two for the day, two for the month, four for
/// the year — in the order of the locale's compact date (day first in
/// French or German, month first in US English). Null when it is not eight
/// digits or not a real day (31 February).
@visibleForTesting
DateTime? parseDigitsDate(String? input, MaterialLocalizations localizations) {
  final digits = input?.trim() ?? '';
  if (!_eightDigits.hasMatch(digits)) return null;

  final fields = <String, int>{};
  var at = 0;
  for (final field in _fieldOrder(localizations)) {
    final length = field == 'y' ? 4 : 2;
    fields[field] = int.parse(digits.substring(at, at + length));
    at += length;
  }

  final day = fields['d']!, month = fields['m']!, year = fields['y']!;
  final date = DateTime(year, month, day);
  // DateTime rolls an impossible day over to the next month: refuse it.
  if (date.year != year || date.month != month || date.day != day) {
    return null;
  }
  return date;
}

/// Where the day ('d'), the month ('m') and the year ('y') sit in the
/// locale's compact date, read off a probe whose three parts all differ.
List<String> _fieldOrder(MaterialLocalizations localizations) {
  final probe = localizations.formatCompactDate(DateTime(2033, 11, 22));
  final positions = {
    'd': probe.indexOf('22'),
    'm': probe.indexOf('11'),
    'y': probe.indexOf('2033'),
  };
  if (positions.values.any((position) => position < 0)) {
    return const ['d', 'm', 'y'];
  }
  return positions.keys.toList()
    ..sort((a, b) => positions[a]!.compareTo(positions[b]!));
}
