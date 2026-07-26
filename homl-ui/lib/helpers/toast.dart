import 'package:flutter/material.dart';

/// How long a toast stays up on its own: confirmations are short, errors get
/// a little more time to be read.
const Duration _infoDuration = Duration(seconds: 3);
const Duration _errorDuration = Duration(seconds: 5);

/// Shows the app's floating toast, replacing anything already on screen.
///
/// Every user-facing message goes through here rather than through
/// [ScaffoldMessenger.showSnackBar] directly, for two behaviours the raw
/// [SnackBar] does not give us:
///
/// * the whole surface reacts to a tap, which dismisses the toast right away —
///   the timeout is a fallback, not the only way out;
/// * a new toast clears the queue instead of stacking behind it. Queued
///   toasts used to play one after another, so a listener firing on every
///   keystroke (a failed login, then each character retyped) left a trail of
///   toasts still running long after the screen that produced them.
ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showToast(
  BuildContext context,
  String message, {
  bool isError = false,
  Duration? duration,
}) =>
    showToastWith(ScaffoldMessenger.of(context), message,
        isError: isError, duration: duration);

/// [showToast] against an already resolved messenger, for the flows that leave
/// the screen before confirming it (an edit pops back to the list, and its
/// context is gone by then).
ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showToastWith(
  ScaffoldMessengerState messenger,
  String message, {
  bool isError = false,
  Duration? duration,
}) {
  messenger.clearSnackBars();
  return messenger.showSnackBar(SnackBar(
    duration: duration ?? (isError ? _errorDuration : _infoDuration),
    backgroundColor: isError ? Colors.redAccent : null,
    // No padding on the SnackBar, all of it inside the gesture detector: the
    // padding ring has to react to taps too, otherwise the edges of the toast
    // feel dead.
    padding: EdgeInsets.zero,
    content: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: messenger.hideCurrentSnackBar,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Text(message),
      ),
    ),
  ));
}

/// Removes the toast currently on screen, if any.
///
/// Called whenever the user leaves the place a message belongs to (see
/// [ToastRouteObserver] for routes, the home PageView for tabs): a message
/// about the screen just left is noise on the new one.
void dismissToasts(BuildContext context) {
  ScaffoldMessenger.of(context).clearSnackBars();
}

/// Clears the toasts on every route change.
///
/// The messenger lives on the [MaterialApp], above the navigator, so a toast
/// outlives the screen that showed it — a failed-login error used to follow
/// the user all the way into the app. Wired through
/// `MaterialApp.navigatorObservers`, and safe for the
/// navigate-then-confirm flows (an edit pops the route, then shows its
/// confirmation): observers are notified synchronously during the navigation
/// call, so a toast shown after it stays.
class ToastRouteObserver extends NavigatorObserver {
  ToastRouteObserver(this._messengerKey);

  final GlobalKey<ScaffoldMessengerState> _messengerKey;

  void _clear() => _messengerKey.currentState?.clearSnackBars();

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => _clear();

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => _clear();

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      _clear();
}
