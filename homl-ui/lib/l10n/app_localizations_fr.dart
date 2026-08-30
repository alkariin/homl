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
  String get account => 'Sécurité';

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
  String get account_deleteAccount => 'Supprimer mon compte';

  @override
  String get account_deleteAccountTitle => 'Supprimer votre compte ?';

  @override
  String get account_deleteAccountWarning =>
      'Ceci supprime définitivement votre compte ainsi que tous vos événements, tags et catégories, sur tous vos appareils. Cette action est irréversible. Saisissez votre mot de passe pour confirmer.';

  @override
  String get account_deleteAccountError =>
      'Le compte n\'a pas pu être supprimé, réessayez plus tard';

  @override
  String get account_deleted => 'Votre compte a été supprimé';

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
  String get settings_about => 'À propos';

  @override
  String settings_versionApp(String version) {
    return 'App $version';
  }

  @override
  String settings_versionServer(String version) {
    return 'Serveur $version';
  }

  @override
  String get settings_versionServerUnavailable => 'Serveur injoignable';

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
  String get e2ee_cancel => 'Annuler';

  @override
  String get e2ee_continue => 'Continuer';

  @override
  String get account_e2eeSwitchText =>
      'Chiffrement de bout en bout (seul cet appareil peut lire)';

  @override
  String get account_e2eeEnableTitle => 'Chiffrer vos données';

  @override
  String get account_e2eeEnableWarning =>
      'Vos tags, catégories et notes seront chiffrés sur cet appareil avec une clé que vous seul possédez. Le serveur ne pourra plus les lire. Si vous perdez la clé et sa phrase de récupération, les données seront définitivement perdues.';

  @override
  String get account_e2eeDisableTitle => 'Désactiver le chiffrement';

  @override
  String get account_e2eeDisableWarning =>
      'Vos données resteront chiffrées sur le serveur, mais celui-ci pourra de nouveau les lire. Continuer ?';

  @override
  String get account_e2eeEnabled => 'Chiffrement activé';

  @override
  String get account_e2eeDisabled => 'Chiffrement désactivé';

  @override
  String get account_e2eeError =>
      'Échec du changement de chiffrement, réessayez plus tard';

  @override
  String get account_e2eeMnemonicTitle => 'Votre phrase de récupération';

  @override
  String get account_e2eeMnemonicHint =>
      'Notez ces 12 mots et conservez-les en lieu sûr. C\'est le seul moyen de récupérer vos données sur un autre appareil ou après une réinstallation. Nous ne pouvons pas les récupérer à votre place.';

  @override
  String get account_e2eeMnemonicSkip => 'Ignorer (risqué)';

  @override
  String get account_e2eeMnemonicSaved => 'C\'est noté';

  @override
  String account_e2eeMnemonicCount(int count) {
    return '$count mots';
  }

  @override
  String get account_e2eeMnemonicCopy => 'Copier';

  @override
  String get account_e2eeMnemonicCopied => 'Phrase de récupération copiée';

  @override
  String get e2ee_lockedTitle => 'Données chiffrées';

  @override
  String get e2ee_lockedExplanation =>
      'Ce compte est chiffré de bout en bout, mais cet appareil n\'a pas de clé. Saisissez votre phrase de récupération pour déverrouiller vos données, ou supprimez-les pour repartir de zéro.';

  @override
  String get e2ee_restoreHint => 'Phrase de récupération (12 mots)';

  @override
  String get e2ee_restoreButton => 'Déverrouiller';

  @override
  String get e2ee_restoreInvalid =>
      'Cette phrase est valide mais ne correspond pas à ce compte. Elle vient peut-être d\'un autre compte ou d\'une activation annulée.';

  @override
  String get e2ee_restoreMalformed =>
      'Ce n\'est pas une phrase de récupération valide : vérifiez les fautes de frappe ou l\'autocorrection (12 mots anglais en minuscules).';

  @override
  String get e2ee_restoreUnknownWords => 'Mots absents du dictionnaire';

  @override
  String e2ee_restoreWordCount(int count) {
    return 'Vous avez saisi $count mots — une phrase de récupération en compte exactement 12.';
  }

  @override
  String get e2ee_restoreChecksum =>
      'Les 12 mots existent, mais la somme de contrôle échoue : deux mots sont probablement inversés, ou l\'un a été remplacé par un mot proche du dictionnaire.';

  @override
  String get e2ee_purgeButton => 'Supprimer mes données chiffrées';

  @override
  String get e2ee_purgeConfirmTitle => 'Tout supprimer ?';

  @override
  String get e2ee_purgeConfirmText =>
      'Ceci supprime définitivement tous vos événements, tags et catégories chiffrés et désactive le chiffrement. Cette action est irréversible.';

  @override
  String get e2ee_purgeConfirmAction => 'Supprimer';

  @override
  String get nav_categories => 'Catégories';

  @override
  String get nav_search => 'Rechercher';

  @override
  String get nav_add => 'Ajouter';

  @override
  String get insert_tagInputLabel => 'Ajouter un tag';

  @override
  String insert_newTagCategoryTitle(String tag) {
    return 'Nouveau tag \"$tag\" : choisir une catégorie';
  }

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
  String get list_editEvent => 'Modifier l\'événement';

  @override
  String get list_deleteEventTitle => 'Supprimer l\'événement ?';

  @override
  String get list_deleteEventInfo =>
      'Cet événement et sa description seront définitivement supprimés.';

  @override
  String get list_eventUpdated => 'Événement mis à jour';

  @override
  String get categories_newCategory => 'Nouvelle catégorie';

  @override
  String get categories_editCategory => 'Modifier la catégorie';

  @override
  String get categories_deleteCategory => 'Supprimer la catégorie ?';

  @override
  String get categories_deleteMoveTags =>
      'Déplacer les tags vers la catégorie Autres';

  @override
  String get categories_categoryName => 'Nom';

  @override
  String get categories_defaultDates => 'Dates';

  @override
  String get categories_defaultPersons => 'Personnes';

  @override
  String get categories_defaultOthers => 'Autres';

  @override
  String get categories_color => 'Couleur';

  @override
  String categories_tagCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tags',
      one: '1 tag',
      zero: 'Aucun tag',
    );
    return '$_temp0';
  }

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

  @override
  String get categories_renameSynonym => 'Renommer le synonyme';

  @override
  String get categories_deleteSynonymTitle => 'Supprimer le synonyme ?';

  @override
  String categories_deleteSynonymInfo(String synonym, String tag) {
    return 'Les événements tagués \"$synonym\" seront déplacés vers \"$tag\".';
  }

  @override
  String get categories_moveTag => 'Déplacer vers une autre catégorie';

  @override
  String categories_moveTagTitle(String tag) {
    return 'Déplacer \"$tag\" vers';
  }

  @override
  String categories_deleteTagTitle(String tag) {
    return 'Supprimer \"$tag\" ?';
  }

  @override
  String categories_deleteTagEvents(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count événements utilisent ce tag.',
      one: '1 événement utilise ce tag.',
      zero: 'Aucun événement n\'utilise ce tag.',
    );
    return '$_temp0';
  }

  @override
  String categories_deleteTagSynonyms(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ses $count synonymes seront aussi supprimés.',
      one: 'Son synonyme sera aussi supprimé.',
    );
    return '$_temp0';
  }

  @override
  String categories_deleteTagExclusiveEvents(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count événements n\'ont aucun autre tag :',
      one: '1 événement n\'a aucun autre tag :',
    );
    return '$_temp0';
  }

  @override
  String get categories_deleteTagKeepEvents =>
      'Conserver ces événements (date uniquement)';

  @override
  String get categories_deleteTagDeleteEvents => 'Supprimer ces événements';

  @override
  String categories_deleteCategoryTags(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Cette catégorie a $count tags.',
      one: 'Cette catégorie a 1 tag.',
      zero: 'Cette catégorie n\'a aucun tag.',
    );
    return '$_temp0';
  }

  @override
  String categories_deleteCategoryEvents(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count événements les utilisent.',
      one: '1 événement les utilise.',
      zero: 'Aucun événement ne les utilise.',
    );
    return '$_temp0';
  }

  @override
  String get categories_deleteCategoryDeleteTags =>
      'Supprimer les tags, conserver les événements';

  @override
  String get categories_deleteCategoryDeleteAll =>
      'Supprimer les tags et leurs événements';

  @override
  String categories_deleteCategoryDeleteAllDetail(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count événements n\'utilisent que des tags de cette catégorie et seront supprimés.',
      one:
          '1 événement n\'utilise que des tags de cette catégorie et sera supprimé.',
    );
    return '$_temp0';
  }
}
