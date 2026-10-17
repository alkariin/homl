// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tag_group.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TagGroup _$TagGroupFromJson(Map<String, dynamic> json) => TagGroup(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      members: (json['members'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          [],
    );

Map<String, dynamic> _$TagGroupToJson(TagGroup instance) => <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'members': instance.members,
    };
