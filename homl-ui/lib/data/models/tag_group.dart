import 'package:json_annotation/json_annotation.dart';

part 'tag_group.g.dart';

/// A named set of main tags of one category ("Family" = Alice and Bob),
/// which the tag inputs expand into its members when the user picks it. It
/// is never linked to an event (homl-web/docs/tag-groups.md).
@JsonSerializable()
class TagGroup {
  final int id;
  final String name;

  /// Ids of the member tags: main tags of the group's category. Empty once
  /// every member was deleted.
  @JsonKey(defaultValue: [])
  final List<int> members;

  TagGroup({required this.id, required this.name, required this.members});

  factory TagGroup.fromJson(Map<String, dynamic> json) =>
      _$TagGroupFromJson(json);

  Map<String, dynamic> toJson() => _$TagGroupToJson(this);
}
