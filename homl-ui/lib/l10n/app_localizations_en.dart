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
  String get list_filterLabel => 'Tag or text';

  @override
  String get list_filterHint => '-Bob, \"beach\"';

  @override
  String get list_pickDates => 'Filter by dates';

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
  String get list_showGrid => 'Show the grid';

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
}
