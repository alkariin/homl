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
  /// **'Account'**
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
  /// **'Actual password'**
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

  /// No description provided for @list_manageCategories.
  ///
  /// In en, this message translates to:
  /// **'Manage categories'**
  String get list_manageCategories;

  /// No description provided for @list_noEvents.
  ///
  /// In en, this message translates to:
  /// **'No events found'**
  String get list_noEvents;

  /// No description provided for @categories_title.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get categories_title;

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
