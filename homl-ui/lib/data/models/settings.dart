import 'package:json_annotation/json_annotation.dart';

import 'package:homl/helpers/language.dart';

part 'settings.g.dart';

@JsonSerializable(explicitToJson: true)
class Settings {
  final Language language;
  final bool defaultScreen;

  /// Read-only: only the E2EE migration endpoint flips it server-side.
  @JsonKey(defaultValue: false)
  final bool isE2eeEnabled;

  /// Server-stored HMAC verifying a typed recovery phrase (E2EE users only).
  final String? e2eeKeyCheck;

  Settings({
    required this.language,
    required this.defaultScreen,
    this.isE2eeEnabled = false,
    this.e2eeKeyCheck,
  });

  Settings.initial() : this(language: Language.en, defaultScreen: false);

  factory Settings.fromJson(Map<String, dynamic> json) =>
      _$SettingsFromJson(json);

  Map<String, dynamic> toJson() => _$SettingsToJson(this);

  Settings copyWith({Language? language, bool? defaultScreen}) {
    return Settings(
      language: language ?? this.language,
      defaultScreen: defaultScreen ?? this.defaultScreen,
      isE2eeEnabled: isE2eeEnabled,
      e2eeKeyCheck: e2eeKeyCheck,
    );
  }
}
