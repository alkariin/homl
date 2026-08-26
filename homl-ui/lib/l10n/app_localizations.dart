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

  /// No description provided for @insert_noTagsError.
  ///
  /// In en, this message translates to:
  /// **'Add at least one tag'**
  String get insert_noTagsError;

  /// No description provided for @list_filterLabel.
  ///
  /// In en, this message translates to:
  /// **'Filter by tag'**
  String get list_filterLabel;

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
  /// **'Move the tags to the Other category'**
  String get categories_deleteMoveTags;

  /// No description provided for @categories_categoryName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get categories_categoryName;

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
  /// **'{count, plural, =1{1 event has no other tag:} other{{count} events have no other tag:}}'**
  String categories_deleteTagExclusiveEvents(int count);

  /// No description provided for @categories_deleteTagKeepEvents.
  ///
  /// In en, this message translates to:
  /// **'Keep these events (date only)'**
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
  /// **'{count, plural, =1{1 event only uses tags from this category and will be deleted.} other{{count} events only use tags from this category and will be deleted.}}'**
  String categories_deleteCategoryDeleteAllDetail(int count);
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
