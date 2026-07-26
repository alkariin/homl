// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'settings.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Settings _$SettingsFromJson(Map<String, dynamic> json) => Settings(
      language: $enumDecode(_$LanguageEnumMap, json['language']),
      defaultScreen: json['defaultScreen'] as bool,
      isE2eeEnabled: json['isE2eeEnabled'] as bool? ?? false,
      e2eeKeyCheck: json['e2eeKeyCheck'] as String?,
    );

Map<String, dynamic> _$SettingsToJson(Settings instance) => <String, dynamic>{
      'language': _$LanguageEnumMap[instance.language]!,
      'defaultScreen': instance.defaultScreen,
      'isE2eeEnabled': instance.isE2eeEnabled,
      'e2eeKeyCheck': instance.e2eeKeyCheck,
    };

const _$LanguageEnumMap = {
  Language.fr: 'fr',
  Language.de: 'de',
  Language.en: 'en',
};
