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

  Stream<AuthenticationStatus> get status async* {
    yield AuthenticationStatus.unauthenticated;
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
        LocalStorageManager.setValue(
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
          LocalStorageManager.remove(LocalStorageKey.refreshToken);
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
        LocalStorageManager.remove(LocalStorageKey.refreshToken);
        _controller.add(AuthenticationStatus.unauthenticated);
      }
      return false;
    } catch (_) {
      log('Unexpected error while refreshing token', name: 'Api');
      return false;
    }
  }

  Future<String> _askForChallengeString(String refreshToken) async {
    final response = await api
        .get<String>('/challenge', data: {'refresh_token': refreshToken});
    return response.data!;
  }

  Future<Response<dynamic>> _retry(RequestOptions requestOptions) async {
    final options = Options(
      method: requestOptions.method,
      headers: requestOptions.headers,
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
    final pinKeypairPromise =
        LocalStorageManager.getValue(LocalStorageKey.pinKeypair);
    final refreshTokenPromise =
        LocalStorageManager.getValue(LocalStorageKey.refreshToken);
    return Future.wait([pinKeypairPromise, refreshTokenPromise])
        .then((value) async {
      final pinKeypair = value[0];
      final refreshToken = value[1];

      if (pinKeypair != null && refreshToken != null) {
        try {
          final challenge = await _askForChallengeString(refreshToken);
          final signature = await encryption.signData(challenge, pinKeypair);
          return _refreshToken(refreshToken,
              signature: base64.encode(signature.bytes), pin: pin);
        } catch (e) {
          log('Error with pin $e');
          return false;
        }
      } else {
        return false;
      }
    });
  }

  Future<void> cancelPinAuth() async {
    _controller.add(AuthenticationStatus.unauthenticated);
  }

  Api._internal() {
    if (baseUrl.isEmpty) {
      throw StateError(
          'API_BASE_URL is not set. Run with --dart-define=API_BASE_URL=<url>');
    }

    _controller = StreamController<AuthenticationStatus>();

    api = Dio(BaseOptions(
      baseUrl: baseUrl,
      contentType: Headers.jsonContentType,
      responseType: ResponseType.json,
      connectTimeout: const Duration(seconds: 10),
    ));
    // we get the value from the local storage because the user is not logged in atm so we cannot know if the user activated the fingerprint
    final isFingerprintEnabled =
        LocalStorageManager.getValue(LocalStorageKey.isFingerprintEnabled);
    final refreshToken =
        LocalStorageManager.getValue(LocalStorageKey.refreshToken);
    final pinKeypairPromise =
        LocalStorageManager.getValue(LocalStorageKey.pinKeypair);

    Future.wait([isFingerprintEnabled, pinKeypairPromise, refreshToken])
        .then((value) {
      final isFingerPrintEnabled = value[0];
      final keyPair = value[1];
      final refreshToken = value[2];
      if (isFingerPrintEnabled == "true" && refreshToken != null) {
        try {
          _askForChallengeString(refreshToken).then((challenge) {
            signData(challenge).then((signature) {
              _refreshToken(refreshToken,
                  signature: base64.encode(signature.bytes));
            });
          });
        } catch (e) {
          log('Error with fingerprint $e');
        }
      } else if (keyPair != null && refreshToken != null) {
        _controller.add(AuthenticationStatus.pinCheck);
      } else {
        if (refreshToken != null) {
          _refreshToken(refreshToken);
        }
      }
    });

    // Create interceptor which will manage tokens for each request
    api.interceptors
        .add(InterceptorsWrapper(onRequest: (options, handler) async {
      if (accessToken != null) {
        options.headers['Authorization'] = 'Bearer $accessToken';
      }
      return handler.next(options);
    }, onError: (DioException error, handler) async {
      log('HTTP interceptor caught an error', name: 'Api');
      if ((error.response?.statusCode == 401 &&
          error.response.toString() == "Invalid JWT")) {
        // TODO: check this condition, it no longer seems to trigger as expected.
        log('Access token expired, attempting refresh', name: 'Api');
        final refreshToken =
            await LocalStorageManager.getValue(LocalStorageKey.refreshToken);
        if (refreshToken != null) {
          await _refreshToken(refreshToken);
          return handler.resolve(await _retry(error.requestOptions));
        }
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
}
