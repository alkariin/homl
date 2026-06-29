import 'package:json_annotation/json_annotation.dart';

part 'user.g.dart';

@JsonSerializable(explicitToJson: true)
class User {
  final bool isFingerprintEnabled; // to know if the switch is on/off
  final bool isPinEnabled; // to know if the switch is on/off
  final String? pin; // the pin code if set
  final String? pkey; // public key

  User({
    required this.isFingerprintEnabled,
    required this.isPinEnabled,
    this.pin,
    this.pkey,
  });

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);

  Map<String, dynamic> toJson() => _$UserToJson(this);

  User copyWith(
      {bool? isFingerprintEnabled,
      bool? isPinEnabled,
      String? pin,
      String? pkey}) {
    return User(
      isFingerprintEnabled: isFingerprintEnabled ?? this.isFingerprintEnabled,
      isPinEnabled: isPinEnabled ?? this.isPinEnabled, // read only value
      pin: pin, // always remove it if not provided
      pkey: pkey, // always remove it if not provided
    );
  }
}
