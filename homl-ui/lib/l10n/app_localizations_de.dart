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
  String get global_serverUnreachable =>
      'Server nicht erreichbar: Dafür ist eine Verbindung nötig.';

  @override
  String get account => 'Sicherheit';

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
  String get account_pinOfflineUnavailable =>
      'Server nicht erreichbar. Deine PIN funktioniert offline, sobald du sie hier einmal mit Verbindung eingegeben hast.';

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
  String get account_deleteAccount => 'Mein Konto löschen';

  @override
  String get account_deleteAccountTitle => 'Konto löschen?';

  @override
  String get account_deleteAccountWarning =>
      'Dies löscht dauerhaft dein Konto sowie alle deine Ereignisse, Tags und Kategorien auf allen Geräten. Dies kann nicht rückgängig gemacht werden. Gib dein Passwort ein, um zu bestätigen.';

  @override
  String get account_deleteAccountError =>
      'Das Konto konnte nicht gelöscht werden, versuche es später erneut';

  @override
  String get account_deleted => 'Dein Konto wurde gelöscht';

  @override
  String get account_sessions => 'Angemeldete Geräte';

  @override
  String get sessions_thisDevice => 'Dieses Gerät';

  @override
  String sessions_lastActive(String date) {
    return 'Aktiv am $date';
  }

  @override
  String sessions_signedIn(String date) {
    return 'Angemeldet am $date';
  }

  @override
  String get sessions_signedInUnknown => 'Angemeldet vor der Geräteliste';

  @override
  String sessions_app(String version) {
    return 'App $version';
  }

  @override
  String get sessions_unknownDevice => 'Unbekanntes Gerät';

  @override
  String get sessions_signOut => 'Abmelden';

  @override
  String get sessions_signOutTitle => 'Dieses Gerät abmelden?';

  @override
  String get sessions_signOutInfo =>
      'Es braucht das Passwort, um sich wieder anzumelden. Noch nicht gesendete Änderungen warten bis dahin darauf.';

  @override
  String get sessions_signOutOthers => 'Alle anderen Geräte abmelden';

  @override
  String get sessions_signOutOthersTitle => 'Alle anderen Geräte abmelden?';

  @override
  String get sessions_failed =>
      'Die Geräte konnten nicht aufgelistet werden: Dafür braucht es eine Verbindung.';

  @override
  String get sessions_retry => 'Erneut versuchen';

  @override
  String get sessions_actionFailed =>
      'Das hat nicht geklappt: Versuche es erneut, sobald der Server erreichbar ist.';

  @override
  String get sessions_activityNote =>
      'Die letzte Aktivität wird etwa alle zehn Minuten Nutzung aktualisiert. Die Adresse ist die von diesem Moment.';

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
  String get login_serverUnreachable =>
      'Server nicht erreichbar. Prüfe deine Verbindung und versuche es erneut.';

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
  String get login_server => 'Server';

  @override
  String get login_serverChoose => 'Server auswählen';

  @override
  String get login_serverLabel => 'Serveradresse';

  @override
  String get login_serverHint => 'z. B. http://192.168.1.10:8090';

  @override
  String get login_serverInvalid =>
      'Geben Sie eine Adresse wie http://192.168.1.10:8090 ein';

  @override
  String get login_serverNoAnswer =>
      'Unter dieser Adresse antwortet kein Server.';

  @override
  String get login_serverNotHoml =>
      'Unter dieser Adresse antwortet etwas, aber kein homl-Server.';

  @override
  String get login_serverUntrusted =>
      'Das Zertifikat dieses Servers wird vom Gerät nicht anerkannt.';

  @override
  String get login_serverCleartext =>
      'Unverschlüsselte Verbindung: nur im Heimnetz verwenden.';

  @override
  String login_serverConnected(String version) {
    return 'Verbunden mit homl $version';
  }

  @override
  String get login_serverConnectedNoVersion => 'Mit dem Server verbunden';

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
  String get register_closedTitle => 'Registrierung geschlossen';

  @override
  String get register_closedInfo =>
      'Dieser Server nimmt keine neuen Konten an. Wer ihn betreibt, kann die Registrierung öffnen.';

  @override
  String get register_backToLogin => 'Zurück zur Anmeldung';

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
  String get settings_appearance => 'Erscheinungsbild';

  @override
  String get settings_selectAppearance => 'Erscheinungsbild auswählen';

  @override
  String get settings_themeSystem => 'Wie das System';

  @override
  String get settings_themeLight => 'Hell';

  @override
  String get settings_themeDark => 'Dunkel';

  @override
  String get settings_about => 'Über';

  @override
  String settings_versionApp(String version) {
    return 'App $version';
  }

  @override
  String settings_versionServer(String version) {
    return 'Server $version';
  }

  @override
  String get settings_versionServerUnavailable => 'Server nicht erreichbar';

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
  String account_e2eeMnemonicCount(int count) {
    return '$count Wörter';
  }

  @override
  String get account_e2eeMnemonicCopy => 'Kopieren';

  @override
  String get account_e2eeMnemonicCopied => 'Wiederherstellungsphrase kopiert';

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
  String e2ee_restoreWordCount(int count) {
    return 'Du hast $count Wörter eingegeben — eine Wiederherstellungsphrase hat genau 12.';
  }

  @override
  String get e2ee_restoreChecksum =>
      'Alle 12 Wörter existieren, aber die Prüfsumme der Phrase schlägt fehl: wahrscheinlich sind zwei Wörter vertauscht oder eines wurde durch ein ähnliches Wörterbuchwort ersetzt.';

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
  String get insert_emptyError => 'Einen Tag oder eine Beschreibung hinzufügen';

  @override
  String get insert_periodSingleDay => 'Ein Tag';

  @override
  String get insert_periodClosed => 'Zeitraum';

  @override
  String get insert_periodOngoing => 'Laufend';

  @override
  String get list_filterLabel => 'Tag oder Text';

  @override
  String get list_filterHint => '-Bob, \"Strand\"';

  @override
  String get activity_title => 'Aktivität';

  @override
  String get activity_lastYear => 'Letzte 12 Monate';

  @override
  String get activity_pickYear => 'Jahr wählen';

  @override
  String get activity_less => 'Weniger';

  @override
  String get activity_more => 'Mehr';

  @override
  String activity_day(int count, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Ereignisse',
      one: '1 Ereignis',
      zero: 'Kein Ereignis',
    );
    return '$_temp0 · $date';
  }

  @override
  String get list_showTimeline => 'Zeitleiste anzeigen';

  @override
  String get list_showGrid => 'Raster anzeigen';

  @override
  String get timeline_empty =>
      'Hier gibt es keinen Zeitraum. Ein Ereignis mit Enddatum oder noch laufend erscheint auf der Zeitleiste.';

  @override
  String timeline_singleDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count eintägige Ereignisse werden nicht angezeigt',
      one: '1 eintägiges Ereignis wird nicht angezeigt',
    );
    return '$_temp0';
  }

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
  String get list_onThisDay => 'An diesem Tag';

  @override
  String get list_lastTime => 'Zuletzt:';

  @override
  String get list_lastTimeNow => 'gerade jetzt';

  @override
  String list_eventCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Ereignisse',
      one: '1 Ereignis',
    );
    return '$_temp0';
  }

  @override
  String list_thisYearCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dieses Jahr',
      zero: 'keines dieses Jahr',
    );
    return '$_temp0';
  }

  @override
  String get event_ongoing => 'Laufend';

  @override
  String event_durationDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Tage',
      one: '1 Tag',
    );
    return '$_temp0';
  }

  @override
  String event_durationMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Monate',
      one: '1 Monat',
    );
    return '$_temp0';
  }

  @override
  String event_durationYears(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Jahre',
      one: '1 Jahr',
    );
    return '$_temp0';
  }

  @override
  String event_sinceDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'seit $count Tagen',
      one: 'seit 1 Tag',
    );
    return '$_temp0';
  }

  @override
  String event_sinceMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'seit $count Monaten',
      one: 'seit 1 Monat',
    );
    return '$_temp0';
  }

  @override
  String event_sinceYears(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'seit $count Jahren',
      one: 'seit 1 Jahr',
    );
    return '$_temp0';
  }

  @override
  String event_daysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'vor $count Tagen',
      one: 'gestern',
      zero: 'heute',
    );
    return '$_temp0';
  }

  @override
  String event_monthsAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'vor $count Monaten',
      one: 'vor 1 Monat',
    );
    return '$_temp0';
  }

  @override
  String event_yearsAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'vor $count Jahren',
      one: 'vor 1 Jahr',
    );
    return '$_temp0';
  }

  @override
  String get categories_newCategory => 'Neue Kategorie';

  @override
  String get categories_editCategory => 'Kategorie bearbeiten';

  @override
  String get categories_deleteCategory => 'Kategorie löschen?';

  @override
  String get categories_deleteMoveTags =>
      'Tags in die Kategorie Sonstiges verschieben';

  @override
  String get categories_categoryName => 'Name';

  @override
  String get categories_defaultDates => 'Daten';

  @override
  String get categories_defaultPersons => 'Personen';

  @override
  String get categories_defaultOthers => 'Sonstiges';

  @override
  String get categories_color => 'Farbe';

  @override
  String categories_tagCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Tags',
      one: '1 Tag',
      zero: 'Keine Tags',
    );
    return '$_temp0';
  }

  @override
  String get categories_newTag => 'Neuer Tag';

  @override
  String get categories_browseTags => 'Tags durchsuchen';

  @override
  String get categories_pickTag => 'Tag auswählen';

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
  String get categories_synonyms => 'Synonyme';

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
      other: '$count davon behalten nur ihr Datum.',
      one: '1 davon behält nur sein Datum.',
    );
    return '$_temp0';
  }

  @override
  String get categories_deleteTagKeepEvents =>
      'Diese Ereignisse behalten, Tag entfernen';

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
      other: '$count Ereignisse verwenden diese Tags und werden gelöscht.',
      one: '1 Ereignis verwendet diese Tags und wird gelöscht.',
    );
    return '$_temp0';
  }

  @override
  String get categories_deleteTagNameConflict =>
      'Ein Tag oder eine Gruppe dieser Kategorie existiert bereits in Sonstiges. Benenne sie um oder lösche die Tags, statt sie zu verschieben.';

  @override
  String get categories_tagNameConflict =>
      'Diese Kategorie hat bereits einen Tag mit diesem Namen. Wähle einen anderen.';

  @override
  String get categories_groups => 'Gruppen';

  @override
  String get categories_newGroup => 'Neue Gruppe';

  @override
  String get categories_editGroup => 'Gruppe bearbeiten';

  @override
  String get categories_deleteGroup => 'Gruppe löschen';

  @override
  String get categories_groupHint =>
      'Wenn du den Namen der Gruppe eingibst, werden alle ihre Tags auf einmal hinzugefügt.';

  @override
  String get categories_groupMembers => 'Tags der Gruppe';

  @override
  String get categories_groupNeedsMembers => 'Wähle mindestens einen Tag.';

  @override
  String get categories_groupNameTaken =>
      'Ein Tag oder eine Gruppe trägt bereits diesen Namen.';

  @override
  String get categories_groupNameReserved =>
      'Dieser Name ist für die Daten reserviert.';

  @override
  String get categories_groupNameConflict =>
      'Diese Kategorie hat bereits eine Gruppe mit diesem Namen. Wähle einen anderen.';

  @override
  String get categories_groupEmpty => 'Keine Tags mehr';

  @override
  String categories_deleteGroupTitle(String group) {
    return '\"$group\" löschen?';
  }

  @override
  String get categories_deleteGroupInfo =>
      'Nur die Gruppe wird gelöscht: Ihre Tags und deren Ereignisse bleiben.';

  @override
  String get offline_title => 'Offline';

  @override
  String get offline_explanation =>
      'Server nicht erreichbar. Du siehst die auf diesem Gerät gespeicherten Daten; Änderungen brauchen eine Verbindung. Die App verbindet sich von selbst wieder.';

  @override
  String offline_explanationSince(String date) {
    return 'Server nicht erreichbar. Du siehst die auf diesem Gerät gespeicherten Daten (Stand: $date); Änderungen brauchen eine Verbindung. Die App verbindet sich von selbst wieder.';
  }

  @override
  String get sync_savedOffline =>
      'Auf diesem Gerät gespeichert. Es wird gesendet, sobald der Server erreichbar ist.';

  @override
  String get sync_sent => 'Deine offline gemachten Änderungen wurden gesendet.';

  @override
  String get sync_restored =>
      'Ein auf einem anderen Gerät gelöschtes Ereignis wurde hier geändert: Es ist wieder da, mit deinen Änderungen.';

  @override
  String get sync_kept =>
      'Etwas, das du gelöscht hattest, wurde auf einem anderen Gerät geändert: Es wurde behalten.';

  @override
  String get sync_conflicts =>
      'Deine Offline-Änderungen haben Änderungen an denselben Ereignissen von einem anderen Gerät ersetzt.';

  @override
  String get sync_parked =>
      'Einige Änderungen konnten nicht gesendet werden: Sieh dir die wartenden Änderungen an.';

  @override
  String get sync_dropped =>
      'Eine offline gemachte Änderung wurde verworfen: Was sie änderte, war auf einem anderen Gerät gelöscht worden.';

  @override
  String get sync_pendingChangesFirst =>
      'Offline gemachte Änderungen warten noch: Sende oder verwirf sie zuerst.';

  @override
  String get pending_title => 'Wartende Änderungen';

  @override
  String get pending_info =>
      'Auf diesem Gerät gemacht, während der Server nicht erreichbar war. Sie werden gesendet, sobald er antwortet.';

  @override
  String get pending_sendNow => 'Jetzt senden';

  @override
  String get pending_retry => 'Erneut versuchen';

  @override
  String get pending_discard => 'Verwerfen';

  @override
  String get pending_createEvent => 'Neues Ereignis';

  @override
  String get pending_updateEvent => 'Geändertes Ereignis';

  @override
  String get pending_deleteEvent => 'Gelöschtes Ereignis';

  @override
  String get pending_createTag => 'Neuer Tag';

  @override
  String get pending_updateTag => 'Bearbeiteter Tag';

  @override
  String get pending_deleteTag => 'Gelöschter Tag';

  @override
  String get pending_createCategory => 'Neue Kategorie';

  @override
  String get pending_updateCategory => 'Bearbeitete Kategorie';

  @override
  String get pending_deleteCategory => 'Gelöschte Kategorie';

  @override
  String get pending_createGroup => 'Neue Tag-Gruppe';

  @override
  String get pending_updateGroup => 'Bearbeitete Tag-Gruppe';

  @override
  String get pending_deleteGroup => 'Gelöschte Tag-Gruppe';

  @override
  String get pending_waiting => 'Wartet';

  @override
  String get pending_refused => 'Vom Server abgelehnt';

  @override
  String get pending_missingTag =>
      'Verwendet einen Tag, der nicht erstellt werden konnte';

  @override
  String get pending_missingParent =>
      'Braucht eine Kategorie oder Gruppe, die nicht erstellt werden konnte';

  @override
  String get pending_encryptionChanged =>
      'Die Verschlüsselung wurde auf einem anderen Gerät geändert';

  @override
  String get pending_dataReplaced =>
      'Die Serverdaten wurden ersetzt (aus einer Sicherung wiederhergestellt)';

  @override
  String get logout_pendingTitle => 'Nicht gesendete Änderungen';

  @override
  String get logout_pendingConfirm => 'Trotzdem abmelden';

  @override
  String logout_pendingInfo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count offline gemachte Änderungen sind noch nicht auf dem Server. Beim Abmelden gehen sie verloren.',
      one:
          '1 offline gemachte Änderung ist noch nicht auf dem Server. Beim Abmelden geht sie verloren.',
    );
    return '$_temp0';
  }

  @override
  String get account_exportData => 'Meine Daten exportieren';

  @override
  String get account_exportDataHint =>
      'Eine Datei mit deinen Kategorien, Tags und Ereignissen';

  @override
  String get account_importData => 'Daten importieren';

  @override
  String get account_importDataHint =>
      'Den Inhalt einer Exportdatei hinzufügen';

  @override
  String get export_title => 'Deine Daten exportieren';

  @override
  String get export_info =>
      'Die Datei enthält deine Kategorien, Tags und Ereignisse. Wer sie bekommt, kann sie lesen, außer sie ist mit einem Passwort geschützt.';

  @override
  String get export_passwordSwitch => 'Mit einem Passwort schützen';

  @override
  String get export_password => 'Passwort';

  @override
  String get export_passwordRepeat => 'Passwort wiederholen';

  @override
  String get export_passwordTooShort => 'Mindestens 8 Zeichen';

  @override
  String get export_passwordHint =>
      'Ohne dieses Passwort kann niemand die Datei öffnen, auch du nicht: Es kann nicht wiederhergestellt werden.';

  @override
  String get export_e2eeWarning =>
      'Dein Konto ist Ende-zu-Ende-verschlüsselt: Ohne Passwort enthält diese Datei deine Daten im Klartext.';

  @override
  String get export_confirm => 'Exportieren';

  @override
  String get export_saved => 'Export gespeichert';

  @override
  String get export_failed =>
      'Der Export ist fehlgeschlagen, versuche es später erneut';

  @override
  String get import_passwordTitle => 'Geschützte Datei';

  @override
  String get import_passwordInfo =>
      'Gib das beim Export gewählte Passwort ein.';

  @override
  String get import_passwordWrong => 'Falsches Passwort';

  @override
  String get import_open => 'Öffnen';

  @override
  String get import_invalidFile =>
      'Diese Datei ist kein HOML-Export oder sie ist beschädigt';

  @override
  String get import_newerVersion =>
      'Diese Datei stammt aus einer neueren HOML-Version: Aktualisiere die App, um sie zu importieren';

  @override
  String get import_confirmTitle => 'Diese Datei importieren?';

  @override
  String import_confirmInfo(String date) {
    return 'Am $date exportiert, sie enthält:';
  }

  @override
  String get import_confirmMerge =>
      'Alles wird deinem Konto hinzugefügt: Was schon vorhanden ist, wird übersprungen, und nichts wird geändert oder gelöscht.';

  @override
  String import_countCategories(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Kategorien',
      one: '1 Kategorie',
    );
    return '$_temp0';
  }

  @override
  String import_countTags(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Tags',
      one: '1 Tag',
    );
    return '$_temp0';
  }

  @override
  String import_countGroups(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Tag-Gruppen',
      one: '1 Tag-Gruppe',
    );
    return '$_temp0';
  }

  @override
  String import_countEvents(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Ereignisse',
      one: '1 Ereignis',
    );
    return '$_temp0';
  }

  @override
  String get import_confirm => 'Importieren';

  @override
  String import_progress(int done, int total) {
    return 'Import läuft… $done von $total';
  }

  @override
  String get import_keepOpen =>
      'Lass die App geöffnet, bis der Import fertig ist.';

  @override
  String get import_doneTitle => 'Import abgeschlossen';

  @override
  String get import_doneAdded => 'Hinzugefügt:';

  @override
  String get import_doneNothing =>
      'Nichts Neues: Dein Konto enthielt bereits alles.';

  @override
  String import_doneExisting(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Ereignisse waren schon vorhanden.',
      one: '1 Ereignis war schon vorhanden.',
    );
    return '$_temp0';
  }

  @override
  String import_doneSkipped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count Elemente wurden vom Server abgelehnt (zum Beispiel ein reservierter Tag-Name) und ausgelassen.',
      one:
          '1 Element wurde vom Server abgelehnt (zum Beispiel ein reservierter Tag-Name) und ausgelassen.',
    );
    return '$_temp0';
  }

  @override
  String get import_interrupted =>
      'Verbindung verloren: Der Import wurde unterbrochen. Importiere dieselbe Datei erneut, um ihn abzuschließen; Vorhandenes wird übersprungen.';
}
