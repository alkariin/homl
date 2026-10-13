import 'package:flutter/foundation.dart';
import 'package:rxdart/rxdart.dart';

enum Reachability {
  /// Nothing observed yet (app start, before the first request lands).
  unknown,

  /// The backend answered recently.
  online,

  /// The last request could not reach the backend (no network, timeout,
  /// gateway error): the app runs on the data saved on this device until a
  /// probe finds the server again.
  offline,
}

/// Whether the backend answers, as last observed by the Api.
///
/// A plain singleton that needs no API_BASE_URL, unlike the Api: the cubits
/// read it when a request fails (to say "server unreachable" rather than
/// "unexpected error") and their tests must be able to build them without
/// the network stack.
class ServerReachability {
  static final ServerReachability instance = ServerReachability._();
  ServerReachability._();

  final BehaviorSubject<Reachability> _subject =
      BehaviorSubject.seeded(Reachability.unknown);

  /// Emits the current value first, then each change.
  Stream<Reachability> get stream => _subject.stream.distinct();

  Reachability get value => _subject.value;

  bool get isOffline => value == Reachability.offline;

  /// When the last transport failure was observed. Requests fail fast for a
  /// short window after it instead of each waiting for its own timeout.
  DateTime? get lastFailureAt => _lastFailureAt;
  DateTime? _lastFailureAt;

  void markOnline() {
    _lastFailureAt = null;
    _subject.add(Reachability.online);
  }

  void markOffline() {
    _lastFailureAt = DateTime.now();
    _subject.add(Reachability.offline);
  }

  /// No session to be online or offline for (it just ended).
  void markUnknown() {
    _lastFailureAt = null;
    _subject.add(Reachability.unknown);
  }

  /// The server answered a probe: stop failing requests fast, so the ones
  /// that reopen the session go through, while still offline until they do.
  void noteAnswer() => _lastFailureAt = null;

  @visibleForTesting
  void reset() => markUnknown();
}
