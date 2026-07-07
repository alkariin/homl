// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tag.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Tag _$TagFromJson(Map<String, dynamic> json) => Tag(
      id: (json['id'] as num).toInt(),
      tag: json['tag'] as String,
      idCategory: (json['idCategory'] as num?)?.toInt(),
      idParentTag: (json['idParentTag'] as num?)?.toInt(),
    );

Map<String, dynamic> _$TagToJson(Tag instance) => <String, dynamic>{
      'id': instance.id,
      'tag': instance.tag,
      'idCategory': instance.idCategory,
      'idParentTag': instance.idParentTag,
    };
