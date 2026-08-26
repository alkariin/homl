// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get global_unexpectedError => 'Unexpected error';

  @override
  String get account => 'Security';

  @override
  String get account_logout => 'Logout';

  @override
  String get account_updatePassword => 'Update password';

  @override
  String get account_currentPassword => 'Current password';

  @override
  String get account_enterPassword => 'Enter the new password';

  @override
  String get account_repeatPassword => 'Repeat the password';

  @override
  String get account_fingerprintSwitchText => 'Add fingerprint lock';

  @override
  String get account_fingerprintSwitchError =>
      'Can\'t use biometric auth on this device.';

  @override
  String get account_pinSwitchText => 'Add PIN code';

  @override
  String get account_pinSwitchError => 'PIN couldn\'t be configured';

  @override
  String get account_enterPin => 'Enter the PIN code';

  @override
  String get account_pinEnabled => 'PIN has been successfully enabled';

  @override
  String get account_pinDisabled => 'PIN has been successfully disabled';

  @override
  String get account_pinIncorrect => 'The PIN code is not correct';

  @override
  String get account_returnToLogin => 'Return to login';

  @override
  String get account_passwordUpdated => 'Your password has been updated';

  @override
  String get account_passwordIncorrect => 'The password is not correct';

  @override
  String get account_passwordUpdateError =>
      'An error appeared during the update, try again later';

  @override
  String get account_currentPasswordError => 'Enter your current password';

  @override
  String get account_passwordsNotIdentical => 'Passwords aren\'t identical';

  @override
  String get account_deleteAccount => 'Delete my account';

  @override
  String get account_deleteAccountTitle => 'Delete your account?';

  @override
  String get account_deleteAccountWarning =>
      'This permanently deletes your account and all your events, tags and categories, on every device. This cannot be undone. Enter your password to confirm.';

  @override
  String get account_deleteAccountError =>
      'The account could not be deleted, try again later';

  @override
  String get account_deleted => 'Your account has been deleted';

  @override
  String get login_usernameLabel => 'username';

  @override
  String get login_passwordLabel => 'password';

  @override
  String get login_submit => 'login';

  @override
  String get login_register => 'Register';

  @override
  String get login_incorrectCredentials => 'Incorrect email or password';

  @override
  String get login_invalidEmail => 'The email is not valid';

  @override
  String get login_invalidPassword =>
      'Must contain at least one number, one uppercase and lowercase letter, one special character, and at least 8 or more characters';

  @override
  String get login_forgotPassword => 'Forgot password?';

  @override
  String get login_pinLocked =>
      'Your PIN has been locked after too many attempts. Please log in with your password.';

  @override
  String get forgot_title => 'Reset password';

  @override
  String get forgot_emailInstructions =>
      'Enter your email address and we will send you a 6-digit code.';

  @override
  String get forgot_sendCode => 'Send code';

  @override
  String get forgot_codeInstructions =>
      'Enter the 6-digit code sent to your email and choose a new password.';

  @override
  String get forgot_newPasswordLabel => 'New password';

  @override
  String get forgot_confirmPasswordLabel => 'Confirm password';

  @override
  String get forgot_submit => 'Reset password';

  @override
  String get forgot_resendCode => 'Resend code';

  @override
  String get forgot_invalidCode => 'The code is invalid or has expired';

  @override
  String account_pinAttemptsRemaining(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count attempts remaining',
      one: '1 attempt remaining',
    );
    return '$_temp0';
  }

  @override
  String get biometric_failedTitle => 'Fingerprint authentication failed';

  @override
  String get biometric_failedMessage => 'We could not verify your fingerprint.';

  @override
  String get biometric_retry => 'Try again';

  @override
  String get biometric_usePassword => 'Use my password';

  @override
  String get register_submit => 'Register';

  @override
  String get register_failure => 'Registration failed';

  @override
  String get settings => 'Settings';

  @override
  String get settings_language => 'Language';

  @override
  String get settings_selectLanguage => 'Select language';

  @override
  String get settings_homeTab => 'Home screen';

  @override
  String get settings_selectHomeTab => 'Select home screen';

  @override
  String get global_cancel => 'Cancel';

  @override
  String get global_save => 'Save';

  @override
  String get global_delete => 'Delete';

  @override
  String get global_close => 'Close';

  @override
  String get global_update => 'Update';

  @override
  String get e2ee_cancel => 'Cancel';

  @override
  String get e2ee_continue => 'Continue';

  @override
  String get account_e2eeSwitchText =>
      'End-to-end encryption (only this device can read)';

  @override
  String get account_e2eeEnableTitle => 'Encrypt your data';

  @override
  String get account_e2eeEnableWarning =>
      'Your tags, categories and notes will be encrypted on this device with a key only you hold. The server can no longer read them. If you lose the key and its recovery phrase, the data is lost for good.';

  @override
  String get account_e2eeDisableTitle => 'Turn off encryption';

  @override
  String get account_e2eeDisableWarning =>
      'Your data will stay encrypted on the server, but the server will be able to read it again. Continue?';

  @override
  String get account_e2eeEnabled => 'Encryption enabled';

  @override
  String get account_e2eeDisabled => 'Encryption disabled';

  @override
  String get account_e2eeError => 'Encryption change failed, try again later';

  @override
  String get account_e2eeMnemonicTitle => 'Your recovery phrase';

  @override
  String get account_e2eeMnemonicHint =>
      'Write these 12 words down and keep them somewhere safe. They are the only way to recover your data on another device or after reinstalling. We cannot recover them for you.';

  @override
  String get account_e2eeMnemonicSkip => 'Skip (risky)';

  @override
  String get account_e2eeMnemonicSaved => 'I saved it';

  @override
  String account_e2eeMnemonicCount(int count) {
    return '$count words';
  }

  @override
  String get account_e2eeMnemonicCopy => 'Copy';

  @override
  String get account_e2eeMnemonicCopied => 'Recovery phrase copied';

  @override
  String get e2ee_lockedTitle => 'Encrypted data';

  @override
  String get e2ee_lockedExplanation =>
      'This account is end-to-end encrypted, but this device has no key. Enter your recovery phrase to unlock your data, or delete it to start over.';

  @override
  String get e2ee_restoreHint => 'Recovery phrase (12 words)';

  @override
  String get e2ee_restoreButton => 'Unlock';

  @override
  String get e2ee_restoreInvalid =>
      'This phrase is valid but does not match this account. It may come from another account or an older, cancelled activation.';

  @override
  String get e2ee_restoreMalformed =>
      'This is not a valid recovery phrase: check for typos or autocorrected words (12 lowercase English words).';

  @override
  String get e2ee_restoreUnknownWords => 'Words not in the dictionary';

  @override
  String e2ee_restoreWordCount(int count) {
    return 'You entered $count words — a recovery phrase has exactly 12.';
  }

  @override
  String get e2ee_restoreChecksum =>
      'All 12 words exist, but the phrase\'s checksum fails: two words are probably swapped, or one was replaced by a similar dictionary word.';

  @override
  String get e2ee_purgeButton => 'Delete my encrypted data';

  @override
  String get e2ee_purgeConfirmTitle => 'Delete everything?';

  @override
  String get e2ee_purgeConfirmText =>
      'This permanently deletes all your encrypted events, tags and categories and turns encryption off. This cannot be undone.';

  @override
  String get e2ee_purgeConfirmAction => 'Delete';

  @override
  String get nav_categories => 'Categories';

  @override
  String get nav_search => 'Search';

  @override
  String get nav_add => 'Add';

  @override
  String get insert_tagInputLabel => 'Add a tag';

  @override
  String insert_newTagCategoryTitle(String tag) {
    return 'New tag \"$tag\": choose a category';
  }

  @override
  String get insert_descriptionLabel => 'Description';

  @override
  String get insert_submit => 'Create event';

  @override
  String get insert_eventCreated => 'Event created';

  @override
  String get insert_noTagsError => 'Add at least one tag';

  @override
  String get list_filterLabel => 'Filter by tag';

  @override
  String get list_noEvents => 'No events found';

  @override
  String get list_editEvent => 'Edit event';

  @override
  String get list_deleteEventTitle => 'Delete event?';

  @override
  String get list_deleteEventInfo =>
      'This event and its description will be permanently deleted.';

  @override
  String get list_eventUpdated => 'Event updated';

  @override
  String get categories_newCategory => 'New category';

  @override
  String get categories_editCategory => 'Edit category';

  @override
  String get categories_deleteCategory => 'Delete category?';

  @override
  String get categories_deleteMoveTags => 'Move the tags to the Other category';

  @override
  String get categories_categoryName => 'Name';

  @override
  String get categories_color => 'Color';

  @override
  String categories_tagCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tags',
      one: '1 tag',
      zero: 'No tags',
    );
    return '$_temp0';
  }

  @override
  String get categories_newTag => 'New tag';

  @override
  String get categories_renameTag => 'Rename tag';

  @override
  String get categories_deleteTag => 'Delete tag';

  @override
  String get categories_addSynonym => 'Add a synonym';

  @override
  String get categories_detachSynonym => 'Detach synonym';

  @override
  String get categories_synonymName => 'Synonym';

  @override
  String get categories_renameSynonym => 'Rename synonym';

  @override
  String get categories_deleteSynonymTitle => 'Delete synonym?';

  @override
  String categories_deleteSynonymInfo(String synonym, String tag) {
    return 'Events tagged \"$synonym\" will be moved to \"$tag\".';
  }

  @override
  String get categories_moveTag => 'Move to another category';

  @override
  String categories_moveTagTitle(String tag) {
    return 'Move \"$tag\" to';
  }

  @override
  String categories_deleteTagTitle(String tag) {
    return 'Delete \"$tag\"?';
  }

  @override
  String categories_deleteTagEvents(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count events use this tag.',
      one: '1 event uses this tag.',
      zero: 'No event uses this tag.',
    );
    return '$_temp0';
  }

  @override
  String categories_deleteTagSynonyms(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Its $count synonyms will be deleted too.',
      one: 'Its synonym will be deleted too.',
    );
    return '$_temp0';
  }

  @override
  String categories_deleteTagExclusiveEvents(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count events have no other tag:',
      one: '1 event has no other tag:',
    );
    return '$_temp0';
  }

  @override
  String get categories_deleteTagKeepEvents => 'Keep these events (date only)';

  @override
  String get categories_deleteTagDeleteEvents => 'Delete these events';

  @override
  String categories_deleteCategoryTags(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'This category has $count tags.',
      one: 'This category has 1 tag.',
      zero: 'This category has no tags.',
    );
    return '$_temp0';
  }

  @override
  String categories_deleteCategoryEvents(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count events use them.',
      one: '1 event uses them.',
      zero: 'No event uses them.',
    );
    return '$_temp0';
  }

  @override
  String get categories_deleteCategoryDeleteTags =>
      'Delete the tags, keep the events';

  @override
  String get categories_deleteCategoryDeleteAll =>
      'Delete the tags and their events';

  @override
  String categories_deleteCategoryDeleteAllDetail(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count events only use tags from this category and will be deleted.',
      one: '1 event only uses tags from this category and will be deleted.',
    );
    return '$_temp0';
  }
}
