// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'category.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Category _$CategoryFromJson(Map<String, dynamic> json) => Category(
      id: (json['id'] as num).toInt(),
      category: json['category'] as String,
      color: json['color'] as String,
      isLocked: json['isLocked'] as bool,
      kind: $enumDecodeNullable(_$CategoryKindEnumMap, json['kind'],
          unknownValue: JsonKey.nullForUndefinedEnumValue),
      tags: (json['tags'] as List<dynamic>?)
              ?.map((e) => Tag.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );

Map<String, dynamic> _$CategoryToJson(Category instance) => <String, dynamic>{
      'id': instance.id,
      'category': instance.category,
      'color': instance.color,
      'isLocked': instance.isLocked,
      'kind': _$CategoryKindEnumMap[instance.kind],
      'tags': instance.tags,
    };

const _$CategoryKindEnumMap = {
  CategoryKind.date: 'date',
  CategoryKind.person: 'person',
  CategoryKind.other: 'other',
  CategoryKind.custom: 'custom',
};
