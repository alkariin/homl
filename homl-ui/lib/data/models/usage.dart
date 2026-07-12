import 'package:json_annotation/json_annotation.dart';

part 'usage.g.dart';

/// Event counts for a tag's synonym group, shown in the delete confirmation
/// dialog: [events] references the group at all, [exclusiveEvents] have no
/// other non-date tag (deleting the group would leave them date-only).
@JsonSerializable()
class TagUsage {
  final int events;
  final int exclusiveEvents;

  TagUsage({required this.events, required this.exclusiveEvents});

  factory TagUsage.fromJson(Map<String, dynamic> json) =>
      _$TagUsageFromJson(json);

  Map<String, dynamic> toJson() => _$TagUsageToJson(this);
}

/// Tag and event counts for a category, shown in the delete confirmation
/// dialog. [exclusiveEvents] counts the events whose only non-date tags live
/// in the category.
@JsonSerializable()
class CategoryUsage {
  final int tags;
  final int events;
  final int exclusiveEvents;

  CategoryUsage(
      {required this.tags, required this.events, required this.exclusiveEvents});

  factory CategoryUsage.fromJson(Map<String, dynamic> json) =>
      _$CategoryUsageFromJson(json);

  Map<String, dynamic> toJson() => _$CategoryUsageToJson(this);
}
