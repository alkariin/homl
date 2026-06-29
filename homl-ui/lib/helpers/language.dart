enum Language { fr, de, en }

const german = 'Deutsch';
const english = 'English';
const french = 'Français';

extension GetText on Language {
  String get longText {
    return languageToLongString(this);
  }

  String get text {
    return languageToString(this);
  }
}

/// Language.en -> "en"
String languageToString(Language lang) {
  return lang.name;
}

/// Language.en -> "English"
String languageToLongString(Language lang) {
  switch (lang) {
    case Language.de:
      return german;
    case Language.en:
      return english;
    case Language.fr:
      return french;
  }
}

/// "en" -> Language.en
Language stringToLanguage(String? locale) {
  try {
    return Language.values.byName(locale ?? '');
  } catch (_) {
    return Language.en;
  }
}

/// "English" -> Language.en
Language longStringToLanguage(String locale) {
  switch (locale) {
    case german:
      return Language.de;
    case english:
      return Language.en;
    case french:
      return Language.fr;
    default:
      return Language.en;
  }
}
