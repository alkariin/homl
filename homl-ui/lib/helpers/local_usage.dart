import 'package:homl/data/models/category.dart';
import 'package:homl/data/models/event.dart';
import 'package:homl/data/models/usage.dart';

/// The delete dialog counts worked out from the data on the device, when the
/// server cannot be asked. Offline they are exactly right for what the
/// dialog offers: a deletion "with its events" made offline deletes the
/// events this device shows, never others (homl-web/docs/offline-sync.md).

/// The ids of the date tags (months, years, `Ongoing`): they never count as
/// another tag of an event.
Set<int> _dateTagIds(List<Category> categories) => {
      for (final category in categories)
        if (category.kind == CategoryKind.date)
          for (final tag in category.tags) tag.id,
    };

/// The tag [id] and its synonyms, from its main tag: the server deletes,
/// and counts, a synonym group as a whole.
Set<int> synonymGroup(List<Category> categories, int id) {
  for (final category in categories) {
    for (final tag in category.tags) {
      if (tag.id != id) continue;
      final main = tag.idParentTag ?? tag.id;
      return {
        main,
        for (final other in category.tags)
          if (other.idParentTag == main) other.id,
      };
    }
  }
  return {id};
}

({int events, int exclusiveEvents}) _count(
    List<Event> events, Set<int> tags, Set<int> dateTags) {
  var tagged = 0, exclusive = 0;
  for (final event in events) {
    if (!event.tags.any((tag) => tags.contains(tag.id))) continue;
    tagged++;
    final hasOther = event.tags
        .any((tag) => !tags.contains(tag.id) && !dateTags.contains(tag.id));
    if (!hasOther) exclusive++;
  }
  return (events: tagged, exclusiveEvents: exclusive);
}

/// How many [events] carry tag [id]'s synonym group, and how many carry
/// nothing else but date tags.
TagUsage localTagUsage(List<Event> events, List<Category> categories, int id) {
  final counts =
      _count(events, synonymGroup(categories, id), _dateTagIds(categories));
  return TagUsage(
      events: counts.events, exclusiveEvents: counts.exclusiveEvents);
}

/// The tags of category [id] (synonyms included), how many [events] carry
/// one of them, and how many carry nothing else but date tags.
CategoryUsage localCategoryUsage(
    List<Event> events, List<Category> categories, int id) {
  final tags = {
    for (final category in categories)
      if (category.id == id)
        for (final tag in category.tags) tag.id,
  };
  final counts = _count(events, tags, _dateTagIds(categories));
  return CategoryUsage(
      tags: tags.length,
      events: counts.events,
      exclusiveEvents: counts.exclusiveEvents);
}
