import 'package:homl/data/models/tag.dart';
import 'package:json_annotation/json_annotation.dart';

part 'event.g.dart';

@JsonSerializable()
class Event {
  final int id;
  final String description;
  final DateTime date;
  final List<Tag> tags;

  Event(
      {required this.id,
      required this.description,
      required this.date,
      required this.tags});

  factory Event.fromJson(Map<String, dynamic> json) => _$EventFromJson(json);

  Map<String, dynamic> toJson() => _$EventToJson(this);
}
