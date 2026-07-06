import 'package:json_annotation/json_annotation.dart';

part 'tag.g.dart';

@JsonSerializable()
class Tag {
  final int id;
  final String tag;
  final int? idCategory;

  /// Id of the main tag when this tag is a synonym (null = main tag).
  final int? idParentTag;

  Tag({
    required this.id,
    required this.tag,
    this.idCategory,
    this.idParentTag,
  });

  factory Tag.fromJson(Map<String, dynamic> json) => _$TagFromJson(json);

  Map<String, dynamic> toJson() => _$TagToJson(this);
}
