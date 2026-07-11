// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get global_unexpectedError => 'Unerwarteter Fehler';

  @override
  String get account => 'Konto';

  @override
  String get account_logout => 'Abmelden';

  @override
  String get account_updatePassword => 'Passwort aktualisieren';

  @override
  String get account_currentPassword => 'Aktuelles Passwort';

  @override
  String get account_enterPassword => 'Neues Passwort eingeben';

  @override
  String get account_repeatPassword => 'Passwort wiederholen';

  @override
  String get account_fingerprintSwitchText => 'Fingerabdrucksperre hinzufügen';

  @override
  String get account_fingerprintSwitchError =>
      'Biometrische Authentifizierung ist auf diesem Gerät nicht verfügbar.';

  @override
  String get account_pinSwitchText => 'PIN-Code hinzufügen';

  @override
  String get account_pinSwitchError =>
      'Der PIN-Code konnte nicht eingerichtet werden';

  @override
  String get account_enterPin => 'PIN-Code eingeben';

  @override
  String get account_pinEnabled => 'PIN wurde erfolgreich aktiviert';

  @override
  String get account_pinDisabled => 'PIN wurde erfolgreich deaktiviert';

  @override
  String get account_pinIncorrect => 'Der PIN-Code ist nicht korrekt';

  @override
  String get account_returnToLogin => 'Zurück zur Anmeldung';

  @override
  String get account_passwordUpdated => 'Ihr Passwort wurde aktualisiert';

  @override
  String get account_passwordIncorrect => 'Das Passwort ist nicht korrekt';

  @override
  String get account_passwordUpdateError =>
      'Beim Aktualisieren ist ein Fehler aufgetreten, versuchen Sie es später erneut';

  @override
  String get account_currentPasswordError =>
      'Geben Sie Ihr aktuelles Passwort ein';

  @override
  String get account_passwordsNotIdentical =>
      'Die Passwörter stimmen nicht überein';

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
  String get login_invalidEmail => 'Die E-Mail-Adresse ist ungültig';

  @override
  String get login_invalidPassword =>
      'Muss mindestens eine Zahl, einen Groß- und einen Kleinbuchstaben, ein Sonderzeichen und mindestens 8 Zeichen enthalten';

  @override
  String get login_forgotPassword => 'Passwort vergessen?';

  @override
  String get login_pinLocked =>
      'Ihre PIN wurde nach zu vielen Versuchen gesperrt. Bitte melden Sie sich mit Ihrem Passwort an.';

  @override
  String get forgot_title => 'Passwort zurücksetzen';

  @override
  String get forgot_emailInstructions =>
      'Geben Sie Ihre E-Mail-Adresse ein und wir senden Ihnen einen 6-stelligen Code.';

  @override
  String get forgot_sendCode => 'Code senden';

  @override
  String get forgot_codeInstructions =>
      'Geben Sie den per E-Mail erhaltenen 6-stelligen Code ein und wählen Sie ein neues Passwort.';

  @override
  String get forgot_newPasswordLabel => 'Neues Passwort';

  @override
  String get forgot_confirmPasswordLabel => 'Passwort bestätigen';

  @override
  String get forgot_submit => 'Passwort zurücksetzen';

  @override
  String get forgot_resendCode => 'Code erneut senden';

  @override
  String get forgot_invalidCode => 'Der Code ist ungültig oder abgelaufen';

  @override
  String account_pinAttemptsRemaining(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Versuche übrig',
      one: '1 Versuch übrig',
    );
    return '$_temp0';
  }

  @override
  String get biometric_failedTitle =>
      'Fingerabdruck-Authentifizierung fehlgeschlagen';

  @override
  String get biometric_failedMessage =>
      'Wir konnten Ihren Fingerabdruck nicht überprüfen.';

  @override
  String get biometric_retry => 'Erneut versuchen';

  @override
  String get biometric_usePassword => 'Mein Passwort verwenden';

  @override
  String get register_submit => 'Registrieren';

  @override
  String get register_failure => 'Registrierung fehlgeschlagen';

  @override
  String get settings => 'Einstellungen';

  @override
  String get settings_language => 'Sprache';

  @override
  String get settings_selectLanguage => 'Sprache auswählen';

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
  String get global_close => 'Schließen';

  @override
  String get global_update => 'Aktualisieren';

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
