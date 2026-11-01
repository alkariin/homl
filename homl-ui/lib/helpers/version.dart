import 'package:flutter/foundation.dart';

/// Where the backend's `/healthz` lives, derived from the API base URL.
///
/// The Go router mounts `/healthz` at the server root and the API under
/// `HOML_API_URL` (`/api` by default), so `https://host/api` → `https://host/healthz`
/// and a proxy sub-path is kept: `https://host/homl/api` → `https://host/homl/healthz`.
/// A base URL without the `/api` suffix just gets `/healthz` appended.
String healthzUrl(String apiBaseUrl) {
  final uri = Uri.parse(apiBaseUrl);
  var path = uri.path;
  while (path.endsWith('/')) {
    path = path.substring(0, path.length - 1);
  }
  if (path.endsWith('/api')) {
    path = path.substring(0, path.length - '/api'.length);
  }
  return uri
      .replace(path: '$path/healthz', query: null, fragment: null)
      .toString();
}

/// The oldest server release this app works with in full.
///
/// Raise it in the change that makes the app rely on something only a newer
/// server does (a new endpoint or field, a new meaning), and say so in that
/// release's notes; a release whose app needs nothing new from the server
/// leaves it alone, so a phone upgraded ahead of its server (Obtainium
/// installs in the background) carries on without a word. Never newer than
/// the pubspec version, which a test checks. See homl-web/docs/deployment.md,
/// "The app and its server".
///
/// 0.6.0: events without any tag are listed from that server on.
const minServerRelease = '0.6.0';

final _releaseNumber = RegExp(r'^v?(\d+)\.(\d+)\.(\d+)');

/// The release number [version] starts with ("v0.6.0-3-gabc1234" → 0, 6, 0),
/// or null when it starts with none.
List<int>? _releaseParts(String version) {
  final match = _releaseNumber.firstMatch(version);
  if (match == null) return null;
  return [for (var i = 1; i <= 3; i++) int.parse(match[i]!)];
}

/// Whether [a]'s release comes before (< 0), with (0) or after (> 0) [b]'s,
/// compared as numbers; null when either is not a release number.
int? _compareReleases(String a, String b) {
  final left = _releaseParts(a);
  final right = _releaseParts(b);
  if (left == null || right == null) return null;
  for (var i = 0; i < 3; i++) {
    final order = left[i].compareTo(right[i]);
    if (order != 0) return order;
  }
  return 0;
}

/// The release the server runs ("0.6.0") when it is newer than the app's,
/// which means a newer app is out; null otherwise, or when either version is
/// not a release number. The server reports `git describe` ("v0.6.0", or
/// "v0.6.0-3-gabc1234" for a build past the tag, still 0.6.0), the app its
/// pubspec version ("0.5.0").
String? newerServerRelease({required String server, required String app}) {
  final order = _compareReleases(server, app);
  return order != null && order > 0 ? _releaseParts(server)!.join('.') : null;
}

/// The release the server runs ("0.5.0") when it is older than [minimum],
/// which means this app relies on something that server does not do yet;
/// null otherwise, or when the server's version is not a release number (a
/// build from an untagged checkout is never called too old).
String? outdatedServerRelease(
    {required String server, String minimum = minServerRelease}) {
  final order = _compareReleases(server, minimum);
  return order != null && order < 0 ? _releaseParts(server)!.join('.') : null;
}

/// The GitHub release of [release] ("0.6.0"), which carries the signed
/// Android APK (homl-web/docs/deployment.md, "Building the clients").
String releasePageUrl(String release) =>
    'https://github.com/alkariin/homl/releases/tag/v$release';

/// How the app names itself to the server — its platform and version,
/// "android 0.5.0" — sent with every request (the `X-Homl-Client` header):
/// the server shows it in the list of signed-in devices
/// (homl-web/docs/auth-flows.md, "Signed-in devices"). Nothing else about the
/// device is sent. [version] null (unreadable) leaves the platform alone.
String clientLabel(
    {required bool isWeb, required TargetPlatform platform, String? version}) {
  final name = isWeb
      ? 'web'
      : switch (platform) {
          TargetPlatform.iOS => 'ios',
          TargetPlatform.macOS => 'macos',
          _ => platform.name,
        };
  return version == null || version.isEmpty ? name : '$name $version';
}
