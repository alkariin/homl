import 'package:json_annotation/json_annotation.dart';

import 'package:homl/helpers/language.dart';

part 'settings.g.dart';

@JsonSerializable(explicitToJson: true)
class Settings {
  final Language language;
  final bool defaultScreen;

  Settings({
    required this.language,
    required this.defaultScreen,
  });

  Settings.initial() : this(language: Language.en, defaultScreen: false);

  factory Settings.fromJson(Map<String, dynamic> json) =>
      _$SettingsFromJson(json);

  Map<String, dynamic> toJson() => _$SettingsToJson(this);

  Settings copyWith({Language? language, bool? defaultScreen}) {
    return Settings(
      language: language ?? this.language,
      defaultScreen: defaultScreen ?? this.defaultScreen,
    );
  }
}
