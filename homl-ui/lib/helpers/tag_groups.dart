import 'package:homl/components/tag_input.dart';
import 'package:homl/data/models/category.dart';
import 'package:homl/data/models/tag_group.dart';

/// Stored names of the tags [group] stands for, in the group's order. An id
/// the category no longer lists (a tag deleted meanwhile) is skipped.
List<String> tagGroupMemberNames(Category category, TagGroup group) {
  final names = {for (final tag in category.tags) tag.id: tag.tag};
  return [
    for (final id in group.members)
      if (names[id] case final name?) name
  ];
}

/// The tag groups of [categories] as tag input suggestions: picking one adds
/// its tags (see [TagChipData.members]). The chip wears the category color;
/// the Others groups keep the default input styling, like the Others tags.
/// A group with no tag left would add nothing and is not offered.
List<TagChipData> tagGroupSuggestions(List<Category> categories) => [
      for (final category in categories)
        for (final group in category.groups)
          if (tagGroupMemberNames(category, group) case final members
              when members.isNotEmpty)
            TagChipData(
              id: group.id,
              name: group.name,
              color: category.color,
              highlightColor:
                  category.kind == CategoryKind.other ? null : category.color,
              members: members,
            ),
    ];
