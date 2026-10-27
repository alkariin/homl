import 'package:homl/data/models/category.dart';

/// Ids of the categories holding the backend-managed date tags (month/year).
/// Legacy backends do not send the kind: fall back to the convention that the
/// first category is Dates (same rule as the categories page).
Set<int> dateCategoryIds(List<Category> categories) {
  final ids = categories
      .where((category) => category.kind == CategoryKind.date)
      .map((category) => category.id)
      .toSet();
  if (ids.isNotEmpty || categories.isEmpty) return ids;
  return {categories.first.id};
}

/// [categories] in the order the screens list them: the backend's (creation
/// order), except the Others bucket, always last. It is seeded with the
/// account, so a category created later would otherwise land below it.
List<Category> othersLast(List<Category> categories) => [
      for (final category in categories)
        if (category.kind != CategoryKind.other) category,
      for (final category in categories)
        if (category.kind == CategoryKind.other) category,
    ];
