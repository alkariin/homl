// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'settings.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Settings _$SettingsFromJson(Map<String, dynamic> json) => Settings(
      language: $enumDecode(_$LanguageEnumMap, json['language']),
      defaultScreen: json['defaultScreen'] as bool,
    );

Map<String, dynamic> _$SettingsToJson(Settings instance) => <String, dynamic>{
      'language': _$LanguageEnumMap[instance.language]!,
      'defaultScreen': instance.defaultScreen,
    };

const _$LanguageEnumMap = {
  Language.fr: 'fr',
  Language.de: 'de',
  Language.en: 'en',
};
