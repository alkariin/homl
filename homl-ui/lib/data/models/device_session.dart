/// A signed-in device, as `GET /sessions` lists it: a login and every
/// refresh since (homl-web/docs/auth-flows.md, "Signed-in devices").
class DeviceSession {
  final String id;

  /// How the app named itself, "android 0.5.0"; empty when it did not say.
  final String client;

  /// The address of its last login or refresh.
  final String ip;

  /// Null for a session opened before devices were recorded.
  final DateTime? createdAt;
  final DateTime lastSeenAt;

  /// The device asking: this one.
  final bool current;

  const DeviceSession(
      {required this.id,
      required this.client,
      required this.ip,
      this.createdAt,
      required this.lastSeenAt,
      required this.current});

  factory DeviceSession.fromJson(Map<String, dynamic> json) => DeviceSession(
        id: json['id'] as String,
        client: json['client'] as String? ?? '',
        ip: json['ip'] as String? ?? '',
        createdAt: json['createdAt'] == null
            ? null
            : DateTime.parse(json['createdAt'] as String).toLocal(),
        lastSeenAt: DateTime.parse(json['lastSeenAt'] as String).toLocal(),
        current: json['current'] as bool? ?? false,
      );

  /// The platform word of [client]: "android", "ios", "web"… or empty.
  String get platform => client.split(' ').first.toLowerCase();

  /// The app version of [client], or null when it did not say.
  String? get version {
    final parts = client.split(' ');
    return parts.length > 1 ? parts.sublist(1).join(' ') : null;
  }
}
