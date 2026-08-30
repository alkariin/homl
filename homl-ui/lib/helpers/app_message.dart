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
    }
  }
}
