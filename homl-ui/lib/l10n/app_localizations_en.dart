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
  String get account => 'Account';

  @override
  String get account_logout => 'Logout';

  @override
  String get account_updatePassword => 'Update password';

  @override
  String get account_currentPassword => 'Actual password';

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
  String get account_pinIncorrect => 'Pin code is not correct';

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
  String get nav_categories => 'Categories';

  @override
  String get nav_search => 'Search';

  @override
  String get nav_add => 'Add';

  @override
  String get insert_tagInputLabel => 'Add a tag';

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
}
