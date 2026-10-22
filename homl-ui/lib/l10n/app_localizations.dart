import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
    Locale('fr')
  ];

  /// No description provided for @global_unexpectedError.
  ///
  /// In en, this message translates to:
  /// **'Unexpected error'**
  String get global_unexpectedError;

  /// No description provided for @global_serverUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Server unreachable: this needs a connection.'**
  String get global_serverUnreachable;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get account;

  /// No description provided for @account_logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get account_logout;

  /// No description provided for @account_updatePassword.
  ///
  /// In en, this message translates to:
  /// **'Update password'**
  String get account_updatePassword;

  /// No description provided for @account_currentPassword.
  ///
  /// In en, this message translates to:
  /// **'Current password'**
  String get account_currentPassword;

  /// No description provided for @account_enterPassword.
  ///
  /// In en, this message translates to:
  /// **'Enter the new password'**
  String get account_enterPassword;

  /// No description provided for @account_repeatPassword.
  ///
  /// In en, this message translates to:
  /// **'Repeat the password'**
  String get account_repeatPassword;

  /// No description provided for @account_fingerprintSwitchText.
  ///
  /// In en, this message translates to:
  /// **'Add fingerprint lock'**
  String get account_fingerprintSwitchText;

  /// No description provided for @account_fingerprintSwitchError.
  ///
  /// In en, this message translates to:
  /// **'Can\'t use biometric auth on this device.'**
  String get account_fingerprintSwitchError;

  /// No description provided for @account_pinSwitchText.
  ///
  /// In en, this message translates to:
  /// **'Add PIN code'**
  String get account_pinSwitchText;

  /// No description provided for @account_pinSwitchError.
  ///
  /// In en, this message translates to:
  /// **'PIN couldn\'t be configured'**
  String get account_pinSwitchError;

  /// No description provided for @account_enterPin.
  ///
  /// In en, this message translates to:
  /// **'Enter the PIN code'**
  String get account_enterPin;

  /// No description provided for @account_pinEnabled.
  ///
  /// In en, this message translates to:
  /// **'PIN has been successfully enabled'**
  String get account_pinEnabled;

  /// No description provided for @account_pinDisabled.
  ///
  /// In en, this message translates to:
  /// **'PIN has been successfully disabled'**
  String get account_pinDisabled;

  /// No description provided for @account_pinIncorrect.
  ///
  /// In en, this message translates to:
  /// **'The PIN code is not correct'**
  String get account_pinIncorrect;

  /// No description provided for @account_pinOfflineUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Server unreachable. Your PIN works offline once you have entered it here while connected.'**
  String get account_pinOfflineUnavailable;

  /// No description provided for @account_returnToLogin.
  ///
  /// In en, this message translates to:
  /// **'Return to login'**
  String get account_returnToLogin;

  /// No description provided for @account_passwordUpdated.
  ///
  /// In en, this message translates to:
  /// **'Your password has been updated'**
  String get account_passwordUpdated;

  /// No description provided for @account_passwordIncorrect.
  ///
  /// In en, this message translates to:
  /// **'The password is not correct'**
  String get account_passwordIncorrect;

  /// No description provided for @account_passwordUpdateError.
  ///
  /// In en, this message translates to:
  /// **'An error appeared during the update, try again later'**
  String get account_passwordUpdateError;

  /// No description provided for @account_currentPasswordError.
  ///
  /// In en, this message translates to:
  /// **'Enter your current password'**
  String get account_currentPasswordError;

  /// No description provided for @account_passwordsNotIdentical.
  ///
  /// In en, this message translates to:
  /// **'Passwords aren\'t identical'**
  String get account_passwordsNotIdentical;

  /// No description provided for @account_deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete my account'**
  String get account_deleteAccount;

  /// No description provided for @account_deleteAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete your account?'**
  String get account_deleteAccountTitle;

  /// No description provided for @account_deleteAccountWarning.
  ///
  /// In en, this message translates to:
  /// **'This permanently deletes your account and all your events, tags and categories, on every device. This cannot be undone. Enter your password to confirm.'**
  String get account_deleteAccountWarning;

  /// No description provided for @account_deleteAccountError.
  ///
  /// In en, this message translates to:
  /// **'The account could not be deleted, try again later'**
  String get account_deleteAccountError;

  /// No description provided for @account_deleted.
  ///
  /// In en, this message translates to:
  /// **'Your account has been deleted'**
  String get account_deleted;

  /// No description provided for @account_sessions.
  ///
  /// In en, this message translates to:
  /// **'Signed-in devices'**
  String get account_sessions;

  /// No description provided for @sessions_thisDevice.
  ///
  /// In en, this message translates to:
  /// **'This device'**
  String get sessions_thisDevice;

  /// No description provided for @sessions_lastActive.
  ///
  /// In en, this message translates to:
  /// **'Last active {date}'**
  String sessions_lastActive(String date);

  /// No description provided for @sessions_signedIn.
  ///
  /// In en, this message translates to:
  /// **'Signed in {date}'**
  String sessions_signedIn(String date);

  /// No description provided for @sessions_signedInUnknown.
  ///
  /// In en, this message translates to:
  /// **'Signed in before devices were listed'**
  String get sessions_signedInUnknown;

  /// No description provided for @sessions_app.
  ///
  /// In en, this message translates to:
  /// **'app {version}'**
  String sessions_app(String version);

  /// No description provided for @sessions_unknownDevice.
  ///
  /// In en, this message translates to:
  /// **'Unknown device'**
  String get sessions_unknownDevice;

  /// No description provided for @sessions_signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get sessions_signOut;

  /// No description provided for @sessions_signOutTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign this device out?'**
  String get sessions_signOutTitle;

  /// No description provided for @sessions_signOutInfo.
  ///
  /// In en, this message translates to:
  /// **'It will need the password to sign in again. Its changes not sent yet wait on it until then.'**
  String get sessions_signOutInfo;

  /// No description provided for @sessions_signOutOthers.
  ///
  /// In en, this message translates to:
  /// **'Sign out all other devices'**
  String get sessions_signOutOthers;

  /// No description provided for @sessions_signOutOthersTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign out all other devices?'**
  String get sessions_signOutOthersTitle;

  /// No description provided for @sessions_failed.
  ///
  /// In en, this message translates to:
  /// **'The devices could not be listed: this needs a connection.'**
  String get sessions_failed;

  /// No description provided for @sessions_retry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get sessions_retry;

  /// No description provided for @sessions_actionFailed.
  ///
  /// In en, this message translates to:
  /// **'That did not work: try again once the server is reachable.'**
  String get sessions_actionFailed;

  /// No description provided for @sessions_activityNote.
  ///
  /// In en, this message translates to:
  /// **'Last activity is renewed about every ten minutes of use. The address is the one of that moment.'**
  String get sessions_activityNote;

  /// No description provided for @login_usernameLabel.
  ///
  /// In en, this message translates to:
  /// **'username'**
  String get login_usernameLabel;

  /// No description provided for @login_passwordLabel.
  ///
  /// In en, this message translates to:
  /// **'password'**
  String get login_passwordLabel;

  /// No description provided for @login_submit.
  ///
  /// In en, this message translates to:
  /// **'login'**
  String get login_submit;

  /// No description provided for @login_register.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get login_register;

  /// No description provided for @login_incorrectCredentials.
  ///
  /// In en, this message translates to:
  /// **'Incorrect email or password'**
  String get login_incorrectCredentials;

  /// No description provided for @login_serverUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Server unreachable. Check your connection and try again.'**
  String get login_serverUnreachable;

  /// No description provided for @login_invalidEmail.
  ///
  /// In en, this message translates to:
  /// **'The email is not valid'**
  String get login_invalidEmail;

  /// No description provided for @login_invalidPassword.
  ///
  /// In en, this message translates to:
  /// **'Must contain at least one number, one uppercase and lowercase letter, one special character, and at least 8 or more characters'**
  String get login_invalidPassword;

  /// No description provided for @login_forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get login_forgotPassword;

  /// No description provided for @login_pinLocked.
  ///
  /// In en, this message translates to:
  /// **'Your PIN has been locked after too many attempts. Please log in with your password.'**
  String get login_pinLocked;

  /// No description provided for @login_server.
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get login_server;

  /// No description provided for @login_serverChoose.
  ///
  /// In en, this message translates to:
  /// **'Choose a server'**
  String get login_serverChoose;

  /// No description provided for @login_serverLabel.
  ///
  /// In en, this message translates to:
  /// **'Server address'**
  String get login_serverLabel;

  /// No description provided for @login_serverHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. http://192.168.1.10:8090'**
  String get login_serverHint;

  /// No description provided for @login_serverInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter an address such as http://192.168.1.10:8090'**
  String get login_serverInvalid;

  /// No description provided for @login_serverNoAnswer.
  ///
  /// In en, this message translates to:
  /// **'No server answers at this address.'**
  String get login_serverNoAnswer;

  /// No description provided for @login_serverNotHoml.
  ///
  /// In en, this message translates to:
  /// **'Something answers at this address, but it is not a homl server.'**
  String get login_serverNotHoml;

  /// No description provided for @login_serverUntrusted.
  ///
  /// In en, this message translates to:
  /// **'This server\'s certificate is not trusted by the device.'**
  String get login_serverUntrusted;

  /// No description provided for @login_serverCleartext.
  ///
  /// In en, this message translates to:
  /// **'Unencrypted connection: use it on your home network only.'**
  String get login_serverCleartext;

  /// No description provided for @login_serverConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected to homl {version}'**
  String login_serverConnected(String version);

  /// No description provided for @login_serverConnectedNoVersion.
  ///
  /// In en, this message translates to:
  /// **'Connected to the server'**
  String get login_serverConnectedNoVersion;

  /// No description provided for @forgot_title.
  ///
  /// In en, this message translates to:
  /// **'Reset password'**
  String get forgot_title;

  /// No description provided for @forgot_emailInstructions.
  ///
  /// In en, this message translates to:
  /// **'Enter your email address and we will send you a 6-digit code.'**
  String get forgot_emailInstructions;

  /// No description provided for @forgot_sendCode.
  ///
  /// In en, this message translates to:
  /// **'Send code'**
  String get forgot_sendCode;

  /// No description provided for @forgot_codeInstructions.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6-digit code sent to your email and choose a new password.'**
  String get forgot_codeInstructions;

  /// No description provided for @forgot_newPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get forgot_newPasswordLabel;

  /// No description provided for @forgot_confirmPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get forgot_confirmPasswordLabel;

  /// No description provided for @forgot_submit.
  ///
  /// In en, this message translates to:
  /// **'Reset password'**
  String get forgot_submit;

  /// No description provided for @forgot_resendCode.
  ///
  /// In en, this message translates to:
  /// **'Resend code'**
  String get forgot_resendCode;

  /// No description provided for @forgot_invalidCode.
  ///
  /// In en, this message translates to:
  /// **'The code is invalid or has expired'**
  String get forgot_invalidCode;

  /// No description provided for @account_pinAttemptsRemaining.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 attempt remaining} other{{count} attempts remaining}}'**
  String account_pinAttemptsRemaining(int count);

  /// No description provided for @biometric_failedTitle.
  ///
  /// In en, this message translates to:
  /// **'Fingerprint authentication failed'**
  String get biometric_failedTitle;

  /// No description provided for @biometric_failedMessage.
  ///
  /// In en, this message translates to:
  /// **'We could not verify your fingerprint.'**
  String get biometric_failedMessage;

  /// No description provided for @biometric_retry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get biometric_retry;

  /// No description provided for @biometric_usePassword.
  ///
  /// In en, this message translates to:
  /// **'Use my password'**
  String get biometric_usePassword;

  /// No description provided for @register_submit.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get register_submit;

  /// No description provided for @register_failure.
  ///
  /// In en, this message translates to:
  /// **'Registration failed'**
  String get register_failure;

  /// Shown instead of the sign-up form when the server takes no new accounts (REGISTRATION_OPEN=false on the backend).
  ///
  /// In en, this message translates to:
  /// **'Registration is closed'**
  String get register_closedTitle;

  /// No description provided for @register_closedInfo.
  ///
  /// In en, this message translates to:
  /// **'This server takes no new accounts. Whoever runs it can open registration.'**
  String get register_closedInfo;

  /// No description provided for @register_backToLogin.
  ///
  /// In en, this message translates to:
  /// **'Back to login'**
  String get register_backToLogin;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @settings_language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settings_language;

  /// No description provided for @settings_selectLanguage.
  ///
  /// In en, this message translates to:
  /// **'Select language'**
  String get settings_selectLanguage;

  /// No description provided for @settings_homeTab.
  ///
  /// In en, this message translates to:
  /// **'Home screen'**
  String get settings_homeTab;

  /// No description provided for @settings_selectHomeTab.
  ///
  /// In en, this message translates to:
  /// **'Select home screen'**
  String get settings_selectHomeTab;

  /// No description provided for @settings_appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settings_appearance;

  /// No description provided for @settings_selectAppearance.
  ///
  /// In en, this message translates to:
  /// **'Select appearance'**
  String get settings_selectAppearance;

  /// No description provided for @settings_themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get settings_themeSystem;

  /// No description provided for @settings_themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settings_themeLight;

  /// No description provided for @settings_themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get settings_themeDark;

  /// No description provided for @settings_about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settings_about;

  /// No description provided for @settings_versionApp.
  ///
  /// In en, this message translates to:
  /// **'App {version}'**
  String settings_versionApp(String version);

  /// No description provided for @settings_versionServer.
  ///
  /// In en, this message translates to:
  /// **'Server {version}'**
  String settings_versionServer(String version);

  /// No description provided for @settings_versionServerUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Server unreachable'**
  String get settings_versionServerUnavailable;

  /// No description provided for @global_cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get global_cancel;

  /// No description provided for @global_save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get global_save;

  /// No description provided for @global_delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get global_delete;

  /// No description provided for @global_close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get global_close;

  /// No description provided for @global_update.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get global_update;

  /// No description provided for @e2ee_cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get e2ee_cancel;

  /// No description provided for @e2ee_continue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get e2ee_continue;

  /// No description provided for @account_e2eeSwitchText.
  ///
  /// In en, this message translates to:
  /// **'End-to-end encryption (only this device can read)'**
  String get account_e2eeSwitchText;

  /// No description provided for @account_e2eeEnableTitle.
  ///
  /// In en, this message translates to:
  /// **'Encrypt your data'**
  String get account_e2eeEnableTitle;

  /// No description provided for @account_e2eeEnableWarning.
  ///
  /// In en, this message translates to:
  /// **'Your tags, categories and notes will be encrypted on this device with a key only you hold. The server can no longer read them. If you lose the key and its recovery phrase, the data is lost for good.'**
  String get account_e2eeEnableWarning;

  /// No description provided for @account_e2eeDisableTitle.
  ///
  /// In en, this message translates to:
  /// **'Turn off encryption'**
  String get account_e2eeDisableTitle;

  /// No description provided for @account_e2eeDisableWarning.
  ///
  /// In en, this message translates to:
  /// **'Your data will stay encrypted on the server, but the server will be able to read it again. Continue?'**
  String get account_e2eeDisableWarning;

  /// No description provided for @account_e2eeEnabled.
  ///
  /// In en, this message translates to:
  /// **'Encryption enabled'**
  String get account_e2eeEnabled;

  /// No description provided for @account_e2eeDisabled.
  ///
  /// In en, this message translates to:
  /// **'Encryption disabled'**
  String get account_e2eeDisabled;

  /// No description provided for @account_e2eeError.
  ///
  /// In en, this message translates to:
  /// **'Encryption change failed, try again later'**
  String get account_e2eeError;

  /// No description provided for @account_e2eeMnemonicTitle.
  ///
  /// In en, this message translates to:
  /// **'Your recovery phrase'**
  String get account_e2eeMnemonicTitle;

  /// No description provided for @account_e2eeMnemonicHint.
  ///
  /// In en, this message translates to:
  /// **'Write these 12 words down and keep them somewhere safe. They are the only way to recover your data on another device or after reinstalling. We cannot recover them for you.'**
  String get account_e2eeMnemonicHint;

  /// No description provided for @account_e2eeMnemonicSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip (risky)'**
  String get account_e2eeMnemonicSkip;

  /// No description provided for @account_e2eeMnemonicSaved.
  ///
  /// In en, this message translates to:
  /// **'I saved it'**
  String get account_e2eeMnemonicSaved;

  /// No description provided for @account_e2eeMnemonicCount.
  ///
  /// In en, this message translates to:
  /// **'{count} words'**
  String account_e2eeMnemonicCount(int count);

  /// No description provided for @account_e2eeMnemonicCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get account_e2eeMnemonicCopy;

  /// No description provided for @account_e2eeMnemonicCopied.
  ///
  /// In en, this message translates to:
  /// **'Recovery phrase copied'**
  String get account_e2eeMnemonicCopied;

  /// No description provided for @e2ee_lockedTitle.
  ///
  /// In en, this message translates to:
  /// **'Encrypted data'**
  String get e2ee_lockedTitle;

  /// No description provided for @e2ee_lockedExplanation.
  ///
  /// In en, this message translates to:
  /// **'This account is end-to-end encrypted, but this device has no key. Enter your recovery phrase to unlock your data, or delete it to start over.'**
  String get e2ee_lockedExplanation;

  /// No description provided for @e2ee_restoreHint.
  ///
  /// In en, this message translates to:
  /// **'Recovery phrase (12 words)'**
  String get e2ee_restoreHint;

  /// No description provided for @e2ee_restoreButton.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get e2ee_restoreButton;

  /// No description provided for @e2ee_restoreInvalid.
  ///
  /// In en, this message translates to:
  /// **'This phrase is valid but does not match this account. It may come from another account or an older, cancelled activation.'**
  String get e2ee_restoreInvalid;

  /// No description provided for @e2ee_restoreMalformed.
  ///
  /// In en, this message translates to:
  /// **'This is not a valid recovery phrase: check for typos or autocorrected words (12 lowercase English words).'**
  String get e2ee_restoreMalformed;

  /// No description provided for @e2ee_restoreUnknownWords.
  ///
  /// In en, this message translates to:
  /// **'Words not in the dictionary'**
  String get e2ee_restoreUnknownWords;

  /// No description provided for @e2ee_restoreWordCount.
  ///
  /// In en, this message translates to:
  /// **'You entered {count} words — a recovery phrase has exactly 12.'**
  String e2ee_restoreWordCount(int count);

  /// No description provided for @e2ee_restoreChecksum.
  ///
  /// In en, this message translates to:
  /// **'All 12 words exist, but the phrase\'s checksum fails: two words are probably swapped, or one was replaced by a similar dictionary word.'**
  String get e2ee_restoreChecksum;

  /// No description provided for @e2ee_purgeButton.
  ///
  /// In en, this message translates to:
  /// **'Delete my encrypted data'**
  String get e2ee_purgeButton;

  /// No description provided for @e2ee_purgeConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete everything?'**
  String get e2ee_purgeConfirmTitle;

  /// No description provided for @e2ee_purgeConfirmText.
  ///
  /// In en, this message translates to:
  /// **'This permanently deletes all your encrypted events, tags and categories and turns encryption off. This cannot be undone.'**
  String get e2ee_purgeConfirmText;

  /// No description provided for @e2ee_purgeConfirmAction.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get e2ee_purgeConfirmAction;

  /// No description provided for @nav_categories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get nav_categories;

  /// No description provided for @nav_search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get nav_search;

  /// No description provided for @nav_add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get nav_add;

  /// No description provided for @insert_tagInputLabel.
  ///
  /// In en, this message translates to:
  /// **'Add a tag'**
  String get insert_tagInputLabel;

  /// No description provided for @insert_newTagCategoryTitle.
  ///
  /// In en, this message translates to:
  /// **'New tag \"{tag}\": choose a category'**
  String insert_newTagCategoryTitle(String tag);

  /// No description provided for @insert_descriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get insert_descriptionLabel;

  /// No description provided for @insert_submit.
  ///
  /// In en, this message translates to:
  /// **'Create event'**
  String get insert_submit;

  /// No description provided for @insert_eventCreated.
  ///
  /// In en, this message translates to:
  /// **'Event created'**
  String get insert_eventCreated;

  /// No description provided for @insert_emptyError.
  ///
  /// In en, this message translates to:
  /// **'Add a tag or a description'**
  String get insert_emptyError;

  /// No description provided for @insert_periodSingleDay.
  ///
  /// In en, this message translates to:
  /// **'Single day'**
  String get insert_periodSingleDay;

  /// No description provided for @insert_periodClosed.
  ///
  /// In en, this message translates to:
  /// **'Period'**
  String get insert_periodClosed;

  /// No description provided for @insert_periodOngoing.
  ///
  /// In en, this message translates to:
  /// **'Ongoing'**
  String get insert_periodOngoing;

  /// No description provided for @list_filterLabel.
  ///
  /// In en, this message translates to:
  /// **'Tag or text'**
  String get list_filterLabel;

  /// Example search in the empty field: a tag excluded with a leading '-', then a text in quotes (searched in the descriptions); the '-' comes first so it survives a cut. Keep it short: the field is narrow on a phone.
  ///
  /// In en, this message translates to:
  /// **'-Bob, \"beach\"'**
  String get list_filterHint;

  /// No description provided for @activity_title.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get activity_title;

  /// No description provided for @activity_lastYear.
  ///
  /// In en, this message translates to:
  /// **'Last 12 months'**
  String get activity_lastYear;

  /// No description provided for @activity_pickYear.
  ///
  /// In en, this message translates to:
  /// **'Pick a year'**
  String get activity_pickYear;

  /// No description provided for @activity_less.
  ///
  /// In en, this message translates to:
  /// **'Less'**
  String get activity_less;

  /// No description provided for @activity_more.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get activity_more;

  /// Tooltip of a day square of the activity calendar.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No event} =1{1 event} other{{count} events}} · {date}'**
  String activity_day(int count, String date);

  /// No description provided for @list_showTimeline.
  ///
  /// In en, this message translates to:
  /// **'Show the timeline'**
  String get list_showTimeline;

  /// No description provided for @list_showGrid.
  ///
  /// In en, this message translates to:
  /// **'Show the grid'**
  String get list_showGrid;

  /// No description provided for @timeline_empty.
  ///
  /// In en, this message translates to:
  /// **'No period here. An event with an end date, or still ongoing, shows up on the timeline.'**
  String get timeline_empty;

  /// Under the timeline: the results it leaves out, which have no length to draw.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 single-day event is not shown} other{{count} single-day events are not shown}}'**
  String timeline_singleDays(int count);

  /// No description provided for @list_noEvents.
  ///
  /// In en, this message translates to:
  /// **'No events found'**
  String get list_noEvents;

  /// No description provided for @list_editEvent.
  ///
  /// In en, this message translates to:
  /// **'Edit event'**
  String get list_editEvent;

  /// No description provided for @list_deleteEventTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete event?'**
  String get list_deleteEventTitle;

  /// No description provided for @list_deleteEventInfo.
  ///
  /// In en, this message translates to:
  /// **'This event and its description will be permanently deleted.'**
  String get list_deleteEventInfo;

  /// No description provided for @list_eventUpdated.
  ///
  /// In en, this message translates to:
  /// **'Event updated'**
  String get list_eventUpdated;

  /// Title of the strip of events that started on today's date in earlier years.
  ///
  /// In en, this message translates to:
  /// **'On this day'**
  String get list_onThisDay;

  /// Before how long ago a search last happened, e.g. "Last time: 14 months ago".
  ///
  /// In en, this message translates to:
  /// **'Last time:'**
  String get list_lastTime;

  /// Instead of how long ago, when one of the results is still going on.
  ///
  /// In en, this message translates to:
  /// **'right now'**
  String get list_lastTimeNow;

  /// No description provided for @list_eventCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 event} other{{count} events}}'**
  String list_eventCount(int count);

  /// How many of the search results started this calendar year.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{none this year} other{{count} this year}}'**
  String list_thisYearCount(int count);

  /// No description provided for @event_ongoing.
  ///
  /// In en, this message translates to:
  /// **'Ongoing'**
  String get event_ongoing;

  /// No description provided for @event_durationDays.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day} other{{count} days}}'**
  String event_durationDays(int count);

  /// No description provided for @event_durationMonths.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 month} other{{count} months}}'**
  String event_durationMonths(int count);

  /// No description provided for @event_durationYears.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 year} other{{count} years}}'**
  String event_durationYears(int count);

  /// Elapsed length of an open period; one key per unit because German declines the noun after 'seit'.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{for 1 day} other{for {count} days}}'**
  String event_sinceDays(int count);

  /// No description provided for @event_sinceMonths.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{for 1 month} other{for {count} months}}'**
  String event_sinceMonths(int count);

  /// No description provided for @event_sinceYears.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{for 1 year} other{for {count} years}}'**
  String event_sinceYears(int count);

  /// How long ago something happened; one key per unit because German declines the noun after 'vor'. 0 = today, 1 = yesterday.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{today} =1{yesterday} other{{count} days ago}}'**
  String event_daysAgo(int count);

  /// No description provided for @event_monthsAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 month ago} other{{count} months ago}}'**
  String event_monthsAgo(int count);

  /// No description provided for @event_yearsAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 year ago} other{{count} years ago}}'**
  String event_yearsAgo(int count);

  /// No description provided for @categories_newCategory.
  ///
  /// In en, this message translates to:
  /// **'New category'**
  String get categories_newCategory;

  /// No description provided for @categories_editCategory.
  ///
  /// In en, this message translates to:
  /// **'Edit category'**
  String get categories_editCategory;

  /// No description provided for @categories_deleteCategory.
  ///
  /// In en, this message translates to:
  /// **'Delete category?'**
  String get categories_deleteCategory;

  /// No description provided for @categories_deleteMoveTags.
  ///
  /// In en, this message translates to:
  /// **'Move the tags to the Others category'**
  String get categories_deleteMoveTags;

  /// No description provided for @categories_categoryName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get categories_categoryName;

  /// No description provided for @categories_defaultDates.
  ///
  /// In en, this message translates to:
  /// **'Dates'**
  String get categories_defaultDates;

  /// No description provided for @categories_defaultPersons.
  ///
  /// In en, this message translates to:
  /// **'Persons'**
  String get categories_defaultPersons;

  /// No description provided for @categories_defaultOthers.
  ///
  /// In en, this message translates to:
  /// **'Others'**
  String get categories_defaultOthers;

  /// No description provided for @categories_color.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get categories_color;

  /// No description provided for @categories_tagCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No tags} =1{1 tag} other{{count} tags}}'**
  String categories_tagCount(int count);

  /// No description provided for @categories_newTag.
  ///
  /// In en, this message translates to:
  /// **'New tag'**
  String get categories_newTag;

  /// No description provided for @categories_browseTags.
  ///
  /// In en, this message translates to:
  /// **'Browse tags'**
  String get categories_browseTags;

  /// No description provided for @categories_pickTag.
  ///
  /// In en, this message translates to:
  /// **'Choose a tag'**
  String get categories_pickTag;

  /// No description provided for @categories_renameTag.
  ///
  /// In en, this message translates to:
  /// **'Rename tag'**
  String get categories_renameTag;

  /// No description provided for @categories_deleteTag.
  ///
  /// In en, this message translates to:
  /// **'Delete tag'**
  String get categories_deleteTag;

  /// No description provided for @categories_addSynonym.
  ///
  /// In en, this message translates to:
  /// **'Add a synonym'**
  String get categories_addSynonym;

  /// No description provided for @categories_detachSynonym.
  ///
  /// In en, this message translates to:
  /// **'Detach synonym'**
  String get categories_detachSynonym;

  /// No description provided for @categories_synonymName.
  ///
  /// In en, this message translates to:
  /// **'Synonym'**
  String get categories_synonymName;

  /// No description provided for @categories_renameSynonym.
  ///
  /// In en, this message translates to:
  /// **'Rename synonym'**
  String get categories_renameSynonym;

  /// No description provided for @categories_deleteSynonymTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete synonym?'**
  String get categories_deleteSynonymTitle;

  /// No description provided for @categories_deleteSynonymInfo.
  ///
  /// In en, this message translates to:
  /// **'Events tagged \"{synonym}\" will be moved to \"{tag}\".'**
  String categories_deleteSynonymInfo(String synonym, String tag);

  /// No description provided for @categories_moveTag.
  ///
  /// In en, this message translates to:
  /// **'Move to another category'**
  String get categories_moveTag;

  /// No description provided for @categories_moveTagTitle.
  ///
  /// In en, this message translates to:
  /// **'Move \"{tag}\" to'**
  String categories_moveTagTitle(String tag);

  /// No description provided for @categories_deleteTagTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{tag}\"?'**
  String categories_deleteTagTitle(String tag);

  /// No description provided for @categories_deleteTagEvents.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No event uses this tag.} =1{1 event uses this tag.} other{{count} events use this tag.}}'**
  String categories_deleteTagEvents(int count);

  /// No description provided for @categories_deleteTagSynonyms.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Its synonym will be deleted too.} other{Its {count} synonyms will be deleted too.}}'**
  String categories_deleteTagSynonyms(int count);

  /// No description provided for @categories_deleteTagExclusiveEvents.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 of them will be left with its date only.} other{{count} of them will be left with their date only.}}'**
  String categories_deleteTagExclusiveEvents(int count);

  /// No description provided for @categories_deleteTagKeepEvents.
  ///
  /// In en, this message translates to:
  /// **'Keep these events, remove the tag'**
  String get categories_deleteTagKeepEvents;

  /// No description provided for @categories_deleteTagDeleteEvents.
  ///
  /// In en, this message translates to:
  /// **'Delete these events'**
  String get categories_deleteTagDeleteEvents;

  /// No description provided for @categories_deleteCategoryTags.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{This category has no tags.} =1{This category has 1 tag.} other{This category has {count} tags.}}'**
  String categories_deleteCategoryTags(int count);

  /// No description provided for @categories_deleteCategoryEvents.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No event uses them.} =1{1 event uses them.} other{{count} events use them.}}'**
  String categories_deleteCategoryEvents(int count);

  /// No description provided for @categories_deleteCategoryDeleteTags.
  ///
  /// In en, this message translates to:
  /// **'Delete the tags, keep the events'**
  String get categories_deleteCategoryDeleteTags;

  /// No description provided for @categories_deleteCategoryDeleteAll.
  ///
  /// In en, this message translates to:
  /// **'Delete the tags and their events'**
  String get categories_deleteCategoryDeleteAll;

  /// No description provided for @categories_deleteCategoryDeleteAllDetail.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 event uses these tags and will be deleted.} other{{count} events use these tags and will be deleted.}}'**
  String categories_deleteCategoryDeleteAllDetail(int count);

  /// No description provided for @categories_deleteTagNameConflict.
  ///
  /// In en, this message translates to:
  /// **'One of these tags or groups already exists in Others. Rename it, or delete the tags instead of moving them.'**
  String get categories_deleteTagNameConflict;

  /// No description provided for @categories_tagNameConflict.
  ///
  /// In en, this message translates to:
  /// **'This category already has a tag with that name. Pick another one.'**
  String get categories_tagNameConflict;

  /// No description provided for @categories_groups.
  ///
  /// In en, this message translates to:
  /// **'Groups'**
  String get categories_groups;

  /// No description provided for @categories_newGroup.
  ///
  /// In en, this message translates to:
  /// **'New group'**
  String get categories_newGroup;

  /// No description provided for @categories_editGroup.
  ///
  /// In en, this message translates to:
  /// **'Edit group'**
  String get categories_editGroup;

  /// No description provided for @categories_deleteGroup.
  ///
  /// In en, this message translates to:
  /// **'Delete group'**
  String get categories_deleteGroup;

  /// No description provided for @categories_groupHint.
  ///
  /// In en, this message translates to:
  /// **'Typing the group\'s name adds all its tags at once.'**
  String get categories_groupHint;

  /// No description provided for @categories_groupMembers.
  ///
  /// In en, this message translates to:
  /// **'Tags of the group'**
  String get categories_groupMembers;

  /// No description provided for @categories_groupNeedsMembers.
  ///
  /// In en, this message translates to:
  /// **'Pick at least one tag.'**
  String get categories_groupNeedsMembers;

  /// No description provided for @categories_groupNameTaken.
  ///
  /// In en, this message translates to:
  /// **'A tag or a group already has this name.'**
  String get categories_groupNameTaken;

  /// No description provided for @categories_groupNameReserved.
  ///
  /// In en, this message translates to:
  /// **'This name is reserved for the dates.'**
  String get categories_groupNameReserved;

  /// No description provided for @categories_groupNameConflict.
  ///
  /// In en, this message translates to:
  /// **'This category already has a group with that name. Pick another one.'**
  String get categories_groupNameConflict;

  /// No description provided for @categories_groupEmpty.
  ///
  /// In en, this message translates to:
  /// **'No tags left'**
  String get categories_groupEmpty;

  /// No description provided for @categories_deleteGroupTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{group}\"?'**
  String categories_deleteGroupTitle(String group);

  /// No description provided for @categories_deleteGroupInfo.
  ///
  /// In en, this message translates to:
  /// **'Only the group goes: its tags and their events stay.'**
  String get categories_deleteGroupInfo;

  /// No description provided for @offline_title.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get offline_title;

  /// No description provided for @offline_explanation.
  ///
  /// In en, this message translates to:
  /// **'Server unreachable. You are viewing the data saved on this device; changes need a connection. The app reconnects by itself.'**
  String get offline_explanation;

  /// No description provided for @offline_explanationSince.
  ///
  /// In en, this message translates to:
  /// **'Server unreachable. You are viewing the data saved on this device (last updated {date}); changes need a connection. The app reconnects by itself.'**
  String offline_explanationSince(String date);

  /// No description provided for @sync_savedOffline.
  ///
  /// In en, this message translates to:
  /// **'Saved on this device. It will be sent once the server is reachable.'**
  String get sync_savedOffline;

  /// No description provided for @sync_sent.
  ///
  /// In en, this message translates to:
  /// **'Your offline changes were sent.'**
  String get sync_sent;

  /// No description provided for @sync_restored.
  ///
  /// In en, this message translates to:
  /// **'An event deleted on another device was edited here: it is back, with your changes.'**
  String get sync_restored;

  /// No description provided for @sync_kept.
  ///
  /// In en, this message translates to:
  /// **'Something you deleted had been changed on another device: it was kept.'**
  String get sync_kept;

  /// No description provided for @sync_conflicts.
  ///
  /// In en, this message translates to:
  /// **'Your offline changes replaced changes made to the same events on another device.'**
  String get sync_conflicts;

  /// No description provided for @sync_parked.
  ///
  /// In en, this message translates to:
  /// **'Some changes could not be sent: see the changes waiting.'**
  String get sync_parked;

  /// No description provided for @sync_dropped.
  ///
  /// In en, this message translates to:
  /// **'A change you made offline was dropped: what it changed had been deleted on another device.'**
  String get sync_dropped;

  /// No description provided for @sync_pendingChangesFirst.
  ///
  /// In en, this message translates to:
  /// **'Changes made offline are still waiting: send or discard them first.'**
  String get sync_pendingChangesFirst;

  /// No description provided for @pending_title.
  ///
  /// In en, this message translates to:
  /// **'Changes waiting'**
  String get pending_title;

  /// No description provided for @pending_info.
  ///
  /// In en, this message translates to:
  /// **'Made on this device while the server was out of reach. They are sent as soon as it answers.'**
  String get pending_info;

  /// No description provided for @pending_sendNow.
  ///
  /// In en, this message translates to:
  /// **'Send now'**
  String get pending_sendNow;

  /// No description provided for @pending_retry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get pending_retry;

  /// No description provided for @pending_discard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get pending_discard;

  /// No description provided for @pending_createEvent.
  ///
  /// In en, this message translates to:
  /// **'New event'**
  String get pending_createEvent;

  /// No description provided for @pending_updateEvent.
  ///
  /// In en, this message translates to:
  /// **'Edited event'**
  String get pending_updateEvent;

  /// No description provided for @pending_deleteEvent.
  ///
  /// In en, this message translates to:
  /// **'Deleted event'**
  String get pending_deleteEvent;

  /// No description provided for @pending_createTag.
  ///
  /// In en, this message translates to:
  /// **'New tag'**
  String get pending_createTag;

  /// No description provided for @pending_updateTag.
  ///
  /// In en, this message translates to:
  /// **'Edited tag'**
  String get pending_updateTag;

  /// No description provided for @pending_deleteTag.
  ///
  /// In en, this message translates to:
  /// **'Deleted tag'**
  String get pending_deleteTag;

  /// No description provided for @pending_createCategory.
  ///
  /// In en, this message translates to:
  /// **'New category'**
  String get pending_createCategory;

  /// No description provided for @pending_updateCategory.
  ///
  /// In en, this message translates to:
  /// **'Edited category'**
  String get pending_updateCategory;

  /// No description provided for @pending_deleteCategory.
  ///
  /// In en, this message translates to:
  /// **'Deleted category'**
  String get pending_deleteCategory;

  /// No description provided for @pending_createGroup.
  ///
  /// In en, this message translates to:
  /// **'New tag group'**
  String get pending_createGroup;

  /// No description provided for @pending_updateGroup.
  ///
  /// In en, this message translates to:
  /// **'Edited tag group'**
  String get pending_updateGroup;

  /// No description provided for @pending_deleteGroup.
  ///
  /// In en, this message translates to:
  /// **'Deleted tag group'**
  String get pending_deleteGroup;

  /// No description provided for @pending_waiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting'**
  String get pending_waiting;

  /// No description provided for @pending_refused.
  ///
  /// In en, this message translates to:
  /// **'Refused by the server'**
  String get pending_refused;

  /// No description provided for @pending_missingTag.
  ///
  /// In en, this message translates to:
  /// **'Uses a tag that could not be created'**
  String get pending_missingTag;

  /// No description provided for @pending_missingParent.
  ///
  /// In en, this message translates to:
  /// **'Needs a category or group that could not be created'**
  String get pending_missingParent;

  /// No description provided for @pending_encryptionChanged.
  ///
  /// In en, this message translates to:
  /// **'The encryption changed on another device'**
  String get pending_encryptionChanged;

  /// No description provided for @pending_dataReplaced.
  ///
  /// In en, this message translates to:
  /// **'The server data was replaced (restored from a backup)'**
  String get pending_dataReplaced;

  /// No description provided for @logout_pendingTitle.
  ///
  /// In en, this message translates to:
  /// **'Changes not sent'**
  String get logout_pendingTitle;

  /// No description provided for @logout_pendingConfirm.
  ///
  /// In en, this message translates to:
  /// **'Log out anyway'**
  String get logout_pendingConfirm;

  /// No description provided for @logout_pendingInfo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 change made offline has not reached the server yet. Logging out loses it.} other{{count} changes made offline have not reached the server yet. Logging out loses them.}}'**
  String logout_pendingInfo(int count);

  /// No description provided for @account_exportData.
  ///
  /// In en, this message translates to:
  /// **'Export my data'**
  String get account_exportData;

  /// No description provided for @account_exportDataHint.
  ///
  /// In en, this message translates to:
  /// **'A file with your categories, tags and events'**
  String get account_exportDataHint;

  /// No description provided for @account_importData.
  ///
  /// In en, this message translates to:
  /// **'Import data'**
  String get account_importData;

  /// No description provided for @account_importDataHint.
  ///
  /// In en, this message translates to:
  /// **'Add the content of an export file'**
  String get account_importDataHint;

  /// No description provided for @export_title.
  ///
  /// In en, this message translates to:
  /// **'Export your data'**
  String get export_title;

  /// No description provided for @export_info.
  ///
  /// In en, this message translates to:
  /// **'The file holds your categories, tags and events. Anyone who gets it can read them, unless it is protected with a password.'**
  String get export_info;

  /// No description provided for @export_passwordSwitch.
  ///
  /// In en, this message translates to:
  /// **'Protect with a password'**
  String get export_passwordSwitch;

  /// No description provided for @export_password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get export_password;

  /// No description provided for @export_passwordRepeat.
  ///
  /// In en, this message translates to:
  /// **'Repeat the password'**
  String get export_passwordRepeat;

  /// No description provided for @export_passwordTooShort.
  ///
  /// In en, this message translates to:
  /// **'At least 8 characters'**
  String get export_passwordTooShort;

  /// No description provided for @export_passwordHint.
  ///
  /// In en, this message translates to:
  /// **'Without this password nobody can open the file, not even you: it cannot be recovered.'**
  String get export_passwordHint;

  /// No description provided for @export_e2eeWarning.
  ///
  /// In en, this message translates to:
  /// **'Your account is end-to-end encrypted: without a password, this file holds your data in clear.'**
  String get export_e2eeWarning;

  /// No description provided for @export_confirm.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get export_confirm;

  /// No description provided for @export_saved.
  ///
  /// In en, this message translates to:
  /// **'Export saved'**
  String get export_saved;

  /// No description provided for @export_failed.
  ///
  /// In en, this message translates to:
  /// **'The export failed, try again later'**
  String get export_failed;

  /// No description provided for @import_passwordTitle.
  ///
  /// In en, this message translates to:
  /// **'Protected file'**
  String get import_passwordTitle;

  /// No description provided for @import_passwordInfo.
  ///
  /// In en, this message translates to:
  /// **'Enter the password chosen when exporting.'**
  String get import_passwordInfo;

  /// No description provided for @import_passwordWrong.
  ///
  /// In en, this message translates to:
  /// **'Wrong password'**
  String get import_passwordWrong;

  /// No description provided for @import_open.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get import_open;

  /// No description provided for @import_invalidFile.
  ///
  /// In en, this message translates to:
  /// **'This file is not a HOML export, or it is damaged'**
  String get import_invalidFile;

  /// No description provided for @import_newerVersion.
  ///
  /// In en, this message translates to:
  /// **'This file comes from a newer version of HOML: update the app to import it'**
  String get import_newerVersion;

  /// No description provided for @import_confirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Import this file?'**
  String get import_confirmTitle;

  /// No description provided for @import_confirmInfo.
  ///
  /// In en, this message translates to:
  /// **'Exported on {date}, it holds:'**
  String import_confirmInfo(String date);

  /// No description provided for @import_confirmMerge.
  ///
  /// In en, this message translates to:
  /// **'Everything is added to your account: what is already there is skipped, and nothing is changed or deleted.'**
  String get import_confirmMerge;

  /// No description provided for @import_countCategories.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 category} other{{count} categories}}'**
  String import_countCategories(int count);

  /// No description provided for @import_countTags.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 tag} other{{count} tags}}'**
  String import_countTags(int count);

  /// No description provided for @import_countGroups.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 tag group} other{{count} tag groups}}'**
  String import_countGroups(int count);

  /// No description provided for @import_countEvents.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 event} other{{count} events}}'**
  String import_countEvents(int count);

  /// No description provided for @import_confirm.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get import_confirm;

  /// No description provided for @import_progress.
  ///
  /// In en, this message translates to:
  /// **'Importing… {done} of {total}'**
  String import_progress(int done, int total);

  /// No description provided for @import_keepOpen.
  ///
  /// In en, this message translates to:
  /// **'Keep the app open until the import ends.'**
  String get import_keepOpen;

  /// No description provided for @import_doneTitle.
  ///
  /// In en, this message translates to:
  /// **'Import finished'**
  String get import_doneTitle;

  /// No description provided for @import_doneAdded.
  ///
  /// In en, this message translates to:
  /// **'Added:'**
  String get import_doneAdded;

  /// No description provided for @import_doneNothing.
  ///
  /// In en, this message translates to:
  /// **'Nothing new: your account already held all of it.'**
  String get import_doneNothing;

  /// No description provided for @import_doneExisting.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 event was already there.} other{{count} events were already there.}}'**
  String import_doneExisting(int count);

  /// No description provided for @import_doneSkipped.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 item was refused by the server (a reserved tag name, for example) and left out.} other{{count} items were refused by the server (a reserved tag name, for example) and left out.}}'**
  String import_doneSkipped(int count);

  /// No description provided for @import_interrupted.
  ///
  /// In en, this message translates to:
  /// **'Connection lost: the import stopped. Import the same file again to finish it, what is already there is skipped.'**
  String get import_interrupted;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
