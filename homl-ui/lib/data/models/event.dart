import 'package:homl/data/models/tag.dart';
import 'package:json_annotation/json_annotation.dart';

part 'event.g.dart';

/// An event is a single day, a closed period or an open one:
///
///     single day     date, endDate null, isOngoing false
///     closed period  date, endDate set (inclusive, after date)
///     open period    date, endDate null, isOngoing true
///
/// The backend validates the combinations and normalizes an end on the start
/// day to a single day, so a one-day event always has one representation.
@JsonSerializable()
class Event {
  final int id;
  final String description;

  /// Start of the event, and its only day unless it is a period.
  final DateTime date;

  /// Inclusive last day of a closed period; null for a single day and for an
  /// open period.
  final DateTime? endDate;

  /// Open period: started on [date], no end yet. Never true with an
  /// [endDate]. Required with no constructor default on purpose: every place
  /// that rebuilds an Event field by field (the E2EE decryption does) has to
  /// carry it or does not compile. A payload cached before the field existed
  /// still parses through the JSON default.
  @JsonKey(defaultValue: false)
  final bool isOngoing;

  final List<Tag> tags;

  Event(
      {required this.id,
      required this.description,
      required this.date,
      this.endDate,
      required this.isOngoing,
      required this.tags});

  factory Event.fromJson(Map<String, dynamic> json) => _$EventFromJson(json);

  Map<String, dynamic> toJson() => _$EventToJson(this);
}
