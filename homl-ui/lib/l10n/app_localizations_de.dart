// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

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
  String get login_usernameLabel => 'Benutzername';

  @override
  String get login_passwordLabel => 'Passwort';

  @override
  String get login_submit => 'Anmelden';

  @override
  String get login_register => 'Registrieren';

  @override
  String get login_incorrectCredentials => 'E-Mail oder Passwort falsch';

  @override
  String get login_invalidEmail => 'Die E-Mail-Adresse ist ungultig';

  @override
  String get login_invalidPassword =>
      'Muss mindestens eine Zahl, einen Gross- und einen Kleinbuchstaben, ein Sonderzeichen und mindestens 8 Zeichen enthalten';

  @override
  String get settings => 'Settings';

  @override
  String get settings_language => 'Language';

  @override
  String get settings_selectLanguage => 'Select language';

  @override
  String get settings_homeTab => 'Startbildschirm';

  @override
  String get settings_selectHomeTab => 'Startbildschirm auswählen';

  @override
  String get global_cancel => 'Abbrechen';

  @override
  String get global_save => 'Speichern';

  @override
  String get global_delete => 'Löschen';

  @override
  String get nav_categories => 'Kategorien';

  @override
  String get nav_search => 'Suchen';

  @override
  String get nav_add => 'Hinzufügen';

  @override
  String get insert_tagInputLabel => 'Tag hinzufügen';

  @override
  String get insert_descriptionLabel => 'Beschreibung';

  @override
  String get insert_submit => 'Ereignis erstellen';

  @override
  String get insert_eventCreated => 'Ereignis erstellt';

  @override
  String get insert_noTagsError => 'Mindestens einen Tag hinzufügen';

  @override
  String get list_filterLabel => 'Nach Tag filtern';

  @override
  String get list_noEvents => 'Keine Ereignisse gefunden';

  @override
  String get categories_newCategory => 'Neue Kategorie';

  @override
  String get categories_editCategory => 'Kategorie bearbeiten';

  @override
  String get categories_deleteCategory => 'Kategorie löschen?';

  @override
  String get categories_deleteMoveTags =>
      'Tags in die Kategorie Other verschieben';

  @override
  String get categories_categoryName => 'Name';

  @override
  String get categories_color => 'Farbe';

  @override
  String get categories_newTag => 'Neuer Tag';

  @override
  String get categories_renameTag => 'Tag umbenennen';

  @override
  String get categories_deleteTag => 'Tag löschen';

  @override
  String get categories_addSynonym => 'Synonym hinzufügen';

  @override
  String get categories_detachSynonym => 'Synonym trennen';

  @override
  String get categories_synonymName => 'Synonym';
}
