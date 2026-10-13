import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

import 'package:homl/helpers/biometric_storage.dart' as biometric;
import 'package:homl/helpers/e2ee.dart';
import 'package:homl/helpers/encryption.dart' as encryption;
import 'package:homl/helpers/local_storage_manager.dart';
import 'package:homl/helpers/pin_verifier.dart';
import 'package:homl/helpers/server_reachability.dart';
import 'package:homl/helpers/version.dart';

enum AuthenticationStatus {
  unknown,

  /// A session is open. Normally vouched for by the server; when the server
  /// cannot be reached, unlocked on this device with the account's own
  /// factor (PIN, fingerprint, or none) to browse the data saved here —
  /// [ServerReachability] tells the two apart.
  authenticated,
  unauthenticated,
  pinCheck,
  pinLocked,
  biometricCheck,

  /// The account is end-to-end encrypted but this device has no (matching)
  /// key: the app is blocked on the restore-or-purge screen. Never emitted
  /// by [Api] itself — the AuthenticationCubit derives it after fetching the
  /// settings.
  e2eeLocked,

  /// The account was just deleted server-side and this device wiped: the same
  /// destination as [unauthenticated], plus a confirmation toast on the login
  /// screen. Emitted only by `UsersRepository.deleteAccount`.
  accountDeleted,
}

/// Outcome of a PIN authentication attempt, carrying the lockout information
/// (the server's, or the offline counter's) so the UI can inform the user.
class PinAuthResult {
  final bool success;
  final bool locked;
  final int? attemptsRemaining;

  /// The server could not be reached and this device cannot check the PIN on
  /// its own yet: no PIN was accepted online here since the session started.
  final bool unreachable;

  const PinAuthResult(
      {required this.success,
      this.locked = false,
      this.attemptsRemaining,
      this.unreachable = false});
}

/// What a session refresh came to.
enum _Refresh {
  refreshed,

  /// The server answered and turned the session down (revoked or expired
  /// refresh token): the session is over.
  rejected,

  /// No verdict: no network, a timeout, a gateway or server error, a page
  /// that is not ours. The session is kept and the app goes offline.
  unreachable,
  pinIncorrect,
  pinLocked,

  /// The account has a PIN or a fingerprint and the request carried none
  /// (`SECOND_FACTOR_REQUIRED`), or this device cannot produce it right now.
  /// The refresh token itself is still valid.
  secondFactorRequired,
}

class _RefreshResult {
  final _Refresh outcome;
  final int? attemptsRemaining;

  const _RefreshResult(this.outcome, {this.attemptsRemaining});
}

class Api {
  static final Api _api = Api._internal();

  static const baseUrl = String.fromEnvironment('API_BASE_URL');

  late Dio api;
  String? accessToken;
  late final StreamController<AuthenticationStatus> _controller;
  late final String _healthzUrl;

  /// Reads the fingerprint-protected keypair (OS prompt). Injectable: the
  /// tests have no biometric plugin.
  final Future<String> Function() _readBiometricKeyPair;

  /// Single-flight guard: concurrent 401s all await the same refresh attempt.
  Future<_Refresh>? _refreshInFlight;

  /// The second factor of the open session, in memory only. The server wants
  /// the PIN, or a fingerprint signature, on every refresh. The user gives it
  /// once when the app opens; the refreshes that follow (each time the
  /// 10-minute access token expires, or when the server comes back after an
  /// offline start) reuse it instead of ending the session.
  String? _sessionPin;
  String? _sessionBiometricKeyPair;

  final ServerReachability _reachability = ServerReachability.instance;
  Timer? _probeTimer;
  bool _probing = false;
  bool _inForeground = true;
  Duration _probeDelay = _probeMinDelay;

  /// While offline and in the foreground, `/healthz` is probed with this
  /// backoff until the server answers.
  static const _probeMinDelay = Duration(seconds: 5);
  static const _probeMaxDelay = Duration(minutes: 2);
  static const _probeTimeout = Duration(seconds: 3);

  /// Requests fail at once for this long after a transport failure instead of
  /// each waiting for its own timeout: an offline start would otherwise sit on
  /// the splash through the settings request too.
  static const _failFastWindow = Duration(seconds: 10);

  Stream<AuthenticationStatus> get status async* {
    // Stay on the splash screen until the token refresh resolves instead of
    // flashing the login page.
    yield AuthenticationStatus.unknown;
    yield* _controller.stream;
  }

  void updateStatus(AuthenticationStatus authStatus) {
    _controller.add(authStatus);
  }

  void dispose() {
    _stopProbing();
    _controller.close();
  }

  /// Makes [pin] or [biometricKeyPair] the factor of the open session (the
  /// Security page just set it up); both null forgets it.
  void holdSecondFactor({String? pin, String? biometricKeyPair}) {
    _sessionPin = pin;
    _sessionBiometricKeyPair = biometricKeyPair;
  }

  /// Ends the session on this device: logout, a session the server turned
  /// down, the PIN lockout. The cached data goes with it — another account may
  /// use the device next — and so does the offline PIN; the PIN keypair and
  /// the E2EE seed stay, so the same account unlocks the same way next time.
  Future<void> endSession(AuthenticationStatus status) async {
    accessToken = null;
    holdSecondFactor();
    _stopProbing();
    // No session left to be online or offline for.
    _reachability.markUnknown();
    await LocalStorageManager.remove(LocalStorageKey.refreshToken);
    await LocalStorageManager.clearDataCaches();
    await PinVerifier.clear();
    E2ee().lock();
    _controller.add(status);
  }

  Future<_RefreshResult> _postRefresh(String refreshToken,
      {String? signature, String? pin}) async {
    log('Refresh', name: 'Api');
    final data = {
      'refresh_token': refreshToken,
      if (signature != null) 'signature': signature,
      if (pin != null) 'pin': pin,
    };

    try {
      final response = await api.post<dynamic>('/refresh', data: data);
      final body = response.data;
      if (response.statusCode == 201 &&
          body is Map &&
          body['refresh_token'] is String &&
          body['access_token'] is String) {
        await LocalStorageManager.setValue(
            LocalStorageKey.refreshToken, body['refresh_token'] as String);
        accessToken = body['access_token'] as String;
        _markOnline();
        return const _RefreshResult(_Refresh.refreshed);
      }
      // A 2xx that is not a token pair comes from something in front of the
      // server (captive portal, proxy page), not from it.
      log('Unexpected refresh response payload', name: 'Api');
      return const _RefreshResult(_Refresh.unreachable);
    } on DioException catch (error) {
      return _classifyAuthError(error, pinSent: pin != null);
    } catch (error) {
      log('Unexpected error while refreshing token', name: 'Api', error: error);
      return const _RefreshResult(_Refresh.unreachable);
    }
  }

  /// Only a 401 is a verdict on the session; anything else (no answer, 5xx,
  /// 429, a page that is not ours) keeps it.
  _RefreshResult _classifyAuthError(DioException error,
      {required bool pinSent}) {
    if (error.response?.statusCode != 401) {
      return const _RefreshResult(_Refresh.unreachable);
    }

    final data = error.response?.data;
    final errorBody = data is Map ? data['error'] : null;
    final code = errorBody is Map ? errorBody['code'] : null;
    final message = errorBody is Map ? errorBody['message'] : null;

    // Fall back to message matching for servers that predate error codes.
    if (pinSent && (code == 'PIN_LOCKED' || message == 'Pin is locked')) {
      return const _RefreshResult(_Refresh.pinLocked);
    }
    if (pinSent &&
        (code == 'PIN_INCORRECT' || message == 'Pin code not correct')) {
      final remaining = errorBody is Map ? errorBody['attemptsRemaining'] : null;
      return _RefreshResult(_Refresh.pinIncorrect,
          attemptsRemaining: remaining is int ? remaining : null);
    }
    if (code == 'SECOND_FACTOR_REQUIRED' ||
        message == 'Pin must be provided' ||
        message == 'Signature must be provided') {
      return const _RefreshResult(_Refresh.secondFactorRequired);
    }
    return const _RefreshResult(_Refresh.rejected);
  }

  /// Signs a fresh one-time challenge with [keyPair] (the PIN keypair or the
  /// fingerprint one) and refreshes with the signature.
  Future<_RefreshResult> _refreshWithKeyPair(
      String refreshToken, String keyPair,
      {String? pin}) async {
    final String challenge;
    try {
      challenge = await _askForChallengeString(refreshToken);
    } on DioException catch (error) {
      return _classifyAuthError(error, pinSent: false);
    } catch (error) {
      log('Unexpected challenge response', name: 'Api', error: error);
      return const _RefreshResult(_Refresh.unreachable);
    }

    final signature = await encryption.signData(challenge, keyPair);
    return _postRefresh(refreshToken,
        signature: base64.encode(signature.bytes), pin: pin);
  }

  /// Refreshes the access token with the stored refresh token and the
  /// session's factor, making sure a single refresh request is in flight at
  /// any time. [interactive]: a request the user made is waiting, so the
  /// fingerprint may be asked for when this session does not hold it yet.
  Future<_Refresh> _refreshSession({required bool interactive}) {
    return _refreshInFlight ??=
        _doRefreshSession(interactive).whenComplete(() {
      _refreshInFlight = null;
    });
  }

  Future<_Refresh> _doRefreshSession(bool interactive) async {
    final refreshToken =
        await LocalStorageManager.getValue(LocalStorageKey.refreshToken);
    if (refreshToken == null) return _Refresh.rejected;

    final _RefreshResult result;
    try {
      if (await LocalStorageManager.getBool(
          LocalStorageKey.isFingerprintEnabled)) {
        var keyPair = _sessionBiometricKeyPair;
        if (keyPair == null) {
          // Not held by this session (the fingerprint was enabled since it
          // opened): ask for it, but only for a request the user waits on.
          if (!interactive) return _Refresh.secondFactorRequired;
          try {
            keyPair = _sessionBiometricKeyPair = await _readBiometricKeyPair();
          } catch (error) {
            log('Fingerprint prompt failed', name: 'Api', error: error);
            return _Refresh.secondFactorRequired;
          }
        }
        result = await _refreshWithKeyPair(refreshToken, keyPair);
      } else {
        final pinKeypair =
            await LocalStorageManager.getValue(LocalStorageKey.pinKeypair);
        if (pinKeypair == null) {
          result = await _postRefresh(refreshToken);
        } else {
          final pin = _sessionPin;
          if (pin == null) {
            if (interactive) _controller.add(AuthenticationStatus.pinCheck);
            return _Refresh.secondFactorRequired;
          }
          result =
              await _refreshWithKeyPair(refreshToken, pinKeypair, pin: pin);
        }
      }
    } catch (error) {
      // A failure on this device (a keypair that no longer signs, storage):
      // not a verdict on the session, which is kept. The request fails.
      log('Refresh failed on this device', name: 'Api', error: error);
      return _Refresh.unreachable;
    }

    switch (result.outcome) {
      case _Refresh.refreshed:
        _controller.add(AuthenticationStatus.authenticated);
      case _Refresh.unreachable:
        _markOffline();
      case _Refresh.rejected:
        log('Refresh token rejected, ending the session', name: 'Api');
        await endSession(AuthenticationStatus.unauthenticated);
      case _Refresh.pinLocked:
        await endSession(AuthenticationStatus.pinLocked);
      case _Refresh.pinIncorrect:
        // The PIN held for the session no longer matches: stop spending the
        // server's tries on it and ask the user again.
        _sessionPin = null;
        _controller.add(AuthenticationStatus.pinCheck);
      case _Refresh.secondFactorRequired:
        // The server wants a factor this device does not know (enabled from
        // another device): this session cannot be renewed here.
        await endSession(AuthenticationStatus.unauthenticated);
    }
    return result.outcome;
  }

  /// Fetches the one-time challenge to sign. The response is a bare JSON
  /// string, so it must be decoded: asking Dio for a `String` would force
  /// `ResponseType.plain` and hand back the raw body — the challenge still
  /// wrapped in its JSON quotes. Signing those quotes makes the server-side
  /// ed25519 verification fail and logs the user out on every start.
  Future<String> _askForChallengeString(String refreshToken) async {
    final response = await api
        .post<dynamic>('/challenge', data: {'refresh_token': refreshToken});
    return response.data as String;
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

  /// Settles an unlock attempt made at the gate (app start, PIN dialog,
  /// fingerprint retry). An unreachable server still opens the session, on
  /// the data saved on this device, since the factor was checked locally.
  Future<bool> _openSession(_RefreshResult result) async {
    switch (result.outcome) {
      case _Refresh.refreshed:
        _controller.add(AuthenticationStatus.authenticated);
        return true;
      case _Refresh.unreachable:
        _openOffline();
        return true;
      case _Refresh.pinLocked:
        await endSession(AuthenticationStatus.pinLocked);
        return false;
      case _Refresh.rejected:
      case _Refresh.pinIncorrect:
      case _Refresh.secondFactorRequired:
        await endSession(AuthenticationStatus.unauthenticated);
        return false;
    }
  }

  void _openOffline() {
    log('Server unreachable, opening the saved data', name: 'Api');
    _markOffline();
    _controller.add(AuthenticationStatus.authenticated);
  }

  Future<PinAuthResult> sendPinAuth(String pin) async {
    final pinKeypair =
        await LocalStorageManager.getValue(LocalStorageKey.pinKeypair);
    final refreshToken =
        await LocalStorageManager.getValue(LocalStorageKey.refreshToken);

    if (pinKeypair == null || refreshToken == null) {
      return const PinAuthResult(success: false);
    }

    try {
      final result =
          await _refreshWithKeyPair(refreshToken, pinKeypair, pin: pin);
      switch (result.outcome) {
        case _Refresh.refreshed:
          _sessionPin = pin;
          // The server just accepted it: the PIN to check offline from now on.
          await PinVerifier.store(pin);
          _controller.add(AuthenticationStatus.authenticated);
          return const PinAuthResult(success: true);
        case _Refresh.pinIncorrect:
          log('PIN validation failed', name: 'Api');
          return PinAuthResult(
              success: false, attemptsRemaining: result.attemptsRemaining);
        case _Refresh.unreachable:
          return _unlockOffline(pin);
        case _Refresh.pinLocked:
          // Keep the pinKeypair: after the password login the PIN is still
          // the way in on this device.
          await endSession(AuthenticationStatus.pinLocked);
          return const PinAuthResult(success: false, locked: true);
        case _Refresh.rejected:
        case _Refresh.secondFactorRequired:
          await endSession(AuthenticationStatus.unauthenticated);
          return const PinAuthResult(success: false);
      }
    } catch (e) {
      log('Error with pin $e', name: 'Api');
      return const PinAuthResult(success: false);
    }
  }

  /// The server is unreachable: check the PIN against the hash kept on the
  /// device, with the same 3-strike lockout as the server.
  Future<PinAuthResult> _unlockOffline(String pin) async {
    switch (await PinVerifier.verify(pin)) {
      case OfflinePinCheck.unavailable:
        return const PinAuthResult(success: false, unreachable: true);
      case OfflinePinCheck.match:
        _sessionPin = pin;
        _openOffline();
        return const PinAuthResult(success: true);
      case OfflinePinCheck.mismatch:
        log('Offline PIN validation failed', name: 'Api');
        return PinAuthResult(
            success: false,
            attemptsRemaining: await PinVerifier.remainingTries());
      case OfflinePinCheck.locked:
        await endSession(AuthenticationStatus.pinLocked);
        return const PinAuthResult(success: false, locked: true);
    }
  }

  Future<void> cancelPinAuth() async {
    _controller.add(AuthenticationStatus.unauthenticated);
  }

  /// Authenticates with the biometric-protected keypair. Emits
  /// [AuthenticationStatus.biometricCheck] when the biometric prompt fails or
  /// is canceled, so the UI can offer a retry or a password fallback.
  ///
  /// The prompt comes first: releasing the keypair is what proves the owner
  /// is there, so an unreachable server can still open the saved data.
  Future<bool> sendBiometricAuth() async {
    final refreshToken =
        await LocalStorageManager.getValue(LocalStorageKey.refreshToken);
    if (refreshToken == null) {
      _controller.add(AuthenticationStatus.unauthenticated);
      return false;
    }

    try {
      final keyPair = await _readBiometricKeyPair();
      _sessionBiometricKeyPair = keyPair;
      // A rejected session is a real logout, not a biometric failure:
      // _openSession falls through to the login screen instead of a retry.
      return await _openSession(
          await _refreshWithKeyPair(refreshToken, keyPair));
    } catch (e) {
      log('Error with fingerprint $e', name: 'Api');
      _controller.add(AuthenticationStatus.biometricCheck);
      return false;
    }
  }

  Future<bool> retryBiometricAuth() => sendBiometricAuth();

  /// Falls back to the password login while keeping the refresh token and the
  /// fingerprint flag, so the next app start offers the fingerprint again.
  Future<void> cancelBiometricAuth() async {
    _controller.add(AuthenticationStatus.unauthenticated);
  }

  /// The app is back in the foreground: if the server was unreachable, look
  /// again right away (typically: back home, on the LAN).
  void onAppResumed() {
    _inForeground = true;
    if (_reachability.isOffline) {
      _probeTimer?.cancel();
      _probeTimer = null;
      unawaited(_probe());
    }
  }

  /// No probing in the background; [onAppResumed] picks it up again.
  void onAppPaused() {
    _inForeground = false;
    _probeTimer?.cancel();
    _probeTimer = null;
  }

  void _markOffline() {
    _reachability.markOffline();
    _scheduleProbe();
  }

  void _markOnline() {
    _stopProbing();
    _reachability.markOnline();
  }

  void _stopProbing() {
    _probeTimer?.cancel();
    _probeTimer = null;
    _probeDelay = _probeMinDelay;
  }

  void _scheduleProbe() {
    if (_probing || !_inForeground || _probeTimer != null) return;
    _probeTimer = Timer(_probeDelay, () => unawaited(_probe()));
  }

  Future<void> _probe() async {
    _probeTimer = null;
    if (_probing || !_inForeground || !_reachability.isOffline) return;

    _probing = true;
    try {
      if (await _serverAnswers()) {
        _reachability.noteAnswer();
        await _reopenSession();
      }
    } catch (error) {
      log('Reconnection failed', name: 'Api', error: error);
    } finally {
      _probing = false;
    }

    // No answer, or the refresh failed again: try later, less often.
    if (_reachability.isOffline) {
      final next = _probeDelay * 2;
      _probeDelay = next > _probeMaxDelay ? _probeMaxDelay : next;
      _scheduleProbe();
    }
  }

  Future<bool> _serverAnswers() async {
    try {
      final response = await api.get<dynamic>(_healthzUrl,
          options: Options(
              extra: {_probeKey: true}, receiveTimeout: _probeTimeout));
      // Our /healthz answers a JSON object, with a 200 once MySQL and Redis
      // are up; a 503 means the API cannot serve yet.
      return response.statusCode == 200 && response.data is Map;
    } catch (_) {
      return false;
    }
  }

  /// The server answers again. A session unlocked offline has no access token
  /// yet: open it with the factor given at unlock (online on success, the
  /// session ends if the server turns it down).
  Future<void> _reopenSession() async {
    if (accessToken == null &&
        await LocalStorageManager.getValue(LocalStorageKey.refreshToken) !=
            null) {
      final outcome = await _refreshSession(interactive: false);
      if (outcome != _Refresh.secondFactorRequired) return;
      // The factor is not held by this session: the next request the user
      // makes asks for it (see _doRefreshSession).
    }
    _markOnline();
  }

  bool get _failFast {
    final lastFailure = _reachability.lastFailureAt;
    return _reachability.isOffline &&
        lastFailure != null &&
        DateTime.now().difference(lastFailure) < _failFastWindow;
  }

  /// Whether [error] means "the server did not answer" rather than an answer
  /// the caller has to deal with.
  static bool _isUnreachable(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
      case DioExceptionType.badCertificate:
        return true;
      case DioExceptionType.unknown:
        return error.response == null;
      case DioExceptionType.cancel:
      case DioExceptionType.transformTimeout:
        return false;
      case DioExceptionType.badResponse:
        // A gateway in front of the backend answering for it.
        final status = error.response?.statusCode;
        return status == 502 || status == 503 || status == 504;
    }
  }

  static const _retriedKey = 'homl_retried';
  static const _probeKey = 'homl_probe';

  /// Paths that must never trigger an automatic token refresh: a 401 there is
  /// a real authentication failure, not an expired access token.
  static const _noRefreshPaths = [
    '/login',
    '/refresh',
    '/challenge',
    '/registration',
    '/resetPassword',
    '/confirmResetPassword',
  ];

  Api._internal() : this.internal(initFromStorage: true);

  @visibleForTesting
  Api.internal(
      {String? baseUrlOverride,
      bool initFromStorage = true,
      Future<String> Function()? readBiometricKeyPair})
      : _readBiometricKeyPair =
            readBiometricKeyPair ?? biometric.readBiometricKeyPair {
    final effectiveBaseUrl = baseUrlOverride ?? baseUrl;
    if (effectiveBaseUrl.isEmpty) {
      throw StateError(
          'API_BASE_URL is not set. Run with --dart-define=API_BASE_URL=<url>');
    }

    _controller = StreamController<AuthenticationStatus>.broadcast();
    _healthzUrl = healthzUrl(effectiveBaseUrl);

    api = Dio(BaseOptions(
      baseUrl: effectiveBaseUrl,
      contentType: Headers.jsonContentType,
      responseType: ResponseType.json,
      // Short, so an offline start reaches the saved data quickly: away from
      // the LAN, the server's address typically just drops the packets.
      connectTimeout: const Duration(seconds: 5),
      // A server that accepts the connection but never answers must not hang
      // the app either; the long E2EE migrations set their own.
      receiveTimeout: const Duration(seconds: 30),
    ));

    if (initFromStorage) {
      unawaited(restoreSession());
    }

    // Create interceptor which will manage tokens for each request
    api.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      if (options.extra[_probeKey] == true) {
        options.connectTimeout = _probeTimeout;
      } else if (_failFast) {
        return handler.reject(DioException.connectionError(
            requestOptions: options, reason: 'server unreachable (offline)'));
      }
      if (accessToken != null) {
        options.headers['Authorization'] = 'Bearer $accessToken';
      }
      return handler.next(options);
    }, onResponse: (response, handler) {
      // Offline was flagged by a failure, yet a regular request just went
      // through: the server is back. A request of a session unlocked offline
      // then gets its token through the usual 401 → refresh with the factor
      // held by the session. Not the auth paths: a session reopening goes
      // online once its refresh lands (see _postRefresh), not at its
      // challenge. JSON or 204 only: a captive portal answering for the
      // server with its login page does not count.
      final options = response.requestOptions;
      final isAuthPath = _noRefreshPaths.any(options.path.endsWith);
      final isOurs = response.statusCode == 204 ||
          (response.headers.value(Headers.contentTypeHeader) ?? '')
              .contains('json');
      if (options.extra[_probeKey] != true &&
          !isAuthPath &&
          _reachability.isOffline &&
          isOurs) {
        _markOnline();
      }
      return handler.next(response);
    }, onError: (DioException error, handler) async {
      log('HTTP interceptor caught an error', name: 'Api');
      final options = error.requestOptions;
      final isProbe = options.extra[_probeKey] == true;
      final alreadyRetried = options.extra[_retriedKey] == true;
      final isAuthPath = _noRefreshPaths
          .any((noRefreshPath) => options.path.endsWith(noRefreshPath));

      if (isProbe) return handler.next(error);

      if (_isUnreachable(error)) {
        log('Server unreachable', name: 'Api', error: error);
        _markOffline();
        return handler.next(error);
      }

      if (error.response?.statusCode == 401 && !isAuthPath && !alreadyRetried) {
        log('Access token expired, attempting refresh', name: 'Api');
        final refreshed = await _refreshSession(interactive: true);
        if (refreshed == _Refresh.refreshed) {
          try {
            return handler.resolve(await _retry(options));
          } on DioException catch (retryError) {
            return handler.next(retryError);
          }
        }
        // The refresh failed: propagate the original 401 to the caller.
        return handler.next(error);
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

  /// Restores the session on app start: fingerprint or PIN when enabled,
  /// plain refresh token otherwise. When the server cannot be reached the
  /// session still opens on the data saved on this device, once the factor
  /// passed its local check (homl-web/docs/auth-flows.md, "Offline unlock").
  Future<void> restoreSession() async {
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
        await sendBiometricAuth();
      } else if (keyPair != null) {
        _controller.add(AuthenticationStatus.pinCheck);
      } else {
        await _openSession(await _postRefresh(refreshToken));
      }
    } catch (e) {
      log('Error while restoring the authentication state $e', name: 'Api');
      _controller.add(AuthenticationStatus.unauthenticated);
    }
  }
}
