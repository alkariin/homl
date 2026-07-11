import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

import 'package:homl/helpers/biometric_storage.dart';
import 'package:homl/helpers/local_storage_manager.dart';
import 'package:homl/helpers/encryption.dart' as encryption;

enum AuthenticationStatus { unknown, authenticated, unauthenticated, pinCheck }

class Api {
  static final Api _api = Api._internal();

  static const baseUrl = String.fromEnvironment('API_BASE_URL');

  late Dio api;
  String? accessToken;
  late final StreamController<AuthenticationStatus> _controller;

  /// Single-flight guard: concurrent 401s all await the same refresh attempt.
  Future<bool>? _refreshInFlight;

  Stream<AuthenticationStatus> get status async* {
    // Stay on the splash screen until the token refresh resolves instead of
    // flashing the login page.
    yield AuthenticationStatus.unknown;
    yield* _controller.stream;
  }

  void updateStatus(AuthenticationStatus authStatus) {
    _controller.add(authStatus);
  }

  void dispose() => _controller.close();

  Future<bool> _refreshToken(String refreshToken,
      {String? signature, String? pin}) async {
    log('Refresh');
    var data = {'refresh_token': refreshToken};
    if (signature != null) {
      data['signature'] = signature;
    }
    if (pin != null) {
      data['pin'] = pin;
    }

    try {
      final response = await api.post('/refresh', data: data);

      if (response.statusCode == 201 &&
          response.data != null &&
          response.data!.containsKey('refresh_token')) {
        await LocalStorageManager.setValue(
            LocalStorageKey.refreshToken, response.data!['refresh_token']);
        accessToken = response.data!['access_token'];

        _controller.add(AuthenticationStatus.authenticated);
        return true;
      } else {
        log('Unexpected refresh response payload', name: 'Api');
        return false;
      }
    } on DioException catch (error) {
      if (error.response?.statusCode == 401 && pin != null) {
        if (error.response?.data?['error']?['message'] == "Pin is locked") {
          accessToken = null;
          // don't remove the pinKeypair so that after the login, the keypair is still here and the next login will happen with the pin again
          await LocalStorageManager.remove(LocalStorageKey.refreshToken);
          _controller.add(AuthenticationStatus.unauthenticated);
          return true; // to avoid to see the keyboard disappearing + appearing again on the view
        } else {
          // nothing
          log('PIN validation failed', name: 'Api');
        }
      } else {
        log('Refresh token rejected, clearing local auth state', name: 'Api');
        // refresh token is wrong so log out user.
        accessToken = null;
        await LocalStorageManager.remove(LocalStorageKey.refreshToken);
        _controller.add(AuthenticationStatus.unauthenticated);
      }
      return false;
    } catch (_) {
      log('Unexpected error while refreshing token', name: 'Api');
      return false;
    }
  }

  /// Refreshes the access token with the stored refresh token, making sure a
  /// single refresh request is in flight at any time.
  Future<bool> _refreshAccessToken() {
    return _refreshInFlight ??= _doRefreshAccessToken().whenComplete(() {
      _refreshInFlight = null;
    });
  }

  Future<bool> _doRefreshAccessToken() async {
    final refreshToken =
        await LocalStorageManager.getValue(LocalStorageKey.refreshToken);
    if (refreshToken == null) {
      return false;
    }
    return _refreshToken(refreshToken);
  }

  Future<String> _askForChallengeString(String refreshToken) async {
    final response = await api
        .post<String>('/challenge', data: {'refresh_token': refreshToken});
    return response.data!;
  }

  Future<Response<dynamic>> _retry(RequestOptions requestOptions) async {
    final options = Options(
      method: requestOptions.method,
      headers: requestOptions.headers,
      extra: {...requestOptions.extra, _retriedKey: true},
    );

    return api.request<dynamic>(requestOptions.path,
        data: requestOptions.data,
        queryParameters: requestOptions.queryParameters,
        options: options);
  }

  factory Api() {
    return _api;
  }

  Future<bool> sendPinAuth(String pin) async {
    final pinKeypair =
        await LocalStorageManager.getValue(LocalStorageKey.pinKeypair);
    final refreshToken =
        await LocalStorageManager.getValue(LocalStorageKey.refreshToken);

    if (pinKeypair == null || refreshToken == null) {
      return false;
    }

    try {
      final challenge = await _askForChallengeString(refreshToken);
      final signature = await encryption.signData(challenge, pinKeypair);
      return await _refreshToken(refreshToken,
          signature: base64.encode(signature.bytes), pin: pin);
    } catch (e) {
      log('Error with pin $e');
      return false;
    }
  }

  Future<void> cancelPinAuth() async {
    _controller.add(AuthenticationStatus.unauthenticated);
  }

  static const _retriedKey = 'homl_retried';

  /// Paths that must never trigger an automatic token refresh: a 401 there is
  /// a real authentication failure, not an expired access token.
  static const _noRefreshPaths = ['/login', '/refresh', '/registration'];

  Api._internal() : this.internal(initFromStorage: true);

  @visibleForTesting
  Api.internal({String? baseUrlOverride, bool initFromStorage = true}) {
    final effectiveBaseUrl = baseUrlOverride ?? baseUrl;
    if (effectiveBaseUrl.isEmpty) {
      throw StateError(
          'API_BASE_URL is not set. Run with --dart-define=API_BASE_URL=<url>');
    }

    _controller = StreamController<AuthenticationStatus>.broadcast();

    api = Dio(BaseOptions(
      baseUrl: effectiveBaseUrl,
      contentType: Headers.jsonContentType,
      responseType: ResponseType.json,
      connectTimeout: const Duration(seconds: 10),
    ));

    if (initFromStorage) {
      unawaited(_initAuthFromStorage());
    }

    // Create interceptor which will manage tokens for each request
    api.interceptors
        .add(InterceptorsWrapper(onRequest: (options, handler) async {
      if (accessToken != null) {
        options.headers['Authorization'] = 'Bearer $accessToken';
      }
      return handler.next(options);
    }, onError: (DioException error, handler) async {
      log('HTTP interceptor caught an error', name: 'Api');
      final path = error.requestOptions.path;
      final alreadyRetried = error.requestOptions.extra[_retriedKey] == true;
      final isAuthPath =
          _noRefreshPaths.any((noRefreshPath) => path.endsWith(noRefreshPath));

      if (error.response?.statusCode == 401 && !isAuthPath && !alreadyRetried) {
        log('Access token expired, attempting refresh', name: 'Api');
        final refreshed = await _refreshAccessToken();
        if (refreshed) {
          try {
            return handler.resolve(await _retry(error.requestOptions));
          } on DioException catch (retryError) {
            return handler.next(retryError);
          }
        }
        // The refresh failed: propagate the original 401 to the caller.
        return handler.next(error);
      } else if (error.type == DioExceptionType.connectionTimeout) {
        log('Connection timeout', name: 'Api', error: error);
      } else if (error.type == DioExceptionType.unknown) {
        log('Unknown network error: ${error.message}',
            name: 'Api', error: error);
      }
      // if not 2xx then throw an error
      log('Propagating HTTP error to caller', name: 'Api', error: error);
      return handler.next(error);
    }));

    if (kDebugMode) {
      api.interceptors.add(PrettyDioLogger(
        requestHeader: true,
        requestBody: true,
        responseBody: true,
        responseHeader: false,
        error: true,
        compact: true,
        maxWidth: 90,
      ));
    }
  }

  /// Restores the authentication state on app start: fingerprint or PIN based
  /// re-authentication when enabled, plain refresh token otherwise.
  Future<void> _initAuthFromStorage() async {
    try {
      // we get the value from the local storage because the user is not logged
      // in atm so we cannot know if the user activated the fingerprint
      final isFingerprintEnabled =
          await LocalStorageManager.getBool(LocalStorageKey.isFingerprintEnabled);
      final keyPair =
          await LocalStorageManager.getValue(LocalStorageKey.pinKeypair);
      final refreshToken =
          await LocalStorageManager.getValue(LocalStorageKey.refreshToken);

      if (refreshToken == null) {
        _controller.add(AuthenticationStatus.unauthenticated);
        return;
      }

      if (isFingerprintEnabled) {
        try {
          final challenge = await _askForChallengeString(refreshToken);
          final signature = await signData(challenge);
          final refreshed = await _refreshToken(refreshToken,
              signature: base64.encode(signature.bytes));
          if (!refreshed) {
            _controller.add(AuthenticationStatus.unauthenticated);
          }
        } catch (e) {
          log('Error with fingerprint $e', name: 'Api');
          _controller.add(AuthenticationStatus.unauthenticated);
        }
      } else if (keyPair != null) {
        _controller.add(AuthenticationStatus.pinCheck);
      } else {
        final refreshed = await _refreshToken(refreshToken);
        if (!refreshed) {
          _controller.add(AuthenticationStatus.unauthenticated);
        }
      }
    } catch (e) {
      log('Error while restoring the authentication state $e', name: 'Api');
      _controller.add(AuthenticationStatus.unauthenticated);
    }
  }
}
