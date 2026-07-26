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
  String get e2ee_cancel => 'Abbrechen';

  @override
  String get e2ee_continue => 'Weiter';

  @override
  String get account_e2eeSwitchText =>
      'Ende-zu-Ende-Verschlüsselung (nur dieses Gerät kann lesen)';

  @override
  String get account_e2eeEnableTitle => 'Daten verschlüsseln';

  @override
  String get account_e2eeEnableWarning =>
      'Deine Tags, Kategorien und Notizen werden auf diesem Gerät mit einem Schlüssel verschlüsselt, den nur du besitzt. Der Server kann sie nicht mehr lesen. Wenn du den Schlüssel und seine Wiederherstellungsphrase verlierst, sind die Daten unwiederbringlich verloren.';

  @override
  String get account_e2eeDisableTitle => 'Verschlüsselung deaktivieren';

  @override
  String get account_e2eeDisableWarning =>
      'Deine Daten bleiben auf dem Server verschlüsselt, aber der Server kann sie wieder lesen. Fortfahren?';

  @override
  String get account_e2eeEnabled => 'Verschlüsselung aktiviert';

  @override
  String get account_e2eeDisabled => 'Verschlüsselung deaktiviert';

  @override
  String get account_e2eeError =>
      'Änderung der Verschlüsselung fehlgeschlagen, später erneut versuchen';

  @override
  String get account_e2eeMnemonicTitle => 'Deine Wiederherstellungsphrase';

  @override
  String get account_e2eeMnemonicHint =>
      'Schreibe diese 12 Wörter auf und bewahre sie sicher auf. Sie sind der einzige Weg, deine Daten auf einem anderen Gerät oder nach einer Neuinstallation wiederherzustellen. Wir können sie nicht für dich wiederherstellen.';

  @override
  String get account_e2eeMnemonicSkip => 'Überspringen (riskant)';

  @override
  String get account_e2eeMnemonicSaved => 'Gespeichert';

  @override
  String get e2ee_lockedTitle => 'Verschlüsselte Daten';

  @override
  String get e2ee_lockedExplanation =>
      'Dieses Konto ist Ende-zu-Ende verschlüsselt, aber dieses Gerät hat keinen Schlüssel. Gib deine Wiederherstellungsphrase ein, um deine Daten zu entsperren, oder lösche sie, um neu zu beginnen.';

  @override
  String get e2ee_restoreHint => 'Wiederherstellungsphrase (12 Wörter)';

  @override
  String get e2ee_restoreButton => 'Entsperren';

  @override
  String get e2ee_restoreInvalid =>
      'Diese Phrase ist gültig, passt aber nicht zu diesem Konto. Sie stammt möglicherweise von einem anderen Konto oder einer abgebrochenen Aktivierung.';

  @override
  String get e2ee_restoreMalformed =>
      'Dies ist keine gültige Wiederherstellungsphrase: prüfe auf Tippfehler oder Autokorrektur (12 englische Wörter in Kleinbuchstaben).';

  @override
  String get e2ee_restoreUnknownWords => 'Wörter nicht im Wörterbuch';

  @override
  String get e2ee_purgeButton => 'Meine verschlüsselten Daten löschen';

  @override
  String get e2ee_purgeConfirmTitle => 'Alles löschen?';

  @override
  String get e2ee_purgeConfirmText =>
      'Dies löscht dauerhaft alle deine verschlüsselten Ereignisse, Tags und Kategorien und deaktiviert die Verschlüsselung. Dies kann nicht rückgängig gemacht werden.';

  @override
  String get e2ee_purgeConfirmAction => 'Löschen';

  @override
  String get nav_categories => 'Kategorien';

  @override
  String get nav_search => 'Suchen';

  @override
  String get nav_add => 'Hinzufügen';

  @override
  String get insert_tagInputLabel => 'Tag hinzufügen';

  @override
  String insert_newTagCategoryTitle(String tag) {
    return 'Neuer Tag \"$tag\": Kategorie wählen';
  }

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
  String get list_editEvent => 'Ereignis bearbeiten';

  @override
  String get list_deleteEventTitle => 'Ereignis löschen?';

  @override
  String get list_deleteEventInfo =>
      'Dieses Ereignis und seine Beschreibung werden endgültig gelöscht.';

  @override
  String get list_eventUpdated => 'Ereignis aktualisiert';

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

  @override
  String get categories_renameSynonym => 'Synonym umbenennen';

  @override
  String get categories_deleteSynonymTitle => 'Synonym löschen?';

  @override
  String categories_deleteSynonymInfo(String synonym, String tag) {
    return 'Ereignisse mit dem Tag \"$synonym\" werden zu \"$tag\" verschoben.';
  }

  @override
  String get categories_moveTag => 'In andere Kategorie verschieben';

  @override
  String categories_moveTagTitle(String tag) {
    return '\"$tag\" verschieben nach';
  }

  @override
  String categories_deleteTagTitle(String tag) {
    return '\"$tag\" löschen?';
  }

  @override
  String categories_deleteTagEvents(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Ereignisse verwenden diesen Tag.',
      one: '1 Ereignis verwendet diesen Tag.',
      zero: 'Kein Ereignis verwendet diesen Tag.',
    );
    return '$_temp0';
  }

  @override
  String categories_deleteTagSynonyms(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Seine $count Synonyme werden ebenfalls gelöscht.',
      one: 'Sein Synonym wird ebenfalls gelöscht.',
    );
    return '$_temp0';
  }

  @override
  String categories_deleteTagExclusiveEvents(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Ereignisse haben keinen anderen Tag:',
      one: '1 Ereignis hat keinen anderen Tag:',
    );
    return '$_temp0';
  }

  @override
  String get categories_deleteTagKeepEvents =>
      'Diese Ereignisse behalten (nur Datum)';

  @override
  String get categories_deleteTagDeleteEvents => 'Diese Ereignisse löschen';

  @override
  String categories_deleteCategoryTags(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Diese Kategorie hat $count Tags.',
      one: 'Diese Kategorie hat 1 Tag.',
      zero: 'Diese Kategorie hat keine Tags.',
    );
    return '$_temp0';
  }

  @override
  String categories_deleteCategoryEvents(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Ereignisse verwenden sie.',
      one: '1 Ereignis verwendet sie.',
      zero: 'Kein Ereignis verwendet sie.',
    );
    return '$_temp0';
  }

  @override
  String get categories_deleteCategoryDeleteTags =>
      'Tags löschen, Ereignisse behalten';

  @override
  String get categories_deleteCategoryDeleteAll =>
      'Tags und ihre Ereignisse löschen';

  @override
  String categories_deleteCategoryDeleteAllDetail(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count Ereignisse verwenden nur Tags aus dieser Kategorie und werden gelöscht.',
      one:
          '1 Ereignis verwendet nur Tags aus dieser Kategorie und wird gelöscht.',
    );
    return '$_temp0';
  }
}
