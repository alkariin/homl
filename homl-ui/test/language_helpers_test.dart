import 'package:flutter_test/flutter_test.dart';
import 'package:homl/helpers/language.dart';

void main() {
  group('Language helpers', () {
    test('stringToLanguage resolves known locales', () {
      expect(stringToLanguage('fr'), Language.fr);
      expect(stringToLanguage('de'), Language.de);
      expect(stringToLanguage('en'), Language.en);
    });

    test('stringToLanguage falls back to english for unknown locales', () {
      expect(stringToLanguage('es'), Language.en);
      expect(stringToLanguage(null), Language.en);
    });

    test('languageToLongString maps enum values to labels', () {
      expect(languageToLongString(Language.en), english);
      expect(languageToLongString(Language.fr), french);
      expect(languageToLongString(Language.de), german);
    });
  });
}
