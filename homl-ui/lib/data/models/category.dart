import 'package:homl/data/models/tag.dart';
import 'package:json_annotation/json_annotation.dart';

part 'category.g.dart';

@JsonSerializable()
class Category {
  final int id;
  final String category;
  final String color;
  final bool isLocked;
  final List<Tag> tags;

  Category(
      {required this.id,
      required this.category,
      required this.color,
      required this.isLocked,
      required this.tags});

  factory Category.fromJson(Map<String, dynamic> json) =>
      _$CategoryFromJson(json);

  Map<String, dynamic> toJson() => _$CategoryToJson(this);
}
