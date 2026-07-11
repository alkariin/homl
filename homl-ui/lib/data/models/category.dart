import 'package:homl/data/models/tag.dart';
import 'package:json_annotation/json_annotation.dart';

part 'category.g.dart';

/// Backend-defined role of a category. Older backends do not send the field,
/// in which case [Category.kind] is null and callers must fall back to the
/// legacy id-arithmetic convention.
enum CategoryKind {
  @JsonValue('date')
  date,
  @JsonValue('person')
  person,
  @JsonValue('other')
  other,
  @JsonValue('custom')
  custom,
}

@JsonSerializable()
class Category {
  final int id;
  final String category;
  final String color;
  final bool isLocked;
  @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue)
  final CategoryKind? kind;
  final List<Tag> tags;

  Category(
      {required this.id,
      required this.category,
      required this.color,
      required this.isLocked,
      this.kind,
      required this.tags});

  factory Category.fromJson(Map<String, dynamic> json) =>
      _$CategoryFromJson(json);

  Map<String, dynamic> toJson() => _$CategoryToJson(this);
}
