import 'package:json_annotation/json_annotation.dart';
import 'nickname.dart';

part 'person.g.dart';

@JsonSerializable(explicitToJson: true)
class Person {
  final String firstname, lastname;
  final List<Nickname> nicknames;

  Person(
      {required this.firstname,
      required this.lastname,
      required this.nicknames});

  factory Person.fromJson(Map<String, dynamic> json) => _$PersonFromJson(json);

  Map<String, dynamic> toJson() => _$PersonToJson(this);
}
