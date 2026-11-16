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
  String get global_serverUnreachable =>
      'Server unreachable: this needs a connection.';

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
  String get account_pinOfflineUnavailable =>
      'Server unreachable. Your PIN works offline once you have entered it here while connected.';

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
  String get account_sessions => 'Signed-in devices';

  @override
  String get sessions_thisDevice => 'This device';

  @override
  String sessions_lastActive(String date) {
    return 'Last active $date';
  }

  @override
  String sessions_signedIn(String date) {
    return 'Signed in $date';
  }

  @override
  String get sessions_signedInUnknown => 'Signed in before devices were listed';

  @override
  String sessions_app(String version) {
    return 'app $version';
  }

  @override
  String get sessions_unknownDevice => 'Unknown device';

  @override
  String get sessions_signOut => 'Sign out';

  @override
  String get sessions_signOutTitle => 'Sign this device out?';

  @override
  String get sessions_signOutInfo =>
      'It will need the password to sign in again. Its changes not sent yet wait on it until then.';

  @override
  String get sessions_signOutOthers => 'Sign out all other devices';

  @override
  String get sessions_signOutOthersTitle => 'Sign out all other devices?';

  @override
  String get sessions_failed =>
      'The devices could not be listed: this needs a connection.';

  @override
  String get sessions_retry => 'Try again';

  @override
  String get sessions_actionFailed =>
      'That did not work: try again once the server is reachable.';

  @override
  String get sessions_activityNote =>
      'Last activity is renewed about every ten minutes of use. The address is the one of that moment.';

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
  String get login_serverUnreachable =>
      'Server unreachable. Check your connection and try again.';

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
  String get login_server => 'Server';

  @override
  String get login_serverChoose => 'Choose a server';

  @override
  String get login_serverLabel => 'Server address';

  @override
  String get login_serverHint => 'e.g. http://192.168.1.10:8090';

  @override
  String get login_serverInvalid =>
      'Enter an address such as http://192.168.1.10:8090';

  @override
  String get login_serverNoAnswer => 'No server answers at this address.';

  @override
  String get login_serverNotHoml =>
      'Something answers at this address, but it is not a homl server.';

  @override
  String get login_serverUntrusted =>
      'This server\'s certificate is not trusted by the device.';

  @override
  String get login_serverCleartext =>
      'Unencrypted connection: use it on your home network only.';

  @override
  String login_serverConnected(String version) {
    return 'Connected to homl $version';
  }

  @override
  String get login_serverConnectedNoVersion => 'Connected to the server';

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
  String get register_closedTitle => 'Registration is closed';

  @override
  String get register_closedInfo =>
      'This server takes no new accounts. Whoever runs it can open registration.';

  @override
  String get register_backToLogin => 'Back to login';

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
  String get settings_appearance => 'Appearance';

  @override
  String get settings_selectAppearance => 'Select appearance';

  @override
  String get settings_themeSystem => 'System default';

  @override
  String get settings_themeLight => 'Light';

  @override
  String get settings_themeDark => 'Dark';

  @override
  String get settings_about => 'About';

  @override
  String settings_versionApp(String version) {
    return 'App $version';
  }

  @override
  String settings_versionServer(String version) {
    return 'Server $version';
  }

  @override
  String get settings_versionServerUnavailable => 'Server unreachable';

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
  String get insert_emptyError => 'Add a tag or a description';

  @override
  String get insert_periodSingleDay => 'Single day';

  @override
  String get insert_periodClosed => 'Period';

  @override
  String get insert_periodOngoing => 'Ongoing';

  @override
  String get insert_dateLabel => 'Date';

  @override
  String get insert_dateFromLabel => 'From';

  @override
  String get insert_dateToLabel => 'To';

  @override
  String get insert_dateSinceLabel => 'Since';

  @override
  String insert_moreMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '+ $count months',
      one: '+ 1 month',
    );
    return '$_temp0';
  }

  @override
  String get list_filterLabel => 'Tag or text';

  @override
  String get list_filterHint => '-Bob, \"beach\"';

  @override
  String get activity_title => 'Activity';

  @override
  String get activity_lastYear => 'Last 12 months';

  @override
  String get activity_pickYear => 'Pick a year';

  @override
  String get activity_less => 'Less';

  @override
  String get activity_more => 'More';

  @override
  String activity_day(int count, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count events',
      one: '1 event',
      zero: 'No event',
    );
    return '$_temp0 · $date';
  }

  @override
  String get list_showTimeline => 'Show the timeline';

  @override
  String get list_showList => 'Show the list';

  @override
  String get timeline_empty =>
      'No period here. An event with an end date, or still ongoing, shows up on the timeline.';

  @override
  String timeline_singleDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count single-day events are not shown',
      one: '1 single-day event is not shown',
    );
    return '$_temp0';
  }

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
  String get list_onThisDay => 'On this day';

  @override
  String get list_lastTime => 'Last time:';

  @override
  String get list_lastTimeNow => 'right now';

  @override
  String list_eventCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count events',
      one: '1 event',
    );
    return '$_temp0';
  }

  @override
  String list_thisYearCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count this year',
      zero: 'none this year',
    );
    return '$_temp0';
  }

  @override
  String get event_ongoing => 'Ongoing';

  @override
  String event_durationDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String event_durationMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count months',
      one: '1 month',
    );
    return '$_temp0';
  }

  @override
  String event_durationYears(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count years',
      one: '1 year',
    );
    return '$_temp0';
  }

  @override
  String event_sinceDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'for $count days',
      one: 'for 1 day',
    );
    return '$_temp0';
  }

  @override
  String event_sinceMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'for $count months',
      one: 'for 1 month',
    );
    return '$_temp0';
  }

  @override
  String event_sinceYears(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'for $count years',
      one: 'for 1 year',
    );
    return '$_temp0';
  }

  @override
  String event_daysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days ago',
      one: 'yesterday',
      zero: 'today',
    );
    return '$_temp0';
  }

  @override
  String event_monthsAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count months ago',
      one: '1 month ago',
    );
    return '$_temp0';
  }

  @override
  String event_yearsAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count years ago',
      one: '1 year ago',
    );
    return '$_temp0';
  }

  @override
  String get categories_newCategory => 'New category';

  @override
  String get categories_editCategory => 'Edit category';

  @override
  String get categories_deleteCategory => 'Delete category?';

  @override
  String get categories_deleteMoveTags =>
      'Move the tags to the Others category';

  @override
  String get categories_categoryName => 'Name';

  @override
  String get categories_defaultDates => 'Dates';

  @override
  String get categories_defaultPersons => 'Persons';

  @override
  String get categories_defaultOthers => 'Others';

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
  String get categories_browseTags => 'Browse tags';

  @override
  String get categories_pickTag => 'Choose a tag';

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
  String get categories_synonyms => 'Synonyms';

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
      other: '$count of them will be left with their date only.',
      one: '1 of them will be left with its date only.',
    );
    return '$_temp0';
  }

  @override
  String get categories_deleteTagKeepEvents =>
      'Keep these events, remove the tag';

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
      other: '$count events use these tags and will be deleted.',
      one: '1 event uses these tags and will be deleted.',
    );
    return '$_temp0';
  }

  @override
  String get categories_deleteTagNameConflict =>
      'One of these tags or groups already exists in Others. Rename it, or delete the tags instead of moving them.';

  @override
  String get categories_tagNameConflict =>
      'This category already has a tag with that name. Pick another one.';

  @override
  String get categories_groups => 'Groups';

  @override
  String get categories_newGroup => 'New group';

  @override
  String get categories_editGroup => 'Edit group';

  @override
  String get categories_deleteGroup => 'Delete group';

  @override
  String get categories_groupHint =>
      'Typing the group\'s name adds all its tags at once.';

  @override
  String get categories_groupMembers => 'Tags of the group';

  @override
  String get categories_groupNeedsMembers => 'Pick at least one tag.';

  @override
  String get categories_groupNameTaken =>
      'A tag or a group already has this name.';

  @override
  String get categories_groupNameReserved =>
      'This name is reserved for the dates.';

  @override
  String get categories_groupNameConflict =>
      'This category already has a group with that name. Pick another one.';

  @override
  String get categories_groupEmpty => 'No tags left';

  @override
  String categories_deleteGroupTitle(String group) {
    return 'Delete \"$group\"?';
  }

  @override
  String get categories_deleteGroupInfo =>
      'Only the group goes: its tags and their events stay.';

  @override
  String get offline_title => 'Offline';

  @override
  String get offline_explanation =>
      'Server unreachable. You are viewing the data saved on this device; changes need a connection. The app reconnects by itself.';

  @override
  String offline_explanationSince(String date) {
    return 'Server unreachable. You are viewing the data saved on this device (last updated $date); changes need a connection. The app reconnects by itself.';
  }

  @override
  String get sync_savedOffline =>
      'Saved on this device. It will be sent once the server is reachable.';

  @override
  String get sync_sent => 'Your offline changes were sent.';

  @override
  String get sync_restored =>
      'An event deleted on another device was edited here: it is back, with your changes.';

  @override
  String get sync_kept =>
      'Something you deleted had been changed on another device: it was kept.';

  @override
  String get sync_conflicts =>
      'Your offline changes replaced changes made to the same events on another device.';

  @override
  String get sync_parked =>
      'Some changes could not be sent: see the changes waiting.';

  @override
  String get sync_dropped =>
      'A change you made offline was dropped: what it changed had been deleted on another device.';

  @override
  String get sync_pendingChangesFirst =>
      'Changes made offline are still waiting: send or discard them first.';

  @override
  String get pending_title => 'Changes waiting';

  @override
  String get pending_info =>
      'Made on this device while the server was out of reach. They are sent as soon as it answers.';

  @override
  String get pending_sendNow => 'Send now';

  @override
  String get pending_retry => 'Try again';

  @override
  String get pending_discard => 'Discard';

  @override
  String get pending_createEvent => 'New event';

  @override
  String get pending_updateEvent => 'Edited event';

  @override
  String get pending_deleteEvent => 'Deleted event';

  @override
  String get pending_createTag => 'New tag';

  @override
  String get pending_updateTag => 'Edited tag';

  @override
  String get pending_deleteTag => 'Deleted tag';

  @override
  String get pending_createCategory => 'New category';

  @override
  String get pending_updateCategory => 'Edited category';

  @override
  String get pending_deleteCategory => 'Deleted category';

  @override
  String get pending_createGroup => 'New tag group';

  @override
  String get pending_updateGroup => 'Edited tag group';

  @override
  String get pending_deleteGroup => 'Deleted tag group';

  @override
  String get pending_waiting => 'Waiting';

  @override
  String get pending_refused => 'Refused by the server';

  @override
  String get pending_missingTag => 'Uses a tag that could not be created';

  @override
  String get pending_missingParent =>
      'Needs a category or group that could not be created';

  @override
  String get pending_encryptionChanged =>
      'The encryption changed on another device';

  @override
  String get pending_dataReplaced =>
      'The server data was replaced (restored from a backup)';

  @override
  String get logout_pendingTitle => 'Changes not sent';

  @override
  String get logout_pendingConfirm => 'Log out anyway';

  @override
  String logout_pendingInfo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count changes made offline have not reached the server yet. Logging out loses them.',
      one:
          '1 change made offline has not reached the server yet. Logging out loses it.',
    );
    return '$_temp0';
  }

  @override
  String get account_exportData => 'Export my data';

  @override
  String get account_exportDataHint =>
      'A file with your categories, tags and events';

  @override
  String get account_importData => 'Import data';

  @override
  String get account_importDataHint => 'Add the content of an export file';

  @override
  String get export_title => 'Export your data';

  @override
  String get export_info =>
      'The file holds your categories, tags and events. Anyone who gets it can read them, unless it is protected with a password.';

  @override
  String get export_passwordSwitch => 'Protect with a password';

  @override
  String get export_password => 'Password';

  @override
  String get export_passwordRepeat => 'Repeat the password';

  @override
  String get export_passwordTooShort => 'At least 8 characters';

  @override
  String get export_passwordHint =>
      'Without this password nobody can open the file, not even you: it cannot be recovered.';

  @override
  String get export_e2eeWarning =>
      'Your account is end-to-end encrypted: without a password, this file holds your data in clear.';

  @override
  String get export_confirm => 'Export';

  @override
  String get export_saved => 'Export saved';

  @override
  String get export_failed => 'The export failed, try again later';

  @override
  String get import_passwordTitle => 'Protected file';

  @override
  String get import_passwordInfo => 'Enter the password chosen when exporting.';

  @override
  String get import_passwordWrong => 'Wrong password';

  @override
  String get import_open => 'Open';

  @override
  String get import_invalidFile =>
      'This file is not a HOML export, or it is damaged';

  @override
  String get import_newerVersion =>
      'This file comes from a newer version of HOML: update the app to import it';

  @override
  String get import_confirmTitle => 'Import this file?';

  @override
  String import_confirmInfo(String date) {
    return 'Exported on $date, it holds:';
  }

  @override
  String get import_confirmMerge =>
      'Everything is added to your account: what is already there is skipped, and nothing is changed or deleted.';

  @override
  String import_countCategories(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count categories',
      one: '1 category',
    );
    return '$_temp0';
  }

  @override
  String import_countTags(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tags',
      one: '1 tag',
    );
    return '$_temp0';
  }

  @override
  String import_countGroups(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tag groups',
      one: '1 tag group',
    );
    return '$_temp0';
  }

  @override
  String import_countEvents(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count events',
      one: '1 event',
    );
    return '$_temp0';
  }

  @override
  String get import_confirm => 'Import';

  @override
  String import_progress(int done, int total) {
    return 'Importing… $done of $total';
  }

  @override
  String get import_keepOpen => 'Keep the app open until the import ends.';

  @override
  String get import_doneTitle => 'Import finished';

  @override
  String get import_doneAdded => 'Added:';

  @override
  String get import_doneNothing =>
      'Nothing new: your account already held all of it.';

  @override
  String import_doneExisting(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count events were already there.',
      one: '1 event was already there.',
    );
    return '$_temp0';
  }

  @override
  String import_doneSkipped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count items were refused by the server (a reserved tag name, for example) and left out.',
      one:
          '1 item was refused by the server (a reserved tag name, for example) and left out.',
    );
    return '$_temp0';
  }

  @override
  String get import_interrupted =>
      'Connection lost: the import stopped. Import the same file again to finish it, what is already there is skipped.';

  @override
  String get update_available => 'Update available';

  @override
  String update_title(String release) {
    return 'homl $release is out';
  }

  @override
  String update_body(String release, String installed) {
    return 'Your server already runs $release, this app is still $installed. Update it from Obtainium, or download the APK from the release page.';
  }

  @override
  String get update_later => 'Later';

  @override
  String get update_open => 'Release page';

  @override
  String get update_openFailed => 'Could not open the release page.';

  @override
  String get update_serverNeeded => 'Server update needed';

  @override
  String update_serverBody(String server, String minimum) {
    return 'The server runs $server, and this app needs $minimum or newer: some features may fail until the server is upgraded.';
  }

  @override
  String get update_serverClose => 'OK';

  @override
  String list_monthCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count events',
      one: '1 event',
    );
    return '$_temp0';
  }

  @override
  String get legal_title => 'Terms & privacy';

  @override
  String legal_updated(String date) {
    return 'Last updated: $date';
  }

  @override
  String get legal_termsHeading => 'Terms of use';

  @override
  String get legal_privacyHeading => 'Privacy policy';

  @override
  String get legal_termsServiceTitle => 'The service';

  @override
  String get legal_termsServiceBody =>
      'HOML is a personal journal: you record the events of your life, link them to tags and categories, and browse your own history. These terms apply to your use of the app and of the HOML server you sign in to.';

  @override
  String get legal_termsOperatorTitle => 'Who runs it';

  @override
  String get legal_termsOperatorBody =>
      'HOML is free, self-hosted software. Each server is installed and run by its operator — the person or organisation that administers it — independently of the authors of the software. The operator of the server you chose at sign-in is responsible for your account and your data.';

  @override
  String get legal_termsAccountTitle => 'Your account';

  @override
  String get legal_termsAccountBody =>
      'You need a valid email address and a password. Your account is personal. You must be at least 16 years old, or have the consent of a parent or guardian. Keep your password, your PIN and — if you turn on end-to-end encryption — your recovery phrase safe: without that phrase, nobody can recover your encrypted data.';

  @override
  String get legal_termsUseTitle => 'Acceptable use';

  @override
  String get legal_termsUseBody =>
      'Use HOML lawfully. Do not store unlawful content, do not try to disrupt the server or to access other people\'s accounts. When you write about other people, respect their privacy.';

  @override
  String get legal_termsContentTitle => 'Your content';

  @override
  String get legal_termsContentBody =>
      'Your events, tags and categories belong to you. The operator uses them only to run the service. You can export them at any time from the Security page.';

  @override
  String get legal_termsAvailabilityTitle => 'Availability';

  @override
  String get legal_termsAvailabilityBody =>
      'The service is provided \"as is\", without any guarantee of availability or freedom from errors. The operator may change, interrupt or stop it. Export your data regularly: the file is your own backup.';

  @override
  String get legal_termsLiabilityTitle => 'Liability';

  @override
  String get legal_termsLiabilityBody =>
      'To the extent permitted by law, neither the operator nor the authors of the software are liable for loss of data or for indirect damage resulting from the use of the service. The software itself is distributed under the GNU Affero General Public License v3, without warranty.';

  @override
  String get legal_termsEndTitle => 'Closing your account';

  @override
  String get legal_termsEndBody =>
      'You can delete your account at any time from the Security page: your data is then erased from the server. The operator may close an account that breaks these terms.';

  @override
  String get legal_termsLawTitle => 'Changes and applicable law';

  @override
  String get legal_termsLawBody =>
      'These terms may change with the app; the version in force is the one shown here, dated at the top of this page. They are governed by Swiss law.';

  @override
  String get legal_privacyControllerTitle => 'Who is responsible';

  @override
  String get legal_privacyControllerBody =>
      'The controller of your data is the operator of the server you sign in to. Address any question or request about your data to them. The authors of the software have no access to your server or your data.';

  @override
  String get legal_privacyDataTitle => 'What is processed';

  @override
  String get legal_privacyDataBody =>
      '• Account: your email address, your password (only ever stored hashed), your language and your preferences.\n• Content: your events (dates and descriptions), tags, categories and tag groups.\n• Security: for each signed-in device, the platform and version of the app, its IP address, and when it signed in and was last active; your PIN, stored hashed, or the public key that checks your fingerprint — the fingerprint itself never leaves your device.\n• Technical logs: the server records each request (time, IP address, address called) to run and protect the service.';

  @override
  String get legal_privacyPurposesTitle => 'Why';

  @override
  String get legal_privacyPurposesBody =>
      'Only to provide the service (store, sync and show your content), to secure your account (sign-in, signed-in devices, limiting repeated attempts) and to send you the emails it needs, such as a password reset code. The legal basis is the performance of the contract — providing the service you asked for by creating your account — and the operator\'s legitimate interest in keeping it secure. No advertising, no tracking, no analytics, no sale of data.';

  @override
  String get legal_privacySecurityTitle => 'Encryption';

  @override
  String get legal_privacySecurityBody =>
      'Category names, tag names and event descriptions are encrypted at rest on the server. With end-to-end encryption (optional, on the Security page), they are encrypted on your device and the server cannot read them; the dates of your events stay readable by the server. Connections are encrypted when the server is reached over HTTPS; the app warns you when it is not.';

  @override
  String get legal_privacyDeviceTitle => 'On your device';

  @override
  String get legal_privacyDeviceBody =>
      'To work offline, the app keeps a copy of your data on your device, encrypted with a key that never leaves it. Logging out erases it.';

  @override
  String get legal_privacySharingTitle => 'Sharing';

  @override
  String get legal_privacySharingBody =>
      'Your data is passed on to no one, except: the email provider the operator uses to send the app\'s emails (it sees your address and the message), the company hosting the server if the operator uses one, and authorities where the law requires it. The app contacts no other service: the link to a new version only opens if you tap it.';

  @override
  String get legal_privacyRetentionTitle => 'How long';

  @override
  String get legal_privacyRetentionBody =>
      'Your data is kept as long as your account exists. Deleting your account erases it from the server; it may remain in the operator\'s backups until they are replaced (28 days by default). A device session ends after six months without use, a password reset code after 15 minutes. How long technical logs are kept depends on the server\'s configuration.';

  @override
  String get legal_privacyRightsTitle => 'Your rights';

  @override
  String get legal_privacyRightsBody =>
      'Under the Swiss Federal Act on Data Protection (FADP) and, if you are in the European Union, the GDPR, you can access your data, have it corrected or erased, receive it in a portable format and object to its processing. Most of this is in the app: edit anything, export your data, delete your account. For the rest, contact the operator. You can also complain to a supervisory authority: the FDPIC in Switzerland, or the authority of your country in the EU.';

  @override
  String get legal_privacyChangesTitle => 'Changes';

  @override
  String get legal_privacyChangesBody =>
      'This policy may change with the app; the date at the top of this page shows its last update.';

  @override
  String get register_legalNotice =>
      'By creating an account, you accept the terms of use and the privacy policy.';
}
