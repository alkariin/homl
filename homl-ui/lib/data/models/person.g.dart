// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'person.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Person _$PersonFromJson(Map<String, dynamic> json) => Person(
      firstname: json['firstname'] as String,
      lastname: json['lastname'] as String,
      nicknames: (json['nicknames'] as List<dynamic>)
          .map((e) => Nickname.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$PersonToJson(Person instance) => <String, dynamic>{
      'firstname': instance.firstname,
      'lastname': instance.lastname,
      'nicknames': instance.nicknames.map((e) => e.toJson()).toList(),
    };
