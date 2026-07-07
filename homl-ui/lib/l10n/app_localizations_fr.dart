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
  String get login_usernameLabel => 'identifiant';

  @override
  String get login_passwordLabel => 'mot de passe';

  @override
  String get login_submit => 'connexion';

  @override
  String get login_register => 'Creer un compte';

  @override
  String get login_incorrectCredentials => 'Email ou mot de passe incorrect';

  @override
  String get login_invalidEmail => 'L\'email n\'est pas valide';

  @override
  String get login_invalidPassword =>
      'Doit contenir au moins un chiffre, une majuscule et une minuscule, un caractere special, et au moins 8 caracteres';

  @override
  String get settings => 'Parametres';

  @override
  String get settings_language => 'Langue';

  @override
  String get settings_selectLanguage => 'Selectionner la langue';

  @override
  String get global_cancel => 'Annuler';

  @override
  String get global_save => 'Enregistrer';

  @override
  String get global_delete => 'Supprimer';

  @override
  String get nav_categories => 'Categories';

  @override
  String get nav_search => 'Rechercher';

  @override
  String get nav_add => 'Ajouter';

  @override
  String get insert_tagInputLabel => 'Ajouter un tag';

  @override
  String get insert_descriptionLabel => 'Description';

  @override
  String get insert_submit => 'Creer l\'evenement';

  @override
  String get insert_eventCreated => 'Evenement cree';

  @override
  String get insert_noTagsError => 'Ajouter au moins un tag';

  @override
  String get list_filterLabel => 'Filtrer par tag';

  @override
  String get list_noEvents => 'Aucun evenement trouve';

  @override
  String get categories_newCategory => 'Nouvelle categorie';

  @override
  String get categories_editCategory => 'Modifier la categorie';

  @override
  String get categories_deleteCategory => 'Supprimer la categorie ?';

  @override
  String get categories_deleteMoveTags =>
      'Deplacer les tags vers la categorie Other';

  @override
  String get categories_categoryName => 'Nom';

  @override
  String get categories_color => 'Couleur';

  @override
  String get categories_newTag => 'Nouveau tag';

  @override
  String get categories_renameTag => 'Renommer le tag';

  @override
  String get categories_deleteTag => 'Supprimer le tag';

  @override
  String get categories_addSynonym => 'Ajouter un synonyme';

  @override
  String get categories_detachSynonym => 'Detacher le synonyme';

  @override
  String get categories_synonymName => 'Synonyme';
}
