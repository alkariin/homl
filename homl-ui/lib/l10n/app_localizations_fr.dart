// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get global_unexpectedError => 'Erreur inattendue';

  @override
  String get account => 'Compte';

  @override
  String get account_logout => 'Se deconnecter';

  @override
  String get account_updatePassword => 'Mettre a jour le mot de passe';

  @override
  String get account_currentPassword => 'Mot de passe actuel';

  @override
  String get account_enterPassword => 'Entrer le nouveau mot de passe';

  @override
  String get account_repeatPassword => 'Repeter le mot de passe';

  @override
  String get account_fingerprintSwitchText =>
      'Activer le verrouillage par empreinte';

  @override
  String get account_fingerprintSwitchError =>
      'Impossible d\'utiliser l\'authentification biométrique sur cet appareil.';

  @override
  String get account_pinSwitchText => 'Ajouter un code PIN';

  @override
  String get account_pinSwitchError => 'Le code PIN n\'a pas pu etre configure';

  @override
  String get account_enterPin => 'Entrer le code PIN';

  @override
  String get settings => 'Parametres';

  @override
  String get settings_language => 'Langue';

  @override
  String get settings_selectLanguage => 'Selectionner la langue';
}
