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
/// A plain singleton that needs no network stack, unlike the Api: the cubits
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

  /// Offline, and no probe has found the server since: requests fail at once
  /// instead of each waiting for its own timeout, however long it lasts.
  bool get failsFast => _failsFast;
  bool _failsFast = false;

  /// Looks for the server now, set by the Api ([checkNow]).
  Future<void> Function()? _check;

  set checker(Future<void> Function() check) => _check = check;

  void markOnline() {
    _failsFast = false;
    _subject.add(Reachability.online);
  }

  void markOffline() {
    _failsFast = true;
    _subject.add(Reachability.offline);
  }

  /// No session to be online or offline for (it just ended).
  void markUnknown() {
    _failsFast = false;
    _subject.add(Reachability.unknown);
  }

  /// The server answered a probe: stop failing requests fast, so the ones
  /// that reopen the session go through, while still offline until they do.
  void noteAnswer() => _failsFast = false;

  /// The user asked (pull to refresh): look for the server now rather than
  /// at the next probe, since requests fail at once while offline. Settles
  /// once the server answered and the session reopened, or did not.
  Future<void> checkNow() => _check?.call() ?? Future.value();

  @visibleForTesting
  void reset() {
    _check = null;
    markUnknown();
  }
}
