// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'nickname.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Nickname _$NicknameFromJson(Map<String, dynamic> json) => Nickname(
      id: (json['id'] as num).toInt(),
      nickname: json['nickname'] as String,
    );

Map<String, dynamic> _$NicknameToJson(Nickname instance) => <String, dynamic>{
      'id': instance.id,
      'nickname': instance.nickname,
    };
