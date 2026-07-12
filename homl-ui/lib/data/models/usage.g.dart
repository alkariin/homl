// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'usage.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TagUsage _$TagUsageFromJson(Map<String, dynamic> json) => TagUsage(
      events: (json['events'] as num).toInt(),
      exclusiveEvents: (json['exclusiveEvents'] as num).toInt(),
    );

Map<String, dynamic> _$TagUsageToJson(TagUsage instance) => <String, dynamic>{
      'events': instance.events,
      'exclusiveEvents': instance.exclusiveEvents,
    };

CategoryUsage _$CategoryUsageFromJson(Map<String, dynamic> json) =>
    CategoryUsage(
      tags: (json['tags'] as num).toInt(),
      events: (json['events'] as num).toInt(),
      exclusiveEvents: (json['exclusiveEvents'] as num).toInt(),
    );

Map<String, dynamic> _$CategoryUsageToJson(CategoryUsage instance) =>
    <String, dynamic>{
      'tags': instance.tags,
      'events': instance.events,
      'exclusiveEvents': instance.exclusiveEvents,
    };
