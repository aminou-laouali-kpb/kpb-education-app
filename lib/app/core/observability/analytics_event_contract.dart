/// Canonical Firebase Analytics **event names** (snake_case, GA4-friendly).
///
/// Keep in sync with [`docs/analytics-event-contract.md`](../../../../docs/analytics-event-contract.md).
abstract final class AnalyticsEventName {
  static const logout = 'logout';
  static const orientationStart = 'orientation_start';
  static const orientationComplete = 'orientation_complete';
  static const saveItem = 'save_item';
  static const unsaveItem = 'unsave_item';
  static const compareInstitutions = 'compare_institutions';
  static const caseCreated = 'case_created';
  static const caseViewed = 'case_viewed';
  static const documentUploaded = 'document_uploaded';
  static const caseMessageSent = 'case_message_sent';
  static const profileUpdated = 'profile_updated';
  static const themeToggled = 'theme_toggled';

  /// Guest mode (KPB-156): a visitor chose to explore without an account, and
  /// the moment a guest heads to sign-up (with the gate `source`). Makes the
  /// guest → signup → activation funnel attributable — otherwise guest usage is
  /// invisible.
  static const guestModeEntered = 'guest_mode_entered';
  static const guestToSignup = 'guest_to_signup';

  /// Onboarding funnel (KPB-158): a step became visible, plus completion / skip,
  /// so drop-off across the multi-page stepper is visible. `auth_failed` records
  /// a failed sign-in/up attempt with method + coarse reason (auth drop-off by
  /// method). The signup method itself rides the built-in `sign_up` event's
  /// `method` param (see [AnalyticsService.logRegister]).
  static const onboardingStepViewed = 'onboarding_step_viewed';
  static const onboardingCompleted = 'onboarding_completed';
  static const onboardingSkipped = 'onboarding_skipped';
  static const authFailed = 'auth_failed';

  /// « Continuer » tapé sur une page de l'onboarding dont le contrôle a échoué.
  /// Sans lui, le bouton qui « ne fait rien » ne se voyait qu'en rage clicks
  /// (13 % des comptes sur l'étape 1, octobre 2026) — sans dire POURQUOI.
  /// `step` (1-based) et `reason`, un identifiant fermé : jamais une valeur
  /// saisie.
  static const onboardingValidationFailed = 'onboarding_validation_failed';

  /// Daily "Bourse du jour" (KPB-162): the Home card was seen, and it was
  /// tapped through to the scholarship. viewed → opened gives the card CTR;
  /// saves ride the existing `save_item` event.
  static const dailyScholarshipViewed = 'daily_scholarship_viewed';
  static const dailyScholarshipOpened = 'daily_scholarship_opened';

  /// Parcours stories (KPB-169). `parcours_view` fires when a story actually
  /// becomes the one on screen (not when the list scrolls past it);
  /// `parcours_complete` when it is consumed — a video watched to the end, or a
  /// written interview scrolled to the last answer. The pair IS the completion
  /// rate the ticket asks for; without both, "views" alone say nothing.
  /// `story_of_week_*` measure the Home card's own funnel.
  static const parcoursView = 'parcours_view';
  static const parcoursComplete = 'parcours_complete';
  static const storyOfWeekViewed = 'story_of_week_viewed';
  static const storyOfWeekOpened = 'story_of_week_opened';

  /// "Mon plan" unified progress (KPB-164). Emitted with the current percentage
  /// whenever it changes, so the weekly delta is derived from the series in
  /// PostHog rather than from a local "last week" copy that could drift.
  static const myPlanProgress = 'my_plan_progress';

  /// Shared result card (KPB-165): a student sent an eligibility verdict / match
  /// / budget card into a conversation, carrying an invite link. `source` gives
  /// the share rate per result type; `with_image` tells apart a full card from a
  /// text-only fallback, so a rendering regression is visible in the data.
  static const shareCard = 'share_card';

  /// Conversion: the moment a user is handed off to a KPB advisor on WhatsApp.
  /// This is the core lead→advisor-contact step the funnel is measured on.
  static const whatsappHandoff = 'whatsapp_handoff';

  /// Referral loop (KPB-69): an invite shared via WhatsApp, and a code redeemed
  /// by a referee. Combined with case_created, this makes the referral →
  /// signup → case-created funnel attributable.
  static const referralInviteShared = 'referral_invite_shared';
  static const referralRedeemed = 'referral_redeemed';

  /// Espace « Études en France » — vitrine de Phase 0. `eef_teaser_viewed`
  /// donne la portée ; `eef_interest_declared` est LA question posée par la
  /// vitrine (y a-t-il une demande, et pour le payant ?).
  ///
  /// `eef_interest_failed` n'est pas du zèle : sans lui, un backend en panne le
  /// jour du lancement se lit dans les tableaux de bord exactement comme
  /// « personne n'est intéressé » — et on en tirerait la conclusion inverse de
  /// la vérité.
  static const eefTeaserViewed = 'eef_teaser_viewed';
  static const eefInterestDeclared = 'eef_interest_declared';
  static const eefInterestFailed = 'eef_interest_failed';

  /// Catalogue de l'espace. `eef_catalog_searched` dit si les étudiants
  /// trouvent quelque chose (`result_count`) et si le catalogue est publié
  /// (`catalog_published`) — sans JAMAIS le texte tapé : une requête libre peut
  /// contenir un nom, une ville, un établissement, donc des données de profil.
  ///
  /// `eef_catalog_failed` suit la logique de `eef_interest_failed` : sans lui,
  /// une panne du catalogue le jour du lancement se lit dans les tableaux de
  /// bord exactement comme « personne ne cherche ».
  /// L'espace réel (le hub) : `eef_space_viewed` donne la portée et la porte
  /// d'entrée ; `eef_hub_tile_opened` dit CE QUE les étudiants y viennent faire
  /// (`tile` = catalogue, cv, lettres, entretien, profil) — la seule mesure de ce que l'espace vaut avant la 55.
  /// La tuile `conseiller` a disparu avec la tuile : la carte d'aide l'a
  /// remplacée, et se mesure par `eef_help_cta_tapped` (`help_step` = `hub`).
  static const eefSpaceViewed = 'eef_space_viewed';
  static const eefHubTileOpened = 'eef_hub_tile_opened';
  static const eefCatalogViewed = 'eef_catalog_viewed';
  static const eefCatalogSearched = 'eef_catalog_searched';
  static const eefCatalogFailed = 'eef_catalog_failed';

  /// La carte d'aide de l'espace (« c'est flou ? tu veux de l'aide ? »).
  /// `eef_help_card_shown` donne la portée de chaque emplacement
  /// (`help_step`, `surface`, `variant`) ; `eef_help_cta_tapped` dit lequel
  /// convertit. Le rapport des deux, par `help_step`, est le taux de clic de
  /// l'emplacement — la seule façon de savoir où l'incitation marche et où elle
  /// n'est que du bruit. Le tap part AVANT l'ouverture de WhatsApp ;
  /// `whatsapp_handoff` (`source` = `eef_help_<étape>`) dit ensuite si
  /// l'ouverture a réussi.
  ///
  /// Ni l'un ni l'autre ne porte de donnée personnelle : trois identifiants
  /// fermés écrits dans le code. Le pays n'y figure pas — pas même un drapeau
  /// « suspendu », qui le désignerait presque.
  static const eefHelpCardShown = 'eef_help_card_shown';
  static const eefHelpCtaTapped = 'eef_help_cta_tapped';

  /// La bulle d'aide (build 56) : le menu de sujets de la pastille verte du hub
  /// et du catalogue a été ouvert. Une seule propriété, `surface` (`hub` ou
  /// `catalog`).
  ///
  /// Elle réutilise `eef_help_card_shown` (`help_step` = `bubble`) pour sa
  /// portée et `eef_help_cta_tapped` (`help_step` = `bubble_<sujet>`) pour le
  /// sujet choisi, avec EXACTEMENT les mêmes trois propriétés — mais ouvrir le
  /// menu n'est pas un envoi vers WhatsApp : mesuré à part, il ne gonfle pas
  /// `eef_help_cta_tapped`, qui dit toujours « un message part ». L'entonnoir se
  /// lit : bulle vue, menu ouvert, sujet choisi, envoi (`whatsapp_handoff`).
  static const eefBubbleOpened = 'eef_bubble_opened';

  /// Les écoles privées (build 56) : la feuille d'information « Service KPB » a
  /// été ouverte, depuis l'option de la bulle (`entry` = `bubble`) ou depuis la
  /// ligne de l'état « aucun résultat » du catalogue (`entry` = `catalog_empty`).
  /// Une seule propriété fermée, `entry`.
  ///
  /// Ouvrir une feuille n'est pas un envoi vers WhatsApp : il a donc son propre
  /// événement et ne gonfle pas `eef_help_cta_tapped`, qui dit toujours « un
  /// message part » (ici `help_step` = `private_sheet`, `variant` = `sheet`).
  static const eefPrivateInfoOpened = 'eef_private_info_opened';

  /// La visite guidée du hub (build 56) : `eef_tour_shown` part quand la feuille
  /// s'affiche (propriété `tour_trigger` = `first_open` ou `replay`),
  /// `eef_tour_completed` quand elle se ferme (`tour_exit` = `finished` ou
  /// `skipped`, `tour_cards_seen` = le nombre de cartes atteintes, un entier).
  ///
  /// Propriétés FERMÉES : aucun pays, aucun profil, aucun identifiant qui
  /// désigne une suspension (le nombre de cartes ne dit rien de la variante
  /// neutre de la première). Les rapports se lisent ainsi : portée =
  /// `eef_tour_shown` (`first_open`), taux de « Compris » =
  /// `eef_tour_completed` (`finished`) ÷ `eef_tour_shown`, usage du « ? » =
  /// `eef_tour_shown` (`replay`).
  static const eefTourShown = 'eef_tour_shown';
  static const eefTourCompleted = 'eef_tour_completed';

  /// Liste d'attente Karatou Premium. `premium_waitlist_joined` est la seule
  /// mesure directe de la demande pour le Pass — celle qui dira s'il vaut la
  /// peine d'être construit, et pour combien d'étudiants.
  ///
  /// `premium_waitlist_failed` suit la même logique que son homologue EEF :
  /// sans lui, un backend en panne se lit dans les tableaux de bord exactement
  /// comme « personne n'est intéressé », et on en tirerait la conclusion
  /// inverse de la vérité.
  ///
  /// Aucun événement de retrait, volontairement : mesurer les désinscriptions
  /// demanderait de garder une trace de quelqu'un qui vient de demander à ne
  /// plus en avoir, et le taux ne changerait aucune décision que le compteur
  /// d'inscriptions ne montre déjà.
  static const premiumWaitlistJoined = 'premium_waitlist_joined';
  static const premiumWaitlistFailed = 'premium_waitlist_failed';

  /// Coach IA (KPB Intelligence). `ai_coach_message_sent` part à la fin de
  /// chaque tour : `source` (`input` ou `suggestion`), `result` (`ok`,
  /// `quota_refused`, `error`, `unreachable`) et `quota_remaining` (entier, -1
  /// si inconnu). JAMAIS le texte de la question : il peut contenir un nom, une
  /// note, une situation familiale. `ai_coach_load_failed` : l'écran n'a pas pu
  /// charger quota, suggestions et historique — sans lui, une panne du coach
  /// se lirait comme « personne ne pose de question ».
  static const aiCoachMessageSent = 'ai_coach_message_sent';
  static const aiCoachLoadFailed = 'ai_coach_load_failed';

  /// Boucle « Suivre → alerte → ouvrir » (chantier G).
  /// `push_opened` : un tap sur une notification push, avec son `kind`
  /// (`scholarship_opened`, `scholarship_opened_bundle`, `deadline_reminder`…)
  /// — l'identifiant fermé de la charge, jamais un titre ni un identifiant de
  /// bourse. `permission_primer_shown` / `permission_primer_granted` : la
  /// feuille d'explication du premier « Suivre » et sa conversion en
  /// autorisation (`result` = `granted`, `denied`, `dismissed`).
  static const pushOpened = 'push_opened';
  static const permissionPrimerShown = 'permission_primer_shown';
  static const permissionPrimerGranted = 'permission_primer_granted';

  /// Test « Mes 10 bourses » (chantier H). L'entonnoir : carte vue → test
  /// commencé → étapes → terminé (ou abandonné / échoué) → résultats ouverts,
  /// suivis, dossiers. Propriétés FERMÉES (comptes, rangs, identifiants de
  /// bourse, étapes) : JAMAIS la nationalité, l'âge, la date de naissance, la
  /// moyenne ni le niveau de langue — ni ici, ni dans les tags push.
  static const scholarshipMatchEntryViewed = 'scholarship_match_entry_viewed';
  static const scholarshipMatchStarted = 'scholarship_match_started';
  static const scholarshipMatchStepViewed = 'scholarship_match_step_viewed';
  static const scholarshipMatchStepCompleted =
      'scholarship_match_step_completed';
  static const scholarshipMatchAbandoned = 'scholarship_match_abandoned';
  static const scholarshipMatchCompleted = 'scholarship_match_completed';
  static const scholarshipMatchFailed = 'scholarship_match_failed';
  static const scholarshipMatchResultOpened = 'scholarship_match_result_opened';
  static const scholarshipMatchFollow = 'scholarship_match_follow';
  static const scholarshipMatchCaseStarted = 'scholarship_match_case_started';
  static const scholarshipMatchBroadenTapped =
      'scholarship_match_broaden_tapped';
  static const scholarshipMatchRerun = 'scholarship_match_rerun';
  static const scholarshipMatchAlertsToggled =
      'scholarship_match_alerts_toggled';

  /// Les treize, pour les gardes (noms ≤ 40 caractères, contrat publié).
  static const scholarshipMatchEvents = <String>[
    scholarshipMatchEntryViewed,
    scholarshipMatchStarted,
    scholarshipMatchStepViewed,
    scholarshipMatchStepCompleted,
    scholarshipMatchAbandoned,
    scholarshipMatchCompleted,
    scholarshipMatchFailed,
    scholarshipMatchResultOpened,
    scholarshipMatchFollow,
    scholarshipMatchCaseStarted,
    scholarshipMatchBroadenTapped,
    scholarshipMatchRerun,
    scholarshipMatchAlertsToggled,
  ];

  /// Communauté d'entraide (C1 + C2) : portée, fils, discussions ouvertes,
  /// publications, réponses, réactions, signalements, blocages. Propriétés
  /// FERMÉES (types, compteurs, drapeaux 0/1, identifiants d'écran) : JAMAIS
  /// le texte d'une publication, d'une réponse ou d'une recherche, ni un nom,
  /// un pays ou un identifiant de membre.
  static const communityViewed = 'community_viewed';
  static const communityFeedViewed = 'community_feed_viewed';
  static const communitySearched = 'community_searched';
  static const communityPostOpened = 'community_post_opened';
  static const communityComposerOpened = 'community_composer_opened';
  static const communityPostCreated = 'community_post_created';
  static const communityPostFailed = 'community_post_failed';
  static const communityReplyCreated = 'community_reply_created';
  static const communityHelpfulToggled = 'community_helpful_toggled';
  static const communityFollowToggled = 'community_follow_toggled';
  static const communityReportSent = 'community_report_sent';
  static const communityBlockToggled = 'community_block_toggled';
  static const communityCharterAccepted = 'community_charter_accepted';
  static const communityEntitySectionViewed = 'community_entity_section_viewed';

  /// Les quatorze, pour les gardes (noms ≤ 40 caractères, contrat publié).
  static const communityEvents = <String>[
    communityViewed,
    communityFeedViewed,
    communitySearched,
    communityPostOpened,
    communityComposerOpened,
    communityPostCreated,
    communityPostFailed,
    communityReplyCreated,
    communityHelpfulToggled,
    communityFollowToggled,
    communityReportSent,
    communityBlockToggled,
    communityCharterAccepted,
    communityEntitySectionViewed,
  ];

  /// Sync / catalog observability (paired with [AnalyticsService] helpers).
  static const syncFullComplete = 'sync_full_complete';
  static const syncConflictResolved = 'sync_conflict_resolved';
  static const syncCatalogHiveFallback = 'sync_catalog_hive_fallback';
}

/// Standard parameter keys for custom events (snake_case).
abstract final class AnalyticsParamKey {
  static const totalQuestions = 'total_questions';
  static const matchCount = 'match_count';
  static const itemId = 'item_id';
  static const itemType = 'item_type';
  static const count = 'count';
  static const ids = 'ids';
  static const caseType = 'case_type';
  static const caseId = 'case_id';
  static const theme = 'theme';

  /// WhatsApp hand-off attribution.
  static const source = 'source';
  static const contextType = 'context_type';

  static const success = 'success';
  static const elapsedMs = 'elapsed_ms';
  static const catalogHiveFallbackCount = 'catalog_hive_fallback_count';

  /// `sync_full_complete` en échec : l'étape (`account`/`catalog`) et la
  /// nature de la panne (`timeout`, `connection`, `http_5xx`…), valeurs fermées.
  static const failureStage = 'failure_stage';
  static const errorKind = 'error_kind';

  static const domain = 'domain';
  static const resolution = 'resolution';

  static const resource = 'resource';
  static const attempts = 'attempts';

  /// "Mon plan" progress (KPB-164).
  static const percent = 'percent';
  static const nextStep = 'next_step';

  /// Shared result cards (KPB-165).
  static const withImage = 'with_image';

  /// Parcours stories (KPB-169). `item_type` is 'video' | 'text'; `source`
  /// tells apart the feed, the library list and the Home card, so a completion
  /// rate can be read per surface.
  static const slug = 'slug';

  /// Espace « Études en France ». `field_count` plutôt que la liste des
  /// filières : un compte suffit à segmenter, et n'expose pas le détail du
  /// profil d'un mineur dans une charge analytique.
  /// `reason` n'est pas redéclaré ici : la clé existe déjà plus bas, pour
  /// l'attribution d'échec d'authentification. Les échecs de déclaration
  /// d'intérêt la réutilisent — une seconde constante de même valeur aurait été
  /// un doublon de compilation, et deux noms pour une même clé de tableau de
  /// bord.
  static const currentLevel = 'current_level';
  static const fieldCount = 'field_count';
  static const wantsPremium = 'wants_premium';

  /// Catalogue de l'espace : des COMPTES et des drapeaux, jamais le texte tapé.
  static const tile = 'tile';
  static const hasQuery = 'has_query';
  static const filterCount = 'filter_count';
  static const resultCount = 'result_count';
  static const catalogPublished = 'catalog_published';

  /// Carte d'aide de l'espace : l'emplacement (`hub`, `procedure`,
  /// `catalog_empty`…), l'écran porteur (`hub` ou `catalog`) et la forme
  /// (`card` ou `compact`). Des identifiants fermés, jamais un texte saisi.
  /// `help_step` et non `step` : cette dernière est un entier (1-based) pour
  /// l'onboarding, et on ne mélange pas deux types sous une même clé de
  /// tableau de bord.
  static const helpStep = 'help_step';

  /// Par quelle porte la feuille des écoles privées a été ouverte : `bubble` ou
  /// `catalog_empty`. Un identifiant fermé, jamais un texte saisi.
  static const entry = 'entry';

  /// La visite guidée du hub : ce qui l'a ouverte (`first_open`, `replay`), la
  /// façon dont elle s'est fermée (`finished`, `skipped`), et le nombre de
  /// cartes atteintes (un entier). Des identifiants fermés, jamais un texte.
  static const tourTrigger = 'tour_trigger';
  static const tourExit = 'tour_exit';
  static const tourCardsSeen = 'tour_cards_seen';
  static const surface = 'surface';
  static const variant = 'variant';

  /// Onboarding funnel + auth attribution (KPB-158).
  static const step = 'step';
  static const stepCount = 'step_count';
  static const accountType = 'account_type';
  static const method = 'method';
  static const reason = 'reason';

  /// Coach IA : d'où vient la question et comment le tour s'est terminé.
  static const result = 'result';
  static const quotaRemaining = 'quota_remaining';

  /// `push_opened` : le `kind` de la charge push (identifiant fermé).
  static const kind = 'kind';

  /// Test « Mes 10 bourses » : des comptes, des rangs, des drapeaux 0/1 et
  /// des identifiants fermés. `step` y est le NOM de l'étape (`birth_date`…),
  /// pas un entier : la clé `match_step` évite de mélanger les deux types sous
  /// la clé `step` de l'onboarding.
  static const matchStep = 'match_step';
  static const index = 'index';
  static const total = 'total';
  static const missingCount = 'missing_count';
  static const isRerun = 'is_rerun';
  static const changedPrefill = 'changed_prefill';
  static const lastStep = 'last_step';
  static const eligibleCount = 'eligible_count';
  static const toVerifyCount = 'to_verify_count';
  static const excludedCount = 'excluded_count';
  static const durationS = 'duration_s';
  static const algorithmVersion = 'algorithm_version';
  static const rank = 'rank';
  static const status = 'status';
  static const bulk = 'bulk';
  static const reusedExisting = 'reused_existing';
  static const suggestion = 'suggestion';
  static const enabled = 'enabled';

  /// Communauté : des types, des comptes et des drapeaux 0/1. `post_type`
  /// (`question`/`experience`/`advice`), `tab` (`for_you`/`recent`/
  /// `unanswered`), `target` (`post`/`reply`/`member`), `entity_type`
  /// (`scholarship`/`country`/`institution`/`program`).
  static const tab = 'tab';
  static const postType = 'post_type';
  static const hasHashtag = 'has_hashtag';
  static const isHashtag = 'is_hashtag';
  static const hasVerified = 'has_verified';
  static const hasPrefill = 'has_prefill';
  static const mentionCount = 'mention_count';
  static const hashtagCount = 'hashtag_count';
  static const pendingReview = 'pending_review';
  static const target = 'target';
  static const entityType = 'entity_type';
  static const discussionCount = 'discussion_count';
  static const isEdit = 'is_edit';

  /// `view_item` : la famille du contenu consulté (`scholarship`, `program`,
  /// `country`, `institution`). Clé GA4 standard, distincte d'`item_type`.
  static const itemCategory = 'item_category';
}
