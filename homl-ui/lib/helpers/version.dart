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

final _releaseNumber = RegExp(r'^v?(\d+)\.(\d+)\.(\d+)');

/// The release the server runs ("0.6.0") when it is newer than the app's,
/// which means a newer app is out; null otherwise, or when either version is
/// not a release number. The server reports `git describe` ("v0.6.0", or
/// "v0.6.0-3-gabc1234" for a build past the tag, still 0.6.0), the app its
/// pubspec version ("0.5.0").
String? newerServerRelease({required String server, required String app}) {
  final ours = _releaseNumber.firstMatch(app);
  final theirs = _releaseNumber.firstMatch(server);
  if (ours == null || theirs == null) return null;
  for (var i = 1; i <= 3; i++) {
    final order = int.parse(theirs[i]!).compareTo(int.parse(ours[i]!));
    if (order != 0) {
      return order > 0 ? '${theirs[1]}.${theirs[2]}.${theirs[3]}' : null;
    }
  }
  return null;
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
