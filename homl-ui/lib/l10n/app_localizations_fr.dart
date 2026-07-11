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
  String get account_logout => 'Se déconnecter';

  @override
  String get account_updatePassword => 'Mettre à jour le mot de passe';

  @override
  String get account_currentPassword => 'Mot de passe actuel';

  @override
  String get account_enterPassword => 'Entrer le nouveau mot de passe';

  @override
  String get account_repeatPassword => 'Répéter le mot de passe';

  @override
  String get account_fingerprintSwitchText =>
      'Activer le verrouillage par empreinte';

  @override
  String get account_fingerprintSwitchError =>
      'Impossible d\'utiliser l\'authentification biométrique sur cet appareil.';

  @override
  String get account_pinSwitchText => 'Ajouter un code PIN';

  @override
  String get account_pinSwitchError => 'Le code PIN n\'a pas pu être configuré';

  @override
  String get account_enterPin => 'Entrer le code PIN';

  @override
  String get account_pinEnabled => 'Le code PIN a été activé';

  @override
  String get account_pinDisabled => 'Le code PIN a été désactivé';

  @override
  String get account_pinIncorrect => 'Le code PIN est incorrect';

  @override
  String get account_returnToLogin => 'Retour à la connexion';

  @override
  String get account_passwordUpdated => 'Votre mot de passe a été mis à jour';

  @override
  String get account_passwordIncorrect => 'Le mot de passe est incorrect';

  @override
  String get account_passwordUpdateError =>
      'Une erreur est survenue pendant la mise à jour, réessayez plus tard';

  @override
  String get account_currentPasswordError => 'Entrez votre mot de passe actuel';

  @override
  String get account_passwordsNotIdentical =>
      'Les mots de passe ne sont pas identiques';

  @override
  String get login_usernameLabel => 'identifiant';

  @override
  String get login_passwordLabel => 'mot de passe';

  @override
  String get login_submit => 'connexion';

  @override
  String get login_register => 'Créer un compte';

  @override
  String get login_incorrectCredentials => 'Email ou mot de passe incorrect';

  @override
  String get login_invalidEmail => 'L\'email n\'est pas valide';

  @override
  String get login_invalidPassword =>
      'Doit contenir au moins un chiffre, une majuscule et une minuscule, un caractère spécial, et au moins 8 caractères';

  @override
  String get login_forgotPassword => 'Mot de passe oublié ?';

  @override
  String get login_pinLocked =>
      'Votre PIN a été bloqué après trop de tentatives. Veuillez vous connecter avec votre mot de passe.';

  @override
  String get forgot_title => 'Réinitialiser le mot de passe';

  @override
  String get forgot_emailInstructions =>
      'Entrez votre adresse email et nous vous enverrons un code à 6 chiffres.';

  @override
  String get forgot_sendCode => 'Envoyer le code';

  @override
  String get forgot_codeInstructions =>
      'Entrez le code à 6 chiffres reçu par email et choisissez un nouveau mot de passe.';

  @override
  String get forgot_newPasswordLabel => 'Nouveau mot de passe';

  @override
  String get forgot_confirmPasswordLabel => 'Confirmer le mot de passe';

  @override
  String get forgot_submit => 'Réinitialiser le mot de passe';

  @override
  String get forgot_resendCode => 'Renvoyer le code';

  @override
  String get forgot_invalidCode => 'Le code est invalide ou a expiré';

  @override
  String account_pinAttemptsRemaining(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tentatives restantes',
      one: '1 tentative restante',
    );
    return '$_temp0';
  }

  @override
  String get biometric_failedTitle =>
      'Échec de l\'authentification par empreinte';

  @override
  String get biometric_failedMessage =>
      'Nous n\'avons pas pu vérifier votre empreinte digitale.';

  @override
  String get biometric_retry => 'Réessayer';

  @override
  String get biometric_usePassword => 'Utiliser mon mot de passe';

  @override
  String get register_submit => 'Créer un compte';

  @override
  String get register_failure => 'L\'inscription a échoué';

  @override
  String get settings => 'Paramètres';

  @override
  String get settings_language => 'Langue';

  @override
  String get settings_selectLanguage => 'Sélectionner la langue';

  @override
  String get settings_homeTab => 'Écran d\'accueil';

  @override
  String get settings_selectHomeTab => 'Sélectionner l\'écran d\'accueil';

  @override
  String get global_cancel => 'Annuler';

  @override
  String get global_save => 'Enregistrer';

  @override
  String get global_delete => 'Supprimer';

  @override
  String get global_close => 'Fermer';

  @override
  String get global_update => 'Mettre à jour';

  @override
  String get nav_categories => 'Catégories';

  @override
  String get nav_search => 'Rechercher';

  @override
  String get nav_add => 'Ajouter';

  @override
  String get insert_tagInputLabel => 'Ajouter un tag';

  @override
  String get insert_descriptionLabel => 'Description';

  @override
  String get insert_submit => 'Créer l\'événement';

  @override
  String get insert_eventCreated => 'Événement créé';

  @override
  String get insert_noTagsError => 'Ajouter au moins un tag';

  @override
  String get list_filterLabel => 'Filtrer par tag';

  @override
  String get list_noEvents => 'Aucun événement trouvé';

  @override
  String get categories_newCategory => 'Nouvelle catégorie';

  @override
  String get categories_editCategory => 'Modifier la catégorie';

  @override
  String get categories_deleteCategory => 'Supprimer la catégorie ?';

  @override
  String get categories_deleteMoveTags =>
      'Déplacer les tags vers la catégorie Other';

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
  String get categories_detachSynonym => 'Détacher le synonyme';

  @override
  String get categories_synonymName => 'Synonyme';
}
