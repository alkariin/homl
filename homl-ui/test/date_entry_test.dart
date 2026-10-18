import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:homl/helpers/date_entry.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<MaterialLocalizations> load(String locale) =>
      GlobalMaterialLocalizations.delegate.load(Locale(locale));

  group('parseDigitsDate', () {
    test('day first in French and German', () async {
      for (final locale in ['fr', 'de']) {
        expect(parseDigitsDate('18102026', await load(locale)),
            DateTime(2026, 10, 18),
            reason: locale);
      }
    });

    test('month first in US English', () async {
      final en = await load('en');

      expect(parseDigitsDate('10182026', en), DateTime(2026, 10, 18));
      expect(parseDigitsDate('18102026', en), isNull, reason: 'no month 18');
    });

    test('a day the calendar does not have is refused', () async {
      final fr = await load('fr');

      expect(parseDigitsDate('31022026', fr), isNull);
      expect(parseDigitsDate('00102026', fr), isNull);
      expect(parseDigitsDate('29022028', fr), DateTime(2028, 2, 29));
    });

    test('anything but eight digits is left to the locale format', () async {
      final fr = await load('fr');

      for (final input in ['1810202', '181020266', '18/10/2026', '', null]) {
        expect(parseDigitsDate(input, fr), isNull, reason: '$input');
      }
    });
  });

  test('the picker reads the digits and still the locale format', () async {
    final fr = await load('fr');
    const calendar = DigitsDateCalendarDelegate();

    expect(calendar.parseCompactDate(' 18102026 ', fr), DateTime(2026, 10, 18));
    expect(calendar.parseCompactDate('18/10/2026', fr), DateTime(2026, 10, 18));
    expect(calendar.parseCompactDate('18-10', fr), isNull);
  });
}
