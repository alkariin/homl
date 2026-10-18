import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'package:homl/helpers/local_storage_manager.dart';
import 'package:homl/helpers/version.dart';

/// The homl server this app talks to, as an API base URL (`/api` included):
/// the address picked on the login screen, else the default built in with
/// `--dart-define=API_BASE_URL` — optional, a build without one asks for the
/// address before the first sign-in.
class ServerAddress {
  ServerAddress._();

  static const builtIn = String.fromEnvironment('API_BASE_URL');

  static String _current = builtIn;

  /// Empty when none was built in nor picked yet.
  static String get current => _current;

  static bool get isSet => _current.isNotEmpty;

  /// Reads the address picked on this device. Before the first frame: the
  /// Api is built with it.
  static Future<void> load() async {
    try {
      final saved =
          await LocalStorageManager.getValue(LocalStorageKey.serverUrl);
      if (saved != null && saved.isNotEmpty) _current = saved;
    } catch (error) {
      log('Could not read the server address',
          name: 'ServerAddress', error: error);
    }
  }

  static Future<void> save(String apiBaseUrl) async {
    await LocalStorageManager.setValue(LocalStorageKey.serverUrl, apiBaseUrl);
    _current = apiBaseUrl;
  }

  @visibleForTesting
  static void reset([String value = builtIn]) => _current = value;
}

final _ipv4 = RegExp(r'^\d{1,3}(\.\d{1,3}){3}$');

/// The API base URL for what the user typed as the server's address, or null
/// when it cannot be one.
///
/// - No scheme: `http://` for an IPv4 address or `localhost` — a server on
///   the home network rarely has a certificate — `https://` otherwise.
/// - `/api`, the backend's default `HOML_API_URL`, is appended unless already
///   there; a proxy sub-path is kept: `https://host/homl` →
///   `https://host/homl/api`.
String? apiBaseUrlFor(String input) {
  var text = input.trim();
  if (text.isEmpty) return null;
  if (!text.contains('://')) {
    final host = text.split(RegExp('[:/]')).first;
    final local = host == 'localhost' || _ipv4.hasMatch(host);
    text = '${local ? 'http' : 'https'}://$text';
  }

  final Uri uri;
  try {
    uri = Uri.parse(text);
  } on FormatException {
    return null;
  }
  if ((uri.scheme != 'http' && uri.scheme != 'https') ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.hasQuery ||
      uri.hasFragment) {
    return null;
  }

  var path = uri.path;
  while (path.endsWith('/')) {
    path = path.substring(0, path.length - 1);
  }
  if (!path.endsWith('/api')) path = '$path/api';
  return uri.replace(path: path).toString();
}

/// [apiBaseUrl] the way the user typed it: without the `/api` suffix.
String displayServerAddress(String apiBaseUrl) => apiBaseUrl.endsWith('/api')
    ? apiBaseUrl.substring(0, apiBaseUrl.length - '/api'.length)
    : apiBaseUrl;

/// Whether [apiBaseUrl] travels unencrypted.
bool isCleartext(String apiBaseUrl) => apiBaseUrl.startsWith('http://');

enum ServerCheckOutcome {
  /// A homl server answered (its `/healthz`).
  ok,

  /// Nothing answered: wrong address or port, server down, another network.
  unreachable,

  /// An HTTPS server whose certificate the device does not trust
  /// (self-signed, or issued for another name).
  untrustedCertificate,

  /// Something answered, but not a homl server (another web app, a router).
  notHoml,
}

class ServerCheck {
  final ServerCheckOutcome outcome;

  /// The server's build, when it is a homl server that reports one.
  final String? version;

  const ServerCheck(this.outcome, [this.version]);
}

/// Asks the `/healthz` next to [apiBaseUrl] whether a homl server answers
/// there. [dio]: the tests' fake HTTP stack.
Future<ServerCheck> checkServer(String apiBaseUrl, {Dio? dio}) async {
  final client = dio ??
      Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5)));
  try {
    final response = await client.get<dynamic>(healthzUrl(apiBaseUrl),
        // A 503 carries the same body while MySQL or Redis is down: the
        // address is right all the same.
        options: Options(
            validateStatus: (status) => status != null && status < 600));
    final data = response.data;
    if (data is Map && data.containsKey('mysql')) {
      final version = data['version'];
      return ServerCheck(ServerCheckOutcome.ok,
          version is String && version.isNotEmpty ? version : null);
    }
    return const ServerCheck(ServerCheckOutcome.notHoml);
  } on DioException catch (error) {
    log('No homl server at $apiBaseUrl', name: 'ServerAddress', error: error);
    return ServerCheck(error.type == DioExceptionType.badCertificate
        ? ServerCheckOutcome.untrustedCertificate
        : ServerCheckOutcome.unreachable);
  }
}
