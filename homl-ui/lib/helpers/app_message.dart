import 'package:homl/helpers/server_reachability.dart';
import 'package:homl/l10n/app_localizations.dart';

/// User-facing messages emitted by the blocs.
///
/// Blocs emit these codes instead of localized strings so that they do not
/// depend on a cached [AppLocalizations] (which goes stale when the locale
/// changes). The views translate the code with the current context.
enum AppMessage {
  unexpectedError,
  insertNoTags,
  fingerprintUnavailable,
  pinEnabled,
  pinDisabled,
  passwordIncorrect,
  passwordUpdateError,
  e2eeEnabled,
  e2eeDisabled,
  e2eeError,
  accountDeleteError,
  categoryTagNameConflict,
  tagNameConflict,
  serverUnreachable;

  /// The message for a request that failed: "server unreachable" when the
  /// Api just saw the server go away (the change needs a connection), the
  /// generic error otherwise.
  static AppMessage get requestFailed => ServerReachability.instance.isOffline
      ? AppMessage.serverUnreachable
      : AppMessage.unexpectedError;
}

extension AppMessageLocalization on AppMessage {
  String localize(AppLocalizations localization) {
    switch (this) {
      case AppMessage.unexpectedError:
        return localization.global_unexpectedError;
      case AppMessage.insertNoTags:
        return localization.insert_noTagsError;
      case AppMessage.fingerprintUnavailable:
        return localization.account_fingerprintSwitchError;
      case AppMessage.pinEnabled:
        return localization.account_pinEnabled;
      case AppMessage.pinDisabled:
        return localization.account_pinDisabled;
      case AppMessage.passwordIncorrect:
        return localization.account_passwordIncorrect;
      case AppMessage.passwordUpdateError:
        return localization.account_passwordUpdateError;
      case AppMessage.e2eeEnabled:
        return localization.account_e2eeEnabled;
      case AppMessage.e2eeDisabled:
        return localization.account_e2eeDisabled;
      case AppMessage.e2eeError:
        return localization.account_e2eeError;
      case AppMessage.accountDeleteError:
        return localization.account_deleteAccountError;
      case AppMessage.categoryTagNameConflict:
        return localization.categories_deleteTagNameConflict;
      case AppMessage.tagNameConflict:
        return localization.categories_tagNameConflict;
      case AppMessage.serverUnreachable:
        return localization.global_serverUnreachable;
    }
  }
}
