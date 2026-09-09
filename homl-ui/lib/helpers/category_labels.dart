import 'package:homl/data/models/category.dart';
import 'package:homl/l10n/app_localizations.dart';

/// Names the backend seeds the default categories with (masterdata
/// `constants.json`). They are stored in English for every user, whatever the
/// language picked at registration.
const defaultDatesName = 'Dates';
const defaultPersonsName = 'Persons';
const defaultOthersName = 'Others';

/// Label to display for [category]: the stored name, except for the default
/// categories which are translated to the app language. Like the month date
/// tags, the translation only happens on the way to the screen — the stored
/// name is what the requests carry.
///
/// Dates and Others are locked, so their stored name is always the seeded
/// one. Persons is renamable: it is translated while it still wears the
/// seeded name and shows the user's own name as soon as it was renamed. A
/// custom category the user happened to call "Others" keeps its name.
String localizedCategoryName(Category category, AppLocalizations l10n) {
  switch (category.kind) {
    case CategoryKind.date:
      return l10n.categories_defaultDates;
    case CategoryKind.other:
      return l10n.categories_defaultOthers;
    case CategoryKind.person:
      return category.category == defaultPersonsName
          ? l10n.categories_defaultPersons
          : category.category;
    case CategoryKind.custom:
      return category.category;
    case null:
      // Legacy backend without the kind: fall back to the seeded names.
      switch (category.category) {
        case defaultDatesName:
          return l10n.categories_defaultDates;
        case defaultPersonsName:
          return l10n.categories_defaultPersons;
        case defaultOthersName:
          return l10n.categories_defaultOthers;
      }
      return category.category;
  }
}
