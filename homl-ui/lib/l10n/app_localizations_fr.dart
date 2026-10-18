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
  String get global_serverUnreachable =>
      'Serveur injoignable : cette action nécessite une connexion.';

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
  String get account_pinOfflineUnavailable =>
      'Serveur injoignable. Ton PIN fonctionnera hors ligne une fois que tu l\'auras saisi ici avec une connexion.';

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
  String get account_sessions => 'Appareils connectés';

  @override
  String get sessions_thisDevice => 'Cet appareil';

  @override
  String sessions_lastActive(String date) {
    return 'Actif le $date';
  }

  @override
  String sessions_signedIn(String date) {
    return 'Connecté le $date';
  }

  @override
  String get sessions_signedInUnknown =>
      'Connecté avant le suivi des appareils';

  @override
  String sessions_app(String version) {
    return 'app $version';
  }

  @override
  String get sessions_unknownDevice => 'Appareil inconnu';

  @override
  String get sessions_signOut => 'Déconnecter';

  @override
  String get sessions_signOutTitle => 'Déconnecter cet appareil ?';

  @override
  String get sessions_signOutInfo =>
      'Il lui faudra le mot de passe pour se reconnecter. Ses modifications pas encore envoyées l\'attendent jusque-là.';

  @override
  String get sessions_signOutOthers => 'Déconnecter tous les autres appareils';

  @override
  String get sessions_signOutOthersTitle =>
      'Déconnecter tous les autres appareils ?';

  @override
  String get sessions_failed =>
      'Impossible de lister les appareils : il faut une connexion.';

  @override
  String get sessions_retry => 'Réessayer';

  @override
  String get sessions_actionFailed =>
      'Ça n\'a pas marché : réessaie quand le serveur est joignable.';

  @override
  String get sessions_activityNote =>
      'La dernière activité est mise à jour environ toutes les dix minutes d\'utilisation. L\'adresse est celle de ce moment-là.';

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
  String get login_serverUnreachable =>
      'Serveur injoignable. Vérifie ta connexion et réessaie.';

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
  String get register_closedTitle => 'Inscriptions fermées';

  @override
  String get register_closedInfo =>
      'Ce serveur n\'accepte pas de nouveaux comptes. La personne qui l\'administre peut ouvrir les inscriptions.';

  @override
  String get register_backToLogin => 'Retour à la connexion';

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
  String get insert_periodSingleDay => 'Un jour';

  @override
  String get insert_periodClosed => 'Période';

  @override
  String get insert_periodOngoing => 'En cours';

  @override
  String get list_filterLabel => 'Tag ou texte';

  @override
  String get list_filterHint => '-Bob, \"plage\"';

  @override
  String get list_pickDates => 'Filtrer par dates';

  @override
  String get list_showTimeline => 'Afficher la frise';

  @override
  String get list_showGrid => 'Afficher la grille';

  @override
  String get timeline_empty =>
      'Aucune période ici. Un événement avec une date de fin, ou encore en cours, apparaît sur la frise.';

  @override
  String timeline_singleDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count événements d\'un seul jour ne sont pas affichés',
      one: '1 événement d\'un seul jour n\'est pas affiché',
    );
    return '$_temp0';
  }

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
  String get list_onThisDay => 'Ce jour-là';

  @override
  String get list_lastTime => 'Dernière fois :';

  @override
  String get list_lastTimeNow => 'en ce moment';

  @override
  String list_eventCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count événements',
      one: '1 événement',
    );
    return '$_temp0';
  }

  @override
  String list_thisYearCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cette année',
      zero: 'aucun cette année',
    );
    return '$_temp0';
  }

  @override
  String get event_ongoing => 'En cours';

  @override
  String event_durationDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count jours',
      one: '1 jour',
    );
    return '$_temp0';
  }

  @override
  String event_durationMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mois',
      one: '1 mois',
    );
    return '$_temp0';
  }

  @override
  String event_durationYears(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ans',
      one: '1 an',
    );
    return '$_temp0';
  }

  @override
  String event_sinceDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'depuis $count jours',
      one: 'depuis 1 jour',
    );
    return '$_temp0';
  }

  @override
  String event_sinceMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'depuis $count mois',
      one: 'depuis 1 mois',
    );
    return '$_temp0';
  }

  @override
  String event_sinceYears(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'depuis $count ans',
      one: 'depuis 1 an',
    );
    return '$_temp0';
  }

  @override
  String event_daysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'il y a $count jours',
      one: 'hier',
      zero: 'aujourd\'hui',
    );
    return '$_temp0';
  }

  @override
  String event_monthsAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'il y a $count mois',
      one: 'il y a 1 mois',
    );
    return '$_temp0';
  }

  @override
  String event_yearsAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'il y a $count ans',
      one: 'il y a 1 an',
    );
    return '$_temp0';
  }

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
  String get categories_browseTags => 'Parcourir les tags';

  @override
  String get categories_pickTag => 'Choisir un tag';

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
      other: '$count d\'entre eux ne garderont que leur date.',
      one: '1 d\'entre eux ne gardera que sa date.',
    );
    return '$_temp0';
  }

  @override
  String get categories_deleteTagKeepEvents =>
      'Conserver ces événements, retirer le tag';

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
      other: '$count événements utilisent ces tags et seront supprimés.',
      one: '1 événement utilise ces tags et sera supprimé.',
    );
    return '$_temp0';
  }

  @override
  String get categories_deleteTagNameConflict =>
      'Un de ces tags ou groupes existe déjà dans Autres. Renomme-le, ou supprime les tags au lieu de les déplacer.';

  @override
  String get categories_tagNameConflict =>
      'Cette catégorie a déjà un tag portant ce nom. Choisis-en un autre.';

  @override
  String get categories_groups => 'Groupes';

  @override
  String get categories_newGroup => 'Nouveau groupe';

  @override
  String get categories_editGroup => 'Modifier le groupe';

  @override
  String get categories_deleteGroup => 'Supprimer le groupe';

  @override
  String get categories_groupHint =>
      'Taper le nom du groupe ajoute tous ses tags d\'un coup.';

  @override
  String get categories_groupMembers => 'Tags du groupe';

  @override
  String get categories_groupNeedsMembers => 'Choisis au moins un tag.';

  @override
  String get categories_groupNameTaken =>
      'Un tag ou un groupe porte déjà ce nom.';

  @override
  String get categories_groupNameReserved => 'Ce nom est réservé aux dates.';

  @override
  String get categories_groupNameConflict =>
      'Cette catégorie a déjà un groupe portant ce nom. Choisis-en un autre.';

  @override
  String get categories_groupEmpty => 'Plus aucun tag';

  @override
  String categories_deleteGroupTitle(String group) {
    return 'Supprimer \"$group\" ?';
  }

  @override
  String get categories_deleteGroupInfo =>
      'Seul le groupe disparaît : ses tags et leurs événements restent.';

  @override
  String get offline_title => 'Hors ligne';

  @override
  String get offline_explanation =>
      'Serveur injoignable. Tu consultes les données enregistrées sur cet appareil ; les modifications nécessitent une connexion. L\'app se reconnecte toute seule.';

  @override
  String offline_explanationSince(String date) {
    return 'Serveur injoignable. Tu consultes les données enregistrées sur cet appareil (mises à jour le $date) ; les modifications nécessitent une connexion. L\'app se reconnecte toute seule.';
  }

  @override
  String get sync_savedOffline =>
      'Enregistré sur cet appareil. Ce sera envoyé dès que le serveur sera joignable.';

  @override
  String get sync_sent =>
      'Tes modifications faites hors ligne ont été envoyées.';

  @override
  String get sync_restored =>
      'Un événement supprimé sur un autre appareil avait été modifié ici : il est revenu, avec tes modifications.';

  @override
  String get sync_kept =>
      'Un élément que tu avais supprimé avait été modifié sur un autre appareil : il a été gardé.';

  @override
  String get sync_conflicts =>
      'Tes modifications hors ligne ont remplacé celles faites sur les mêmes événements depuis un autre appareil.';

  @override
  String get sync_parked =>
      'Certaines modifications n\'ont pas pu être envoyées : vois les modifications en attente.';

  @override
  String get sync_dropped =>
      'Une modification faite hors ligne a été abandonnée : ce qu\'elle modifiait avait été supprimé sur un autre appareil.';

  @override
  String get sync_pendingChangesFirst =>
      'Des modifications faites hors ligne attendent encore : envoie-les ou abandonne-les d\'abord.';

  @override
  String get pending_title => 'Modifications en attente';

  @override
  String get pending_info =>
      'Faites sur cet appareil pendant que le serveur était injoignable. Elles partent dès qu\'il répond.';

  @override
  String get pending_sendNow => 'Envoyer maintenant';

  @override
  String get pending_retry => 'Réessayer';

  @override
  String get pending_discard => 'Abandonner';

  @override
  String get pending_createEvent => 'Nouvel événement';

  @override
  String get pending_updateEvent => 'Événement modifié';

  @override
  String get pending_deleteEvent => 'Événement supprimé';

  @override
  String get pending_createTag => 'Nouveau tag';

  @override
  String get pending_updateTag => 'Tag modifié';

  @override
  String get pending_deleteTag => 'Tag supprimé';

  @override
  String get pending_createCategory => 'Nouvelle catégorie';

  @override
  String get pending_updateCategory => 'Catégorie modifiée';

  @override
  String get pending_deleteCategory => 'Catégorie supprimée';

  @override
  String get pending_createGroup => 'Nouveau groupe de tags';

  @override
  String get pending_updateGroup => 'Groupe de tags modifié';

  @override
  String get pending_deleteGroup => 'Groupe de tags supprimé';

  @override
  String get pending_waiting => 'En attente';

  @override
  String get pending_refused => 'Refusée par le serveur';

  @override
  String get pending_missingTag => 'Utilise un tag qui n\'a pas pu être créé';

  @override
  String get pending_missingParent =>
      'A besoin d\'une catégorie ou d\'un groupe qui n\'a pas pu être créé';

  @override
  String get pending_encryptionChanged =>
      'Le chiffrement a changé sur un autre appareil';

  @override
  String get pending_dataReplaced =>
      'Les données du serveur ont été remplacées (restauration d\'une sauvegarde)';

  @override
  String get logout_pendingTitle => 'Modifications non envoyées';

  @override
  String get logout_pendingConfirm => 'Se déconnecter quand même';

  @override
  String logout_pendingInfo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count modifications faites hors ligne ne sont pas encore sur le serveur. Te déconnecter les fait perdre.',
      one:
          '1 modification faite hors ligne n\'est pas encore sur le serveur. Te déconnecter la fait perdre.',
    );
    return '$_temp0';
  }

  @override
  String get account_exportData => 'Exporter mes données';

  @override
  String get account_exportDataHint =>
      'Un fichier avec tes catégories, tags et événements';

  @override
  String get account_importData => 'Importer des données';

  @override
  String get account_importDataHint =>
      'Ajouter le contenu d\'un fichier exporté';

  @override
  String get export_title => 'Exporter tes données';

  @override
  String get export_info =>
      'Le fichier contient tes catégories, tags et événements. Quiconque l\'obtient peut les lire, sauf s\'il est protégé par un mot de passe.';

  @override
  String get export_passwordSwitch => 'Protéger par un mot de passe';

  @override
  String get export_password => 'Mot de passe';

  @override
  String get export_passwordRepeat => 'Répète le mot de passe';

  @override
  String get export_passwordTooShort => 'Au moins 8 caractères';

  @override
  String get export_passwordHint =>
      'Sans ce mot de passe, personne ne peut ouvrir le fichier, pas même toi : il ne peut pas être récupéré.';

  @override
  String get export_e2eeWarning =>
      'Ton compte est chiffré de bout en bout : sans mot de passe, ce fichier contient tes données en clair.';

  @override
  String get export_confirm => 'Exporter';

  @override
  String get export_saved => 'Export enregistré';

  @override
  String get export_failed => 'L\'export a échoué, réessaie plus tard';

  @override
  String get import_passwordTitle => 'Fichier protégé';

  @override
  String get import_passwordInfo =>
      'Saisis le mot de passe choisi lors de l\'export.';

  @override
  String get import_passwordWrong => 'Mot de passe incorrect';

  @override
  String get import_open => 'Ouvrir';

  @override
  String get import_invalidFile =>
      'Ce fichier n\'est pas un export HOML, ou il est endommagé';

  @override
  String get import_newerVersion =>
      'Ce fichier vient d\'une version plus récente de HOML : mets l\'app à jour pour l\'importer';

  @override
  String get import_confirmTitle => 'Importer ce fichier ?';

  @override
  String import_confirmInfo(String date) {
    return 'Exporté le $date, il contient :';
  }

  @override
  String get import_confirmMerge =>
      'Tout est ajouté à ton compte : ce qui existe déjà est ignoré, et rien n\'est modifié ni supprimé.';

  @override
  String import_countCategories(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count catégories',
      one: '1 catégorie',
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
      other: '$count groupes de tags',
      one: '1 groupe de tags',
    );
    return '$_temp0';
  }

  @override
  String import_countEvents(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count événements',
      one: '1 événement',
    );
    return '$_temp0';
  }

  @override
  String get import_confirm => 'Importer';

  @override
  String import_progress(int done, int total) {
    return 'Import en cours… $done sur $total';
  }

  @override
  String get import_keepOpen =>
      'Garde l\'app ouverte jusqu\'à la fin de l\'import.';

  @override
  String get import_doneTitle => 'Import terminé';

  @override
  String get import_doneAdded => 'Ajouté :';

  @override
  String get import_doneNothing =>
      'Rien de nouveau : ton compte contenait déjà tout.';

  @override
  String import_doneExisting(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count événements étaient déjà là.',
      one: '1 événement était déjà là.',
    );
    return '$_temp0';
  }

  @override
  String import_doneSkipped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count éléments ont été refusés par le serveur (un nom de tag réservé, par exemple) et laissés de côté.',
      one:
          '1 élément a été refusé par le serveur (un nom de tag réservé, par exemple) et laissé de côté.',
    );
    return '$_temp0';
  }

  @override
  String get import_interrupted =>
      'Connexion perdue : l\'import s\'est arrêté. Importe à nouveau le même fichier pour le terminer, ce qui est déjà là sera ignoré.';
}
