// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

User _$UserFromJson(Map<String, dynamic> json) => User(
      isFingerprintEnabled: json['isFingerprintEnabled'] as bool,
      isPinEnabled: json['isPinEnabled'] as bool,
      pin: json['pin'] as String?,
      pkey: json['pkey'] as String?,
    );

Map<String, dynamic> _$UserToJson(User instance) => <String, dynamic>{
      'isFingerprintEnabled': instance.isFingerprintEnabled,
      'isPinEnabled': instance.isPinEnabled,
      'pin': instance.pin,
      'pkey': instance.pkey,
    };
