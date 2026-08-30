import 'package:flutter_test/flutter_test.dart';
import 'package:homl/data/models/category.dart';
import 'package:homl/helpers/category_labels.dart';
import 'package:homl/l10n/app_localizations_en.dart';
import 'package:homl/l10n/app_localizations_fr.dart';

Category category(String name, CategoryKind? kind) => Category(
    id: 1,
    category: name,
    color: '#999999',
    isLocked: false,
    kind: kind,
    tags: []);

void main() {
  final fr = AppLocalizationsFr();
  final en = AppLocalizationsEn();

  test('the default categories are translated to the app language', () {
    expect(localizedCategoryName(category('Dates', CategoryKind.date), fr),
        'Dates');
    expect(localizedCategoryName(category('Persons', CategoryKind.person), fr),
        'Personnes');
    expect(localizedCategoryName(category('Others', CategoryKind.other), fr),
        'Autres');
    expect(localizedCategoryName(category('Others', CategoryKind.other), en),
        'Others');
  });

  test('a renamed Persons category shows the name the user gave it', () {
    expect(localizedCategoryName(category('Famille', CategoryKind.person), fr),
        'Famille');
  });

  test('custom categories are never translated, even named like a default', () {
    expect(localizedCategoryName(category('Hobbies', CategoryKind.custom), fr),
        'Hobbies');
    expect(localizedCategoryName(category('Others', CategoryKind.custom), fr),
        'Others');
  });

  test('a legacy backend without the kind falls back to the seeded names', () {
    expect(localizedCategoryName(category('Persons', null), fr), 'Personnes');
    expect(localizedCategoryName(category('Others', null), fr), 'Autres');
    expect(localizedCategoryName(category('Hobbies', null), fr), 'Hobbies');
  });
}
