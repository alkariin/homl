import 'package:json_annotation/json_annotation.dart';

part 'nickname.g.dart';

@JsonSerializable(explicitToJson: true)
class Nickname {
  final int id;
  final String nickname;

  Nickname({required this.id, required this.nickname});

  factory Nickname.fromJson(Map<String, dynamic> json) =>
      _$NicknameFromJson(json);

  Map<String, dynamic> toJson() => _$NicknameToJson(this);
}
