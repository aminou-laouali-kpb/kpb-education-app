// Textes français de l’application.
// Clés partagées avec l'autre langue : toute clé ajoutée ici doit l'être aussi
// dans l'autre fichier (vérifié par les tests de parité).
const Map<String, String> appTranslationsFr = {
  'app_title': 'KPB Education',
  'app_tagline':
      'Orientation, études à l’étranger et accompagnement pour les étudiants africains.',
  'student': 'Étudiant',
  'parent': 'Parent',
  'partner': 'Partenaire',
  'continue': 'Continuer',
  'create_account': 'Démarrer',
  'full_name': 'Nom complet',
  'email': 'Email',
  'phone': 'Téléphone',
  'whatsapp': 'WhatsApp',
  'country': 'Pays',
  'current_level': 'Niveau actuel',
  'target_level': 'Niveau visé',
  'language_level': 'Niveau d\'anglais',
  'grade_range': 'Moyenne académique sur les 3 dernières années',
  'monthly_budget': 'Budget mensuel (par mois)',
  'tuition_budget_annual': 'Budget annuel pour les frais de scolarité',
  'preferred_currency': 'Devise d\'affichage',
  'currency_eur': 'Euro (€)',
  'currency_xof': 'Franc CFA (FCFA)',
  'currency_usd': "Dollar américain (\$)",
  'scholarship_interest': 'Recherche d\'écoles privées',
  'onboarding_newsletter_consent':
      'Recevoir les nouvelles bourses d\'études disponibles',
  'available_documents': 'Documents disponibles',
  'preferred_language': 'Langue préférée',
  'app_language': 'Langue de l\'application',
  // ── Guest gating for dossiers ──────────────────────────
  'guest_case_gate_title': 'Connecte-toi pour créer un dossier',
  'guest_case_gate_body':
      'Un compte est nécessaire pour qu\'un conseiller KPB puisse traiter ta demande et te répondre.',
  'guest_case_gate_cta': 'Se connecter',
  // Mur invité des outils IA. Sans lui, le clic d'un visiteur sur
  // « Générateur de CV » ne produisait rien du tout.
  'guest_ai_tool_gate_title': 'Connecte-toi pour utiliser les outils IA',
  'guest_ai_tool_gate_body':
      'Le générateur de CV, les lettres de motivation et le simulateur d\'entretien travaillent à partir de ton profil. Un compte est nécessaire pour les personnaliser.',
  'guest_ai_tool_gate_cta': 'Créer mon compte',
  // Authentifié mais sans profil en cache : synchronisation inaboutie.
  // Ni un invité, ni un refus de consentement.
  'profile_sync_pending_title': 'Profil pas encore synchronisé',
  'profile_sync_pending_body':
      'Tes informations n\'ont pas encore été récupérées. Vérifie ta connexion et réessaie dans un instant.',
  // ── Mur invité de l'onglet Bourses (PARC-04) ──
  // L'index des bourses exige une session côté serveur. L'écran
  // affichait « problème de connexion » et un bouton « Réessayer »
  // qui ne pouvait jamais aboutir : on nomme la vraie cause, et on
  // donne l'action qui la lève.
  'scholarships_auth_required_title': 'Crée ton compte pour voir les bourses',
  'scholarships_auth_required_body':
      'Les bourses sont vérifiées par KPB. Il faut un compte pour les voir et les suivre. C\'est gratuit et ça prend deux minutes.',
  'scholarships_auth_required_cta': 'Créer mon compte',
  'guest_cases_title': 'Tes dossiers en un seul endroit',
  'guest_cases_body':
      'Connecte-toi pour créer tes demandes et suivre leur progression avec un conseiller KPB.',
  // ── Outils KPB (drawer hamburger) ──────────────────────
  'tools_drawer_title': 'Outils KPB',
  'tools_drawer_subtitle': 'Tout pour préparer ta candidature',
  'tools_cv': 'CV',
  'tools_motivation_letter': 'Lettre de motivation',
  'tools_interview': 'Simulateur d\'entretien',
  'tools_doc_scanner': 'Scanner de documents',
  'tools_budget': 'Calculateur de budget',
  'tools_flight': 'Estimateur de vol',
  'tools_housing': 'Estimateur de logement',
  'tools_doc_review': 'Relecture IA',
  'tools_impact': 'Tableau d\'impact',
  // ── Batch C2: screen i18n (buttons + titles) ───────────
  'cancel': 'Annuler',
  'retry': 'Réessayer',
  'logout': 'Se déconnecter',
  'logout_confirm_title': 'Se déconnecter ?',
  'save_changes': 'Enregistrer',
  'compare': 'Comparer',
  'levels': 'Niveaux',
  'fees_per_year': 'Frais / an',
  'profile_edit': 'Modifier',
  // Photo de profil. Un message par cause : « vérifiez votre connexion »
  // est réservé au VRAI échec réseau. Distinction essentielle entre
  // `infected` (la photo est en cause) et `scan_unavailable` (notre
  // antivirus est en fail-closed — l'utilisateur n'y est pour rien).
  'profile_avatar_sheet_title': 'Photo de profil',
  'profile_avatar_take_photo': 'Prendre une photo',
  'profile_avatar_choose_photo': 'Choisir dans la galerie',
  'profile_avatar_remove': 'Retirer la photo',
  'profile_avatar_remove_confirm_title': 'Retirer ta photo ?',
  'profile_avatar_remove_confirm_body':
      'Tes initiales seront affichées à la place. Tu pourras ajouter une nouvelle photo à tout moment.',
  'profile_avatar_updated': 'Ta photo de profil a été mise à jour.',
  'profile_avatar_removed': 'Ta photo de profil a été retirée.',
  'profile_avatar_a11y_label': 'Modifier la photo de profil',
  'profile_avatar_error_too_large':
      'Cette image est trop lourde. Choisis une photo plus légère.',
  'profile_avatar_error_unsupported_type':
      'Ce format n\'est pas accepté. Utilise une photo JPEG, PNG ou WebP.',
  'profile_avatar_error_unreadable':
      'Cette image n\'a pas pu être lue. Choisis une autre photo.',
  'profile_avatar_error_infected':
      'Cette image a été refusée par notre analyse antivirus. Choisis une autre photo — réessayer avec la même ne fonctionnera pas.',
  'profile_avatar_error_scan_unavailable':
      'Notre analyse antivirus est momentanément indisponible, donc rien n\'a été enregistré. Ta photo n\'est pas en cause : réessaie dans quelques minutes.',
  'profile_avatar_error_service_unavailable':
      'Notre service d\'images est momentanément indisponible. Ta photo n\'est pas en cause : réessaie dans quelques minutes.',
  'profile_avatar_error_conflict':
      'Une autre modification de ta photo a été enregistrée avant celle-ci. Réessaie.',
  'profile_avatar_error_profile_missing':
      'Ton profil n\'a pas été retrouvé sur le serveur. Reconnecte-toi, puis réessaie.',
  'profile_avatar_error_unauthorized':
      'Ta session a expiré. Reconnecte-toi, puis réessaie.',
  'profile_avatar_error_rate_limited':
      'Trop de tentatives. Attends une minute avant de réessayer.',
  'profile_avatar_error_permission_denied':
      'KPB Education n\'a pas accès à ton appareil photo ou à tes photos. Autorise-le dans les réglages de ton téléphone.',
  'profile_avatar_error_network':
      'Impossible de joindre le serveur. Vérifie ta connexion, puis réessaie.',
  'profile_avatar_error_server':
      'Le serveur a rencontré une erreur. Réessaie plus tard.',
  'profile_avatar_error_unknown':
      'L\'envoi de la photo a échoué pour une raison inattendue. Réessaie ; si cela continue, contacte un conseiller KPB.',
  'profile_edit_title': 'Modifier le profil',
  'profile_security': 'Sécurité',
  'profile_biometric': 'Verrouillage biométrique',
  'profile_data_saver': 'Mode données réduites',
  'profile_academic_info': 'Informations académiques',
  'profile_contact': 'Contact',
  'profile_quick_access': 'Accès rapide',
  'profile_legal_info': 'Informations légales',
  'profile_my_journey': 'Mon parcours',
  'profile_target_countries': 'Pays visés',
  'profile_fields_of_interest': 'Filières qui t\'intéressent',
  'profile_completed': 'Profil complété',
  'profile_complete_cta': 'Compléter mon profil',
  'see_schools': 'Voir les écoles',
  'my_application_journey': 'Mon parcours de candidature',
  'explore_my_results': 'Explorer mes résultats',
  'start_a_case': 'Démarrer un dossier',
  'retake_test': 'Refaire le test',
  'get_support': 'Être accompagné',
  'explore_title': 'Explorer',
  'apply_with_kpb': 'Candidater avec KPB',
  'talk_to_expert': 'Parler à un expert',
  'country_not_found': 'Pays introuvable',
  'program_not_found': 'Programme introuvable',
  'take_eligibility_quiz': 'Faire le quiz d\'éligibilité',
  'chat_on_whatsapp': 'Discuter sur WhatsApp',
  'eligibility_quiz_short': 'Quiz éligibilité',
  'enroll_with_kpb': 'M\'inscrire avec KPB',
  'alternative_destinations': 'Destinations alternatives',
  'back_to_country': 'Retour à la fiche pays',
  'student_tools_title': 'Outils étudiants',
  'updated_on': 'Mis à jour @date',
  // ── Signal de confiance : badge vérifié + fraîcheur ────
  'verified_on': 'Vérifié le @date',
  'verified_semantics': 'Information vérifiée le @date',
  'reverify_label': 'À revérifier',
  'reverify_semantics': 'Information à revérifier — vérifiée le @date',
  'to_confirm_label': 'À confirmer',
  'to_confirm_semantics': 'Information à confirmer, non vérifiée',
  'offline_mode': 'Mode hors-ligne',
  // --- flight search (Kayak) ---
  'flight_search_prices': 'Trouver les meilleurs prix',
  'flight_same_airports': 'Le départ et l\'arrivée doivent être différents.',
  'flight_searching': 'Recherche des meilleurs prix…',
  'flight_results_title': 'Meilleurs prix trouvés',
  'flight_visa_advice':
      'N\'achète ton billet qu\'après l\'obtention du visa — ou choisis un tarif remboursable.',
  'flight_cached_note': 'Prix vus récemment',
  'flight_cheapest_badge': 'Le moins cher',
  'flight_direct': 'Direct',
  'flight_stops_one': '1 escale',
  'flight_stops_many': '@count escales',
  'flight_book_on_kayak': 'Réserver sur Kayak',
  'flight_calendar_title': 'Prix par jour ce mois-ci',
  'flight_calendar_predicted': 'estimé',
  'flight_no_results':
      'Aucun prix trouvé pour cette recherche. Essayez d\'autres dates.',
  'flight_prices_unavailable':
      'La recherche en direct est momentanément indisponible. Ouvrez Kayak pour comparer.',
  'flight_picker_search_hint': 'Ville, aéroport ou pays',
  'flight_picker_no_match': 'Aucun aéroport ne correspond.',
  'flight_field_return_date': 'Date de retour',
  'flight_trip_one_way': 'Aller simple',
  'flight_trip_round_trip': 'Aller-retour',
  'flight_round_trip_hint': 'aller-retour',
  'flight_round_trip_label': 'Aller-retour',
  'a11y_back': 'Retour',
  'a11y_close': 'Fermer',
  'a11y_save': 'Enregistrer',
  'a11y_refresh': 'Actualiser',
  'a11y_share': 'Partager',
  'a11y_download': 'Télécharger',
  'a11y_clear_search': 'Effacer la recherche',
  'a11y_send_message': 'Envoyer le message',
  'a11y_remove': 'Retirer',
  'a11y_rate': 'Noter',
  'a11y_whatsapp_advisor': 'Contacter le conseiller sur WhatsApp',
  'parent_case_view_title': 'Dossier (lecture)',
  // --- KPB-89 wave2 ---
  'api_client_session_expired_title': 'Session Expirée',
  'api_client_session_expired_message': 'Ta session a expiré. Reconnecte-toi.',
  'coach_suggestion_budget_schools':
      'Quelles écoles pour un budget de 10 000€ ?',
  'coach_suggestion_top_business_schools': 'Top écoles de commerce en France',
  'coach_suggestion_tech_programs': 'Formations Tech (EPITA, Epitech...)',
  'file_size_bytes': '@size o',
  'file_size_kb': '@size Ko',
  'file_size_mb': '@size Mo',
  'security_biometric_reason':
      'Déverrouille pour accéder à tes documents sécurisés KPB',
  'error_state_default_title': 'Connexion impossible',
  'error_state_default_subtitle': 'Vérifie ta connexion internet et réessaie.',
  'scholarship_status_badge_open': 'Ouvert',
  'scholarship_status_badge_closing_soon': 'Bientôt clôturé',
  'scholarship_status_badge_closed': 'Clôturé',
  'academy_course_expert_badge': 'COURS EXPERT',
  'academy_sessions_count_single': '@count session',
  'academy_sessions_count_plural': '@count sessions',
  'academy_course_program_title': 'Programme de la formation',
  'academy_benefit_senior_advisor_tips': 'Astuces de conseillers senior KPB',
  'academy_continue_course_cta': 'Continuer la formation',
  'academy_buy_pack_cta': 'Acheter le pack',
  'academy_finalize_purchase_title': 'Finaliser l\'achat',
  'academy_confirm_pay_cta': 'Confirmer et payer',
  'academy_purchase_success_title': 'Félicitations !',
  'academy_purchase_success_body':
      'Formation débloquée. Tu peux maintenant suivre les cours.',
  'academy_player_no_session': 'Aucune session disponible',
  'academy_player_session_progress': 'Session @current sur @total',
  'budget_calculator_title': 'Simulateur de coût',
  'budget_lifestyle_econome': 'Économe',
  'budget_lifestyle_standard': 'Standard',
  'budget_lifestyle_confort': 'Confort',
  'budget_category_rent': 'Loyer',
  'budget_category_utilities': 'Charges & énergie',
  'budget_category_food': 'Alimentation',
  'budget_category_transport': 'Transport',
  'budget_category_health': 'Santé & assurance',
  'budget_category_phone_internet': 'Forfait & Internet',
  'budget_category_supplies': 'Fournitures & livres',
  'budget_category_clothing_hygiene': 'Vêtements & hygiène',
  'budget_category_leisure': 'Loisirs & divers',
  'budget_note_fr_rent': 'Hors capitale, coloc ou studio modeste',
  'budget_note_uk_health': 'IHS surcharge lissé sur l\'année',
  'budget_note_de_health': 'Assurance santé étudiante obligatoire',
  'budget_note_cn_rent': 'Résidence universitaire ou coloc hors centre-ville',
  'budget_note_cn_health': 'Assurance étudiante obligatoire ~600-800 CNY/an',
  'case_reference_provisional': '⏳ provisoire',
  'case_contact_inapp': 'Dans l\'application',
  'commercial_response_time_minutes': '@count min',
  'commercial_response_time_hours': '@count h',
  'commercial_response_time_days': '@count j',
  'housing_auto_search_soon':
      'La recherche de logement automatisée pour le @country arrive très bientôt. Nos conseillers peuvent t\'aider dans tes dossiers.',
  'housing_studapart_open_error': 'Impossible d\'ouvrir Studapart.',
  'housing_find_your_nest': 'Trouve ton cocon',
  'housing_studapart_partnership_title': 'Partenariat Studapart',
  'housing_studapart_partnership_desc':
      'Loue ton logement en France facilement, avec ou sans garant local.',
  'parent_load_error': 'Impossible de charger. Vérifie ta connexion.',
  'parent_child_default': 'votre enfant',
  'parent_readonly_chip': 'Lecture seule',
  'parent_create_cta': 'Générer un code d\'invitation',
  'parent_share_cta': 'Partager sur WhatsApp',
  'parent_link_refresh': 'J\'ai partagé — actualiser',
  'parent_code_share_note':
      'Partagez ce code avec votre enfant. Il l\'entre dans son app (Profil → Suivi parental) pour lier vos comptes.',
  'parent_invite_share_msg':
      'Bonjour, voici mon code parent KPB : @code. Ajoute-le dans ton app KPB (Profil → Suivi parental) pour me partager ton parcours.',
  'parent_waiting_title': '@child n\'a pas encore partagé de dossier',
  'parent_waiting_body':
      'Dès que votre enfant partage un dossier depuis son app, son avancement apparaîtra ici.',
  'parent_nextstep_label': 'PROCHAINE ÉTAPE',
  'parent_docs_managed_note':
      'Lecture seule — les documents sont gérés par votre enfant et son conseiller.',
  'parent_financing_body':
      'Vous pouvez envoyer une preuve de financement (relevé, attestation) à votre conseiller KPB.',
  'parent_no_updates':
      'Les actualités partagées par le conseiller apparaîtront ici.',
  'parent_appbar': 'Espace parent',
  'parent_linked_ok': 'Compte lié ✓',
  'parent_link_error': 'Code invalide ou expiré. Réessayez.',
  'parent_greeting_generic': 'Bonjour',
  'parent_hello': 'Bonjour, @name',
  'parent_linked_readonly': 'Compte parent — lié à @child (lecture seule)',
  'parent_advisor_title': 'Parler au conseiller KPB',
  'parent_advisor_sub': 'WhatsApp · réponse sous 24 h',
  'parent_privacy_note':
      'C\'est votre enfant qui contrôle ce que vous voyez, champ par champ, depuis son app. L\'avancement du dossier et les échéances restent toujours visibles.',
  'parent_case_title': 'Dossier partagé',
  'parent_docs_locked_title': 'Documents non partagés',
  'parent_docs_locked_body':
      '@child n\'a pas encore partagé de dossier avec vous.',
  'parent_financing_label': 'Financement',
  'parent_fin_upload': 'Envoyer une preuve de financement',
  'parent_updates_title': 'Actualités',
  'parent_updates_sub': 'Avancement partagé par le conseiller',
  'parent_msg_locked_title': 'Messages non partagés',
  'parent_msg_locked_body':
      'Les messages privés entre votre enfant et son conseiller ne sont pas partagés.',
  'parent_pay_title': 'Paiements',
  'parent_pay_sub': 'Payez pour votre enfant — via votre conseiller KPB',
  'parent_premium_title': 'Karatou Premium pour @child',
  'parent_premium_sub': 'Copilote illimité · lettres illimitées · live VIP',
  'parent_premium_item': 'Karatou Premium',
  'parent_premium_cta': 'Activer via le conseiller KPB',
  // --- App-engagement: Student Profil + honest Premium ---
  'profile_target_universities': 'Mes universités cibles',
  'profile_universities_see_all': 'Voir tout',
  'profile_universities_empty':
      'Aucune université enregistrée pour l\'instant.',
  'profile_explore_schools': 'Explorer les écoles',
  'profile_preferences': 'Préférences',
  'profile_replay_onboarding': 'Revoir le tutoriel de démarrage',
  'profile_replay_confirm_title': 'Revoir le tutoriel ?',
  'profile_replay_confirm_body':
      'Tu reverras l\'intro de démarrage. Tes informations de profil sont conservées.',
  'profile_replay_confirm_cta': 'Revoir',
  'profile_parent_access': 'Accès parent',
  'profile_parent_access_desc':
      'Relie un parent avec un code d\'invitation pour partager ta progression. Tu choisis ce qu\'il peut voir, dossier par dossier.',
  'profile_parent_access_cta': 'Relier un parent',
  'profile_premium_card_title': 'Karatou Premium',
  'profile_premium_card_sub': 'Bientôt — activez via un conseiller KPB',
  'premium_screen_title': 'Karatou Premium',
  'premium_badge_soon': 'Bientôt disponible',
  'premium_hero_title': 'Passez à Karatou Premium',
  'premium_hero_sub':
      'Premium arrive bientôt. En attendant, un conseiller KPB peut t\'accompagner — sans aucun paiement dans l\'application.',
  'premium_value_ai_coach':
      'KPB Intelligence illimité — l\'offre gratuite inclut @count messages par semaine.',
  'premium_value_advisors':
      'Accompagnement prioritaire par un conseiller KPB vérifié.',
  'premium_value_more_soon': 'De nouveaux avantages Premium arrivent bientôt.',
  'premium_compare_title': 'Gratuit vs Premium',
  'premium_compare_feature': 'Ce que tu obtiens',
  'premium_compare_free': 'Gratuit',
  'premium_compare_premium': 'Premium',
  'premium_row_ai_coach': 'Messages KPB Intelligence',
  'premium_free_ai_coach': '@count / sem.',
  'premium_unlimited_soon': 'Illimité (bientôt)',
  'premium_how_title': 'Comment activer Premium',
  'premium_how_body':
      'Aucun paiement dans l\'application. Premium arrive bientôt — un conseiller KPB te guidera pour l\'activer.',
  'premium_wa_prefill':
      'Bonjour KPB, je souhaite en savoir plus sur Karatou Premium.',
  'premium_no_payment_note': 'Karatou ne propose aucun paiement intégré.',
  // ── Ce qu'est le Pass, en une carte ──────────────────────────
  //
  // Décrit un service À VENIR, jamais un produit achetable ici : ni
  // prix, ni bouton d'achat, ni verbe « s'abonner ». Karatou n'encaisse
  // rien dans l'application (règle App Store 3.1.1), et le badge
  // « Bientôt disponible » de l'écran reste affiché au-dessus.
  'premium_pitch_title': 'Postuler de A à Z, accompagné',
  'premium_pitch_body':
      'Le Pass Karatou, c\'est ta candidature aux bourses prise en main du début à la fin : KPB Intelligence pour préparer, des conseillers KPB pour relire et valider.',
  'premium_pitch_point_shortlist':
      'Une sélection de bourses faite pour ton profil, pas une liste générique.',
  'premium_pitch_point_documents':
      'CV, lettres de motivation et réponses préparés avec KPB Intelligence.',
  'premium_pitch_point_review':
      'Une relecture humaine par un conseiller KPB avant l\'envoi.',
  'premium_pitch_point_deadlines':
      'Un suivi des échéances, pour ne pas rater une date.',
  // ── Liste d'attente ──────────────────────────────────────────
  //
  // ATTENTION : le texte de `premium_waitlist_notice` est ce que
  // `kPremiumWaitlistConsentVersion` DÉSIGNE. Le modifier sans
  // incrémenter la constante ferait pointer la preuve de consentement
  // vers un texte qui n'existe plus. Un test verrouille l'appariement.
  // C'est pourquoi `premium_waitlist_body` et `premium_waitlist_notice`
  // vouvoient encore (exceptions de `voice_tutoiement_guard_test.dart`) :
  // les tutoyer = une version v2, déployée d'abord côté backend.
  'premium_waitlist_title': 'Sois prévenu à l\'ouverture',
  'premium_waitlist_body':
      'Le Pass n\'est pas encore ouvert. Inscrivez-vous sur la liste d\'attente : nous vous préviendrons en premier.',
  'premium_waitlist_notice':
      'En vous inscrivant, vous acceptez que KPB vous contacte au sujet du Pass Karatou. C\'est gratuit et sans engagement, et vous pouvez vous retirer à tout moment.',
  'premium_waitlist_cta': 'M\'inscrire sur la liste d\'attente',
  'premium_waitlist_joined_title': 'Tu es sur la liste',
  'premium_waitlist_joined_body':
      'Inscrit le @date. Nous te préviendrons dès l\'ouverture du Pass.',
  'premium_waitlist_leave': 'Me retirer de la liste',
  'premium_waitlist_error_network':
      'Connexion impossible. Vérifie ton réseau et réessaie.',
  'premium_waitlist_error_unauthorized':
      'Ta session a expiré. Reconnecte-toi puis réessaie.',
  'premium_waitlist_error_server':
      'Inscription impossible pour l\'instant. Réessaie dans un moment.',
  'premium_waitlist_student_only':
      'La liste d\'attente est réservée aux comptes étudiants.',
  'guest_premium_waitlist_title': 'Crée ton compte',
  'guest_premium_waitlist_body':
      'La liste d\'attente sert à te prévenir à l\'ouverture du Pass. Sans compte, nous n\'aurions personne à prévenir.',
  'guest_premium_waitlist_cta': 'Créer mon compte',
  'parent_packs_label': 'Accompagnement KPB',
  'parent_pack_review': 'Relecture de dossier KPB',
  'parent_pack_review_desc':
      'Un conseiller vérifié relit tout le dossier avant dépôt',
  'parent_pack_full': 'Accompagnement complet',
  'parent_pack_full_desc':
      '3 sessions conseiller + suivi Campus France jusqu\'au dépôt',
  'parent_pay_cta': 'Réserver',
  'parent_pay_history_label': 'Historique',
  'parent_pay_history_empty': 'Vos reçus apparaîtront ici',
  'parent_pay_note':
      'Paiement organisé avec votre conseiller KPB sur WhatsApp — reçu par message. Aucun paiement à des « agents » hors du circuit KPB.',
  'parent_ask_access': 'Demander l\'accès',
  'parent_nav_overview': 'Vue d\'ensemble',
  'parent_nav_case': 'Dossier',
  'parent_nav_updates': 'Actualités',
  'parent_nav_pay': 'Paiements',
  'parent_onboarding_title': 'Suivez le parcours de votre enfant',
  'parent_onboarding_sub':
      'Générez un code d\'invitation et partagez-le avec votre enfant. Il l\'entre dans son app pour lier vos comptes.',
  'parent_invite_code_label': 'Code d\'invitation',
  'parent_onboarding_b1':
      'Toujours visible : avancement du dossier et échéances',
  'parent_onboarding_b2':
      'Contrôlé par votre enfant : documents, messages, finances',
  'parent_onboarding_b3': 'Contact direct avec le conseiller KPB sur WhatsApp',
  'parent_wa_advisor':
      'Bonjour, je suis le parent d\'un étudiant suivi par KPB. J\'aimerais échanger avec le conseiller.',
  'parent_wa_ask_access':
      'Bonjour, je souhaite demander l\'accès à une information du dossier de mon enfant.',
  'parent_wa_upload':
      'Bonjour, je voudrais envoyer une preuve de financement pour le dossier de mon enfant.',
  'parent_wa_pay':
      'Bonjour, je souhaite régler « @item » pour mon enfant via KPB.',
  'parent_invite_create_error': 'Impossible de créer l\'invitation.',
  'parent_invite_code_title': 'Code d\'invitation',
  'parent_code_copied': 'Code copié.',
  'parent_invite_whatsapp_message':
      'Rejoins-moi sur KPB Education avec ce code: @code',
  'parent_code_length_error': 'Le code fait 8 caractères.',
  'parent_link_activated': 'Liaison activée.',
  'parent_invite_child_title': 'Invite ton enfant',
  'parent_link_account_title': 'Lier un compte parent',
  'parent_no_shared_cases': 'Ton enfant n\'a pas encore partagé de dossier.',
  'partners_strip_trust_title': 'Ils nous font confiance',
  'recommandations_title_sc': 'Bourses recommandées',
  'recommandations_desc_sc': 'Une sélection de bourses adaptées à ton profil.',
  'service_packages_load_error':
      'Impossible de charger la liste. Vérifie ta connexion.',
  'service_packages_title': 'Services KPB',
  'service_packages_empty': 'Aucun service disponible pour le moment.',
  'service_packages_category_dossier_pret': 'Dossier prêt',
  'service_packages_category_scholarship_kit': 'Kit bourse',
  'service_packages_category_visa_kit': 'Kit visa',
  'service_packages_category_default': 'Service',
  'flight_picker_select_origin': 'Sélectionner le départ',
  'flight_picker_select_destination': 'Sélectionner l\'arrivée',
  'flight_launch_failed': 'Impossible d\'ouvrir le comparateur de vols.',
  'flight_estimator_appbar_title': 'Simulateur de Vols',
  'flight_field_departure': 'Départ',
  'flight_field_arrival': 'Arrivée',
  'flight_field_choose': 'Choisir',
  'flight_field_date': 'Date',
  'flight_view_on_kayak': 'Voir les vols sur Kayak',
  'flight_hero_select': 'Sélectionner',
  'm6_level_bachelor': 'Bachelor',
  'm6_level_master': 'Master',
  'm6_level_mba': 'MBA / DBA',
  'm6_level_doctorate': 'Doctorat',
  'm6_level_other': 'Autre',
  'm6_language_fr': 'Français',
  'm6_language_en': 'Anglais',
  'm6_language_de': 'Allemand',
  'm6_language_es': 'Espagnol',
  'm6_language_tr': 'Turc',
  'm6_language_ar': 'Arabe',
  // --- KPB-89 lock-in ---
  'sync_data_stale_offline': 'Données potentiellement obsolètes — hors ligne',
  'coach_requires_connection':
      'KPB Intelligence nécessite une connexion au serveur KPB. ',
  'academy_hd_videos': 'Vidéos pas-à-pas en HD',
  'academy_letter_templates': 'Modèles de lettres de motivation',
  'housing_view_offers_in': 'Voir les offres à @city',
  'parent_no_children_linked': 'Aucun enfant lié pour le moment.',
  'lang_name_french': '🇫🇷 Français',
  'lang_name_english': '🇬🇧 English',
  // --- KPB-89 batch4b interp ---
  'time_ago_minutes': 'il y a @n min',
  'time_ago_hours': 'il y a @n h',
  'time_ago_days': 'il y a @n j',
  'time_ago_weeks': 'il y a @n sem.',
  'time_ago_months': 'il y a @n mois',
  'time_ago_just_now': 'à l\'instant',
  'lead_motive_prefix': 'Motif : @motive',
  'saved_count_one': '@count élément sauvegardé',
  'saved_count_other': '@count éléments sauvegardés',
  'salon_session_host': 'Avec @host',
  'orientation_question_number_badge': 'Question @n',
  'orientation_matched_programs_subtitle_field':
      'Des programmes liés à @field.',
  'deadlines_missing_document': 'Document manquant · @code',
  'deadlines_status_days': '@n jours',
  'compare_program_count': '@n programmes',
  'compare_open_case_for': 'Dossier @name',
  'compare_subtitle': 'Touche une colonne pour changer d\'université',
  'compare_pick': 'CHOISIR',
  'compare_picker_title': 'Choisir une université',
  'compare_search_hint': 'Rechercher une université…',
  'compare_picker_empty': 'Aucune université ne correspond à ta recherche.',
  'compare_verdict_higher_match': '@name correspond mieux à ton profil.',
  'compare_verdict_partner': '@name est un partenaire vérifié KPB.',
  'compare_verdict_more_programs':
      '@name propose plus de programmes (@hi contre @lo).',
  'compare_share_line': '🏛 @name — @fit\n',
  'compare_share_line_plain': '🏛 @name\n',
  'compare_share_tuition': '   Frais : @tuition\n',
  'compare_share_language': '   Langue : @lang\n\n',
  'community_empty_articles_for_tag': 'Aucun article pour #@tag',
  'alumni_programme_label': 'Programme : @programme',
  'alumni_country_label': 'Pays : @country',
  'coach_welcome_message':
      'Bonjour @name ! Je suis KPB Intelligence. 🤖\n\nPose-moi tes questions sur les écoles, le budget ou les filières partenaires.',
  'coach_quota_reached_body':
      'Tu as atteint la limite de @quota messages cette semaine. Reviens la semaine prochaine ou contacte un conseiller humain.',
  'coach_online_status': 'En ligne • @rem/@total restants cette semaine',
  'ai_report_action': 'Signaler',
  'ai_report_title': 'Signaler cette réponse IA',
  'ai_report_body':
      'Choisis un motif. La réponse et ta note seront transmises de façon sécurisée à l’équipe KPB pour examen.',
  'ai_report_reason_label': 'Pourquoi la signales-tu ?',
  'ai_report_reason_inaccurate': 'Inexacte ou trompeuse',
  'ai_report_reason_unsafe': 'Dangereuse ou nuisible',
  'ai_report_reason_offensive': 'Offensante ou biaisée',
  'ai_report_reason_privacy': 'Problème de confidentialité',
  'ai_report_reason_other': 'Autre',
  'ai_report_note_label': 'Détails facultatifs',
  'ai_report_note_hint': 'Explique ce qui pose problème…',
  'ai_report_submit': 'Envoyer le signalement',
  'ai_report_submitting': 'Envoi…',
  'ai_report_submit_error':
      'Le signalement n’a pas été enregistré. Vérifie ta connexion et réessaie.',
  'ai_report_success_title': 'Signalement envoyé',
  'ai_report_success_body':
      'L’équipe KPB examinera le dossier @code. Merci de nous avoir prévenus.',
  // --- KPB-89 batch ---
  'commercial_my_profile': 'Mon profil',
  'commercial_refresh_stats': 'Actualiser les stats',
  'commercial_default_name': 'Commercial',
  'commercial_performance_30_days': 'Mes performances — 30 derniers jours',
  'commercial_total_leads': 'Total leads',
  'commercial_converted': 'Convertis',
  'commercial_first_response': '1ère réponse',
  'commercial_conversion_rate': 'Taux de conversion',
  'loading_error_title': 'Erreur de chargement',
  'lead_tag_qualified': 'Qualifié',
  'lead_tag_not_qualified': 'Non qualifié',
  'lead_tag_awaiting_payment': 'En attente paiement',
  'lead_tag_converted': 'Converti',
  'lead_tag_lost': 'Perdu',
  'lead_tag_to_follow_up': 'À relancer',
  'refresh': 'Actualiser',
  'leads_filter_all': 'Tous',
  'leads_filter_new': 'Nouveaux',
  'leads_filter_today': "Aujourd'hui",
  'leads_filter_qualified': 'Qualifiés',
  'lead_tag_none': 'Sans tag',
  'lead_change_status': 'Changer le statut',
  'error': 'Erreur',
  'lead_status_update_failed': 'Impossible de mettre à jour le statut.',
  'lead_status_sheet_title': 'Statut du lead',
  'saved_none_yet': 'Aucun élément sauvegardé',
  'saved_empty_title': 'Rien de sauvegardé',
  'saved_empty_subtitle':
      'Explorez des filières, pays, universités et programmes, puis sauvegardez-les pour les retrouver ici.',
  'saved_group_fields': 'Filières',
  'saved_group_countries': 'Pays',
  'saved_group_institutions': 'Universités',
  'saved_partner_badge': 'Partenaire',
  'saved_group_programs': 'Programmes',
  'salon_load_error': 'Impossible de charger le Salon. Vérifie ta connexion.',
  'salon_title': 'Salon KPB Virtuel',
  'salon_unavailable_title': 'Salon indisponible',
  'salon_no_edition_title': 'Pas d\'édition programmée',
  'salon_no_edition_subtitle':
      'Reviens bientôt — la prochaine édition sera annoncée dans les notifications.',
  'salon_live_now': 'En direct',
  'salon_view_sessions': 'Voir les sessions',
  'salon_program_load_error': 'Impossible de charger le programme.',
  'salon_fallback_title': 'Salon KPB',
  'salon_program_unavailable_title': 'Programme indisponible',
  'salon_program_upcoming_title': 'Programme à venir',
  'salon_program_upcoming_subtitle':
      "Le programme n'est pas encore publié. Reviens bientôt.",
  'salon_session_live': 'Live',
  'salon_join': 'Rejoindre',
  'salon_registration_confirmed': 'Inscription confirmée',
  'salon_register': "M'inscrire",
  'parcours_appbar_title': 'Parcours KPB',
  'parcours_empty_soon_title': 'Bientôt disponible',
  'parcours_empty_soon_subtitle':
      'Les vidéos de parcours et témoignages arrivent très vite. Reviens bientôt !',
  'parcours_empty_error_title': 'Contenu indisponible',
  'parcours_empty_error_subtitle':
      'Impossible de charger les parcours pour le moment.',
  'parcours_intro_title': 'Ils l\'ont fait avant toi',
  'parcours_free_badge': 'GRATUIT',
  'parcours_convert_title': 'Tu veux suivre un parcours similaire ?',
  'parcours_convert_subtitle': 'Discute avec un conseiller KPB de ton projet.',
  'parcours_whatsapp_prefill':
      'Bonjour KPB, un parcours dans l\'app m\'a inspiré et j\'aimerais discuter de mon projet d\'études.',
  'parcours_search_hint': 'Rechercher un métier, une école, un nom…',
  'parcours_filter_all': 'Tous',
  'parcours_kind_written': 'Témoignage écrit',
  'parcours_empty_filter_title': 'Aucun résultat',
  'parcours_empty_filter_subtitle':
      'Essaie un autre thème ou une autre recherche.',
  'parcours_up_next': 'À suivre',
  'parcours_story_appbar': 'Témoignage',
  'parcours_video_unavailable':
      'Cette vidéo n\'est pas disponible pour le moment.',
  'orientation_roadmap_appbar_title': 'Mon parcours',
  'orientation_consultation_case_title': 'Séance de conseil KPB',
  'case_message_send_failed':
      'Ton message n\'a pas pu être envoyé. Vérifie-le puis réessaie.',
  'orientation_consultation_case_context': 'Accompagnement orientation',
  'orientation_roadmap_heading': 'Ton parcours de candidature',
  'orientation_roadmap_create_case_button': 'Créer mon dossier',
  'case_application_title': 'Dossier de candidature',
  'orientation_next_button': 'Continuer →',
  'orientation_see_results_button': 'Voir mes résultats',
  'orientation_matched_programs_title': 'Formations qui te correspondent',
  'orientation_matched_programs_subtitle_generic':
      'Des programmes liés à tes résultats.',
  'orientation_your_results_fallback': 'tes résultats',
  'orientation_case_context_label': 'Suite orientation',
  'orientation_results_congrats': 'Bravo ! 🎉',
  'orientation_best_match_label': 'MEILLEURE CORRESPONDANCE',
  'orientation_best_match_badge': '⭐ Meilleur match',
  'orientation_ai_resilient_badge': '🛡 Résilient à l\'IA',
  'orientation_why_it_fits_label': 'Pourquoi c\'est fait pour toi',
  'orientation_available_scholarships_label': 'Bourses disponibles',
  'orientation_ia_resilience_high': 'Métier d\'avenir · résistant à l\'IA',
  'orientation_ia_resilience_medium': 'Bonne résilience face à l\'IA',
  'orientation_ia_resilience_low': 'À faire évoluer face à l\'IA',
  'france_step_choose_school':
      'Choix de l\'école privée partenaire (OMNES, ICN, Schiller, IGENSIA…)',
  'france_step_build_dossier': 'Constitution du dossier d\'admission avec KPB',
  'france_step_interview_validation': 'Entretien / validation admission école',
  'france_step_student_visa': 'Visa long séjour étudiant',
  'france_step_housing_departure': 'Logement & préparation du départ',
  'france_step_arrival': 'Arrivée en France avec suivi KPB',
  'france_case_title': 'Procédure France — écoles privées',
  // La campagne (@intake) est CALCULÉE par IntakeCalendar, jamais
  // écrite en dur : ces chaînes vivaient dans le binaire et devenaient
  // fausses le 1er octobre, sans qu'aucune mise à jour de contenu
  // puisse les corriger. Un test statique interdit le retour du
  // littéral « septembre 20xx » dans ce fichier.
  'france_case_context_label': 'France · @intake',
  'privacy_s1_title': '1. Responsable du traitement',
  'privacy_s2_title': '2. Données collectées',
  'privacy_s3_title': '3. Finalités du traitement',
  'privacy_s4_title': '4. Base légale',
  'privacy_s5_title': '5. Partage des données',
  'privacy_s6_title': '6. Durée de conservation',
  'privacy_s7_title': '7. Sécurité',
  'privacy_s8_title': '8. Vos droits',
  'privacy_s9_title': '9. Analytique produit & enregistrement de session',
  'privacy_s10_title': '10. Modifications',
  'privacy_transfers_title': 'Transferts hors de votre pays',
  'last_updated_october_2026': 'Dernière mise à jour : octobre 2026',
  // L'éditeur. « KPB Education » est un SERVICE, pas une personne
  // morale : le responsable du traitement est KPB Global L.L.C-FZ, et
  // la politique doit le dire, sinon l'utilisateur consent au profit
  // d'une entité qu'il ne peut pas nommer — ni assigner.
  'privacy_s1_body':
      'KPB Education (ci-après "nous", "notre", "KPB") est un service de KPB Global L.L.C-FZ, société à responsabilité limitée de zone franche immatriculée auprès de la Meydan Free Zone (Meydan City Corporation, Émirat de Dubaï) sous la licence n° 2537631.01. KPB Global L.L.C-FZ est le responsable du traitement des données personnelles collectées via l\'application mobile KPB Education.\n\n'
          'Siège social : Meydan Grandstand, 6th floor, Meydan Road, Nad Al Sheba, Dubaï, Émirats arabes unis\n'
          'Contact : contact@kpbeducation.com\n'
          'Site : https://kpbeducation.cloud\n\n'
          'Le traitement relève du décret-loi fédéral n° 45 de 2021 des Émirats arabes unis sur la protection des données personnelles. Vous pouvez adresser une réclamation au UAE Data Office. Si la loi de votre pays de résidence vous ouvre un recours devant une autorité locale de protection des données, ce recours reste entier.',
  'privacy_s2_body': 'Nous collectons les données suivantes :\n\n'
      '• Identité : nom complet, adresse e-mail, numéro de téléphone, WhatsApp\n'
      '• Date de naissance (étudiants) ; nom et contact du tuteur si vous avez moins de 18 ans\n'
      '• Photo de profil, si vous en ajoutez une (caméra ou photothèque)\n'
      '• Profil académique : niveau d\'études, niveau cible, compétences linguistiques, notes, filières d\'intérêt, pays de destination\n'
      // Chantier D/H : les réponses du test vivent sur le profil (écrites par
      // POST /scholarships/match/runs seulement). Le test est derrière
      // `features.scholarshipMatch`, fermé tant que la collecte de la
      // nationalité n'est pas validée (docs/data-inventory.md).
      '• Test « Mes 10 bourses », si vous le passez (fonction ouverte progressivement) : nationalité(s), pays de résidence, date de naissance, plus haut diplôme, niveau de bourse visé, domaines, tranche de moyenne sur 20, niveaux d\'anglais et de français, scores de tests de langue, tranche d\'expérience professionnelle et, si vous avez 16 ou 17 ans, l\'accord de votre représentant légal. Rien ne vous oblige à répondre : sans ces réponses, le test ne calcule pas de résultat, et le reste de l\'app reste utilisable\n'
      '• Bourses suivies et notifications : les bourses que vous suivez, vos réglages d\'alerte, les notifications reçues dans l\'app et le moment où vous en ouvrez une\n'
      // Rédigé le 18/10/2026 — à relire par le propriétaire avant soumission.
      '• Communauté, suggestions automatiques, parrainage et compétition : voir les sections dédiées plus bas\n'
      '• Messages de dossier et textes soumis au coach (KPB Intelligence)\n'
      // Le repli réseau est NOMMÉ parce qu'il subsiste dans le code.
      // `SpeechInputService.startListening` demande bien la
      // reconnaissance locale (`onDevice: true`), et sur iPhone c'est un
      // contrat dur : sans reconnaissance locale la session est refusée,
      // rien ne part. Sur Android ce n'est qu'une préférence
      // (`EXTRA_PREFER_OFFLINE`) : le greffon retombe SILENCIEUSEMENT
      // sur le reconnaisseur réseau quand le modèle local manque, et ce
      // repli n'est visible depuis aucune API Dart. Écrire « converti en
      // texte sur l'appareil » sans réserve serait donc faux sur une
      // partie des Android — précisément le public de l'app.
      '• Dictée vocale : le micro capte votre voix, l\'app demande à votre téléphone de la convertir en texte sur l\'appareil et n\'en garde que le texte ; l\'enregistrement audio ne nous est jamais transmis. Sur iPhone, si la reconnaissance locale est indisponible, la dictée ne démarre pas. Sur Android, la reconnaissance locale n\'est qu\'une préférence : sans modèle local installé, le service de reconnaissance de votre téléphone (Google) peut traiter votre voix hors de l\'appareil\n'
      '• Documents (passeport, relevés, pièces de dossier) : l\'envoi depuis l\'application est masqué. Ces pièces passent par WhatsApp vers votre conseiller, pas par un téléversement in-app\n'
      '• Données d\'utilisation : résultats d\'orientation, éléments sauvegardés, historique de recherche\n'
      '• Données techniques : jeton de notifications de l\'appareil, version et numéro de build de l\'app utilisée, biométrie locale (verrouillage), localisation déclarée dans la configuration iOS mais jamais demandée ni utilisée\n'
      '• Analytique : Firebase Analytics et PostHog ; enregistrements de session PostHog (textes et images masqués)\n'
      '• Diagnostics : Firebase Crashlytics ; métriques agrégées de synchronisation',
  'privacy_s3_body': 'Vos données sont utilisées pour :\n\n'
      '• Personnaliser vos recommandations de filières, pays et bourses\n'
      '• Gérer vos dossiers de candidature et vos rendez-vous\n'
      '• Vous envoyer des notifications pertinentes (mises à jour de dossier, deadlines, ouverture et dates limites des bourses que vous suivez ; nouvelles bourses compatibles avec votre test seulement si vous l\'activez)\n'
      '• Pour le test « Mes 10 bourses » : comparer vos réponses aux conditions officielles des bourses (nationalité, âge, niveau, notes, langues, expérience) et vous montrer jusqu\'à 10 bourses compatibles ou à vérifier. Le résultat est indicatif : aucune décision n\'est prise à votre place, et seul l\'organisme de la bourse décide de votre candidature\n'
      '• Vous envoyer par email les nouvelles bourses d\'études disponibles, uniquement si vous y avez consenti (case à cocher — désinscription possible à tout moment depuis votre profil ou le lien de désinscription des emails)\n'
      // Correctifs 57 (XC-06), 19/10/2026 — à relire par le propriétaire
      // avant soumission. Uniquement ce que le code fait (campaign-purpose.ts).
      // Chantier juridique 57 : push promotionnel en opt-in (App Store
      // 4.5.4), à relire par le propriétaire avant soumission.
      '• Vous envoyer des nouvelles et des offres de KPB Education, uniquement si vous l\'avez accepté, canal par canal : par e-mail (Profil → « Nouvelles et offres de KPB par e-mail ») et par notification (réglages des notifications → « Nouvelles et offres de KPB par notification »). Les deux choix sont distincts et désactivés par défaut ; pour un mineur de 16 ou 17 ans, il faut en plus l\'accord déclaré de son représentant légal. Chaque e-mail contient un lien de désinscription en un clic, et vous pouvez retirer chacun de ces accords à tout moment depuis l\'app\n'
      '• Améliorer nos services via des statistiques agrégées et anonymisées\n'
      '• Communiquer avec vous dans le cadre de vos démarches\n'
      '• Vous rappeler au sujet d\'un espace ou d\'un accompagnement pour lequel vous avez déclaré votre intérêt, si vous l\'avez accepté au moment de le déclarer. Cette déclaration est lisible par nos conseillers et notre équipe commerciale, et vous pouvez la retirer à tout moment depuis l\'écran où vous l\'avez faite',
  'privacy_s4_body':
      // Chantier juridique 57, 19/10/2026 — à relire par le propriétaire
      // avant soumission. Uniquement ce que le code fait.
      '• Exécution du service : le traitement est nécessaire pour vous fournir l\'application et ses services (compte, profil, recommandations, dossiers, notifications liées à votre compte et à vos dossiers)\n'
          '• Consentement, pour les traitements que vous acceptez explicitement dans l\'application et que vous pouvez refuser : la newsletter bourses ; les nouvelles et offres de KPB, par e-mail et par notification (deux choix distincts, désactivés par défaut) ; KPB Intelligence (fenêtre « Activer KPB Intelligence », que vous pouvez refuser) ; le rappel au sujet d\'un espace ou d\'un accompagnement pour lequel vous avez déclaré votre intérêt\n'
          // Rédigé le 18/10/2026 — à relire par le propriétaire avant soumission.
          '• Consentement explicite : votre nationalité, pour le test « Mes 10 bourses » (voir « Votre nationalité »)\n'
          '• Intérêt légitime, avec votre droit de vous y opposer : l\'analytique produit et les enregistrements de session, actifs par défaut et désactivables à tout moment depuis Profil → « Analyse d\'usage » (voir section 9) ; la sécurité de la plateforme\n'
          '• Intérêt légitime : prévention de la fraude au parrainage et à la compétition (empreintes anti-fraude, identifiant d\'installation)\n'
          '• Obligation légale : conservation comptable de la trace des prix versés\n'
          '• Mineurs de 16 et 17 ans : l\'accord déclaré d\'un représentant légal (nom et contact) est demandé avant de compléter le profil, d\'utiliser KPB Intelligence ou de passer le test « Mes 10 bourses ». L\'application n\'est pas destinée aux moins de 16 ans',
  'privacy_s5_body': 'Vos données ne sont PAS vendues à des tiers.\n\n'
      'Elles peuvent être partagées avec :\n'
      '• Notre backend KPB (VPS Hostinger, api.kpbeducation.cloud) pour faire fonctionner l\'application\n'
      '• Supabase (authentification : e-mail, session, Google)\n'
      '• OpenRouter et Groq (États-Unis) : textes du coach et profil pseudonymisé — le routage OpenRouter est limité à des services d\'IA sans conservation des données ; jamais vendus\n'
      // Les notifications passent par Firebase Cloud Messaging en direct
      // (`PushService`) : Google ne reçoit que le jeton de l'appareil, et
      // c'est NOTRE backend qui sait à quel compte il appartient. Le ciblage
      // (niveau, pays visé) se calcule sur le serveur — plus aucune étiquette
      // ne part chez un tiers.
      '• Firebase / Google (Analytics, Crashlytics, Cloud Messaging) pour l\'analytique, la stabilité et l\'acheminement des notifications — Cloud Messaging ne reçoit que le jeton de notifications de l\'appareil, aucun identifiant de compte ni donnée de profil\n'
      // OneSignal reste nommé tant que les versions qui l'embarquent sont
      // en circulation : le serveur leur envoie encore leurs notifications,
      // et leurs abonnements (avec les quatre étiquettes qu'elles envoyaient)
      // vivent chez OneSignal jusqu'au retrait.
      '• OneSignal (États-Unis) : uniquement pour les versions antérieures de l\'application, en cours de retrait — jeton de notifications, identifiant de compte et quatre étiquettes de ciblage (type de compte, niveau d\'études, pays visé, langue) ; jamais votre adresse e-mail\n'
      // Le lecteur intégré et les vignettes chargent des contenus
      // YouTube dès leur affichage — accueil compris, connexion ou pas.
      // Google reçoit alors l'adresse IP et des données techniques :
      // c'est un destinataire, il se nomme. Le test de parité l'exige
      // désormais (jeton « YouTube »).
      '• YouTube (Google) : les vidéos de témoignages et de bourses sont lues par le lecteur YouTube intégré (domaine youtube-nocookie.com) et leurs vignettes sont chargées depuis YouTube — dès leur affichage, Google reçoit votre adresse IP et des données techniques, même sans compte\n'
      '• Wikimedia Commons (Wikimedia Foundation, États-Unis) : les logos d\'établissements du catalogue Études en France sont chargés depuis Wikimedia — dès leur affichage, la fondation reçoit votre adresse IP et des données techniques, même sans compte\n'
      '• Le service de reconnaissance vocale de votre téléphone (Apple ou Google) : uniquement pour la dictée — l\'app demande d\'abord la reconnaissance locale, et ne sollicite ce service qu\'avec votre accord ; sur Android, le système peut aussi y recourir de lui-même quand le modèle local manque (voir « Dictée vocale », section 2)\n'
      '• PostHog (États-Unis) : analytique produit et enregistrements de session au contenu masqué\n'
      '• Resend (États-Unis) : e-mails transactionnels et campagnes\n'
      '• Mautic (outil d\'emailing auto-hébergé par KPB) pour la newsletter bourses, uniquement si vous y avez consenti\n'
      '• PayDunya et CinetPay : intentions de paiement si vous souscrivez un accompagnement payant\n'
      '• Nos conseillers internes pour le suivi de vos dossiers, et notre équipe commerciale pour les déclarations d\'intérêt que vous avez faites. Dès qu\'une demande de dossier est déposée, les coordonnées du compte (nom, e-mail, téléphone, WhatsApp et, le cas échéant, le contact du responsable légal) sont envoyées par e-mail aux commerciaux actifs\n'
      '• Votre nationalité, votre date de naissance et vos autres réponses au test « Mes 10 bourses » ne sont transmises à aucune école, à aucun organisme de bourse ni à notre équipe commerciale, et ne partent ni dans l\'analytique ni dans les notifications. Quand vous ouvrez un dossier depuis une bourse, votre conseiller voit la bourse concernée, pas vos réponses. Le test peut mettre à jour des champs de votre profil déjà utilisés ailleurs (pays de résidence, niveau d\'anglais, moyenne) : ils suivent alors les règles de cette section\n'
      '• Nos partenaires institutionnels (universités) uniquement avec votre accord explicite lors de la soumission d\'un dossier\n'
      '• Les autorités compétentes si la loi l\'exige',
  // Chantier juridique 57, 19/10/2026 — à relire par le propriétaire avant
  // soumission : le transfert ne repose plus sur « l'acceptation » de la
  // politique.
  'privacy_transfers_body':
      'Certains destinataires sont établis aux États-Unis (OpenRouter, Groq, PostHog, OneSignal, Resend, Firebase / Google — YouTube et les services de reconnaissance vocale compris — et Wikimedia). Ces transferts sont nécessaires pour vous fournir le service. Ils sont encadrés par les clauses contractuelles types du sous-traitant lorsqu\'elles existent et, pour l\'IA et l\'analytique, par les choix que vous faites dans l\'application : vous pouvez refuser l\'analytique depuis Profil → « Analyse d\'usage » et refuser KPB Intelligence, le reste de l\'app reste utilisable.',
  // Sections ajoutées le 18/10/2026 (communauté, bots, parrainage et
  // compétition, nationalité) — décisions du propriétaire du 18/10/2026.
  // Rédigé le 18/10/2026 — à relire par le propriétaire avant soumission.
  // Uniquement ce que le code fait (docs/data-inventory.md §5 à §7 ter).
  'privacy_community_title':
      'Communauté d\'entraide (fonction ouverte progressivement)',
  'privacy_community_body': 'Si vous utilisez la communauté :\n'
      '\n'
      '• Ce que vous publiez : vos publications et vos réponses (titre, texte, bourses, pays, établissements ou formations cités, mots-clés) sont visibles des autres élèves connectés, avec un nom affiché sous la forme « Prénom I. », le pays de résidence de votre profil et vos badges. Votre nom complet, votre e-mail et votre téléphone ne sont pas affichés\n'
      '• Pas de messages privés : la communauté n\'a ni messagerie entre membres, ni mention d\'un autre membre\n'
      '• Vérification avant publication : un texte qui contient un numéro, une adresse e-mail, un lien WhatsApp, un lien externe, une demande d\'argent ou un terme interdit n\'est pas publié tout de suite ; il attend la revue de l\'équipe KPB et reste visible de vous seul. Cette vérification se fait sur nos serveurs, sans service externe\n'
      '• Signalements et blocages : vous pouvez signaler une publication, une réponse ou un membre (motif, et précision facultative de 500 caractères au plus). Seule l\'équipe KPB voit les signalements, jamais la personne signalée. Un contenu signalé par plusieurs membres peut être masqué en attendant la revue. Vous pouvez aussi bloquer un membre : vous ne voyez plus ses contenus, et il ne voit plus les vôtres\n'
      '• Modération : l\'équipe KPB peut masquer ou supprimer un contenu, marquer une réponse comme vérifiée et prendre une sanction (avertissement, lecture seule, exclusion), dont le motif vous est notifié. Chaque décision est enregistrée dans un journal de modération\n'
      '• Notifications : réponses à vos publications et décisions de modération ; vous pouvez couper les notifications push de la communauté dans les réglages des notifications\n'
      '• Conservation : vos contenus restent tant que votre compte existe. Un contenu supprimé, par vous ou par l\'équipe, reste lisible par l\'équipe KPB pendant 30 jours pour la modération, puis est effacé définitivement\n'
      '• Suppression de votre compte : vos publications, réponses, « utile », suivis et blocages sont supprimés définitivement (ils ne sont pas anonymisés), ainsi que les réponses publiées sous vos publications. Les signalements que vous avez rédigés sont conservés sans lien avec votre compte pendant 12 mois après sa suppression, puis effacés, et le journal de modération perd tout lien avec votre compte',
  // Chantier juridique 57 : 12 mois (COMMUNITY_ORPHAN_REPORT_RETENTION_DAYS,
  // purge quotidienne) — à relire par le propriétaire avant soumission.
  'privacy_bots_title':
      'Réponses et suggestions automatiques (fonctions ouvertes progressivement)',
  'privacy_bots_body':
      '• Assistant KPB : une question publiée dans la communauté peut recevoir une réponse signée « Assistant KPB », préparée automatiquement à partir des données vérifiées de notre catalogue (bourses, établissements, formations, pays). Elle est relue et publiée par l\'équipe KPB ; quand l\'équipe l\'a activé, une réponse dont toutes les données sont vérifiées et récentes peut être publiée automatiquement. Cette préparation ne recopie ni votre question, ni votre nom, ni votre profil, et votre question n\'est envoyée à aucun service externe\n'
          '• Suggestions de l\'équipe KPB : vos publications et réponses dans la communauté sont analysées automatiquement, sur nos serveurs, pour repérer un besoin (trouver une bourse, préparer un visa, choisir une école…) et vous suggérer en privé, par une notification, la fonction de l\'app ou la ligne WhatsApp de KPB qui peut vous aider. Aucun texte n\'est stocké par cette analyse : seuls le besoin repéré, la règle utilisée, la référence de la publication concernée et les dates d\'envoi et de réaction sont enregistrés, pendant 12 mois. Une suggestion n\'est jamais publique et ne cite pas votre texte\n'
          '• Vous pouvez couper ces suggestions à tout moment dans les réglages des notifications (« Suggestions de l\'équipe KPB ») : aucune suggestion ne vous est alors envoyée',
  'privacy_referral_title': 'Parrainage et compétition des ambassadeurs',
  'privacy_referral_body': '• Code de parrain : le code que vous saisissez n\'est envoyé à nos serveurs que lorsque vous appuyez sur « Valider le code », pour vous rattacher à ce parrain (une seule fois)\n'
      '• Lien d\'invitation (Android, fonction ouverte progressivement) : si vous avez installé l\'app depuis un lien d\'invitation Google Play, l\'app lit une fois, sur votre téléphone, l\'information de provenance que Google Play lui fournit (lien d\'origine, dates du clic et de l\'installation) et n\'en garde que le code du parrain, pour préremplir le champ. Rien n\'est transmis tant que vous ne confirmez pas ce code\n'
      '• Identifiant d\'installation : au premier rattachement demandé, l\'app crée un identifiant aléatoire propre à cette installation (ni l\'IMEI, ni l\'identifiant publicitaire). Il est envoyé uniquement avec un code de parrain, pour la prévention de la fraude ; nos serveurs n\'en gardent qu\'une empreinte chiffrée. Il change à chaque réinstallation\n'
      '• Empreintes anti-fraude : lors d\'un rattachement, nos serveurs calculent des empreintes chiffrées (HMAC) de votre adresse IP, de sa plage, de vos jetons de notifications et de l\'identifiant d\'installation — jamais conservés en clair — pour repérer les comptes multiples et les inscriptions en rafale. Elles sont conservées 180 jours, puis effacées\n'
      '• Compétition des ambassadeurs : organisée par KPB Global L.L.C-FZ, réservée aux ambassadeurs inscrits par l\'équipe KPB, selon un règlement publié. Le classement public affiche, pour les ambassadeurs classés, un nom sous la forme « Prénom I. — Ville » et le nombre de filleuls qualifiés, jamais l\'e-mail, le téléphone ni le nom des filleuls. Un ambassadeur de 16 ou 17 ans n\'est classé, et ne reçoit de prix, qu\'avec une autorisation parentale signée et vérifiée par l\'équipe : sans cette autorisation vérifiée, son nom public n\'apparaît pas au classement public ; son prix est versé à son représentant légal. L\'équipe voit l\'identité et l\'e-mail des ambassadeurs et de leurs filleuls, le statut de chaque filleul et les versements\n'
      '• Suppression de votre compte : votre participation, vos rattachements et vos empreintes sont supprimés ; seule la trace d\'un prix déjà versé (rang, nom public, montant, versement) est gardée pour la comptabilité, sans lien avec votre compte\n'
      '• Apple et Google ne sont ni organisateurs ni partenaires de cette compétition',
  'privacy_nationality_title': 'Votre nationalité (test « Mes 10 bourses »)',
  'privacy_nationality_body':
      '• Base légale : votre consentement explicite. Vous donnez votre nationalité seulement si vous passez le test, et elle n\'est envoyée qu\'après que vous avez coché « J\'accepte que KPB Education utilise ma nationalité pour vérifier les conditions des bourses »\n'
          '• Facultative : sans elle, le test ne calcule pas de résultat, et le reste de l\'app reste utilisable\n'
          '• Usage : uniquement vérifier les conditions de nationalité des bourses. Elle n\'est transmise à aucune école, à aucun organisme de bourse ni à notre équipe commerciale, et ne part ni dans l\'analytique ni dans les notifications\n'
          '• Conservation : sur votre profil tant que votre compte existe ; elle est supprimée avec votre compte\n'
          // Correctifs 57, 19/10/2026 — à relire par le propriétaire.
          '• Retrait : vous pouvez retirer votre consentement à tout moment avec le bouton « Effacer ma nationalité » de l\'espace « Mes 10 bourses » : votre nationalité est effacée de votre profil, ainsi que les résultats du test calculés avec elle. Vous pouvez aussi écrire à privacy@kpbeducation.com',
  'privacy_s6_body': '• Données de profil : conservées tant que votre compte est actif\n'
      '• Données de dossier : conservées tant que le dossier est ouvert, puis supprimées avec le compte\n'
      '• Réponses au test « Mes 10 bourses » : gardées sur votre profil tant que votre compte est actif, et modifiables en refaisant le test ; seuls vos 5 derniers résultats sont conservés, les plus anciens s\'effacent automatiquement\n'
      '• Bourses suivies et notifications reçues dans l\'app : conservées tant que votre compte est actif\n'
      '• Sur votre téléphone : le brouillon du test s\'efface à la fin du test et à la déconnexion ; les bourses gardées pour une consultation hors ligne s\'effacent à la déconnexion\n'
      // Rédigé le 18/10/2026 — à relire par le propriétaire avant soumission.
      '• Communauté : un contenu supprimé reste 30 jours lisible par l\'équipe pour la modération, puis il est effacé\n'
      '• Suggestions automatiques : les enregistrements sont gardés 12 mois\n'
      '• Empreintes anti-fraude du parrainage : 180 jours\n'
      // Chantier juridique 57, 19/10/2026 — à relire par le propriétaire
      // avant soumission. Durée de rétention des outils d'analytique : À
      // VALIDER (propriétaire), docs/data-inventory.md.
      '• Signalements rédigés dans la communauté par un compte depuis supprimé : 12 mois après la suppression du compte, puis effacés\n'
      '• Statistiques agrégées et anonymisées : sans limite de durée\n'
      '• Enregistrements de session PostHog : 30 jours, puis supprimés\n'
      '• Événements Firebase Analytics et PostHog liés à un identifiant pseudonyme : conservés pendant la durée de rétention de l\'outil, puis supprimés\n'
      '• En cas de suppression de compte : vos données personnelles sont supprimées sous 30 jours',
  'privacy_s7_body': '• Communication chiffrée via HTTPS/TLS\n'
      '• Mots de passe hachés (bcrypt)\n'
      '• Tokens d\'authentification sécurisés (JWT)\n'
      '• Données sensibles (tokens) stockées dans le Keychain (iOS) / Keystore (Android)\n'
      '• Accès restreint aux données de production',
  'privacy_s8_body':
      'Conformément au décret-loi fédéral n° 45 de 2021 des Émirats arabes unis, au RGPD lorsqu\'il s\'applique et aux lois de votre pays de résidence, vous avez le droit :\n\n'
          '• D\'accéder à vos données personnelles\n'
          '• De rectifier vos données\n'
          '• De supprimer votre compte et vos données\n'
          '• De limiter le traitement\n'
          '• De vous opposer au traitement\n'
          '• De portabilité de vos données\n\n'
          // Rédigé le 18/10/2026 — à relire par le propriétaire avant soumission.
          'L\'export de vos données comprend vos réponses au test « Mes 10 bourses », vos derniers résultats, vos alertes de bourses, les notifications reçues dans l\'app, vos contenus de la communauté, les suggestions automatiques qui vous concernent et vos données de parrainage et de compétition.\n\n'
          'Pour exercer ces droits, contactez-nous à : privacy@kpbeducation.com',
  'privacy_s9_body': 'Nous utilisons Firebase Analytics (Google) et PostHog pour comprendre l\'usage de l\'application et l\'améliorer :\n\n'
      '• Écrans consultés, actions effectuées (orientation, recherche, sauvegarde)\n'
      '• PostHog enregistre également des sessions (captures d\'écran de votre navigation) ; les textes et les images sont masqués automatiquement, donc aucun document, note ou coordonnée n\'est visible dans l\'enregistrement\n'
      '• Aucune donnée personnelle identifiable n\'est transmise à des fins publicitaires ; il n\'y a aucun SDK publicitaire ni suivi inter-applications\n'
      '• Cette mesure est ACTIVE PAR DÉFAUT : elle fait partie du fonctionnement normal du service et sert uniquement à l\'améliorer (voir les CGU, « Mesure d\'audience »)\n'
      '• Vous pouvez la désactiver à tout moment, ainsi que les enregistrements, depuis Profil → « Analyse d\'usage » : la collecte s\'arrête immédiatement, et votre refus est conservé — il n\'est jamais réactivé par une mise à jour',
  'privacy_s10_body':
      // Chantier juridique 57, 19/10/2026 — à relire par le propriétaire
      // avant soumission.
      'Cette politique peut être mise à jour. Avant qu\'une modification importante (par exemple un nouveau traitement de vos données) s\'applique, nous vous en informons dans l\'application, par une notification.\n\n'
          'Un traitement qui repose sur votre consentement n\'est jamais activé par une simple mise à jour de cette politique : il vous est demandé dans l\'application.',
  'terms_s10_body':
      'Les présentes CGU sont régies par le droit des Émirats arabes unis et par la réglementation de la Meydan Free Zone (Émirat de Dubaï), lieu d\'établissement de KPB Global L.L.C-FZ, éditeur de KPB Education.\n\n'
          'En cas de litige, les parties s\'engagent à chercher une résolution amiable ; à défaut d\'accord, les tribunaux compétents de Dubaï le trancheront.\n\n'
          'Si la loi de votre pays de résidence vous accorde des protections impératives en tant que consommateur, celles-ci vous restent acquises.',
  'terms_s11_body': 'Pour toute question relative aux présentes CGU :\n\n'
      'Éditeur : KPB Global L.L.C-FZ (licence Meydan Free Zone n° 2537631.01)\n'
      'Adresse : Meydan Grandstand, 6th floor, Meydan Road, Nad Al Sheba, Dubaï, Émirats arabes unis\n'
      'Email : contact@kpbeducation.com\n'
      'Site web : https://kpbeducation.cloud',
  'onboarding_under_16_title': 'Âge minimum : 16 ans',
  'onboarding_under_16_body':
      'Les CGU exigent 16 ans révolus pour créer un compte. La date indiquée correspond à moins de 16 ans.',
  'terms_of_use_2': 'Conditions d\'Utilisation',
  'terms_s1_title': '1. Objet',
  'terms_s2_title': '2. Acceptation',
  'terms_s3_title': '3. Inscription',
  'terms_s4_title': '4. Services proposés',
  // Les CLÉS `terms_s5..s11` gardent leur numéro d'origine alors que
  // leur numéro AFFICHÉ a glissé d'un cran : `terms_analytics_*`
  // s'intercale en 5. Les gardes légales (legal_identity_test) lisent
  // `terms_s10_body` / `terms_s11_body` par clé — renommer les clés
  // pour recoller les numéros les aurait cassées sans rien gagner.
  'terms_analytics_title': '5. Mesure d\'audience',
  'terms_s5_title': '6. Services payants',
  'terms_s6_title': '7. Obligations de l\'utilisateur',
  'terms_s7_title': '8. Propriété intellectuelle',
  'terms_s8_title': '9. Limitation de responsabilité',
  'terms_s9_title': '10. Résiliation',
  'terms_s10_title': '11. Droit applicable',
  'terms_s11_title': '12. Contact',
  // Rédigé le 18/10/2026 — à relire par le propriétaire avant soumission.
  // La charte reprend les quatre règles de
  // backend/src/modules/community/community.constants.ts.
  'terms_community_title': 'Communauté d\'entraide',
  'terms_community_body': 'La communauté (fonction ouverte progressivement) permet aux élèves de poser des questions et de partager leur expérience. Avant votre première publication, vous acceptez sa charte, en quatre règles :\n'
      '\n'
      '• Bienveillance : pas d\'insulte, pas de moquerie, pas de harcèlement\n'
      '• Jamais d\'argent : personne ne vend de bourse ni de visa ; ne payez jamais un « agent » rencontré dans la communauté, et signalez toute demande d\'argent\n'
      '• Pas de coordonnées : ni numéro, ni WhatsApp, ni e-mail, ni adresse, les vôtres comme celles des autres\n'
      '• Des informations vérifiables : partagez votre expérience et citez les sources officielles\n'
      '\n'
      'Sont interdits notamment : les contenus qui enfreignent ces règles ou la loi, les offres payantes, les demandes d\'argent et les liens externes non autorisés. Un texte qui contient des coordonnées, un lien externe, une demande d\'argent ou un terme interdit attend la revue de l\'équipe KPB avant d\'être publié.\n'
      '\n'
      'Modération : l\'équipe KPB modère la communauté. Elle peut masquer ou supprimer un contenu et, selon la gravité, adresser un avertissement, limiter un compte à la lecture ou l\'exclure de la communauté, pour une durée limitée ou non. Le motif vous est notifié.\n'
      '\n'
      'Signalement : chaque contenu et chaque membre peut être signalé depuis l\'application ; la personne signalée ne sait pas qui l\'a signalée. Vous pouvez aussi bloquer un membre.\n'
      '\n'
      'La communauté n\'a pas de messages privés. Les réponses des membres sont des avis personnels : elles ne remplacent ni les sources officielles ni un conseiller KPB.',
  'terms_competition_title': 'Compétition des ambassadeurs',
  'terms_competition_body':
      'La compétition des ambassadeurs est organisée par KPB Global L.L.C-FZ et réservée aux ambassadeurs inscrits par l\'équipe KPB. Elle est régie par son règlement, accessible depuis l\'écran « Compétition » de l\'application et la page publique du classement ; y participer implique de l\'accepter. En cas de différence, le règlement prévaut pour la compétition.\n'
          '\n'
          'Apple et Google ne sont ni organisateurs ni partenaires de cette compétition.',
  'terms_analytics_body':
      'Pour maintenir et améliorer le service, KPB Education mesure l\'usage de l\'application. Cette mesure est ACTIVE PAR DÉFAUT dès la première ouverture.\n\n'
          'Ce qui est mesuré : les écrans consultés et les actions effectuées (orientation, recherche, sauvegarde, candidature), les diagnostics de plantage, et des enregistrements de session dont les textes et les images sont masqués automatiquement — aucun document, note ou coordonnée n\'y est lisible.\n\n'
          'Ce qui n\'est PAS fait : aucune revente de données, aucun SDK publicitaire, aucun suivi inter-applications, aucun profilage publicitaire.\n\n'
          'Vous gardez la main : Profil → « Analyse d\'usage » coupe la mesure et les enregistrements immédiatement. Votre refus est conservé et n\'est jamais réactivé par une mise à jour de l\'application. Refuser n\'enlève aucune fonctionnalité.\n\n'
          'Le détail des destinataires et des durées de conservation figure dans la Politique de confidentialité, section « Analyse d\'usage ».',
  'deadlines_date_to_confirm': 'Date à confirmer',
  'deadlines_filter_all': 'Toutes',
  'deadlines_filter_saved': 'Bourses suivies',
  'deadlines_filter_cases': 'Dossiers',
  'deadlines_filter_upcoming': 'À venir',
  'deadlines_empty_title': 'Aucune échéance',
  'deadlines_empty_subtitle':
      'Sauvegarde une bourse ou ouvre un dossier pour construire ton tracker.',
  'deadlines_stat_within_30_days': '≤ 30 jours',
  'deadlines_badge_tracked': 'Suivi',
  'deadlines_kind_scholarship': 'Bourse',
  'deadlines_kind_roadmap': 'Roadmap',
  'deadlines_kind_case': 'Dossier',
  'deadlines_kind_document': 'Document',
  'deadlines_status_past': 'Passée',
  'deadlines_status_today_tomorrow': 'Aujourd’hui / demain',
  'compare_title': 'Comparer',
  'compare_row_match': 'Match profil',
  'compare_row_location': 'Localisation',
  'compare_row_tuition': 'Frais',
  'compare_row_language': 'Langue',
  'compare_row_levels': 'Niveaux',
  'compare_row_intakes': 'Inscriptions',
  'compare_row_kpb_partner': 'Partenaire KPB',
  'compare_need_help_choosing': 'Besoin d\'aide au choix ?',
  'compare_help_choosing_university': 'Aide au choix d\'université',
  'compare_share_header': 'Comparaison d\'universités avec KPB Education :\n\n',
  'compare_share_footer':
      'Découvre KPB Education pour ton orientation universitaire.',
  'compare_yes': 'Oui',
  'compare_no': 'Non',
  'community_search_tooltip': 'Rechercher',
  'community_hero_title': 'Apprendre ensemble 🌍',
  'community_articles_section': 'Articles',
  'community_empty_articles_title': 'Aucun article',
  'community_articles_coming_soon': 'Les articles arrivent bientôt.',
  'community_see_all_articles': 'Voir tous les articles',
  'community_forum_section': 'Forum',
  'community_join_whatsapp_group': 'Rejoindre le groupe WhatsApp',
  'whatsapp_open_failed':
      'Impossible d\'ouvrir WhatsApp. Vérifiez que l\'app est installée.',
  // ── Lien externe qui ne s'ouvre pas (PARC-15) ──
  // Le bouton « Formulaire officiel » ne faisait RIEN quand le lien
  // était irrécupérable : ni message, ni repli. Sur l'action même sans
  // laquelle l'étudiant rate la bourse.
  'external_link_failed_title': 'Impossible d\'ouvrir ce lien',
  'external_link_failed_body':
      'Ton téléphone n\'a pas pu ouvrir cette page. Un conseiller KPB peut t\'envoyer le lien directement.',
  'external_link_failed_cta': 'Demander le lien',
  'external_link_failed_prefill':
      'Bonjour KPB Education, je n\'arrive pas à ouvrir le formulaire officiel de « @title ». Pouvez-vous me l\'envoyer ?',
  'kpb_prefill_case':
      'Bonjour KPB Education, je reviens vers vous au sujet du dossier @ref.',
  'kpb_prefill_program':
      'Bonjour KPB Education, je suis intéressé(e) par le programme « @program » et j\'aimerais être accompagné(e).',
  'kpb_prefill_program_with_country':
      'Bonjour KPB Education, je suis intéressé(e) par le programme « @program » (@country) et j\'aimerais être accompagné(e).',
  // Variantes les plus spécifiques : elles portent l'école, donc le
  // conseiller sait de quoi on parle sans relancer. Libellés assertés
  // au caractère près dans whatsapp_utils_test.dart.
  'kpb_prefill_program_full':
      'Bonjour KPB Education, je viens de voir le programme « @program » (@institution, @country) et je suis intéressé(e).',
  'kpb_prefill_program_with_institution':
      'Bonjour KPB Education, je viens de voir le programme « @program » (@institution) et je suis intéressé(e).',
  'kpb_prefill_service':
      'Bonjour KPB Education, je souhaite en savoir plus sur le service « @service ».',
  'kpb_prefill_country':
      'Bonjour KPB Education, je souhaite être accompagné(e) pour mes études — destination : @country.',
  'kpb_prefill_generic':
      'Bonjour KPB Education, j\'aimerais être accompagné(e) dans mon projet d\'études.',
  'community_featured_badge': '📌 À la une',
  'community_safety_note':
      'Modération IA + signalements. Signale toute « offre de bourse » privée payante — c\'est une arnaque.',
  'match_card_eyebrow': 'MON MATCH ÉCOLE',
  'match_card_applying_via': '@name · candidature avec KPB Education',
  'match_card_student_fallback': 'Futur·e étudiant·e',
  'match_card_domain_tagline': 'trouve tes écoles',
  'match_card_share_whatsapp': 'Partager sur WhatsApp',
  'match_card_download': 'Télécharger',
  'match_card_whatsapp_prefill':
      '@school : @fit pour mon profil. Trouve les écoles qui te correspondent sur Karatou : @link',
  'match_card_share_error': 'Impossible de générer la carte. Réessaie.',
  'forum_no_articles_tagged':
      'Aucun article marqué pour l\'instant. Rejoins le groupe WhatsApp pour poser tes questions.',
  'forum_filter_by_topic': 'Filtrer par sujet',
  'forum_filter_all': 'Tous',
  'forum_related_articles': 'Articles liés',
  'forum_join_conversation_title': 'Rejoins la conversation',
  'forum_join_conversation_body':
      'Le forum in-app arrive bientôt. Rejoins WhatsApp pour discuter avec d\'autres étudiants et les conseillers KPB dès maintenant.',
  'forum_open_whatsapp_group': 'Ouvrir le groupe WhatsApp',
  'alumni_load_error':
      'Impossible de charger les mentors. Vérifie ta connexion.',
  'alumni_directory_title': 'Mentors KPB — Alumni',
  'alumni_search_hint': 'Rechercher par université…',
  'alumni_apply_submit_failed':
      "Impossible d'envoyer la candidature pour l'instant.",
  'alumni_apply_title': 'Devenir mentor alumni',
  'alumni_apply_university': 'Université / école',
  'form_required': 'Requis',
  'alumni_apply_programme': 'Programme / filière',
  'alumni_apply_year': "Année d'admission / diplôme",
  'alumni_apply_year_invalid': 'Année invalide',
  'alumni_apply_year_out_of_range': 'Année hors plage',
  'alumni_apply_country': "Pays de l'université (code ISO, ex. FR, CA)",
  'alumni_apply_proof_url': "Lien vers l'admission / le diplôme",
  'alumni_apply_proof_helper': "Google Drive, Dropbox, ou autre lien public",
  'alumni_apply_proof_required': 'Requis pour la vérification',
  'alumni_apply_bio': 'Bio courte (facultatif)',
  'alumni_apply_submit': 'Envoyer ma candidature',
  'alumni_status_pending': 'Ta candidature est en attente de vérification.',
  'alumni_status_approved':
      'Tu es vérifié comme alumni. Ton badge est visible.',
  'alumni_status_rejected':
      'Ta dernière candidature a été refusée. Tu peux la renvoyer.',
  'coach_quota_reached_title': 'Quota KPB Intelligence atteint',
  'coach_unavailable': 'KPB Intelligence indisponible.',
  'coach_unreachable': 'Impossible de joindre KPB Intelligence pour le moment.',
  'coach_ai_title': 'KPB Intelligence',
  'coach_input_hint': 'Pose ta question sur les écoles, les budgets...',
  // ── App-engagement handoff : outils coaching + post-décision ──
  'coach_status_tagline': 'Connaît ton profil · répond aussitôt',
  'coach_quota_info_title': 'Messages KPB Intelligence',
  'coach_quota_info_body':
      'Il te reste @rem message(s) sur @total cette semaine.',
  'coach_generate_letter': 'Générer une lettre',
  'letters_header_subtitle':
      'Choisis un modèle, personnalise-le avec l\'IA (FR + EN).',
  'letters_regenerate': 'Régénérer',
  'letters_export': 'Exporter',
  'interview_header_subtitle': 'Entraîne-toi avec un examinateur IA.',
  'interview_header_progress':
      'Question @current/@total · réponds comme face au jury',
  'interview_jury_label': 'JURY',
  'interview_score_line': 'Score : @score/100',
  'interview_complete_title': 'Entretien terminé !',
  'interview_verdict_strong': 'Excellent — tu es prêt(e) à convaincre le jury.',
  'interview_verdict_promising':
      'Bon départ — peaufine tes réponses et recommence.',
  'interview_verdict_practice':
      'Continue à t\'entraîner — chaque essai te rapproche du but.',
  'interview_replay': 'Rejouer',
  'interview_back_to_application': 'Retour au dossier',
  'post_decision_title': 'Réponse reçue',
  'post_decision_encouragement':
      'Ce n\'est pas la fin du parcours. Ton profil reste solide : avec quelques ajustements, une prochaine candidature peut aboutir.',
  'post_decision_plan_b_title': 'Ton plan B — déjà calculé',
  'post_decision_counselor_title': 'Session conseiller offerte',
  'post_decision_counselor_subtitle':
      '15 min avec un conseiller KPB pour préparer ta prochaine candidature.',
  'post_decision_whatsapp_prefill':
      'Bonjour KPB Education, ma candidature « @title » a été refusée. J\'aimerais être accompagné(e) pour un plan B.',
  'post_decision_entry_title': 'Réponse reçue — vois ton plan B',
  'post_decision_entry_subtitle':
      'Universités alternatives + session conseiller.',
  'notifications_title': 'Notifications',
  'notifications_mark_all_read': 'Tout marquer comme lu',
  'notifications_empty_title': 'Tu es à jour',
  'notifications_empty_body':
      'On te préviendra ici dès qu\'il y aura du nouveau sur tes candidatures et tes décisions.',
  'notif_action_needed_title': 'Action requise : @step',
  'notif_action_needed_fallback': 'Une étape attend ton action',
  'notif_decision_received_title': 'Réponse reçue',
  'notif_decision_received_body':
      'Une décision est arrivée pour « @title » — vois ton plan B.',
  'notifications_push_section': 'NOTIFICATIONS PUSH',
  'notifications_enable_push_title': 'Activer les notifications push',
  'notifications_enable_push_subtitle':
      'Reçois une alerte sur cet appareil pour tes candidatures et décisions.',
  'notifications_push_enable_action': 'Activer',
  'notifications_push_os_note':
      'La distribution des notifications est gérée par ton appareil. '
          'Tu peux les modifier à tout moment dans les réglages du téléphone.',
  'notifications_push_requested':
      'Si l\'invite s\'affiche, autorise les notifications pour rester informé(e).',
  'scanner_pages_scanned': '@count page(s) scannée(s)',
  'interview_question_progress': 'Question @current / @total',
  'search_no_results_title': 'Aucun résultat pour « @query »',
  'scholarship_boost_analysis_title': 'Analyse Boost : @name',
  'live_scholarships_result_count': '@count bourse(s) trouvée(s)',
  'eligibility_pdf_generated_on': 'Généré le @date',
  'eligibility_pdf_budget_per_month': '@budget € / mois',
  // --- KPB-89 batch ---
  // Les accents s'affichent correctement dans le PDF (Latin-1 ⊂ WinAnsi) :
  // l'orthographe prudente « Francais » n'avait pas lieu d'être.
  'cv_default_languages': 'Français, Anglais',
  // Réservé au VRAI échec réseau. Un 404/503 ne doit pas accuser la
  // connexion de l'utilisateur : voir les trois clés suivantes.
  'tools_ai_error_check_connection': 'Erreur IA — vérifie ta connexion',
  'tools_ai_error_unavailable':
      'Le service IA est momentanément indisponible. Réessaie dans un instant.',
  'tools_ai_error_slow':
      'La génération prend plus de temps que prévu. Réessaie dans un instant.',
  'tools_ai_error_rate_limited':
      'Trop de demandes d\'affilée. Réessaie dans une minute.',
  // Quota quotidien par utilisateur (AiQuotaGuard côté serveur).
  'tools_ai_error_daily_quota':
      'Tu as atteint la limite d\'utilisation de l\'IA pour aujourd\'hui. Réessaie demain.',
  'tools_ai_error_input_too_large':
      'Ton texte est trop long. Raccourcis-le puis réessaie.',
  'tools_ai_error_signin_required': 'Reconnecte-toi pour utiliser l\'IA.',
  // Le serveur refuse tant que la date de naissance manque : sans ce
  // message, l'étudiant lisait « reconnecte-toi » alors qu'il était
  // déjà connecté, et se déconnectait pour rien.
  'tools_ai_error_birthdate_required':
      'Ajoute ta date de naissance dans ton profil pour utiliser les outils IA.',
  'cv_field_residence': 'Pays de résidence',
  'cv_objective_prefill':
      'Objectif : intégrer un programme de @level en @field.',
  'cv_objective_destination': 'Destination visée : @country.',
  'cv_generator_title': 'Générateur de CV',
  'cv_generator_intro':
      'Remplis les champs et laisse l\'IA rédiger ton profil professionnel.',
  'cv_field_full_name': 'Nom complet',
  'cv_field_phone': 'Téléphone',
  'cv_field_study_level': 'Niveau d\'études',
  'cv_field_field_of_study': 'Domaine d\'études',
  'cv_field_target_country': 'Pays cible',
  'cv_field_skills': 'Compétences (séparées par des virgules)',
  'cv_field_languages': 'Langues',
  'cv_field_experience': 'Expérience / Stages',
  'cv_field_objective': 'Objectif professionnel',
  'cv_generating': 'Génération en cours...',
  'cv_enhance_with_ai': 'Améliorer avec l\'IA',
  'cv_ai_summary_heading': 'Résumé généré par l\'IA',
  'cv_export_pdf': 'Exporter en PDF',
  'scanner_doc_passport': 'Passeport',
  'scanner_doc_passport_hint': 'Page d\'identité, valide 6 mois min.',
  'scanner_doc_diploma': 'Diplôme / Attestation',
  'scanner_doc_diploma_hint': 'Dernier diplôme obtenu',
  'scanner_doc_transcripts': 'Relevés de notes',
  'scanner_doc_transcripts_hint': 'Bulletins des 2 dernières années',
  'scanner_doc_language_test': 'Test de langue',
  'scanner_doc_language_test_hint': 'TOEFL / IELTS / TCF si disponible',
  'scanner_doc_financial': 'Justificatif financier',
  'scanner_doc_financial_hint': 'Relevé bancaire ou attestation',
  'scanner_doc_id_photo': 'Photo d\'identité',
  'scanner_doc_id_photo_hint': 'Fond clair, format officiel',
  'scanner_title': 'Scanner mes documents',
  'scanner_application_folder': 'Dossier de candidature',
  'scanner_add_page': 'Ajouter une page',
  'scanner_scan': 'Scanner',
  'scanner_reset_tooltip': 'Réinitialiser',
  'impact_title': 'Notre impact',
  'impact_unavailable_title': 'Statistiques indisponibles',
  'impact_unavailable_subtitle':
      'Les données d’impact ne peuvent pas être vérifiées pour le moment. Réessaie plus tard.',
  'impact_hero_title': 'L\'éducation sans frontières',
  'impact_hero_subtitle':
      'KPB Education accompagne les talents africains vers les meilleures destinations d\'études.',
  'impact_stat_students_guided': 'Étudiants accompagnés',
  'impact_stat_admissions': 'Admissions obtenues',
  'impact_stat_scholarships': 'Bourses référencées',
  'impact_stat_countries': 'Pays de destination',
  'impact_stat_partner_institutions': 'Établissements partenaires',
  'impact_stat_orientation_sessions': 'Sessions d\'orientation IA',
  'impact_satisfaction_rate': 'Taux de satisfaction',
  'interview_title': 'Simulateur d\'entretien',
  'interview_picker_intro':
      'Entraîne-toi avec un examinateur IA. Choisis un type d\'entretien :',
  'interview_type_visa_title': 'Entretien de visa étudiant',
  'interview_type_visa_subtitle':
      'Questions consulaires : financement, retour, projet d\'études.',
  'interview_type_admission_title': 'Entretien d\'admission',
  'interview_type_admission_subtitle':
      'Motivation, parcours, adéquation avec le programme.',
  'interview_type_scholarship_title': 'Entretien de bourse',
  'interview_type_scholarship_subtitle':
      'Impact, leadership, projet de retour et engagement.',
  'interview_answer_hint': 'Tape ta réponse ici...',
  'interview_evaluating': 'Évaluation...',
  'interview_submit_answer': 'Soumettre ma réponse',
  'interview_feedback_strengths': 'Points forts',
  'interview_feedback_improvements': 'À améliorer',
  'interview_next_question': 'Question suivante',
  'interview_finish': 'Terminer',
  'letter_tpl_admission_general_title': 'Admission universitaire (général)',
  'letter_tpl_admission_master_title':
      'Admission en Master / Programme spécialisé',
  'letter_tpl_scholarship_kpb_title': 'Bourse d\'études KPB Education',
  'letter_tpl_scholarship_international_title':
      'Bourse d\'excellence internationale',
  'letter_tpl_visa_student_title': 'Lettre de motivation visa étudiant',
  'letter_tpl_internship_title': 'Stage ou alternance à l\'international',
  'letter_category_admission': 'Admissions',
  'letter_category_scholarship': 'Bourses',
  'letter_category_internship': 'Stage / Alternance',
  'letters_title': 'Lettres de motivation',
  'letters_filter_all': 'Tous',
  'letters_personalized_badge': 'Personnalisée',
  'letters_personalizing': 'Personnalisation...',
  'letters_field_strengths': '3 points forts à mettre en avant',
  'letters_field_strengths_hint': 'Leadership, rigueur, bénévolat…',
  'letters_field_event': 'Un événement marquant (optionnel)',
  'letters_field_event_hint': 'Un projet, un défi surmonté…',
  'letters_adapt_to_profile': 'Adapter à mon profil',
  'letters_copy_tooltip': 'Copier',
  'letters_copied_snackbar': 'Copié dans le presse-papier',
  'letters_share_tooltip': 'Partager',
  'student_tools_intro': 'Des outils pratiques pour préparer ta candidature.',
  'student_tools_cv_subtitle':
      'Crée un CV professionnel pré-rempli depuis ton profil, amélioré par l\'IA.',
  'student_tools_letters_subtitle':
      '6 modèles (admissions, bourses, visa, stage) personnalisables avec l\'IA en FR et EN.',
  'student_tools_interview_subtitle':
      'Entraîne-toi aux entretiens visa, admission et bourse avec un examinateur IA qui te note.',
  'student_tools_scanner_subtitle':
      'Scanne et organise les pièces de ton dossier (passeport, diplômes...) en PDF.',
  'student_tools_impact_subtitle':
      'Découvre l\'impact de KPB Education : étudiants accompagnés, admissions, bourses.',
  'search_field_not_found_title': 'Filière introuvable',
  'search_field_not_found_body': 'Cette filière n\'est plus disponible.',
  'search_hint': 'Rechercher une filière, un pays, une école...',
  'search_clear_history': 'Effacer',
  'search_suggestions': 'Suggestions',
  'search_suggestion_france': 'France',
  'search_suggestion_school': 'École',
  'search_suggestion_engineering': 'Ingénierie',
  'search_no_results_subtitle': 'Essayez avec d\'autres mots-clés',
  'search_section_fields': 'Filières',
  'search_section_countries': 'Pays',
  'search_section_institutions': 'Universités',
  'search_section_programs': 'Formations',
  'match_why_this_match': 'Pourquoi ce match ?',
  'scholarships_empty_title': 'Pas de bourses correspondantes',
  'scholarships_empty_subtitle':
      'Essaie de modifier tes critères ou ton orientation.',
  'scholarship_tab_info_criteria': 'Info & Critères',
  'scholarship_tab_success_path': 'Mon Parcours Succès',
  'scholarship_detail_level_label': 'Niveau : ',
  'scholarship_detail_funding_label': 'Financement : ',
  'scholarship_detail_deadline_label': 'Date limite : ',
  'scholarship_apply_with_kpb': 'Candidater avec KPB',
  'scholarship_academy_continue': 'Continue ta formation',
  'scholarship_academy_prepare': 'Prépare ta candidature avec des experts',
  'scholarship_academy_open_pack': 'Ouvrir mon pack',
  'scholarship_academy_view_pack': 'Voir le Pack Réussite',
  'live_scholarships_filter_all': 'Toutes',
  'live_scholarships_filter_fully_funded': 'Entièrement financées',
  'live_scholarships_filter_partially_funded': 'Partiellement financées',
  'live_scholarships_connection_error_title': 'Erreur de connexion',
  'live_scholarships_connection_error_subtitle':
      'Vérifie ta connexion et réessaie.',
  // Le vide a deux causes très différentes, et les confondre faisait
  // porter à l'étudiant la responsabilité d'un catalogue non publié.
  'live_scholarships_empty_filtered_title': 'Aucune bourse pour ces filtres',
  'live_scholarships_empty_filtered_subtitle':
      'Tes filtres ou ton profil académique restreignent la liste. Tu peux voir toutes les bourses disponibles.',
  'live_scholarships_show_all': 'Voir toutes les bourses',
  'live_scholarships_empty_catalog_title':
      'Aucune bourse publiée pour l\'instant',
  'live_scholarships_empty_catalog_subtitle':
      'Notre équipe vérifie et publie de nouvelles bourses régulièrement. Reviens bientôt ou active les alertes.',
  'live_scholarships_unfiltered_notice':
      'Aucune bourse ne correspond exactement à ton profil : voici toutes les bourses disponibles.',
  'live_scholarships_fully_funded': 'Entièrement financée',
  'live_scholarships_partially_funded': 'Partiellement financée',
  'live_scholarships_funding_unknown': 'Financement inconnu',
  'live_scholarships_funding_unspecified': 'Financement non spécifié',
  'live_scholarships_level_label': 'Niveau',
  'live_scholarships_all_levels': 'Tous niveaux',
  'live_scholarships_deadline_label': 'Date limite',
  'live_scholarships_see_official_site': 'Voir site officiel',
  'live_scholarships_match_excellent': 'Excellent profil pour cette bourse !',
  'live_scholarships_match_compatible':
      'Profil compatible — renforce ton dossier.',
  'live_scholarships_match_partial':
      'Profil partiel — les critères sont exigeants.',
  'live_scholarships_section_description': 'Description',
  'live_scholarships_section_advantages': 'Avantages',
  'live_scholarships_section_eligibility': 'Critères d\'éligibilité',
  'live_scholarships_section_key_requirements': 'Documents et exigences clés',
  'live_scholarships_section_application_steps': 'Comment postuler',
  'live_scholarships_requirement_automatic': 'Attribution automatique',
  'live_scholarships_requirement_separate_application':
      'Candidature séparée requise',
  'live_scholarships_step_duration': 'Durée estimée : @days jour(s)',
  'live_scholarships_view_official_application':
      'Voir le site officiel de candidature',
  'live_scholarships_official_form': 'Formulaire officiel',
  'live_scholarships_no_deadline': 'Pas de date limite',
  'live_scholarships_funding_tile': 'Financement',
  'live_scholarships_alert': 'M\'avertir',
  'live_scholarships_alert_enabled': 'Alerte activée',
  'live_scholarships_alert_error':
      'Impossible de modifier cette alerte. Réessaie.',
  // ── Bourses « à venir » (revue du build 49, point 9) ─────────────
  // Quand la fenêtre estimée couvre des MOIS entiers, on l'annonce en
  // mois. Afficher « 01/03/2027 – 30/04/2027 » était plus précis que
  // ce qu'on sait réellement : ces deux dates sont les bornes du mois,
  // pas une date de campagne publiée.
  // ── Liste des bourses (chantier I) : ligne de statut, filtres, tri,
  // hors ligne. Une date ESTIMÉE ne se dit qu'au mois près.
  'scholarships_filter_button': 'Filtrer',
  'scholarships_filter_button_count': 'Filtrer · @count',
  'scholarships_filter_title': 'Filtrer les bourses',
  'scholarships_filter_clear': 'Tout effacer',
  'scholarships_filter_status_section': 'Statut',
  'scholarships_filter_status_open': 'Ouvertes maintenant',
  'scholarships_filter_status_upcoming': 'Ouverture confirmée à venir',
  'scholarships_filter_status_forecast': 'Dates estimées ou à confirmer',
  'scholarships_filter_funding_section': 'Financement',
  'scholarships_filter_apply': 'Voir les bourses',
  'scholarships_sort_button': 'Trier : @sort',
  'scholarships_sort_sheet_title': 'Trier par',
  'scholarships_sort_relevance': 'Pertinence pour ton profil',
  'scholarships_sort_deadline': 'Clôture la plus proche',
  'scholarships_sort_verified': 'Récemment vérifiées',
  'scholarships_sort_title': 'Nom (A-Z)',
  'scholarships_offline_count': '@count bourse(s) gardée(s) sur ton téléphone',
  'scholarship_detail_title': 'Détails de la bourse',
  'scholarship_detail_not_found': 'Bourse introuvable',
  'scholarship_detail_not_found_body':
      'Cette bourse n’est plus disponible ou son lien a expiré.',
  'scholarship_how_to_apply_unavailable':
      'Les étapes détaillées seront ajoutées prochainement. Consulte le formulaire officiel pour les instructions à jour.',
  'scholarship_videos_title': 'Vidéos explicatives',
  'scholarship_video_explanation': 'Comprendre cette bourse',
  'scholarship_video_play': 'Lire la vidéo',
  'scholarship_video_unavailable':
      'Cette vidéo n’est pas disponible pour le moment.',
  'scholarship_video_open_youtube': 'Voir sur YouTube',
  'scholarship_video_more': 'Autres vidéos',
  'scholarship_guide_short_title': 'Le Guide Ultime du Boursier',
  'scholarship_guide_promo_body':
      'Une méthode claire pour préparer tes candidatures aux bourses internationales.',
  'scholarship_guide_learn_more': 'En savoir plus',
  // La carte du guide n'offrait aucune action : « En savoir plus »
  // menait à une page purement éditoriale, sans sortie (revue vidéo
  // du 08/08). Le guide devient une porte d'entrée conseiller.
  //
  // IMPORTANT — le guide est un produit PAYANT, remis par un conseiller
  // après règlement. D'où deux règles sur cette formulation :
  //   1. « Recevoir » laissait croire qu'il était offert : l'étudiant
  //      arrivait en attendant un cadeau et le conseiller devait lui
  //      annoncer un prix. Friction et déception, temps conseiller perdu.
  //   2. Aucun prix ni verbe d'achat DANS l'app : un PDF est un bien
  //      numérique au sens d'Apple 3.1.1, et le vendre hors achat
  //      intégré est un motif de rejet. Le Pass Bourses y échappe parce
  //      qu'il inclut des revues humaines (3.1.3(e)) ; un guide seul,
  //      non. L'app met en relation, le conseiller traite les modalités.
  'scholarship_guide_whatsapp_cta': 'Demander le guide à un conseiller',
  'scholarship_guide_whatsapp_prefill':
      'Bonjour KPB, je souhaite obtenir le Guide Ultime du Boursier. Pouvez-vous m\'indiquer les modalités ?',
  'scholarship_guide_title': 'Le Guide Ultime du Boursier Africain',
  'scholarship_guide_intro':
      'Un parcours pratique pour passer du rêve d\'étudier à l\'étranger à une candidature structurée et compétitive.',
  'scholarship_guide_inside_title': 'Ce que tu vas apprendre',
  'scholarship_guide_item_opportunities':
      'Identifier les bourses internationales accessibles aux étudiants africains.',
  'scholarship_guide_item_documents':
      'Construire un CV et une lettre de motivation adaptés à ton niveau.',
  'scholarship_guide_item_recommendations':
      'Préparer des demandes et modèles de lettres de recommandation.',
  'scholarship_guide_item_steps':
      'Organiser chaque candidature avec des étapes et checklists claires.',
  'scholarship_guide_item_bonus':
      'Renforcer ton anglais et éviter les erreurs les plus fréquentes.',
  'scholarship_guide_author':
      'Conçu par un lauréat Chevening 2024 ayant accompagné des centaines d\'étudiants africains.',
  // « Classées selon ton profil » promettait un tri personnalisé ; la liste
  // est celle des bourses vérifiées et pas encore clôturées
  // (`publicScholarshipWhere` côté serveur). On dit ce qui est vrai.
  'scholarships_sorted_hint':
      'Bourses vérifiées par KPB, pas encore clôturées. Active une alerte pour ne pas rater l\'ouverture.',
  'roadmap_redirect_writing_tutorials':
      'Redirection vers les tutoriels de rédaction...',
  'roadmap_redirect_kpb_expert': 'Redirection vers l\'expert KPB...',
  'roadmap_view_tutorials': 'Voir les tutos',
  'roadmap_book_expert': 'Réserver un expert',
  'eligibility_export_pdf': 'Exporter / partager en PDF',
  'eligibility_your_info': 'Tes informations',
  'eligibility_current_study_level': 'Niveau d\'études actuel',
  'eligibility_bac_series': 'Série du bac',
  'eligibility_monthly_budget_eur': 'Budget mensuel (EUR)',
  'eligibility_budget_hint': 'ex. 900',
  'eligibility_french_level': 'Niveau de français',
  'eligibility_english_level': 'Niveau d\'anglais',
  'eligibility_export_failed_title': 'Export impossible',
  'eligibility_export_failed_body': 'Le PDF n\'a pas pu être généré. Réessaie.',
  'eligibility_summary_eligible': 'Éligible',
  'eligibility_summary_conditions': 'Sous conditions',
  'eligibility_summary_to_prepare': 'À préparer',
  'eligibility_pdf_title': 'Simulateur d\'éligibilité',
  'eligibility_pdf_your_profile': 'Ton profil',
  'eligibility_pdf_name': 'Nom',
  'eligibility_pdf_study_level': 'Niveau d\'études',
  'eligibility_pdf_not_provided': 'Non renseigné',
  'eligibility_pdf_monthly_budget': 'Budget mensuel',
  'eligibility_pdf_to_confirm': 'À confirmer',
  'eligibility_pdf_verdicts_by_destination': 'Verdicts par destination',
  'eligibility_pdf_disclaimer':
      'Estimation indicative générée par KPB Education. Les conditions définitives dépendent de chaque école et du consulat. Contacte ton conseiller KPB pour valider ton dossier.',
  'lang_level_beginner': 'Débutant',
  'lang_level_intermediate': 'Intermédiaire',
  'lang_level_fluent': 'Courant',
  'eligibility_verdict_conditions': 'Éligible sous conditions',
  'eligibility_verdict_not_eligible': 'Non éligible pour l\'instant',
  'case_whatsapp_advisor_prefill_provisional':
      'Bonjour, je reviens vers toi au sujet de ma demande « @title » (référence en cours d\'enregistrement).',
  'case_whatsapp_advisor_prefill':
      'Bonjour, je reviens vers toi au sujet du dossier @reference.',
  'case_whatsapp_continue_prefill_provisional':
      'Bonjour KPB, je souhaite continuer sur ma demande « @title » (référence en cours d\'enregistrement).',
  'case_whatsapp_continue_prefill':
      'Bonjour KPB, je souhaite continuer sur le dossier @reference.',
  'case_section_messages': 'Messages',
  'case_unread_suffix': 'non lu(s)',
  'case_timeline_since_date': 'Depuis le @date',
  'case_timeline_on_date': 'Le @date',
  'case_tunnel_attached_documents_prefix': 'Documents joints:',
  'case_recap_files_count': '@count fichier(s)',
  'cases_count': '@count dossier(s)',
  'cases_new_messages_badge': '@count nouveaux',
  'cases_messages_count': '@count message(s)',
  // --- KPB-89 batch ---
  'case_upload_take_photo': 'Prendre une photo',
  'case_upload_from_gallery': 'Choisir de la galerie',
  'case_upload_pick_pdf': 'Choisir un fichier (PDF)',
  'common_error': 'Erreur',
  'case_not_found_title': 'Dossier introuvable',
  'case_not_found_body_title': 'Ce dossier n\'est plus disponible',
  'case_not_found_subtitle': 'Retourne à la liste des dossiers pour continuer.',
  'case_not_found_action': 'Ouvrir mes dossiers',
  'case_advisor_role': 'Conseiller KPB Education',
  'case_section_documents': 'Documents',
  'case_document_send': 'Envoyer',
  'case_document_received': '✓ Reçu',
  // ── M2 : les documents passent par le conseiller ──
  // Tant que l'envoi en app est masqué, ces libellés remplacent
  // « Envoyer ». Ils disent la destination réelle du document, ce qui
  // est tout le point : l'ancien bouton cochait « fourni ✓ » sur un
  // fichier que personne ne recevait.
  'case_document_send_whatsapp': 'Envoyer sur WhatsApp',
  'case_document_whatsapp_prefill':
      'Bonjour KPB Education, je vous envoie « @document » pour mon dossier @reference.',
  'case_documents_handoff_title': 'Tes documents passent par ton conseiller',
  'case_documents_handoff_body':
      'Pour l\'instant, les pièces jointes ne s\'envoient pas depuis l\'app : ton conseiller les reçoit sur WhatsApp et te confirme leur bonne réception. Prépare ton CV, tes relevés de notes et ton passeport — tu peux les scanner depuis la boîte à outils de l\'app.',
  'case_documents_handoff_cta': 'Envoyer mes documents sur WhatsApp',
  'case_documents_handoff_prefill':
      'Bonjour KPB Education, je prépare ma demande « @title » et je souhaite vous transmettre mes documents.',
  'case_documents_handoff_footnote':
      'Tu peux continuer sans envoyer de document maintenant : ton conseiller te dira lesquels sont nécessaires.',
  'case_ai_review_cta': '✨ Relecture IA de mon dossier',
  'case_section_history': 'Historique',
  'case_continue_whatsapp': 'Continuer sur WhatsApp',
  'case_whatsapp_has_advisor_subtitle':
      'Discute directement avec ton conseiller KPB.',
  'case_whatsapp_no_advisor_subtitle':
      'Rejoins le groupe KPB en attendant ton conseiller.',
  'case_timeline_heading': 'Suivi de ta demande',
  'case_timeline_status_submitted': 'Soumise',
  'case_timeline_status_counselor_assigned': 'Attribuée à un conseiller',
  'case_timeline_status_under_review': 'En revue',
  'case_timeline_status_documents_needed': 'Documents requis',
  'case_timeline_status_awaiting_student': 'En attente de ta réponse',
  'case_timeline_status_in_progress': 'En cours',
  'case_timeline_status_application_submitted': 'Soumise à l\'établissement',
  'case_timeline_status_waiting_decision': 'Décision en attente',
  'case_timeline_status_awaiting_payment': 'Paiement en attente',
  'case_timeline_status_completed': 'Acceptée',
  'case_timeline_status_cancelled': 'Demande annulée',
  'case_timeline_status_rejected': 'Refusée',
  'case_stepper_heading': 'Progression',
  'case_stepper_creation_title': 'Création du dossier',
  'case_stepper_creation_desc_draft':
      'Complète ton profil pour soumettre la demande.',
  'case_stepper_creation_desc_done': 'Dossier soumis avec succès.',
  'case_stepper_analysis_title': 'Analyse et Conseiller',
  'case_stepper_analysis_desc_docs':
      'Des documents supplémentaires sont requis.',
  'case_stepper_analysis_desc_awaiting': 'Ton conseiller attend ta réponse.',
  'case_stepper_analysis_desc_default': 'Nos experts examinent ton profil.',
  'case_stepper_processing_title': 'Traitement',
  'case_stepper_processing_desc':
      'Préparation et soumission de tes candidatures.',
  'case_stepper_decision_title': 'Décision',
  'case_stepper_decision_desc': 'En attente des retours des institutions.',
  'case_stepper_finalization_title': 'Finalisation',
  'case_stepper_finalization_desc_rejected': 'Dossier refusé.',
  'case_stepper_finalization_desc_cancelled': 'Dossier annulé.',
  'case_stepper_finalization_desc_done': 'Procédure terminée avec succès !',
  'case_tunnel_step_type': 'Type',
  'case_tunnel_step_context': 'Contexte',
  'case_tunnel_step_message': 'Message',
  'case_tunnel_step_confirmation': 'Confirmation',
  // Ces trois clés ne servent plus de bandeau d'échec APRÈS cinq étapes
  // remplies : elles sont affichées AVANT, avec un bouton qui mène
  // réellement à l'onboarding (PARC-05).
  'case_tunnel_incomplete_profile_title': 'Profil incomplet',
  'case_tunnel_incomplete_profile_body':
      'Complète ton profil pour qu\'un conseiller KPB puisse traiter ta demande. Ça prend deux minutes, et tu retrouveras cette page ensuite.',
  'case_tunnel_incomplete_profile_cta': 'Compléter mon profil',
  'case_tunnel_pick_photo': 'Photo',
  'case_tunnel_pick_gallery': 'Galerie',
  'case_tunnel_file_too_large_title': 'Fichier trop volumineux',
  // Le corps du bandeau était en anglais brut, produit par le
  // `toString()` de l'exception. Les deux nombres arrivent par
  // paramètres : une chaîne assemblée dans le modèle ne se traduit pas.
  'file_too_large_body':
      'Ce fichier fait @size Mo, la limite est de @max Mo. Prends la photo en plus petit, ou envoie-le à ton conseiller sur WhatsApp.',
  'case_tunnel_add_file_failed': 'Impossible d\'ajouter ce fichier. Réessaie.',
  'common_back': 'Retour',
  'common_next': 'Suivant',
  'case_type_application_support': 'Inscription école',
  'case_type_scholarship': 'Bourse',
  'case_type_consultation': 'Visa / dossier',
  'case_type_housing': 'Logement',
  'case_type_other': 'Autre',
  'case_context_country': 'Pays',
  'case_context_school': 'École',
  'case_context_program': 'Programme',
  'case_doc_transcripts': 'Relevés de notes',
  'case_doc_passport': 'Passeport',
  'case_documents_step_hint':
      'Ajoute tes documents maintenant (optionnel). Tu pourras aussi les envoyer plus tard avec ton conseiller.',
  'common_add': 'Ajouter',
  'common_replace': 'Remplacer',
  'case_message_mic_required_title': 'Micro requis',
  'case_message_mic_required_body':
      'Autorise le micro pour dicter ton message.',
  // `case_message_dictation_unavailable_*` reste le message des pannes
  // ORDINAIRES (micro occupé, plateforme absente). Les trois clés
  // suivantes servent le cas distinct où la plateforme refuse la
  // reconnaissance LOCALE : là, la dictée n'est possible qu'en
  // envoyant la voix au service d'Apple ou de Google, ce qui exige un
  // accord explicite — d'où un dialogue, et non un snackbar.
  'case_message_dictation_unavailable_title': 'Dictée indisponible',
  'case_message_dictation_unavailable_body':
      'La reconnaissance vocale n\'est pas disponible sur cet appareil.',
  // La cause n'est pas la même, donc le message non plus.
  //
  // `..._unavailable_body` dit « pas disponible sur cet appareil » : vrai
  // quand le greffon manque ou que la plateforme ne sait pas reconnaître
  // la voix, faux dans le cas ci-dessous. Après l'accord d'envoi au
  // service de la plateforme, la reconnaissance EST disponible — c'est la
  // SESSION qui n'a pas démarré (micro occupé par un appel, service
  // refusé à cet instant). Servir l'autre message accuserait l'appareil
  // et découragerait le nouvel essai qui peut suffire.
  //
  // Le texte invite à réessayer sans promettre que ça marchera : ni
  // « ça va marcher », ni « dans quelques instants ».
  'case_message_dictation_not_started_title': 'Dictée non démarrée',
  'case_message_dictation_not_started_body':
      'La session de dictée n\'a pas pu démarrer maintenant. Vérifie qu\'aucune autre application n\'utilise le micro, puis réessaie.',
  'case_message_dictation_on_device_unavailable_title':
      'Reconnaissance locale indisponible',
  'case_message_dictation_on_device_unavailable_body':
      'Ton téléphone ne peut pas convertir la voix en texte hors ligne. Pour dicter, ta voix serait envoyée au service de reconnaissance de ton téléphone (Apple ou Google) et traitée hors de l\'appareil. Tu peux aussi écrire ton message.',
  'case_message_dictation_use_platform_service': 'Dicter quand même',
  'case_message_stop_dictation': 'Arrêter la dictée',
  'case_message_dictate': 'Dicter mon message',
  'case_contact_phone': 'Téléphone',
  'case_recap_contact': 'Contact',
  'cases_filter_all': 'Tous',
  'case_type_filter_consultation': 'Consultation',
  'case_type_filter_application': 'Candidature',
  'case_type_filter_mentorship': 'Mentorat',
  'cases_new_message_badge': 'Nouveau message',
  'cases_action_send_documents': '📎 Envoyer mes documents',
  'cases_action_chat_advisor': '💬 Échanger avec mon conseiller',
  'cases_action_reply_advisor': '✉️ Répondre au conseiller',
  'cases_action_view_appointment': '📅 Voir mon rendez-vous',
  'case_status_short_submitted': 'Envoyé',
  'case_status_short_counselor': 'Conseiller',
  'case_status_short_action_required': 'Action requise',
  'case_status_short_scheduled': 'Planifié',
  'case_status_short_application_submitted': 'Soumis',
  'case_status_short_payment': 'Paiement',
  'case_status_short_completed': 'Terminé',
  'case_status_short_rejected': 'Refusé',
  'case_status_short_cancelled': 'Annulé',
  'case_status_short_draft': 'Brouillon',
  'doc_review_kind_motivation': 'Lettre de motivation',
  'doc_review_hint_motivation':
      'Colle ici le texte de ta lettre de motivation…',
  'doc_review_hint_cv': 'Colle ici le contenu de ton CV…',
  'doc_review_unavailable': 'Relecture impossible pour le moment.',
  'doc_review_title': 'Relecture IA',
  'doc_review_kind_label': 'Type de document',
  'doc_review_draft_label': 'Ton brouillon',
  'doc_review_analyze_cta': 'Analyser mon document',
  'doc_review_strengths': 'Points forts',
  'doc_review_missing': 'Éléments manquants',
  'doc_review_disclaimer':
      'Relecture indicative — pour une relecture approfondie, demande un '
          'conseiller KPB.',
  'doc_review_score_label': 'Score global',
  'doc_review_improvements': 'À améliorer',
  'doc_viewer_download_title': 'Téléchargement',
  'doc_viewer_download_body': 'Le téléchargement va bientôt commencer...',
  // --- KPB-89 batch ---
  'country_study_in': 'Étudier en @country',
  'program_available_on_campuses': 'Disponible sur @count campus',
  'program_available_on_one_campus': 'Disponible sur 1 campus',
  'program_recognition': 'Reconnaissance du diplôme',
  'quiz_title_with_country': 'Quiz · @country',
  'quiz_question_progress': 'Question @current/@total',
  'quiz_enrollment_with_program': 'Inscription — @program',
  'explore_campus_count': '📍 @count campus',
  'explore_programs_count': '@count programmes',
  'country_why_this_country': 'Pourquoi ce pays ?',
  'country_how_it_works': 'Comment ça se passe',
  'country_costs': 'Coûts',
  'country_tuition_fees': 'Frais de scolarité',
  'country_living_cost_per_month': 'Coût de la vie / mois',
  'country_visa_and_insurance': 'Visa & assurance',
  'country_required_language': 'Langue requise',
  'country_partner_schools': 'Écoles partenaires dans ce pays',
  'country_available_scholarships': 'Bourses disponibles',
  'program_step_eligibility_choice': 'Quiz d\'éligibilité & choix du programme',
  'program_step_build_file': 'Constitution du dossier avec KPB',
  'program_step_submission': 'Soumission à l\'école partenaire',
  'program_step_submission_direct':
      'Envoi de ta candidature à l\'établissement (KPB n\'en est pas partenaire)',
  'program_step_admission_letter': 'Obtention de la lettre d\'admission',
  'program_step_visa_departure': 'Visa & préparation du départ',
  'badge_kpb_partner': 'Partenaire KPB',
  'program_at_a_glance': 'Le programme en bref',
  'program_level': 'Niveau',
  'program_duration': 'Durée',
  'program_language': 'Langue',
  'program_country': 'Pays',
  'program_campus': 'Campus',
  'program_intake': 'Rentrée',
  'program_field': 'Domaine',
  'program_admission_requirements': 'Conditions d\'admission',
  'program_application_process': 'Processus de candidature',
  'quiz_unavailable_for_country': 'Quiz indisponible pour ce pays.',
  'quiz_load_failed': 'Impossible de charger le quiz.',
  'eligibility_quiz_title': 'Quiz d\'éligibilité',
  'quiz_unavailable_title': 'Quiz indisponible',
  'back': 'Retour',
  'quiz_see_verdict': 'Voir mon verdict',
  'next': 'Suivant',
  'explore_tab_fields': 'Filières',
  'explore_tab_programs': 'Programmes',
  'explore_tab_universities': 'Universités',
  'explore_tab_support': 'Support',
  'explore_no_fields_title': 'Aucune filière disponible',
  'explore_no_fields_body':
      'Revenez plus tard pour découvrir nos nouveaux programmes.',
  'explore_no_countries_title': 'Aucun pays disponible',
  'explore_no_countries_body':
      'Nous élargissons actuellement notre catalogue de destinations.',
  'explore_no_programs_title': 'Aucune formation disponible',
  'explore_no_programs_body':
      'Synchronisez l’app avec le serveur pour charger le catalogue.',
  'explore_search_program': 'Rechercher un programme',
  'explore_share_university': 'Découvrez cette université sur KPB Education.',
  'compare_selected_label': 'Sélectionné',
  'field_careers': 'Débouchés',
  'field_key_subjects': 'Matières clés',
  'field_skills_developed': 'Compétences développées',
  'badge_official_partner': 'Partenaire Officiel',
  'institution_overview': 'Présentation',
  'institution_popular_programs': 'Programmes populaires',
  'institution_kpb_expert': 'Expert KPB',
  'institution_enroll_via_kpb': 'S\'inscrire via KPB',
  'learn_more': 'En savoir plus',
  'institution_premium_support_guaranteed': 'Accompagnement Premium Garanti',
  'institution_premium_support': 'Accompagnement Premium',
  'institution_kpb_benefits': 'Avantages KPB Education',
  'institution_priority_admission': 'Admission Prioritaire',
  'institution_priority_admission_desc':
      'Dossier traité en priorité par l\'université.',
  'institution_dedicated_coach': 'Coach Dédié',
  'institution_dedicated_coach_desc':
      'Un expert te suit de l\'inscription au visa.',
  'institution_exclusive_scholarships': 'Bourses Exclusives',
  'institution_exclusive_scholarships_desc':
      'Accès aux aides financières réservées aux partenaires.',
  'account_type_student': 'Étudiant',
  'account_type_parent': 'Parent d\'élève',
  'account_type_partner': 'Partenaire (école / agence)',
  'account_type_commercial': 'Commercial KPB',
  'onboarding_consent_required_title': 'Consentement requis',
  'onboarding_consent_required_body':
      'Veuillez accepter la politique de confidentialité et les conditions d\'utilisation.',
  'onboarding_selection_required_title': 'Sélection requise',
  'onboarding_select_field_body': 'Choisissez au moins une filière d\'intérêt.',
  'onboarding_select_country_body':
      'Choisissez au moins un pays de destination.',
  // Onboarding V2 : l'erreur s'écrit SOUS le groupe de puces, en tu.
  'onboarding_fields_required_inline':
      'Choisis au moins une filière qui t\'intéresse.',
  'onboarding_countries_required_inline':
      'Choisis au moins un pays où tu aimerais étudier.',
  'onboarding_welcome_title': 'Bienvenue 👋',
  'onboarding_welcome_subtitle': 'Créons ton profil KPB Education.',
  'onboarding_academic_title': 'Ton parcours 🎓',
  'onboarding_academic_subtitle': 'Dis-nous où tu en es.',
  'onboarding_partner_title': 'Votre structure 🤝',
  'onboarding_partner_subtitle': 'Parlez-nous de votre organisation.',
  'onboarding_interests_title': 'Tes intérêts 🌍',
  'onboarding_interests_subtitle': 'Personnalise tes recommandations.',
  'skip': 'Passer',
  'onboarding_i_am': 'Je suis',
  'account_type_parent_short': 'Parent',
  'onboarding_consent_accept_prefix': 'J\'accepte la ',
  'onboarding_consent_and': ' et les ',
  'onboarding_terms_of_use_inline': 'conditions d\'utilisation',
  'onboarding_partnership_space': 'Espace partenariat',
  'intro_slide1_title': 'Explore tes destinations',
  'intro_slide1_body':
      "Découvrez des centaines de programmes au Canada, en France et partout dans le monde.",
  'intro_slide2_title': 'Bourses & accompagnement',
  'intro_slide2_body':
      'Trouve la bourse idéale et obtiens une feuille de route adaptée à ton profil.',
  'intro_slide3_title': 'Suivi en temps réel',
  'intro_slide3_body':
      'Suis l\'avancement de ton dossier et échange avec nos conseillers, dans l\'app.',
  'get_started': 'Commencer',
  'continue_action': 'Continuer',
  'profile_data_saver_desc': 'Economise la data (masque les images lourdes)',
  'profile_analytics': 'Analyse d\'usage',
  // Les diagnostics de plantage sont nommés parce que l'interrupteur les
  // coupe désormais réellement : `AnalyticsService.setCollectionEnabled`
  // est l'entonnoir des TROIS collecteurs (Firebase Analytics,
  // Crashlytics, PostHog). Avant, Crashlytics collectait quoi qu'on
  // réponde — le libellé taisait donc moins qu'il ne mentait.
  'profile_analytics_desc':
      'Autoriser l\'analyse anonyme de l\'usage, les diagnostics de plantage et l\'enregistrement de session (contenu masqué) pour améliorer l\'app',
  'profile_newsletter': 'Newsletter bourses',
  'profile_newsletter_desc':
      'Recevoir les nouvelles bourses d\'études disponibles par email (désinscription à tout moment)',
  'profile_quick_orientation_test': 'Test d\'orientation',
  'profile_quick_eligibility_simulator': 'Simulateur d\'éligibilité',
  'profile_quick_journeys_testimonials': 'Parcours & témoignages',
  'profile_quick_saved_items': 'Éléments sauvegardés',
  'profile_quick_budget_calculator': 'Calculateur de Budget',
  'profile_quick_flight_simulator': 'Simulateur de Vols (Kayak)',
  'profile_quick_student_housing': 'Logement Étudiant (France)',
  'profile_quick_community_articles': 'Communauté & Articles',
  'profile_quick_parent_space': 'Espace parent',
  'profile_quick_parent_mode': 'Mode parent',
  'profile_quick_kpb_services': 'Services KPB (Dossier prêt)',
  'profile_quick_verified_alumni_mentors': 'Mentors alumni vérifiés',
  'profile_quick_become_alumni_mentor': 'Devenir mentor alumni',
  'profile_quick_virtual_salon': 'Salon KPB Virtuel',
  'profile_privacy_policy': 'Politique de confidentialité',
  'profile_terms_of_service': 'Conditions d\'utilisation',
  'account_type_commercial_2': 'Commercial',
  'profile_field_full_name': 'Nom complet',
  'required': 'Requis',
  'profile_field_phone': 'Téléphone',
  'profile_field_email_helper':
      'Email de connexion à ton compte — il ne se modifie pas ici.',
  'profile_field_country_of_residence': 'Pays de résidence',
  'profile_field_current_study_level': 'Niveau d\'études actuel',
  'profile_field_bac_series': 'Série du bac',
  'profile_updated_title': 'Profil mis à jour',
  'profile_updated_body': 'Tes informations ont été sauvegardées.',
  'profile_missing_grade_field': 'Moyenne académique',
  'profile_missing_grade_impact':
      'Améliore la précision de tes recommandations d\'écoles',
  'profile_missing_current_level_impact':
      'Indispensable pour matcher les programmes disponibles',
  'profile_missing_target_level_field': 'Niveau cible',
  'profile_missing_target_level_impact':
      'Aide les conseillers à orienter ton dossier',
  'profile_missing_documents_field': 'Documents disponibles',
  'profile_missing_documents_impact':
      'Nos conseillers en ont besoin pour évaluer ton dossier',
  'profile_missing_language_level_field': 'Niveau de langue',
  'profile_missing_language_level_impact':
      'Certaines universités ont des seuils minimum',
  // ── Les huit items du score qui n'avaient aucun libellé ─────────
  // `completionScore` en compte treize ; la carte n'en savait nommer
  // que cinq. Un profil à qui il ne manquait que le budget affichait
  // « 92 % » au-dessus d'une carte vide.
  'profile_missing_full_name_field': 'Nom complet',
  'profile_missing_full_name_impact':
      'C\'est le nom qui figurera sur tes candidatures',
  'profile_missing_email_field': 'Adresse e-mail',
  'profile_missing_email_impact':
      'Le canal par lequel les écoles et nos conseillers te répondent',
  'profile_missing_phone_field': 'Téléphone',
  'profile_missing_phone_impact':
      'Permet à un conseiller de te joindre pour un dossier urgent',
  'profile_missing_country_field': 'Pays de résidence',
  'profile_missing_country_impact':
      'Détermine les bourses et les procédures qui te sont ouvertes',
  'profile_missing_language_field': 'Langue de l\'application',
  'profile_missing_language_impact':
      'Définit la langue de tes contenus et de tes notifications',
  'profile_missing_fields_field': 'Domaines d\'études',
  'profile_missing_fields_impact':
      'Sans eux, aucune recommandation de filière n\'est possible',
  'profile_missing_target_countries_field': 'Pays visés',
  'profile_missing_target_countries_impact':
      'Oriente tes bourses, tes coûts et tes délais de procédure',
  'profile_missing_budget_field': 'Budget annuel de scolarité',
  'profile_missing_budget_impact':
      'Écarte les programmes hors de portée et cible les bourses utiles',
  'universities_empty_sync_subtitle':
      'Synchronisez l\'app avec le serveur pour charger le catalogue.',
  // --- KPB-89 home ---
  'home_greeting': 'Bonjour 👋',
  'home_greeting_named': 'Bonjour, @name 👋',
  'home_design_greeting': 'Salut 👋',
  'home_design_greeting_named': 'Salut, @name 👋',
  'home_design_header_subtitle': 'Tes destinations @countries',
  'home_design_discovery_title': 'Parcours découverte',
  'home_design_discovery_subtitle':
      'Ta prochaine mission — créée avec ton compte',
  'home_design_tools_title': 'Tes outils',
  'home_profile_pct_notice':
      'À @pct% — des champs manquants limitent tes recommandations',
  'home_admission_prefix': 'Admission : @value',
  'home_subtitle_student': 'Ton tableau de bord',
  'home_subtitle_parent': 'Espace parent',
  'home_subtitle_partner': 'Espace partenaire',
  'home_active_cases_title': 'Dossiers actifs',
  'see_all': 'Voir tout',
  'home_recommended_universities_title': 'Écoles pour ton profil',
  'home_hero_title_partner': 'Développons\nvotre réseau',
  'home_hero_title_parent': 'Accompagnez\nvotre enfant',
  'home_hero_title_student': 'Ton parcours\nvers l\'étranger',
  'home_hero_subtitle_student': 'Une étape à la fois — on avance ensemble.',
  'home_hero_subtitle_other': 'Démarrez dès aujourd\'hui.',
  'home_hero_cta_consultation': 'Consultation',
  'home_hero_cta_become_partner': 'Devenir partenaire',
  // CTA du héros pour un INVITÉ : mène à l'onglet Bourses. Sans durée ni
  // nombre, pour rester vrai que le test « Mes 10 bourses » soit ouvert ou non.
  'home_hero_cta_find_scholarships': 'Trouve tes bourses',
  'home_case_title_book_appointment': 'Prendre rendez-vous',
  'home_hero_profile_ring_label': 'Profil',
  'home_next_step_label_action_required': 'Action requise',
  'home_next_step_title_talk_advisor': 'Échange avec ton conseiller',
  'home_next_step_title_documents_to_send': 'Documents à envoyer',
  'home_next_step_title_response_expected': 'Réponse attendue de toi',
  'home_next_step_label_your_profile': 'Ton profil',
  'home_next_step_title_complete_profile': 'Complète ton profil',
  'home_next_step_subtitle_missing_info':
      'Quelques infos manquent pour personnaliser tes recommandations',
  'home_next_step_label_discovery': 'Découverte',
  'home_next_step_title_take_orientation': 'Fais ton test d\'orientation',
  'home_next_step_subtitle_orientation':
      '5 questions pour trouver les filières qui te correspondent',
  'home_next_step_label_next_step': 'Prochaine étape',
  'home_next_step_title_start_case': 'Démarre ton dossier',
  'home_next_step_subtitle_start_case':
      'Profil et orientation prêts — c\'est le bon moment pour te lancer',
  'home_case_title_new_case': 'Nouveau dossier',
  'home_next_step_label_explore': 'Explorer',
  'home_next_step_title_discover_opportunities':
      'Découvre de nouvelles opportunités',
  'home_next_step_subtitle_explore':
      'Parcours les filières, pays et bourses qui matchent ton profil',
  'home_quick_action_scholarships': 'Bourses',
  'home_quick_action_cases': 'Dossiers',
  'home_ai_advisor_title': "Conseiller d'Orientation IA",
  'home_badge_new': "Nouveau",
  'home_ai_advisor_cta': "Discuter avec l'IA",
  'case_status_documents_needed': 'Docs requis',
  'case_status_awaiting_payment': 'Paiement',
  'case_status_awaiting_student': 'Ta réponse',
  'case_status_scheduled': 'RDV planifié',
  'case_status_in_progress': 'En cours',
  'case_status_under_review': 'En révision',
  'case_status_counselor_assigned': 'Conseiller assigné',
  'case_status_submitted': 'Soumis',
  'case_status_application_submitted': 'Candidature envoyée',
  'case_status_waiting_decision': 'En attente',
  'badge_partner': 'Partenaire',
  'home_days_left_label': 'jours',
  'home_deadline_near_label': '⏰ DEADLINE PROCHE',
  'home_deadline_see_button': 'Voir →',
  'home_badge_guidance': "Accompagnement",
  'home_student_tools_title': 'Outils étudiants',
  'home_student_tools_subtitle': 'CV, lettres de motivation, et plus',
  // ── Progress gauge card (App-engagement handoff) ──
  'home_gauge_eyebrow': 'JAUGE DE PROGRESSION',
  'home_gauge_bar_level': 'Niveau',
  'home_gauge_bar_interests': 'Intérêts',
  'home_gauge_bar_documents': 'Documents',
  'home_gauge_bar_budget': 'Budget',
  'home_case_documents_ratio': '@done/@total documents fournis',
  // ── Parcours preview (Home) ──
  'home_parcours_title': 'Ils l\'ont fait avant toi',
  'home_parcours_subtitle': 'Parcours vidéo d\'étudiants africains — gratuit',
  // ── Contact conseiller KPB (Home, App-engagement handoff) ──
  'home_counselor_cta_title': 'Parler à un conseiller KPB',
  'home_counselor_cta_subtitle':
      'Sur WhatsApp, avec un message déjà prêt. Réponse sous 24 h.',
  'sample_data_notice':
      'Données d’exemple — connexion au serveur impossible. Le catalogue affiché n’est pas encore à jour.',
  'freshness_saved': 'données enregistrées',
  'freshness_today': 'données enregistrées aujourd\'hui',
  'freshness_yesterday': 'données enregistrées hier',
  'freshness_days': 'données enregistrées il y a @n jours',
  'freshness_date': 'données du @date',
  // Distinct de la bannière « données d'exemple » : ici les données sont
  // VRAIES, seulement datées. Crier au loup sur des données correctes
  // apprend à ignorer la bannière qui compte.
  'stale_catalog_notice':
      'Serveur injoignable — données réelles du dernier chargement',
  // ── Espace « Études en France » (Phase 0 — vitrine) ──
  //
  // Le nom : « Études en France », jamais « Campus France ». Campus
  // France est un opérateur de l'État français et rien n'atteste d'un
  // partenariat ; on nomme la procédure qu'on accompagne. Un test de
  // traduction vérifie qu'aucune clé de titre ne porte l'enseigne —
  // sinon la décision se perd au premier ajout de chaîne.
  //
  // Le temps des verbes : futur ou « en préparation », jamais le
  // présent. Rien de tout ça n'existe encore.
  'eef_title': 'Études en France',
  'eef_status_preparing': 'En préparation',
  'eef_hero_title': 'Ton dossier Études en France,\nde A à Z',
  'eef_hero_body':
      'Un espace dédié à la campagne française : trouver les formations '
          'faites pour ton profil, monter ton dossier, préparer ton '
          'entretien. On le construit en ce moment.',
  'eef_opens_in_days': 'ouverture dans @days jours',
  'eef_opens_tomorrow': 'ouverture demain',
  // Les clôtures divergent par pays et la plupart ne sont pas encore
  // publiées : on dit qu'elles existent sans en inventer aucune.
  'eef_deadline_varies_notice':
      'Les dates de clôture varient selon ton pays et ta procédure. On '
          'te les confirmera dans l\'espace.',
  // Suspension : elle REMPLACE la date d'ouverture. Le texte ne promet
  // pas de débloquer une situation diplomatique — il dit ce qui est, et
  // propose la seule chose utile, parler à quelqu'un.
  'eef_official_platform_link': 'Voir la plateforme officielle',
  // RETIRÉS DE L'AFFICHAGE le 05/10/2026 (décision du propriétaire : un
  // étudiant du Niger peut mener sa procédure depuis un autre pays). Les
  // deux clés restent ici pour que les tests d'absence cherchent le VRAI
  // texte : sans lui, `find.text('eef_suspended_notice'.tr)` chercherait
  // le nom de la clé et ne pourrait jamais rougir.
  'eef_official_suspension_link': 'Voir la source officielle',
  'eef_suspended_notice':
      'Dans ton pays, le traitement des dossiers Études en France est '
          'actuellement suspendu par les autorités françaises. '
          'L\'ouverture de la plateforme ne change rien à cela. '
          'Parles-en à un conseiller KPB : d\'autres destinations '
          'restent ouvertes.',
  'eef_pillars_heading': 'Ce que tu pourras faire',
  // ── Hub de l'espace (build 54) ────────────────────────────────────
  // L'agence n'est nommée que dans les CORPS de texte, jamais dans un
  // titre (eef_naming_test). Le corps du héros dit où se dépose la
  // candidature — texte à valider par le juridique.
  'eef_hub_hero_title': 'Prépare ta candidature aux universités françaises',
  'eef_hub_hero_body':
      'Trouve les formations qui te correspondent, puis prépare ton '
          'dossier : CV, lettres de motivation, entretien. La '
          'candidature elle-même se dépose auprès des services '
          'officiels, selon la procédure indiquée sur chaque formation '
          '(plateforme Études en France gérée par Campus France, '
          'demande d\'admission préalable…).',
  'eef_hub_formations_title': 'Trouver ma formation',
  'eef_hub_formations_body':
      'Les universités publiques et quelques établissements publics : '
          'cherche par nom, ville, niveau et procédure d\'admission.',
  'eef_hub_tools_heading': 'Préparer mon dossier',
  'eef_hub_advisor_title': 'Parler à un conseiller',
  'eef_hub_advisor_body':
      'Une question sur ta candidature ? Un conseiller KPB te répond '
          'sur WhatsApp.',
  'eef_hub_whatsapp_prefill':
      'Bonjour, j\'ai une question sur ma candidature aux universités '
          'françaises (Études en France).',
  // ── Aide à chaque étape floue (EefHelpCard) ──────────────────────
  // « À chaque étape où c'est un peu flou, on pose une question. »
  // Règles tenues par ces textes : aucune promesse d'admission ni de
  // visa (la mention `eef_help_fineprint` le dit), aucun prix, jamais le
  // nom de l'opérateur de l'État dans un titre ou un libellé
  // (eef_naming_test), et pour un pays suspendu un jeu NEUTRE
  // (`eef_help_neutral_*`) qui ne parle jamais d'ouvrir un dossier.
  'eef_help_hub_question': 'C\'est flou ? Tu veux de l\'aide ?',
  'eef_help_hub_body':
      'Pour passer à l\'étape supérieure, contacte-nous sur WhatsApp '
          'pour démarrer une étude de ton dossier.',
  'eef_help_hub_cta': 'Démarrer l\'étude de mon dossier sur WhatsApp',
  'eef_help_procedure_question': 'Procédure, dates, dépôt : c\'est flou ?',
  'eef_help_documents_question': 'Tu ne sais pas quels documents préparer ?',
  'eef_help_catalog_results_question': 'Tu hésites sur ta formation ?',
  'eef_help_catalog_results_body':
      'Dis-nous où tu en es sur WhatsApp : un conseiller KPB démarre '
          'l\'étude de ton dossier avec toi, pour choisir et passer à '
          'l\'étape suivante.',
  'eef_help_catalog_results_cta':
      'Démarrer l\'étude de mon dossier sur WhatsApp',
  'eef_help_catalog_procedure_question':
      'Pas sûr(e) de la procédure pour ces formations ?',
  'eef_help_catalog_empty_question': 'Tu ne trouves pas ta formation ?',
  'eef_help_catalog_empty_body':
      'Un conseiller KPB peut chercher avec toi, à partir de ton '
          'profil et de ton projet.',
  'eef_help_catalog_empty_cta': 'Demander de l\'aide sur WhatsApp',
  'eef_help_catalog_unpublished_question': 'Tu ne veux pas attendre ?',
  'eef_help_catalog_unpublished_body':
      'Un conseiller KPB peut déjà regarder ton projet avec toi, sans '
          'attendre l\'arrivée du catalogue.',
  'eef_help_catalog_unpublished_cta': 'Demander de l\'aide sur WhatsApp',
  'eef_help_compact_cta': 'Demander de l\'aide sur WhatsApp',
  'eef_help_neutral_question': 'Besoin d\'y voir plus clair ?',
  'eef_help_neutral_body':
      'Un conseiller KPB peut faire le point avec toi sur les autres '
          'options d\'études.',
  'eef_help_neutral_cta': 'Parler à un conseiller des autres options',
  'eef_help_fineprint':
      'Un accompagnement n\'est pas une garantie : l\'admission et le '
          'visa dépendent des établissements et des autorités.',
  // Le message prérempli de WhatsApp : l'ÉTAPE, aucune donnée
  // personnelle (ni nom, ni e-mail, ni téléphone, ni pays).
  'eef_help_prefill':
      'Bonjour KPB Education, je suis dans l\'espace Études en France '
          'de l\'app (étape : @step). Pour passer à l\'étape supérieure, '
          'j\'aimerais démarrer l\'étude de mon dossier.',
  'eef_help_prefill_suspended':
      'Bonjour KPB Education, je suis dans l\'espace Études en France '
          'de l\'app (étape : @step). La procédure est suspendue dans '
          'mon pays : j\'aimerais parler des autres options d\'études.',
  'eef_help_step_hub': 'accueil de l\'espace',
  'eef_help_step_procedure': 'procédure, dates et dépôt',
  'eef_help_step_documents': 'documents à fournir',
  'eef_help_step_catalog_results': 'choix de ma formation',
  'eef_help_step_catalog_procedure': 'procédure d\'une formation',
  'eef_help_step_catalog_empty': 'recherche de formation sans résultat',
  'eef_help_step_catalog_unpublished': 'catalogue pas encore disponible',
  // ── Build 55 : déclencheurs d'aide (EefHelpLine) ─────────────────
  // Sous chaque formation, sous les filtres actifs, dans les trois
  // outils du dossier. Mêmes règles que ci-dessus : aucune promesse,
  // aucun prix, jamais le nom de l'opérateur de l'État ; et pour un
  // pays suspendu un libellé et un message NEUTRES — jamais « dossier »,
  // jamais un pays, jamais un pays de remplacement.
  'eef_help_line_cta': 'Demander de l\'aide',
  'eef_help_line_neutral_cta': 'Parler à un conseiller',
  'eef_help_line_subject': 'Demander de l\'aide à propos de « @subject »',
  'eef_help_line_neutral_subject':
      'Parler à un conseiller à propos de « @subject »',
  'eef_help_catalog_filters_question': 'Tu hésites entre ces formations ?',
  'eef_help_tool_cv_question': 'Besoin d\'aide pour rédiger ton CV ?',
  'eef_help_tool_letters_question':
      'Besoin d\'aide pour ta lettre de motivation ?',
  'eef_help_tool_interview_question':
      'Besoin d\'aide pour préparer ton entretien ?',
  'eef_help_tool_cv_label': 'CV',
  'eef_help_tool_letters_label': 'lettre de motivation',
  'eef_help_tool_interview_label': 'préparation d\'entretien',
  'eef_help_filters_family': '@family : @values',
  'eef_help_prefill_program':
      'Bonjour KPB Education, je regarde la formation « @program »'
          '@place dans l\'espace Études en France de l\'app et '
          'j\'aimerais de l\'aide pour mon dossier.',
  'eef_help_prefill_program_suspended':
      'Bonjour KPB Education, je regarde la formation « @program »'
          '@place dans l\'espace Études en France de l\'app. La '
          'procédure est suspendue dans mon pays : j\'aimerais savoir '
          'quelles options existent.',
  'eef_help_prefill_filters':
      'Bonjour KPB Education, je regarde les formations de l\'espace '
          'Études en France de l\'app (@filters) et j\'hésite. '
          'J\'aimerais de l\'aide pour choisir.',
  'eef_help_prefill_filters_suspended':
      'Bonjour KPB Education, je regarde les formations de l\'espace '
          'Études en France de l\'app (@filters). La procédure est '
          'suspendue dans mon pays : j\'aimerais savoir quelles options '
          'existent.',
  // Aucun filtre à citer (un identifiant que l'app ne sait pas nommer, ou
  // — pour un pays suspendu — une procédure seule) : jamais de
  // parenthèses vides.
  'eef_help_prefill_filters_none':
      'Bonjour KPB Education, je regarde les formations de l\'espace '
          'Études en France de l\'app et j\'hésite. J\'aimerais de '
          'l\'aide pour choisir.',
  'eef_help_prefill_filters_none_suspended':
      'Bonjour KPB Education, je regarde les formations de l\'espace '
          'Études en France de l\'app. La procédure est suspendue dans '
          'mon pays : j\'aimerais savoir quelles options existent.',
  'eef_help_prefill_tool':
      'Bonjour KPB Education, je suis dans l\'espace Études en France '
          'de l\'app, sur l\'outil « @tool ». J\'aimerais de l\'aide.',
  'eef_help_prefill_tool_suspended':
      'Bonjour KPB Education, je regarde l\'outil « @tool » dans '
          'l\'espace Études en France de l\'app. La procédure est '
          'suspendue dans mon pays : j\'aimerais savoir quelles options '
          'existent.',
  // ── La visite guidée du hub (build 56) ───────────────────────────────
  // Trois ou quatre cartes à la première ouverture, rejouables par le
  // « ? ». Les étapes 2 à 4 sont les mêmes pour tout le monde ; seule
  // l'étape 1 a une variante NEUTRE (compte dont le pays est suspendu) :
  // ni « candidature » ni « dossier », aucun pays nommé. La visite ne
  // parle jamais des écoles privées, ne chiffre rien et ne promet rien.
  'eef_tour_title': 'Visite de l\'espace',
  'eef_tour_counter': 'Étape @n sur @total',
  'eef_tour_skip': 'Passer',
  'eef_tour_next': 'Suivant',
  'eef_tour_done': 'Compris',
  'eef_tour_replay': 'Revoir la visite',
  'eef_tour_1_title': 'Bienvenue dans Études en France',
  'eef_tour_1_body':
      'Ici, tu explores des formations et tu prépares ton projet. Ta '
          'candidature, elle, se dépose auprès des services officiels : '
          'KPB est un service privé d\'accompagnement, pas un service '
          'de l\'État.',
  'eef_tour_1_neutral_body':
      'Ici, tu explores des formations et tu prépares ton projet '
          'd\'études. Les démarches officielles se font sur les '
          'plateformes de l\'État : KPB est un service privé '
          'd\'accompagnement, pas un service de l\'État.',
  'eef_tour_2_title': 'Trouve une formation',
  'eef_tour_2_body':
      'Cherche parmi les formations des universités publiques, puis '
          'filtre par niveau, domaine, ville et procédure d\'admission.',
  'eef_tour_3_title': 'Prépare tes documents',
  'eef_tour_3_body':
      'Un CV, des lettres de motivation et un simulateur d\'entretien '
          't\'aident à te préparer.',
  'eef_tour_4_title': 'Une question ? Écris-nous',
  'eef_tour_4_body':
      'Le bouton vert en bas à droite te met en contact avec l\'équipe '
          'KPB sur WhatsApp. Le message est déjà écrit et tu peux le '
          'modifier avant de l\'envoyer.',
  // ── La bulle verte WhatsApp (build 56) ───────────────────────────────
  // Le cercle, puis la feuille de sujets. Chaque message porte `@place`
  // (où l'étudiant se trouve) et RIEN d'autre : ni nom, ni pays, ni
  // contact. Le jeu « neutre » (compte dont le pays est suspendu) ne
  // dit jamais « dossier », « démarrer », ni ne nomme un pays.
  'eef_help_bubble_tooltip': 'Écrire à l\'équipe KPB sur WhatsApp',
  'eef_help_bubble_hint': 'Ouvre une liste de messages prêts à envoyer',
  'eef_help_bubble_title': 'Écrire à l\'équipe KPB',
  'eef_help_bubble_subtitle':
      'Choisis ton sujet. WhatsApp s\'ouvre avec un message déjà '
          'écrit : tu peux le modifier, et rien n\'est envoyé sans toi.',
  'eef_help_bubble_place_hub': 'l\'espace Études en France de l\'app',
  'eef_help_bubble_place_catalog':
      'le catalogue de l\'espace Études en France de l\'app',
  'eef_help_bubble_assistance_label':
      'Contacter l\'équipe KPB pour une assistance',
  'eef_help_bubble_assistance_label_neutral': 'Parler à un conseiller',
  'eef_help_bubble_assistance_message':
      'Bonjour KPB Education, je suis dans @place et j\'aimerais de '
          'l\'aide de l\'équipe KPB.',
  'eef_help_bubble_assistance_message_neutral':
      'Bonjour KPB Education, je suis dans @place. La procédure est '
          'suspendue dans mon pays : j\'aimerais savoir quelles options '
          'existent.',
  'eef_help_bubble_dossier_label': 'Je veux de l\'aide pour mon dossier',
  'eef_help_bubble_dossier_message':
      'Bonjour KPB Education, je suis dans @place et j\'aimerais de '
          'l\'aide pour préparer mon dossier de candidature.',
  'eef_help_bubble_choose_label': 'Je ne sais pas quelle formation choisir',
  'eef_help_bubble_choose_message':
      'Bonjour KPB Education, je suis dans @place. J\'hésite sur le '
          'choix de ma formation et j\'aimerais en parler.',
  'eef_help_bubble_question_label': 'J\'ai une autre question',
  'eef_help_bubble_question_message':
      'Bonjour KPB Education, j\'ai une question sur @place.',
  'eef_help_bubble_question_message_neutral':
      'Bonjour KPB Education, je suis dans @place. La procédure est '
          'suspendue dans mon pays et j\'ai une question.',
  'eef_help_bubble_number': 'Numéro officiel de KPB Education : @number',
  'eef_help_bubble_copy': 'Copier le numéro',
  'eef_help_bubble_copied': 'Copié',
  'eef_help_bubble_email':
      'Pas de WhatsApp ? Écris-nous à contact@kpbeducation.com',
  // ── Les écoles privées (build 56, PR 3) ──────────────────────────────
  // La feuille d'information « Service KPB », la ligne de l'état « aucun
  // résultat » du catalogue et l'option du menu de la bulle. AUCUN
  // montant, AUCUNE devise, AUCUN nom d'école ni de pays. Le repli sur la
  // phrase des frais (`..._fees_fallback`) n'est PAS affiché par défaut.
  'eef_help_private_chip': 'Service KPB',
  'eef_help_private_title': 'Les écoles privées : ce qu\'il faut savoir',
  'eef_help_private_point_terms':
      'Chaque école privée fixe ses propres conditions d\'admission, '
          'ses frais et son calendrier.',
  'eef_help_private_point_fees':
      'Les frais sont en général plus élevés que dans le public. '
          'Demande-les par écrit avant de t\'engager.',
  'eef_help_private_point_fees_fallback':
      'Les frais varient beaucoup d\'une école à l\'autre. '
          'Demande-les par écrit avant de t\'engager.',
  'eef_help_private_point_steps':
      'Les démarches officielles (admission, visa) dépendent de ton '
          'pays et de l\'école. Vérifie-les sur les sites officiels.',
  'eef_help_private_point_status':
      'KPB Education est un service privé d\'accompagnement, pas un '
          'service de l\'État.',
  'eef_help_private_cta': 'En parler à un conseiller',
  'eef_help_private_dismiss': 'Pas maintenant',
  'eef_help_private_message_label': 'Message qui sera écrit :',
  'eef_help_private_message':
      'Bonjour KPB Education, je suis dans @place. J\'aimerais en savoir '
          'plus sur les écoles privées : conditions d\'admission, frais '
          'et calendrier.',
  'eef_help_private_option_label':
      'Je veux en savoir plus sur les écoles privées',
  'eef_help_private_note_text':
      'Les écoles privées ont d\'autres conditions et un autre '
          'calendrier.',
  'eef_help_private_note_link': 'Les écoles privées : ce qu\'il faut savoir',
  'eef_hub_guest_body':
      'Crée ton compte pour enregistrer ton profil et demander à être '
          'rappelé par un conseiller.',
  'eef_students_only_title': 'Un espace pour les étudiants',
  'eef_students_only_body':
      'Cet espace prépare la candidature d\'un étudiant et utilise son '
          'profil. Connecte-toi avec le compte de l\'étudiant, ou parle '
          'à un conseiller KPB.',
  // ── Mon profil Études en France ───────────────────────────────────
  'eef_profile_title': 'Mon profil Études en France',
  'eef_profile_read_failed':
      'Impossible de lire ton profil pour le moment. Si tu avais déjà '
          'répondu, ta réponse est toujours enregistrée.',
  'eef_profile_empty_body':
      'Dis-nous ton niveau et tes domaines : un conseiller KPB pourra '
          'te rappeler avec les bonnes informations.',
  'eef_profile_declare_cta': 'Compléter mon profil',
  'eef_profile_level_line': 'Niveau actuel : @level',
  'eef_profile_target_line': 'Niveau visé : @level',
  'eef_profile_fields_line': 'Domaines : @fields',
  'eef_profile_no_fields': 'Aucun domaine choisi',
  'eef_profile_recorded_body':
      'Un conseiller KPB peut te rappeler au sujet de cet espace. Tu '
          'peux te retirer à tout moment.',
  'eef_profile_edit_cta': 'Modifier mon profil',
  'eef_profile_edit_title': 'Modifier mon profil',
  'eef_profile_edit_body':
      'Tu modifies seulement ton niveau et tes domaines. Ton accord '
          'pour être rappelé ne change pas.',
  'eef_field_domains': 'Tes domaines (plusieurs choix possibles)',
  // ── Catalogue « Études en France » (Phase 1) ──────────────────
  'eef_catalog_title': 'Formations',
  'eef_catalog_open': 'Ouvrir le catalogue',
  'eef_catalog_search_hint': 'Formation, ville…',
  'eef_catalog_facet_cycle': 'Niveau',
  'eef_catalog_facet_procedure': 'Procédure',
  'eef_catalog_facet_field': 'Domaine',
  'eef_catalog_facet_city': 'Ville',
  // Filtres : boutons, feuille de choix, filtres actifs.
  'eef_catalog_filter_clear': 'Effacer',
  'eef_catalog_filter_semantics_none': 'Aucun choix',
  'eef_catalog_filter_semantics_count': '@count choix',
  'eef_catalog_filter_semantics_hint': 'Ouvre la liste des choix',
  'eef_catalog_option_semantics': '@label, @count formation(s)',
  'eef_catalog_sheet_apply_zero': 'Voir 0 formation',
  'eef_catalog_sheet_apply_one': 'Voir 1 formation',
  'eef_catalog_sheet_apply_many': 'Voir @count formations',
  'eef_catalog_sheet_apply_generic': 'Voir les formations',
  'eef_catalog_active_filters': 'Filtres actifs',
  'eef_catalog_active_clear_all': 'Tout effacer',
  'eef_catalog_active_remove': 'Retirer le filtre @label',
  'eef_catalog_city_search_hint': 'Chercher une ville',
  'eef_catalog_city_loading': 'Chargement des villes…',
  'eef_catalog_city_error_title': 'Impossible de charger les villes',
  'eef_catalog_city_error_network':
      'Pas de connexion. Vérifie-la, puis réessaie.',
  'eef_catalog_city_error_server':
      'Le serveur n\'a pas répondu. Réessaie dans un instant.',
  'eef_catalog_city_retry': 'Réessayer',
  'eef_catalog_city_empty': 'Aucune ville ne correspond',
  'eef_catalog_city_fallback':
      'Villes principales — pour une autre ville, tape-la dans la '
          'recherche',
  'eef_catalog_result_count': '@count formation(s)',
  'eef_catalog_empty_title': 'Aucune formation ne correspond',
  'eef_catalog_empty_body':
      'Le serveur a bien répondu : c\'est la recherche qui est trop '
          'étroite. Retire un filtre ou élargis les mots-clés.',
  'eef_catalog_empty_action': 'Tout effacer',
  'eef_catalog_unpublished_title': 'Le catalogue arrive',
  'eef_catalog_unpublished_body':
      'Les universités sont ajoutées une par une, après vérification '
          'de leurs fiches. Reviens bientôt, ou demande à un conseiller '
          'KPB.',
  'eef_catalog_more_failed': 'Impossible de charger la suite.',
  'eef_catalog_more_retry': 'Réessayer',
  'eef_catalog_sources_row': 'Sources des données et mentions',
  'eef_catalog_sources_title': 'À propos des données',
  'eef_catalog_attribution':
      'Données : @producer (@sources). Licence : @licence. '
          'Récupérées le @date.',
  'eef_catalog_attribution_bare':
      'Données : @producer. Licence : @licence. Récupérées le @date.',
  'eef_catalog_licence_link': 'Voir la licence',
  'eef_catalog_error_network_title': 'Pas de connexion',
  'eef_catalog_error_server_title': 'Catalogue indisponible',
  'eef_catalog_error_body':
      'Rien n\'a pu être demandé au serveur — ce n\'est pas un '
          'catalogue vide. Réessaie dans un instant.',
  'eef_catalog_value_cycle_licence1': 'Licence 1re année',
  'eef_catalog_value_cycle_licence2': 'Licence 2e année',
  'eef_catalog_value_cycle_licence3': 'Licence 3e année',
  'eef_catalog_value_cycle_but1': 'BUT 1re année',
  'eef_catalog_value_cycle_deust': 'DEUST',
  // La famille « Études de santé » entière : PASS, L.AS ET diplômes
  // paramédicaux. « Accès santé » est réservé au badge des seuls PASS / L.AS.
  'eef_catalog_value_cycle_sante': 'Études de santé',
  'eef_catalog_badge_health_access': 'Accès santé',
  'eef_catalog_value_cycle_ingenieur': 'Cycle ingénieur',
  'eef_catalog_value_cycle_master': 'Master',
  'eef_catalog_value_procedureType_dap_blanche': 'DAP dossier blanc',
  'eef_catalog_value_procedureType_dap_jaune': 'DAP dossier jaune',
  'eef_catalog_value_procedureType_eef': 'Études en France',
  'eef_catalog_value_procedureType_parcoursup': 'Parcoursup',
  'eef_catalog_value_procedureType_hors_eef': 'Hors procédure',
  'eef_pillar_catalog_title': 'Un catalogue dense',
  'eef_pillar_catalog_body':
      'Les universités publiques et quelques établissements publics : '
          'licences, BUT, masters, cycles ingénieur. Cherche par nom, '
          'ville, niveau et procédure d\'admission.',
  'eef_pillar_shortlist_title': 'Les formations faites pour toi',
  'eef_pillar_shortlist_body':
      'Une sélection classée en trois étages — ambition, cible, '
          'sécurité — avec, pour chaque formation, la raison pour '
          'laquelle elle est là.',
  'eef_pillar_documents_title': 'Lettres, CV, projet d\'études',
  'eef_pillar_documents_body':
      'Des modèles par procédure et de l\'aide à la rédaction, y compris '
          'pour le projet d\'études — la pièce sur laquelle l\'entretien '
          'te jugera.',
  'eef_pillar_endtoend_title': 'Ta candidature suivie',
  'eef_pillar_endtoend_body':
      'Les échéances, les pièces à fournir, l\'avancement de ton '
          'dossier, et un conseiller KPB quand tu bloques.',
  'eef_plans_heading': 'Gratuit et Premium',
  'eef_plan_free_label': 'Gratuit',
  'eef_plan_premium_label': 'Avec KPB Premium',
  'eef_free_catalog': 'Le catalogue et les filtres de base',
  'eef_free_shortlist_preview': 'Un aperçu de ta sélection',
  'eef_free_letter_preview': 'Un modèle de lettre en aperçu',
  'eef_free_deadlines': 'Le calendrier des échéances',
  'eef_premium_shortlist_full':
      'La sélection complète, justifiée formation par formation',
  'eef_premium_documents': 'Lettres, CV et projet d\'études sans limite',
  'eef_premium_interview': 'Le simulateur d\'entretien et son retour',
  'eef_premium_review': 'La relecture de ton dossier par un conseiller',
  'eef_plan_premium_footnote':
      'Les tarifs et les modalités seront annoncés à l\'ouverture. '
          'Aucun paiement n\'est demandé aujourd\'hui.',
  'eef_cta_heading': 'Ça t\'intéresse ?',
  'eef_cta_body':
      'Dis-le-nous : on te préviendra dès l\'ouverture, et ta réponse '
          'nous dit par quoi commencer.',
  'eef_cta_declare': 'Ça m\'intéresse',
  'eef_guest_body':
      'Crée ton compte pour qu\'on puisse te prévenir à l\'ouverture.',
  'eef_guest_cta': 'Créer mon compte',
  'eef_interest_recorded_title': 'C\'est noté',
  'eef_interest_recorded_body':
      'On te préviendra dès l\'ouverture de l\'espace.',
  'eef_interest_edit_cta': 'Modifier ma réponse',
  'eef_sheet_title': 'Dis-nous où tu en es',
  'eef_sheet_body':
      'Tout est optionnel — un seul tap suffit. Ces réponses servent à '
          'te rappeler avec les bonnes informations, et à mesurer ce '
          'que nous devons préparer.',
  'eef_field_current_level': 'Ton niveau actuel',
  'eef_field_target_level': 'Le niveau que tu veux préparer',
  'eef_field_wants_premium': 'La version Premium m\'intéresserait aussi',
  'eef_consent_notice':
      'En validant, tu acceptes qu\'un conseiller KPB te contacte au '
          'sujet de cet espace, et que ta réponse serve à préparer '
          'notre accompagnement. Tu peux te retirer à tout moment, '
          'depuis cet écran.',
  'eef_withdraw_cta': 'Me retirer de la liste',
  'eef_withdraw_confirm_title': 'Te retirer de la liste ?',
  'eef_withdraw_confirm_body':
      'Ta déclaration sera supprimée et personne ne te rappellera au '
          'sujet de cet espace. Tu pourras revenir quand tu veux.',
  'eef_withdraw_confirm_cta': 'Me retirer',
  'eef_withdraw_cancel': 'Annuler',
  'eef_withdraw_done': 'Tu es retiré de la liste.',
  'eef_withdraw_failed':
      'Retrait impossible pour le moment. Réessaie, ou écris-nous à '
          'privacy@kpbeducation.com.',
  'eef_sheet_confirm': 'Valider',
  'eef_sheet_retry': 'Réessayer',
  'eef_sheet_cancel': 'Annuler',
  'eef_error_network':
      'Envoi impossible : vérifie ta connexion, puis réessaie. Rien '
          'n\'a été enregistré.',
  'eef_error_unauthorized':
      'Ta session a expiré. Reconnecte-toi, puis réessaie. Rien n\'a '
          'été enregistré.',
  'eef_error_server':
      'Envoi impossible pour le moment. Rien n\'a été enregistré — '
          'réessaie dans un instant.',
  'eef_level_unspecified': 'Je préfère ne pas dire',
  'eef_level_terminale': 'Terminale',
  'eef_level_bac': 'Baccalauréat obtenu',
  'eef_level_licence': 'Licence',
  'eef_level_master': 'Master',
  'eef_level_doctorat': 'Doctorat',
  'eef_level_autre': 'Autre',
  'eef_tools_subtitle':
      'Trouver ta formation, monter ton dossier, préparer ton entretien',
  'eef_home_card_subtitle':
      'La campagne française, accompagnée de bout en bout',
  'eef_modules_coming_heading': 'Les modules en cours d\'arrivée',
  'eef_affiliation_notice':
      'KPB Education est un organisme privé d\'accompagnement, sans '
          'lien ni affiliation avec Campus France ni avec aucune '
          'administration française. Les démarches officielles se font '
          'sur les plateformes de l\'État.',
  'coming_soon_title': 'Bientôt disponible',
  'coming_soon_body':
      'Ce module arrive dans une prochaine version de KPB. Reste connecté !',
  // ── Preuve sociale (impact) ──
  'impact_proof_title': 'Notre impact, vérifié',
  'impact_proof_line':
      '@students étudiants accompagnés · @admissions admissions',
  'reviews_basis': 'basé sur @n avis',
  // ── Testimonials carousel (Home social proof, KPB-79) ──
  'testimonials_carousel_title': 'Avis de nos étudiants',
  'testimonials_carousel_body': '@count avis vérifiés',
  'testimonials_empty_state': 'Aucun avis publié pour le moment.',
  // ── KPB accompaniment offer (country detail) ───────────
  'kpb_offer_title': 'L\'accompagnement KPB',
  'kpb_offer_intro':
      'Nos conseillers t\'accompagnent de l\'éligibilité jusqu\'à l\'obtention du visa.',
  'kpb_offer_conditions': 'Conditions d\'éligibilité',
  'kpb_cond_grades': 'Moyenne ≥ 11/20 sur tes 3 dernières années',
  'kpb_cond_language': 'Bon niveau dans la langue d\'enseignement',
  'kpb_cond_guarantor': 'Un garant pour ton dossier visa',
  'kpb_offer_formulas': 'Nos formules d\'accompagnement',
  'pack_admission': 'Admission',
  'pack_admission_desc': 'Sécurise ton admission dans une bonne école.',
  'pack_envol': 'Pack Envol',
  'pack_envol_desc': 'Admission + procédure visa de bout en bout.',
  'svc_school_search': 'Recherche d\'une école adaptée',
  'svc_application': 'CV + lettre de motivation',
  'svc_interview': 'Préparation à l\'entretien',
  'svc_visa': 'Procédure visa accompagnée',
  'kpb_offer_partner_discount':
      '−30 % si tu étudies dans une école partenaire KPB',
  'kpb_offer_price_note':
      'Tarif indicatif · payable après échange avec un conseiller',
  'onboarding_title': 'Construisons ton parcours',
  'partner_redirect':
      'Les partenariats sont gérés via un formulaire dédié et un suivi KPB.',
  'nav_home': 'Accueil',
  'nav_orientation': 'Orientation',
  'nav_destinations': 'Destinations',
  'nav_universities': 'Universités',
  'nav_programs': 'Programmes',
  'nav_institutions': 'Établissements',
  'catalog_filter_all': 'Tous',
  'catalog_filter_business': 'Business',
  'catalog_filter_cs': 'Informatique',
  'catalog_filter_engineering': 'Ingénierie',
  'catalog_program_count': '@count programme(s)',
  'catalog_no_match_title': 'Aucun résultat',
  'catalog_no_match_body': 'Essayez un autre mot-clé ou filtre.',
  'catalog_partner_badge': 'Partenaire KPB',
  'm6_tab_partners': 'Partenaires KPB ⭐',
  'm6_tab_all': 'Toutes les écoles',
  'm6_search_program': 'Rechercher un programme',
  'm6_filters_title': 'Filtres',
  'm6_filters_active': 'Filtres actifs',
  'm6_reset': 'Réinitialiser',
  'm6_reset_filters': 'Réinitialiser les filtres',
  'm6_filter_country': 'Pays',
  'm6_filter_budget': 'Budget max : @max / an',
  'm6_filter_level': 'Niveau',
  'm6_filter_field': 'Domaine',
  'm6_filter_language': 'Langue',
  'm6_see_details': 'Voir détails →',
  'nav_commercial_leads': 'Mes leads',
  'nav_commercial_chat': 'Conversations',
  'commercial_no_leads_title': 'Aucun lead pour le moment',
  'commercial_no_leads_body':
      'Les nouvelles demandes qui te sont attribuées apparaîtront ici.',
  'commercial_no_chat_title': 'Aucune conversation',
  'commercial_no_chat_body':
      'Ouvre un dossier depuis Mes leads pour discuter avec un étudiant.',
  'search': 'Rechercher',
  'nav_scholarships': 'Bourses',
  'nav_cases': 'Dossiers',
  'nav_saved': 'Sauvegardés',
  'nav_profile': 'Profil',
  'model_answer': 'Réponse modèle',
  'france_path_steps': 'Ton parcours en 6 étapes',
  'france_partner_schools_title': 'Écoles partenaires France',
  'france_start_procedure': 'Je commence ma procédure',
  'unlock': 'Déverrouiller',
  'student_housing': 'Logement Étudiant',
  'evaluate_eligibility': 'Évaluer mon éligibilité',
  'improve_profile': 'Améliorer mon profil',
  'latest_messages': 'Derniers échanges',
  'verified_alumni': 'Alumni vérifié',
  'recent_searches': 'Recherches récentes',
  'possible_careers': 'Débouchés possibles',
  'main_subjects': 'Matières principales',
  'linked_children': 'Enfants liés',
  'shared_cases': 'Dossiers partagés',
  'key_criteria': 'Critères clés :',
  'privacy_policy': 'Politique de Confidentialité',
  'parent_create_invite': 'Créer un code d\'invitation',
  'salon_rsvp_error': 'Impossible de mettre à jour l\'inscription.',
  'intake_label': 'Rentrée',
  'offering_intake_spring_month': 'Rentrée décalée · @month @year',
  'offering_intake_spring_year': 'Rentrée décalée · @year',
  'offering_intake_fall_month': 'Rentrée @month @year',
  'offering_intake_fall_year': 'Rentrée d\'automne @year',
  'offering_rhythm_alternance': 'Alternance',
  'offering_rhythm_initiale': 'Formation initiale',
  'program_intakes_one': 'Rentrée :',
  'program_intakes_many': 'Rentrées :',
  'program_intakes_school_one': 'Rentrée de l\'école :',
  'program_intakes_school_many': 'Rentrées de l\'école :',
  'program_intakes_more': '+ @count',
  'program_intakes_none_upcoming': 'Prochaine rentrée non publiée',
  'program_offerings_all_past':
      'Les rentrées publiées (@campuses) sont passées. La prochaine date n’est pas encore publiée : demande-la à ton conseiller KPB.',
  'program_intake_spring_tag': 'décalée',
  'program_intake_spring_a11y': 'rentrée décalée',
  'program_intake_fall_year_short': 'automne @year',
  'offering_intake_estimated_note':
      'Date reconduite de @year, à confirmer · tarif @tuitionYear',
  'offering_intake_estimated_a11y':
      'Date reconduite de la rentrée @year, à confirmer par l\'école. Tarif de l\'année @tuitionYear.',
  'offering_intake_estimated_plain': 'Date et tarif à confirmer',
  'program_intake_estimated_tag': 'à confirmer',
  'program_intake_estimated_a11y': 'date à confirmer',
  'turnaround_label': 'Délai',
  'home_find_school_desc':
      'Trouve ton école privée en France selon ton budget et tes objectifs. Discute instantanément !',
  'closing_label': 'Clôture',
  'home_apply_world_desc':
      'Postulez dans les meilleures universités du monde (Canada, USA, UK, Allemagne, Maroc).',
  'discover': 'Découvrir',
  'home_destinations_desc':
      'Découvre les destinations d\'études où KPB Education t\'accompagne de A à Z : orientation, admission et visa.',
  'tuition_prefix': 'Scolarité : ',
  'analyzing_answers': 'Analyse de tes réponses…',
  'multiple_answers_allowed': 'Plusieurs réponses possibles',
  'orientation_results_intro':
      'Voici les filières qui te correspondent le mieux.',
  'target_careers': 'Métiers visés',
  'recommended_countries': 'Pays recommandés',
  'track_admission_deadlines': 'Suis les échéances de tes admissions',
  'item_deleted': 'Élément supprimé',
  'documents_ready': 'documents prêts',
  'france_admission_title': 'Admission France — Écoles privées',
  'france_sept_intake': 'Rentrée @intake',
  'programs_available': 'programmes disponibles',
  'france_public_unis_soon':
      'Universités publiques — Bientôt disponible · @intake',
  'france_why_private': 'Pourquoi le privé au lancement ?',
  'france_private_intro':
      'Les écoles privées françaises partenaires KPB offrent un parcours d\'admission direct, avec des rentrées flexibles et un accompagnement personnalisé pour les étudiants africains.',
  'france_sync_catalog':
      'Synchronise le catalogue pour voir les écoles OMNES et partenaires.',
  'last_updated_april_2026': 'Dernière mise à jour : Avril 2026',
  'terms_of_use': 'Conditions Générales d\'Utilisation',
  'student_living_cost': 'Coût de la vie étudiante',
  'budget_intro':
      'Anticipe tes dépenses mensuelles selon ta destination et ton mode de vie.',
  'estimated_monthly_budget': 'Budget Mensuel Estimé',
  'details_by_category': 'Détails par catégorie',
  'budget_subtitle_monthly': 'coût de la vie mensuel',
  'budget_monthly_range': 'Fourchette mensuelle',
  'budget_sources_note':
      'Estimations du coût de la vie compilées par KPB Education · montants mensuels indicatifs.',
  'budget_see_scholarships_cta': 'Voir les bourses disponibles',
  'app_locked': 'Application Verrouillée',
  'app_lock_prompt':
      'Authentifie-toi pour accéder à tes documents et suivis KPB.',
  'auth_failed': 'Authentification échouée.',
  'logout_title': 'Déconnexion',
  'private_schools_admission': 'Admission écoles privées',
  'dedicated_path_intake': 'Parcours dédié · @intake',
  'eligibility_simulator_title': 'Simulateur d\'éligibilité',
  'eligibility_hook': 'En 1 minute, vérifie les critères de base',
  'eligibility_intro':
      'Réponds à 5 questions et obtiens un verdict 🟢 🟡 🔴 pour chacune des 9 destinations KPB, puis exporte ton bilan en PDF.',
  'offline_cache_notice': 'Mode hors ligne. Affichage des données en cache.',
  'next_step': 'Prochaine étape',
  'deadlines_title': 'Mes échéances',
  // ── Avis conseiller au jalon d'admission (KPB-75) ──
  'review_prompt_title': 'Note ton conseiller',
  'review_prompt_body':
      'Félicitations pour ton admission ! Ton retour aide d\'autres étudiants à choisir KPB.',
  'review_prompt_later': 'Plus tard',
  'review_prompt_cta': 'Laisser un avis',
  'review_prompt_sheet_body':
      'Donne une note et, si tu veux, quelques mots sur ton accompagnement.',
  'review_prompt_hint': 'Ton témoignage (optionnel)',
  'review_prompt_submit': 'Envoyer mon avis',
  'review_prompt_thanks': 'Merci ! Ton avis sera publié après modération.',
  'review_prompt_error': 'Envoi impossible. Réessaie plus tard.',
  'case_prepare_package_title': 'Préparer mon dossier',
  'case_prepare_package_subtitle':
      'CV, lettre de motivation et pièces relues par KPB avant paiement WhatsApp.',
  // ── Vue parent : argent & échéances (KPB-58) ──
  'parent_tuition_estimate': 'Frais de scolarité estimés',
  'parent_next_deadline': 'Prochaine échéance',
  'parent_cost_note':
      'Estimation indicative — confirme le détail avec le conseiller.',
  'step_label': 'Étape',
  'case_context_prefilled':
      'Contexte pré-rempli depuis ta navigation. Tu peux continuer ou revenir en arrière pour modifier.',
  'listening_speak_clearly': 'Écoute en cours… parle clairement.',
  // Remplace l'indicateur ci-dessus quand la voix est traitée HORS de
  // l'appareil (`SpeechProcessingMode.platformService`). La clé est
  // posée d'avance : le câblage vit dans `case_tunnel_flow.dart`, hors
  // du périmètre de ce lot, et sans elle le prochain lot écrirait un
  // littéral français en dur — le défaut que garde
  // `no_hardcoded_french_test.dart`.
  'listening_via_platform_service':
      'Écoute en cours… ta voix est traitée par le service de reconnaissance de ton téléphone.',
  'review_before_send':
      'Vérifie le récapitulatif avant envoi. KPB te répond sous 24–48 h.',
  'upcoming': 'À venir',
  'scholarship_tutorials':
      'Accède au pack de tutoriels vidéos exclusifs pour réussir ton dossier.',
  'scholarships_title': 'Bourses d\'études',
  'recommended_opportunities': 'Opportunités recommandées',
  'ranked_by_profile':
      'Classées selon ton profil et tes objectifs académiques.',
  'profile_compatibility': 'Compatibilité avec ton profil',
  'protect_app_access': 'Protéger l\'accès à l\'application',
  'logout_redirect_notice':
      'Tu seras redirigé vers l\'écran d\'accueil. Tes données locales seront effacées.',
  'profile_complete_optimized': 'Profil complet — recommandations optimisées ✨',
  'remaining_to_pay': 'Reste à payer',
  'academy_unlock_msg':
      'Tu vas débloquer la formation "@title" définitivement sur ton compte.',
  'coach_quota_exhausted':
      'Quota épuisé — Premium bientôt disponible ou contacte un conseiller KPB.',
  'application_sent_admin':
      'Candidature envoyée. Un admin examinera ton dossier sous 48h.',
  'no_verified_mentor':
      'Aucun mentor vérifié ne correspond à cette recherche pour l\'instant.',
  'community_intro':
      'Articles, guides et conseils de nos experts pour réussir ton projet d\'études.',
  'community_members': '+2 000 étudiants — Conseils, entraide & actu',
  'published_on': 'Publié le',
  'choose_second_uni': 'Choisissez une 2ème université',
  'compare_selected': '@n/2 sélectionnée(s)',
  'register_abroad_title': 'Inscriptions à l\'Étranger',
  'register_abroad_cta': 'S\'inscrire à l\'Étranger',
  'housing_intro':
      'Garantir ton logement est essentiel pour obtenir ton visa étudiant.',
  'estimated_monthly_rent_in': 'Loyer Mensuel Estimé à',
  'to_range': 'à',
  'privacy_policy_inline': 'politique de confidentialité',
  'parcours_intro':
      'Témoignages, conseils et parcours d\'étudiants accompagnés par KPB. Inspire-toi de leur expérience.',
  'parent_invite_share_hint':
      'Envoie ce code à ton enfant par WhatsApp. Il l\'entrera dans son application pour te lier.',
  'parent_create_code_hint':
      'Crée un code à 8 caractères et envoie-le par WhatsApp. Ton enfant pourra ensuite partager ses dossiers avec toi.',
  'parent_accept_code_hint':
      'Si un parent t\'a envoyé un code à 8 caractères, saisis-le ci-dessous pour lui donner un accès lecture à tes dossiers.',
  'prepare_departure': 'Prépare ton départ',
  'travel_intro':
      'Estime le prix du billet pour ton pays d\'études et achète au meilleur moment.',
  'travel_powered_by':
      'Propulsé par le comparateur indépendant Kayak. Les prix sont affichés en direct.',
  'other_results': 'autres résultats',
  'search_results_count': '@n résultat(s)',
  'doc_review_paste_hint':
      'Colle ton brouillon et obtiens un retour structuré en quelques secondes — points forts, axes d’amélioration et éléments manquants.',
  'roadmap_objective':
      'Objectif : rentrée @intake · @field. Voici les étapes, datées à rebours de l’échéance — coche-les au fur et à mesure.',
  'parent_share_case_title': 'Partager avec mon parent',
  'parent_share_case_subtitle':
      'Ton parent lié pourra suivre ce dossier (lecture seule).',
  'parent_visibility_error':
      'Impossible de mettre à jour le partage. Réessaie.',
  'view_official_source': 'Voir la source officielle',
  'nav_community': 'Communauté',
  'home_for_student': 'Ton tableau de bord',
  'home_for_parent': 'Tableau de bord parent',
  'home_for_partner': 'Espace partenariat',
  'book_consultation': 'Réserver une consultation',
  'request_support': 'Demander un accompagnement',
  'view_cases': 'Voir mes dossiers',
  'continue_orientation': 'Continuer mon orientation',
  'explore_fields': 'Explorer les filières',
  'explore_countries': 'Explorer les pays',
  // « Bourses pour toi » sur une liste qui n'est plus calculée pour le profil
  // (ordre par date de clôture, filtre de niveau seulement) aurait menti.
  'home_scholarships_title': 'Bourses à suivre',
  'my_plan_title': 'Mon plan',
  'my_plan_next_step': 'Prochaine étape : @step',
  'my_plan_step_profile': 'compléter ton profil',
  'my_plan_step_orientation': 'faire le test d\'orientation',
  'my_plan_step_dossier': 'ouvrir ton dossier d\'accompagnement',
  'my_plan_step_documents': 'fournir les documents demandés',
  'daily_scholarship_title': 'Bourse du jour',
  'daily_scholarship_badge_new': 'NOUVEAU',
  'daily_scholarship_pref_title': 'Bourse du jour',
  'daily_scholarship_pref_subtitle':
      'Une bourse mise en avant chaque jour. N\'affecte pas les autres notifications.',
  'weekly_digest_pref_title': 'Résumé hebdo',
  'weekly_digest_pref_subtitle':
      'Chaque lundi matin : bourses, échéances et prochaine étape de ton dossier. Rien ne t\'est envoyé s\'il n\'y a rien de neuf.',
  'parcours_weekly_pref_title': 'Récit de la semaine',
  'parcours_weekly_pref_subtitle':
      'Un parcours inspirant choisi par l\'équipe, le dimanche soir. Rien n\'est envoyé si aucun récit n\'est mis en avant.',
  'story_of_week_title': 'RÉCIT DE LA SEMAINE',
  'parcours_feed_title': 'Récits',
  'parcours_feed_cta': 'Voir les récits en plein écran',
  'parcours_feed_play': 'Lancer la vidéo',
  'parcours_feed_read': 'Lire l\'interview',
  'parcours_feed_swipe_hint': 'Glisse vers le haut pour le suivant',
  'profile_completion': 'Complétude du profil',
  'orientation_intro':
      'Réponds à quelques questions. KPB te propose des pistes de filières, des pays et des grandes écoles cohérents.',
  'start_orientation': 'Commencer',
  'restart_orientation': 'Recommencer',
  'orientation_results': 'Résultats de ton orientation',
  'why_it_fits': 'Pourquoi cela te correspond',
  'recommended_scholarships': 'Programmes liés',
  'case_summary': 'Résumé du dossier',
  'assigned_advisor': 'Conseiller assigné',
  'timeline': 'Historique',
  'messages': 'Messages',
  'documents': 'Documents',
  'send': 'Envoyer',
  'upload': 'Marquer comme fourni',
  'no_cases': 'Aucun dossier pour le moment',
  'saved_items': 'Éléments sauvegardés',
  'no_saved_items': 'Aucun élément sauvegardé',
  'partner_cta': 'Devenir partenaire',
  'contact_advisor': 'Contacter un conseiller',
  'request_submitted': 'Ta demande a été envoyée.',
  'create_case': 'Créer un dossier',
  'case_type': 'Type de demande',
  'description': 'Description',
  'contact_method': 'Méthode de contact',
  'submit': 'Soumettre',
  'close': 'Fermer',
  'saved': 'Sauvegardé',
  'save': 'Sauvegarder',
  'profile': 'Profil',
  'parent_support':
      'Comparez les destinations, les coûts et demandez un échange avec un conseiller.',
  'partner_support':
      'Présentez votre structure et nous organiserons un échange avec l’équipe KPB.',
  'kpb_offers': 'Offres KPB',
  'support_destinations': 'Pays d’accompagnement',
  'latest_articles': 'Articles récents',
  'forum_categories': 'Catégories forum',
  'topic_tags': 'Sujets populaires',
  // Niveaux d'étude
  'level_high_school': 'Lycée',
  'level_bachelor': 'Licence',
  'level_master': 'Master',
  'level_phd': 'Doctorat',
  // Niveaux de langue
  'lang_beginner': 'Débutant',
  'lang_intermediate': 'Intermédiaire',
  'lang_advanced': 'Avancé',
  // Documents
  'doc_passport': 'Passeport',
  'doc_cv': 'CV',
  'doc_transcripts': 'Relevés de notes',
  'doc_test_score': 'Score de test',
  // Champs de formulaire
  'first_name': 'Prénom',
  'last_name': 'Nom de famille',
  'field_required': 'Ce champ est obligatoire',
  'whatsapp_same_as_phone': 'Même numéro que le téléphone',
  // Auth
  'login_error': 'Email ou mot de passe incorrect.',
  'auth_welcome_title': 'Bienvenue sur KPB Education',
  'auth_welcome_subtitle':
      'Connecte-toi par email pour sauvegarder ton parcours, ou explore l’app en mode invité.',
  'auth_intelligence_title':
      'KPB Intelligence, ton guide pour étudier à l’étranger',
  // « 12 questions » ne correspondait à rien : l'onboarding étudiant compte 3
  // écrans (`_totalPages`, garde : honest_labels_guard_test.dart).
  'auth_intelligence_body':
      'Crée ton profil en 3 étapes et découvre des universités classées selon tes réponses.',
  'auth_intelligence_benefit_fit': 'Universités classées selon ton profil',
  // Ne nomme QUE le coach, seule surface KPB Intelligence en ligne en
  // build 49. La version précédente promettait « lettre, entretien » :
  // le générateur de lettres et le simulateur d'entretien sont masqués
  // par `AppConfig.aiToolsEnabled` (faux par défaut), donc le premier
  // écran vantait deux outils qu'un testeur ne peut pas atteindre.
  // Les trois sujets cités sont ceux du coach lui-même
  // (`coach_welcome_message`), pas une liste d'outils.
  'auth_intelligence_benefit_ai':
      'KPB Intelligence répond en français : écoles, budget, filières',
  'auth_intelligence_benefit_support': 'Accompagnement humain KPB via WhatsApp',
  'auth_receive_email_link': 'Recevoir un lien par email',
  'auth_explore_guest': 'Explorer sans compte',
  'auth_intelligence_note': 'Gratuit · FCFA · pensé pour l’Afrique francophone',
  'auth_continue_google': 'Continuer avec Google',
  'auth_google_error': 'Connexion Google impossible. Réessayez.',
  'auth_continue_email': 'Continuer avec mon email',
  'auth_continue_guest': 'Explorer sans compte',
  'auth_guest_hint':
      'Mode invité : consultation du catalogue uniquement. Connexion requise pour créer un dossier.',
  'auth_magic_email_title': 'Connexion par email',
  'auth_magic_email_body':
      'Nous t\'enverrons un code à 6 chiffres pour te connecter sans mot de passe.',
  'auth_magic_send_button': 'Envoyer le code',
  'auth_magic_send_error': 'Impossible d’envoyer le code. Réessayez.',
  'auth_magic_verify_title': 'Vérification',
  'auth_magic_verify_body': 'Saisissez le code reçu à @email (valide 15 min).',
  'auth_magic_verify_error': 'Code invalide ou expiré.',
  'auth_magic_verify_code_label': 'Code à 6 chiffres',
  'auth_magic_verify_button': 'Valider',
  'auth_magic_resend': 'Renvoyer le code',
  'auth_magic_resend_wait': 'Renvoyer dans @seconds s',
  'auth_magic_resend_cooldown': 'Veuillez patienter avant de renvoyer un code.',
  'auth_guest_profile_title': 'Connecte-toi pour accéder à ton profil',
  'auth_guest_profile_body':
      'Crée un compte pour suivre tes dossiers, sauvegarder des programmes et personnaliser ton parcours.',
  // Match explanations
  'match_complete_profile': 'Complète ton profil pour un matching personnalisé',
  'match_field_in_interests': 'Filière dans tes intérêts',
  'match_from_orientation': 'Recommandée par ton orientation',
  'match_available_target_country': 'Disponible dans tes pays cibles',
  'match_target_country': 'Pays cible',
  'match_in_target_country': 'Situé dans un pays cible',
  'match_kpb_partner': 'Partenaire KPB',
  'match_field_match': 'Filière correspondante',
  'match_general': 'Correspondance générale',
  // Case snackbar
  'case_created_title': 'Dossier créé ✅',
  'case_created_body': 'Ton dossier @code a bien été soumis.',
  // Contenu du dossier créé sur l'appareil, avant la réponse du serveur
  // (`submitCase`). Enregistré dans les deux langues avec le dossier.
  'case_local_next_step_title': 'Ton dossier est en revue',
  'case_local_next_step_body':
      'L’équipe KPB va étudier ta demande et vérifier tes informations. Ensuite, elle t’attribue un conseiller.',
  'case_local_submitted_title': 'Demande envoyée',
  'case_local_submitted_body':
      'Ta demande est dans l’onglet « Dossiers ». L’équipe KPB l’a reçue.',
  'case_local_welcome_sender': 'Équipe KPB',
  'case_local_welcome_body':
      'Merci pour ta demande. Nous revenons vers toi avec la prochaine étape.',
  'case_local_doc_profile_title': 'Profil académique complet',
  'case_local_student_reply_title': 'Réponse de l’étudiant',
  'case_local_student_reply_body':
      'Le dossier a été mis à jour avec un nouveau message.',
  'view': 'Voir',
  'anti_fraud_title': '🔒 Sécurité KPB',
  'anti_fraud_body':
      'KPB ne demande JAMAIS de paiement sur un numéro Mobile Money personnel, et aucun visa ni bourse n\'est garanti. En cas de doute, vérifie l\'identité du conseiller avant de payer quoi que ce soit.',
  'report_fraud': 'Signaler une fraude',
  'report_fraud_prefill':
      'Bonjour KPB, je souhaite signaler une tentative de fraude ou un comportement suspect.',
  'verified_advisor_title': 'Conseiller KPB vérifié',
  'verified_advisor_badge': 'Identité vérifiée (KYC)',
  'verified_advisor_official_name': 'Conseiller KPB officiel',
  'verified_advisor_expected': 'Numéro WhatsApp officiel à attendre :',
  'verified_advisor_check':
      'Vérifie que le numéro correspond exactement avant d\'écrire. KPB ne demande JAMAIS de paiement sur un numéro Mobile Money personnel.',
  'verified_advisor_prefill_label':
      'MESSAGE PRÉREMPLI — MODIFIABLE DANS WHATSAPP',
  'continue_to_whatsapp': 'Ouvrir WhatsApp',
  // Case status labels
  'status_submitted': 'Envoyé',
  'status_under_review': 'En revue',
  'status_documents_needed': 'Documents à envoyer',
  'status_counselor_assigned': 'Conseiller assigné',
  'status_awaiting_student': 'Action requise',
  'status_scheduled': 'Planifié',
  'status_in_progress': 'En cours',
  'status_application_submitted': 'Soumis',
  'status_waiting_decision': 'On attend la réponse',
  'status_awaiting_payment': 'Paiement requis',
  'status_completed': 'Terminé',
  'status_rejected': 'Refusé',
  'status_cancelled': 'Annulé',
  'status_draft': 'Brouillon',
  // Case detail
  'case_not_found': 'Ce dossier est introuvable.',
  'no_messages': 'Aucun message',
  'send_message_hint': 'Écris un message à ton conseiller.',
  'message_input_hint': 'Écrire un message…',
  // Cases screen
  'new_case': 'Nouvelle demande',
  'case_empty_hint': 'Crée ton premier dossier pour commencer avec KPB.',
  // Case composer
  'case_description_hint':
      'Dis à KPB ce dont tu as besoin, où tu en es dans ton projet, et ce que tu veux obtenir.',
  'case_default_title': 'J\'ai besoin d\'aide pour @title',
  // Connectivity
  'offline_title': 'Hors ligne',
  'offline_body':
      'Pas de connexion internet. Certaines fonctionnalités ne sont pas disponibles.',
  'online_title': 'En ligne',
  'online_body': 'Connexion rétablie.',
  // Auth screens
  'login_subtitle': 'Connecte-toi pour continuer',
  'login_button': 'Se connecter',
  'forgot_password_link': 'Mot de passe oublié ?',
  'no_account_prompt': 'Pas encore de compte ? ',
  'create_account_link': 'Créer un compte',
  'create_account_title': 'Créer un compte',
  'create_account_subtitle': 'Rejoignez +5 000 étudiants sur KPB Education',
  'create_account_button': 'Créer mon compte',
  'already_have_account': 'Déjà un compte ? ',
  'login_link': 'Se connecter',
  'full_name_required': 'Ton nom complet est requis',
  'full_name_hint': 'Entre ton prénom et ton nom',
  'email_required': 'Entre ton email',
  'email_invalid': 'Adresse email invalide',
  'phone_optional': 'Téléphone (optionnel)',
  'password_required': 'Entre ton mot de passe',
  'password_choose': 'Choisissez un mot de passe',
  'password_min_length': 'Le mot de passe doit contenir au moins 8 caractères',
  'password_helper': 'Minimum 8 caractères',
  // Forgot password
  'forgot_password_title': 'Mot de passe oublié',
  'reset_password_title': 'Réinitialiser le mot de passe',
  'reset_password_body':
      'Entre ton adresse email. Nous t\'enverrons un lien pour réinitialiser ton mot de passe.',
  'email_label': 'Adresse email',
  'send_link_button': 'Envoyer le lien',
  'back_to_login': 'Retour à la connexion',
  'email_sent_title': 'Email envoyé !',
  'email_sent_body':
      'Vérifie ta boîte email et suis le lien pour réinitialiser ton mot de passe.',
  'forgot_password_error':
      'Une erreur est survenue. Vérifiez l\'adresse email.',
  // Register errors
  'register_error_generic': 'Une erreur est survenue. Réessayez.',
  'register_error_email_exists': 'Un compte avec cet email existe déjà.',
  'register_error_network': 'Problème de connexion. Vérifie ton réseau.',
  // ── Parrainage (KPB-69) ──
  'copy': 'Copier',
  'referral_title': 'Parrainer un ami',
  'commercial_age_min': 'il y a @n min',
  'commercial_age_hour': 'il y a @n h',
  'commercial_age_day': 'il y a @n j',
  'commercial_tag_new': 'À répondre',
  'commercial_tag_qualified': 'Qualifié',
  'commercial_tag_converted': 'Signé KPB',
  'commercial_leads_title': 'Leads WhatsApp',
  'commercial_leads_sub': '@n à répondre · assignés en round-robin',
  'commercial_sla':
      'Objectif : première réponse sous 24 h. @n lead(s) dans ta file.',
  'commercial_filter_all': 'Tous',
  'commercial_filter_new': 'À répondre',
  'commercial_filter_qualified': 'Qualifiés',
  'commercial_filter_converted': 'Signés',
  'commercial_leads_empty': 'Aucun lead dans cette vue.',
  'commercial_cases_title': 'Dossiers suivis',
  'commercial_cases_sub': '@n dossier(s) actifs',
  'commercial_cases_empty': 'Aucun dossier actif pour l\'instant.',
  'commercial_converted_toast': 'Lead converti 🎉 @name est client(e) KPB',
  'commercial_convert_error': 'Conversion impossible pour le moment.',
  'commercial_wa_reply':
      'Bonjour @name, je suis votre conseiller KPB. Comment puis-je vous aider pour votre projet d\'études ?',
  'commercial_field_level': 'Niveau',
  'commercial_field_ref': 'Référence',
  'commercial_field_case': 'Dossier',
  'commercial_field_status': 'Statut',
  'commercial_profile_title': 'Profil transmis',
  'commercial_reply_wa': 'Répondre WhatsApp',
  'commercial_signed': 'Signé ✓',
  'commercial_mark_signed': 'Signé KPB',
  'commercial_perf_role': 'Conseiller KPB',
  'commercial_stat_total': 'Leads (total)',
  'commercial_stat_converted': 'Signés (30 j)',
  'commercial_stat_response': '1re réponse (moy.)',
  'commercial_perf_breakdown': 'Leads par statut',
  'commercial_perf_empty': 'Pas encore de leads.',
  'commercial_perf_note':
      'Le lead WhatsApp qualifié est la métrique de conversion n°1 de KPB.',
  'commercial_nav_leads': 'Leads',
  'commercial_nav_cases': 'Dossiers',
  'commercial_nav_perf': 'Performance',
  // ── Revue des documents par pièce (Feature D) ──
  'commercial_docs_title': 'Documents du dossier',
  'commercial_docs_sub': '@n document(s)',
  'commercial_docs_to_review': '@n à réviser',
  'commercial_docs_empty': 'Aucun document sur ce dossier pour le moment.',
  'commercial_doc_provided': 'Fourni',
  'commercial_doc_pending': 'En attente de dépôt',
  'commercial_doc_validate': 'Valider',
  'commercial_doc_redo': 'À refaire',
  'commercial_doc_doubtful': 'Douteux',
  'commercial_doc_status_validated': 'Validé',
  'commercial_doc_status_redo': 'À refaire',
  'commercial_doc_status_doubtful': 'Douteux',
  'commercial_doc_reviewed_by': 'Révisé par @name',
  'commercial_doc_reviewed_meta': 'Révisé par @name · @age',
  'commercial_doc_review_error':
      'Impossible d\'enregistrer la revue pour le moment.',
  // ── Ambassadeur (App-engagement · US-032→035) ──
  'referral_become_ambassador': 'Espace ambassadeur',
  'referral_become_ambassador_sub':
      'Gagne des FCFA en parrainant · retraits Wave',
  'amb_appbar': 'Espace ambassadeur',
  'amb_apply_title': 'Programme Ambassadeur',
  'amb_apply_body':
      'Le programme Ambassadeur ouvre sur candidature. Contacte un conseiller KPB pour le rejoindre, ou découvre notre programme de parrainage gratuit.',
  'amb_apply_cta_advisor': 'Contacter un conseiller',
  'amb_apply_cta_referral': 'Découvrir le parrainage',
  'amb_apply_wa_prefill':
      'Bonjour KPB, je souhaite candidater au programme Ambassadeur.',
  'amb_load_error': 'Impossible de charger ton espace ambassadeur.',
  'amb_sample_banner': 'Aperçu — active ton espace pour gagner des FCFA.',
  'amb_nav_dashboard': 'Tableau de bord',
  'amb_nav_referrals': 'Filleuls',
  'amb_nav_payout': 'Retraits',
  'amb_code_label': 'TON CODE DE PARRAINAGE',
  'amb_share': 'Partager',
  // @link en fin de message, sur sa propre ligne : sans lien, le
  // destinataire devait chercher l'app lui-même (revue vidéo du 08/08).
  'amb_share_message':
      'Rejoins KPB Éducation avec mon code @code et lance ton projet d\'études à l\'étranger 🎓\n@link',
  'amb_stat_active': 'Filleuls actifs',
  'amb_stat_placed': 'Placés 🎉',
  'amb_stat_earned': 'FCFA gagnés',
  'amb_objective_title': 'Objectif — @n filleuls',
  'amb_objective_hint':
      'Plus que @n — bonus de @bonus à @target filleuls inscrits.',
  'amb_how_title': 'Comment tu gagnes',
  'amb_reward_signup': 'Inscription avec ton code + quiz complété',
  'amb_reward_placed': 'Filleul placé dans une école via KPB',
  'amb_leaderboard_title': 'Classement @city',
  'amb_leaderboard_title_generic': 'Classement ambassadeurs',
  'amb_referrals_count': '@n filleuls',
  'amb_referrals_title': 'Mes filleuls',
  'amb_referrals_sub': '@n actifs · suivis en temps réel',
  'amb_referrals_tip':
      'Relance tes filleuls : un quiz complété = +1 000 FCFA chacun.',
  'amb_status_placed': 'Placé',
  'amb_status_application': 'Dossier en cours',
  'amb_status_quiz': 'Quiz ✓',
  'amb_status_premium': 'Premium',
  'amb_status_churned': 'Abandonné',
  'amb_status_relance': 'À relancer',
  'amb_payout_title': 'Retraits',
  'amb_payout_sub': 'Paiement Wave · sous 48 h',
  'amb_balance_label': 'SOLDE DISPONIBLE',
  'amb_wave_account': 'Compte Wave : @account',
  'amb_withdraw': 'Retirer @amount',
  'amb_withdraw_pending': 'Retrait en cours — sous 48 h ✓',
  'amb_withdraw_min': 'Retrait minimum @amount',
  'amb_withdraw_error': 'Retrait indisponible pour le moment.',
  'amb_history': 'HISTORIQUE',
  'amb_toast_share': 'WhatsApp s\'ouvre — code + lien d\'invitation prêts 📤',
  'amb_toast_withdraw': 'Retrait Wave demandé — @amount sous 48 h ✓',
  'amb_referrals_empty':
      'Aucun filleul pour l\'instant. Partage ton code pour commencer !',
  'amb_history_empty': 'Aucun mouvement pour l\'instant.',
  'referral_intro':
      'Invite tes amis sur KPB. Quand ils s\'inscrivent et lancent un dossier avec ton code, on suit ton impact.',
  'referral_your_code': 'Ton code de parrainage',
  'referral_invite_whatsapp': 'Inviter sur WhatsApp',
  'referral_invite_message':
      'Salut ! J\'utilise KPB Education pour mes études à l\'étranger (orientation, bourses, accompagnement visa). Inscris-toi et saisis mon code de parrainage : @code\n@link',
  'referral_friends_joined': 'Amis inscrits',
  'referral_friends_cases': 'Ont créé un dossier',
  'referral_have_code': 'Tu as un code de parrainage ?',
  'referral_code_hint': 'Saisis le code',
  'referral_redeem_cta': 'Valider le code',
  'referral_code_copied': 'Code copié',
  'referral_redeemed_ok': 'Code validé — merci ! Ton parrain est crédité.',
  'referral_redeemed_already': 'Tu as déjà utilisé un code de parrainage.',
  'referral_redeem_error': 'Code invalide. Vérifie et réessaie.',
  // ── Récompenses parrainage no-cash (KPB-77) ──
  'referral_credits_title': 'Mes crédits parrainage',
  'referral_credits_label': 'crédit(s)',
  'referral_credits_intro':
      'Un ami qui crée son dossier = 1 crédit. Échange tes crédits contre une relecture approfondie de ton dossier par un conseiller KPB.',
  'referral_redeem_voucher_cta': 'Échanger contre une relecture conseiller',
  'referral_credits_none':
      'Pas encore de crédit — invite un ami pour en gagner.',
  'referral_voucher_title': 'Ton bon KPB 🎁',
  'referral_voucher_body':
      'Montre ce code à ton conseiller sur WhatsApp pour débloquer ta relecture approfondie.',
  'referral_voucher_whatsapp_cta': 'Contacter mon conseiller',
  'referral_voucher_whatsapp_prefill':
      'Bonjour KPB Education, je souhaite utiliser mon bon parrainage @code pour une relecture approfondie de mon dossier.',
  'referral_voucher_error': 'Échec de l\'échange. Réessaie plus tard.',
  // ── Consentement IA (Coach) ──
  'coach_ai': 'KPB Intelligence',
  // Quota épuisé : ne pas laisser l'étudiant dans une impasse. Le moment
  // où il est le plus engagé est celui où l'on bascule vers un conseiller
  // humain — whatsapp_handoff est LA métrique de conversion de l'app.
  'coach_quota_handoff_title': 'Quota gratuit atteint',
  'coach_quota_handoff_body':
      'Tu as utilisé tes @quota messages gratuits de la semaine. Un conseiller KPB peut continuer la discussion avec toi sur WhatsApp, gratuitement.',
  'coach_quota_handoff_cta': 'Continuer avec un conseiller sur WhatsApp',
  // `coach_quota_reached_body` existe déjà plus haut dans ce bloc —
  // ne pas la redéclarer ici (clé dupliquée = avertissement d'analyse).
  'coach_wa_prefill':
      'Bonjour KPB, je discutais avec KPB Intelligence et je souhaite continuer avec un conseiller.',
  'coach_wa_prefill_topic': 'Mon dernier sujet : @topic',
  'ai_consent_title': 'Activer KPB Intelligence',
  'ai_consent_body':
      'Pour te répondre, KPB Intelligence envoie tes messages et des faits de profil (niveau d\'études, pays visés, tranche de budget, domaine) à un service d\'IA tiers (OpenRouter ou Groq) hébergé hors de ton pays. Ton nom civil n\'est pas recopié dans l\'invite. Le texte que tu colles (lettre, CV, message) part tel quel — n\'y mets pas d\'information que tu ne veux pas transmettre. Aucune décision importante ne repose sur l\'IA seule. Tu peux refuser et continuer à utiliser le reste de l\'app.',
  'ai_consent_accept': 'J\'active KPB Intelligence',
  'ai_consent_decline': 'Plus tard',
  'ai_tools_disclosure':
      'Cet outil envoie le texte saisi et des faits de profil (niveau, pays, domaine) à OpenRouter ou Groq (États-Unis). Ton nom n\'est pas recopié dans l\'invite. Aucune décision importante ne repose sur l\'IA seule.',
  'coach_load_error': 'Impossible de charger KPB Intelligence pour le moment.',
  // ── Mes données / RGPD ──
  'data_rights_section': 'Mes données',
  'export_data': 'Exporter mes données',
  'export_data_subject': 'Export de mes données KPB',
  // Partage système (audit 57, F12) : la feuille de partage n'a pas pu s'ouvrir.
  'share_error': 'Le partage n\'a pas pu s\'ouvrir. Réessaie.',
  'export_data_error':
      'Impossible d\'exporter tes données pour le moment. Réessaie.',
  'delete_account': 'Supprimer mon compte',
  'delete_account_confirm_title': 'Supprimer définitivement ton compte ?',
  'delete_account_confirm_body':
      'Cette action est irréversible. Toutes tes données (profil, dossiers, messages, favoris) seront définitivement supprimées de nos serveurs.',
  'delete_account_cta': 'Supprimer',
  'delete_account_error':
      'Suppression impossible pour le moment. Vérifie ta connexion et réessaie.',
  // ── Âge + consentement tuteur (mineurs) ──
  'birth_date': 'Date de naissance',
  'birth_date_hint': 'Sélectionne ta date de naissance',
  'onboarding_birthdate_required_title': 'Date de naissance requise',
  'onboarding_birthdate_required':
      'Indique ta date de naissance pour continuer.',
  'minor_guardian_title': 'Accord d\'un parent / tuteur',
  'minor_guardian_intro':
      'Tu as moins de 18 ans. Un parent ou tuteur doit donner son accord et ses coordonnées pour que tu utilises KPB (synchronisation des données et KPB Intelligence).',
  'guardian_name': 'Nom du parent / tuteur',
  'guardian_contact': 'Contact du parent / tuteur (WhatsApp ou email)',
  'guardian_consent_checkbox': 'Mon parent / tuteur a donné son accord.',
  'guardian_consent_required_title': 'Accord parental requis',
  'guardian_consent_required':
      'Renseigne le nom et le contact de ton parent/tuteur et coche son accord pour continuer.',
  // ── Communauté & alumni (KPB-70) ──
  'contact_mentor': 'Contacter ce mentor',
  'mentor_intro_prefill':
      'Bonjour KPB Education, je souhaite être mis(e) en relation avec votre mentor vérifié @who pour des conseils sur mon projet d\'études.',
  'community_hub_alumni': 'Mentors',
  'community_hub_salon': 'Salons',
  'community_hub_parcours': 'Parcours',
  // ── Mise à jour recommandée (bandeau doux, jamais bloquant) ──
  'update_recommended_title': 'Une mise à jour est disponible',
  'update_recommended_body':
      'Une nouvelle version de KPB Education est disponible. Mets-la à jour pour profiter des dernières nouveautés.',
  'update_recommended_cta': 'Mettre à jour',
  'update_recommended_dismiss': 'Plus tard',
  // ── Mise à jour obligatoire ──
  'force_update_title': 'Mise à jour requise',
  'force_update_body':
      'Cette version de l\'application n\'est plus prise en charge. Mets-la à jour pour continuer à utiliser KPB Education.',
  'force_update_cta': 'Mettre à jour',
  'force_update_contact_cta': 'Contacter un conseiller KPB',
  'force_update_prefill':
      "Bonjour, mon application KPB me demande une mise à jour mais je "
          "n'arrive pas à la faire. Pouvez-vous m'aider ?",
  // ── AHA moment post-onboarding (P0-D) ──
  'aha_loading': 'Calcul de tes compatibilités…',
  'aha_title': 'Tes écoles compatibles',
  'aha_title_named': '@name, voici tes @count écoles compatibles',
  'aha_subtitle':
      'Basé sur ton profil, voici les écoles qui te correspondent le mieux.',
  'aha_empty_body':
      'Pas encore de match — explore le catalogue pour découvrir les écoles.',
  'aha_estimate_note':
      'Estimation — complète ton profil pour plus de précision.',
  'aha_zone_green': 'Correspond très bien à ton profil',
  'aha_zone_yellow': 'Correspond en partie à ton profil',
  'aha_zone_blue': 'Moins aligné avec ton profil actuel',
  'aha_cta': 'Découvrir mon espace',
  'aha_see_all_cta': 'Voir toutes les universités',
  // ── PR2 · Écoles / Destinations / Fiche restyle (App-engagement) ──
  'uni_list_subtitle': 'Meilleurs matchs en tête, selon ton profil',
  'uni_list_subtitle_no_profile':
      'Complète ton profil pour voir tes meilleurs matchs',
  'uni_filter_matches': 'Meilleurs matchs',
  'uni_filter_france': '🇫🇷 France',
  'uni_filter_canada': '🇨🇦 Canada',
  'uni_filter_saved': '♥ Mes cibles',
  'uni_filter_budget': '< 3 M FCFA',
  'full_guide': 'GUIDE COMPLET',
  'guide_short': 'GUIDE',
  'school_fees_per_year': 'FRAIS / AN',
  'school_intake': 'RENTRÉE',
  'school_intake_on_request': 'Sur demande',
  'match_zone_tap_hint': 'Touche pour voir pourquoi',
  'match_zone_strong': 'Correspond bien à ton profil',
  'match_zone_good': 'Correspond en partie à ton profil',
  'match_zone_stretch': 'Peu de points communs avec ton profil',
  'match_zone_no_profile': 'Complète ton profil pour voir ton match',
  // Paliers qualitatifs d'adéquation au profil — jamais de % ni de
  // « chances d'admission » (conformité marque).
  'profile_fit_strong': 'Très bon match',
  'profile_fit_good': 'Bon match',
  'profile_fit_explore': 'À explorer',
  'create_application': 'Créer un dossier',
  'ask_kpb_counselor': 'Poser une question à un conseiller KPB',
  'country_guide_badge': 'GUIDE PAYS',
  'country_overview_highlights': 'Aperçu et points forts',
  'country_admission_routes': 'Voies et processus d\'admission',
  'country_tuition_living': 'Frais d\'études et coût de la vie',
  'country_visa_procedure': 'Procédure d\'obtention du visa étudiant',
  'country_verified_universities': 'Universités vérifiées',
  'country_support_services': 'Services d\'accompagnement KPB',
  'country_cost_estimate_body':
      'Chaque situation est différente : budget familial, bourses, '
          'logement… Contacte l\'équipe KPB pour une estimation '
          'personnalisée et à jour, lors de ta consultation gratuite.',
  'get_supported': 'Être accompagné',
  'dest_countries_heading': 'Pays',
  'dest_list_subtitle':
      'Guides complets : visa, coûts, universités, accompagnement',
  'dest_more_coming_tip':
      'D\'autres destinations (Émirats, Chine, Corée du Sud…) arrivent '
          'bientôt — dis-nous laquelle t\'intéresse.',
  // ── Success Lab ───────────────────────────────────────────────
  'success_lab_title': 'Atelier de réussite',
  'success_lab_subtitle':
      'Prépare chaque candidature étape par étape et retrouve ta progression, même hors connexion.',
  'success_lab_empty_title': 'Aucun atelier pour le moment',
  'success_lab_empty_body':
      'Choisis une bourse avec un cycle disponible pour commencer ta préparation.',
  'success_lab_empty_action': 'Voir les bourses',
  'success_lab_offline_title': 'Tu es hors connexion',
  'success_lab_offline_empty_body':
      'Aucun atelier enregistré sur cet appareil. Reconnecte-toi pour les charger.',
  'success_lab_offline_cached_body':
      'Version enregistrée affichée. Tes changements seront synchronisés au retour du réseau.',
  'success_lab_forbidden_title': 'Accès non autorisé',
  'success_lab_forbidden_body':
      'Connecte-toi avec un compte étudiant autorisé pour utiliser cet atelier.',
  'success_lab_disabled_title': 'Atelier indisponible',
  'success_lab_disabled_body':
      'Cette fonctionnalité n’est pas encore activée pour ton compte.',
  'success_lab_error_title': 'Impossible de charger l’atelier',
  'success_lab_error_body':
      'Une erreur est survenue. Réessaie dans quelques instants.',
  'success_lab_missing_identity':
      'Une session étudiante active est nécessaire.',
  'success_lab_cached_label':
      'Version enregistrée affichée pendant la mise à jour.',
  'success_lab_workspace_fallback': 'Candidature bourse',
  'success_lab_workspace_title': 'Mon atelier',
  'success_lab_progress_label': 'Progression de préparation',
  'success_lab_progress_disclaimer':
      'Cette progression mesure les étapes préparées, pas tes chances d’admission.',
  'success_lab_next_action': 'Prochaine action',
  'success_lab_deadline_confirmed': 'Date limite confirmée',
  'success_lab_deadline_estimated': 'Date limite estimée',
  'success_lab_status_started': 'Commencé',
  'success_lab_status_preparing': 'En préparation',
  'success_lab_status_ready_for_review': 'Prêt pour relecture',
  'success_lab_status_review_requested': 'Relecture demandée',
  'success_lab_status_submitted': 'Candidature envoyée',
  'success_lab_status_decision_received': 'Décision reçue',
  'success_lab_status_archived': 'Archivé',
  'success_lab_status_unknown': 'Statut à vérifier',
  'success_lab_steps_title': 'Étapes de préparation',
  'success_lab_steps_empty':
      'Les étapes de cet atelier ne sont pas encore disponibles.',
  'success_lab_category_profile': 'Profil et éligibilité',
  'success_lab_category_documents': 'Documents',
  'success_lab_category_form_essays': 'Formulaire et essais',
  'success_lab_category_review_submission': 'Relecture et envoi',
  'success_lab_category_unknown': 'Autre étape',
  'success_lab_step_not_started': 'À commencer',
  'success_lab_step_in_progress': 'En cours',
  'success_lab_step_completed': 'Terminée',
  'success_lab_step_not_applicable': 'Non applicable',
  'success_lab_step_status_unknown': 'Statut à vérifier',
  'success_lab_step_required': 'Obligatoire',
  'success_lab_step_complete': 'Marquer comme terminée',
  'success_lab_step_reopen': 'Rouvrir cette étape',
  'success_lab_step_queued': 'En attente de réseau',
  'success_lab_step_sending': 'Synchronisation',
  'success_lab_step_conflict': 'Conflit à résoudre',
  'success_lab_step_failed': 'Échec de synchronisation',
  'success_lab_retry': 'Réessayer la synchronisation',
  'success_lab_pending_changes_body':
      'Des changements locaux attendent d’être synchronisés.',
  'success_lab_diagnostic_title': 'Diagnostic de candidature',
  'success_lab_diagnostic_body':
      'Analyse structurée de la préparation, avec consentement explicite avant tout traitement IA.',
  'success_lab_diagnostic_action': 'Lancer le diagnostic',
  'success_lab_diagnostic_unavailable':
      'Le diagnostic est fermé pour ce compte ou ce pilote.',
  'success_lab_diagnostic_unavailable_title': 'Diagnostic indisponible',
  'success_lab_diagnostic_promise':
      'Une seule amélioration prioritaire, maintenant',
  'success_lab_diagnostic_disclaimer':
      'Ce diagnostic ne calcule pas tes chances d’admission, ne garantit aucun résultat et ne remplace pas un conseiller KPB.',
  'success_lab_diagnostic_loading': 'Vérification de ton diagnostic…',
  'success_lab_diagnostic_running':
      'Analyse en cours. Nous gardons la réponse courte pour limiter le coût et rester utile.',
  'success_lab_diagnostic_online_required':
      'Reconnecte-toi pour lancer ou consulter le diagnostic sécurisé.',
  'success_lab_ai_consent_checkbox':
      'J’ai lu cette notice et j’accepte ce traitement IA limité.',
  'success_lab_ai_consent_required':
      'Tu dois accepter la notice actuelle avant de lancer le diagnostic.',
  'success_lab_guardian_authorization_required':
      'Une autorisation vérifiée du responsable légal est nécessaire pour ce compte.',
  'success_lab_excerpt_title': 'Extrait facultatif',
  'success_lab_excerpt_body':
      'Tu peux coller un court extrait de CV ou de lettre. Retire les noms et coordonnées si possible.',
  'success_lab_excerpt_hint':
      'Exemple : une expérience de leadership ou un paragraphe à améliorer…',
  'success_lab_diagnostic_error_title': 'Diagnostic non terminé',
  'success_lab_diagnostic_error_body':
      'Le diagnostic n’a pas pu être chargé. Aucun nouvel appel payant ne sera lancé sans contrôle du backend.',
  'success_lab_diagnostic_strength': 'Ton point fort',
  'success_lab_diagnostic_priority': 'Ta priorité',
  'success_lab_diagnostic_rationale': 'Pourquoi maintenant',
  'success_lab_diagnostic_next_action': 'Prochaine action',
  'success_lab_diagnostic_stale_title': 'Ta candidature a évolué',
  'success_lab_diagnostic_stale_body':
      'Ce diagnostic correspond à une version antérieure de ton atelier. Il reste visible, sans relancer automatiquement un appel IA.',
  'success_lab_study_title': 'Étude par un conseiller',
  'success_lab_study_body':
      'Demande une étude humaine de ta préparation avant l’envoi.',
  'success_lab_study_action': 'Demander une étude',
  'success_lab_study_unavailable':
      'Cette option n’est pas activée pour ton compte.',
  'success_lab_study_unavailable_title': 'Étude indisponible',
  'success_lab_study_free_title': 'Première étude gratuite du dossier',
  'success_lab_study_decision_disclaimer':
      'Le conseiller KPB formule un avis et des prochaines étapes. La décision finale appartient toujours à l’établissement.',
  'success_lab_study_consent_checkbox':
      'J’ai lu cette notice et j’accepte de partager uniquement les versions sélectionnées avec un conseiller KPB.',
  'success_lab_study_documents_title': 'Documents à partager',
  'success_lab_study_document_kind': 'Type de document',
  'success_lab_study_document_title': 'Titre du document',
  'success_lab_study_add_document': 'Ajouter un document sécurisé',
  'success_lab_study_version_label': 'Version @number · @file · @size',
  'success_lab_study_delete_action': 'Supprimer cette version',
  'success_lab_study_deleting': 'Suppression en cours',
  'success_lab_study_delete_confirm_title': 'Supprimer cette version ?',
  'success_lab_study_delete_confirm_body':
      'Tu vas supprimer définitivement « @title » (@file) de KPB. Cette action ne sera jamais automatique et ne peut pas être annulée.',
  'success_lab_study_delete_confirm_action': 'Supprimer définitivement',
  'success_lab_study_delete_shared':
      'Cette version est déjà partagée avec une étude en cours. Elle ne peut pas être supprimée tant que cette étude reste ouverte.',
  'success_lab_study_message_label': 'Message au conseiller (facultatif)',
  'success_lab_study_message_hint':
      'Précise la bourse ciblée ou la question prioritaire à examiner.',
  'success_lab_study_submit_action': 'Envoyer pour étude',
  'success_lab_study_uploading': 'Téléversement sécurisé en cours…',
  'success_lab_study_submitting': 'Envoi de la demande…',
  'success_lab_study_submitted_title': 'Demande transmise',
  'success_lab_study_submitted_body':
      'Ta demande n°@number est enregistrée. Un conseiller KPB examinera uniquement les versions partagées.',
  'success_lab_study_online_required':
      'Reconnecte-toi pour partager les documents et envoyer la demande de façon sécurisée.',
  'success_lab_study_error_title': 'Demande non envoyée',
  'success_lab_study_error_body':
      'La demande n’a pas pu être terminée. Vérifie tes documents puis réessaie.',
  'success_lab_study_file_too_large':
      'Ce fichier dépasse la taille maximale autorisée de 10 Mo.',
  'success_lab_study_file_not_allowed':
      'Seuls les fichiers PDF, JPG et PNG sont acceptés.',
  'success_lab_study_document_required':
      'Ajoute et sélectionne au moins un document valide.',
  'success_lab_study_already_open':
      'Une demande d’étude est déjà ouverte pour cet atelier.',
  'success_lab_study_consent_required':
      'Tu dois accepter la notice actuelle avant de partager des documents.',
  'success_lab_study_complementing': 'Envoi sécurisé des compléments…',
  'success_lab_study_request_number': 'Demande d’étude n°@number',
  'success_lab_study_submitted_on':
      'Envoyée le @date (heure de ton appareil : @deviceZone). Fuseau du dossier : @zone.',
  'success_lab_study_missing_title': 'Éléments demandés',
  'success_lab_study_shared_title': 'Documents déjà partagés',
  'success_lab_study_complement_title': 'Compléter ma demande',
  'success_lab_study_complement_body':
      'Réponds précisément aux éléments demandés. Tu peux envoyer un message seul ou ajouter de nouvelles versions avec ton accord explicite.',
  'success_lab_study_complement_message': 'Réponse au conseiller',
  'success_lab_study_complement_message_hint':
      'Explique ce que tu as corrigé ou apporte l’information demandée.',
  'success_lab_study_complement_action': 'Envoyer les compléments',
  'success_lab_study_complement_not_allowed':
      'Les compléments ne peuvent être envoyés que lorsque le conseiller les demande.',
  'success_lab_study_complement_changed':
      'La demande a changé. Actualise avant de renvoyer tes compléments.',
  'success_lab_study_complement_required':
      'Ajoute une réponse ou sélectionne au moins un nouveau document.',
  'success_lab_study_choose_slot_action': 'Choisir un créneau',
  'success_lab_study_refresh_action': 'Actualiser le suivi',
  'success_lab_study_status_draft': 'Demande en préparation',
  'success_lab_study_status_submitted': 'Demande envoyée au conseiller',
  'success_lab_study_status_triaged': 'Demande examinée',
  'success_lab_study_status_more_information_needed':
      'Informations complémentaires nécessaires',
  'success_lab_study_status_call_offered': 'Créneaux proposés',
  'success_lab_study_status_scheduled': 'Rendez-vous planifié',
  'success_lab_study_status_converted_to_case': 'Accompagnement KPB créé',
  'success_lab_study_status_autonomy_recommended':
      'Poursuite autonome recommandée',
  'success_lab_study_status_declined': 'Demande non retenue',
  'success_lab_study_status_closed': 'Étude terminée',
  'success_lab_study_status_unknown':
      'État mis à jour — actualise l’application',
  'success_lab_study_next_complete_request': 'Termine puis envoie ta demande.',
  'success_lab_study_next_wait_for_triage':
      'Aucune action : un conseiller va examiner ta demande.',
  'success_lab_study_next_provide_more_information':
      'Réponds aux éléments demandés ci-dessous.',
  'success_lab_study_next_wait_for_slot_offer':
      'Aucune action : des créneaux vont bientôt être proposés.',
  'success_lab_study_next_choose_slot':
      'Choisis l’un des créneaux disponibles.',
  'success_lab_study_next_appointment_scheduled':
      'Ton rendez-vous est confirmé.',
  'success_lab_study_next_case_created':
      'Poursuis ton accompagnement dans ton dossier KPB.',
  'success_lab_study_next_continue_autonomously':
      'Continue ta préparation avec les recommandations reçues.',
  'success_lab_study_next_none': 'Aucune action supplémentaire pour le moment.',
  'success_lab_study_next_unknown':
      'Actualise pour recevoir la prochaine action.',
  'success_lab_schedule_title': 'Choisir un rendez-vous',
  'success_lab_schedule_choose_title': 'Créneaux disponibles',
  'success_lab_schedule_choose_body':
      'Sélectionne un seul créneau, vérifie les heures et confirme. La réservation nécessite une connexion.',
  'success_lab_schedule_offer_details':
      '@name · Heure affichée : ton appareil (@deviceZone) · Fuseau d’origine : @zone',
  'success_lab_schedule_confirm_action': 'Confirmer le créneau',
  'success_lab_schedule_confirm_title': 'Confirmer ce rendez-vous ?',
  'success_lab_schedule_confirm_body':
      '@date avec @name. Heure affichée sur ton appareil (@deviceZone) ; fuseau d’origine : @zone.',
  'success_lab_schedule_booking':
      'Confirmation du rendez-vous auprès du serveur…',
  'success_lab_schedule_booked_title': 'Rendez-vous confirmé',
  'success_lab_schedule_booked_body':
      '@date (heure de ton appareil : @deviceZone). Fuseau de réservation : @zone.',
  'success_lab_schedule_booked_recovered_body':
      'Le serveur confirme qu’un rendez-vous est planifié. Consulte tes notifications KPB pour les détails.',
  'success_lab_schedule_empty_title': 'Aucun créneau disponible actuellement',
  'success_lab_schedule_empty_body':
      'Les créneaux expirés ne sont jamais affichés. Actualise plus tard pour voir les nouvelles propositions.',
  'success_lab_schedule_waiting_title': 'Créneaux pas encore ouverts',
  'success_lab_schedule_waiting_body':
      'Ta demande est suivie, mais tu ne peux réserver qu’après la proposition d’un conseiller.',
  'success_lab_schedule_no_request_title': 'Aucune demande d’étude active',
  'success_lab_schedule_no_request_body':
      'Envoie d’abord une demande d’étude depuis ton atelier Success Lab.',
  'success_lab_schedule_online_required':
      'Reconnecte-toi pour consulter et réserver un créneau.',
  'success_lab_schedule_error_title': 'Créneaux momentanément indisponibles',
  'success_lab_schedule_error_body':
      'La réservation n’a pas été confirmée par le serveur. Réessaie avec le même choix.',
  'success_lab_schedule_expired':
      'Ce créneau a expiré. Sélectionne une autre proposition.',
  'success_lab_schedule_taken':
      'Ce créneau vient d’être pris. Sélectionne une autre proposition.',
  'success_lab_schedule_changed':
      'La demande a changé. Actualise les créneaux avant de réserver.',
  'success_lab_schedule_no_offer': 'Ce créneau n’est plus proposé.',
  'success_lab_schedule_retry':
      'La confirmation est encore en cours. Réessaie dans un instant.',
  'success_lab_submission_title': 'Déclarer ma soumission',
  'success_lab_submission_workspace_body':
      'Indique que ta candidature a réellement été envoyée et joins une preuve privée.',
  'success_lab_submission_open': 'Ouvrir mes soumissions',
  'success_lab_submission_intro_title':
      'Une déclaration factuelle, avec preuve',
  'success_lab_submission_intro_body':
      'KPB enregistre ce que tu déclares. La vérification de la preuve est affichée séparément et ne garantit aucun résultat.',
  'success_lab_submission_channel': 'Canal de soumission (facultatif)',
  'success_lab_submission_channel_hint': 'Ex. portail officiel, e-mail',
  'success_lab_submission_reference': 'Référence de candidature (facultatif)',
  'success_lab_submission_reference_private':
      'Transmise de façon chiffrée ; le serveur ne conserve qu’une empreinte HMAC.',
  'success_lab_submission_date': 'Date de soumission',
  'success_lab_submission_action': 'Déclarer la soumission',
  'success_lab_submission_sending': 'Enregistrement auprès du serveur…',
  'success_lab_submission_confirmed_body':
      'La déclaration a été enregistrée par le serveur. Son statut de vérification reste visible ci-dessous.',
  'success_lab_submission_history': 'Historique des soumissions',
  'success_lab_submission_history_empty': 'Aucune soumission déclarée.',
  'success_lab_submission_declared_label': 'Soumission déclarée',
  'success_lab_outcome_title': 'Admission et financement',
  'success_lab_outcome_workspace_body':
      'Déclare séparément la décision d’admission et le financement reçu.',
  'success_lab_outcome_open': 'Ouvrir mes décisions',
  'success_lab_outcome_intro_title':
      'Décisions déclarées, sans promesse ni inférence',
  'success_lab_outcome_intro_body':
      'L’établissement émet la décision. KPB vérifie uniquement la preuve ; admission et financement restent deux informations séparées.',
  'success_lab_outcome_current_admission': 'Admission actuelle',
  'success_lab_outcome_current_funding': 'Financement actuel',
  'success_lab_outcome_no_admission': 'Aucune décision d’admission déclarée.',
  'success_lab_outcome_no_funding': 'Aucune décision de financement déclarée.',
  'success_lab_outcome_declare_admission': 'Déclarer une décision d’admission',
  'success_lab_outcome_update_admission':
      'Déclarer une nouvelle décision d’admission',
  'success_lab_outcome_declare_funding': 'Déclarer une décision de financement',
  'success_lab_outcome_update_funding':
      'Déclarer une nouvelle décision de financement',
  'success_lab_outcome_issuer': 'Établissement émetteur',
  'success_lab_outcome_issuer_helper':
      'KPB n’est pas l’émetteur de la décision.',
  'success_lab_outcome_admission_decision': 'Décision d’admission',
  'success_lab_outcome_funding_decision': 'Décision de financement',
  'success_lab_outcome_received_date': 'Date de réception',
  'success_lab_outcome_choose_date': 'Choisir la date',
  'success_lab_outcome_device_timezone':
      'Date saisie dans le fuseau de ton appareil : @zone',
  'success_lab_outcome_save_admission': 'Enregistrer la décision d’admission',
  'success_lab_outcome_save_funding': 'Enregistrer le financement',
  'success_lab_outcome_amount_minor': 'Montant en unité monétaire mineure',
  'success_lab_outcome_amount_optional':
      'Facultatif. À renseigner avec la devise, uniquement pour un financement total ou partiel.',
  'success_lab_outcome_currency': 'Devise ISO à 3 lettres',
  'success_lab_outcome_history': 'Historique des décisions',
  'success_lab_outcome_history_empty': 'Aucune ancienne décision enregistrée.',
  'success_lab_outcome_evidence_title': 'Preuve privée obligatoire',
  'success_lab_outcome_evidence_body':
      'PDF, JPG ou PNG, 10 Mo maximum. Le fichier est analysé avant utilisation.',
  'success_lab_outcome_evidence_choose': 'Choisir une preuve',
  'success_lab_outcome_evidence_change': 'Changer la preuve',
  'success_lab_outcome_consent_loading':
      'Chargement de la notice de confidentialité…',
  'success_lab_outcome_consent_private':
      'Ce consentement couvre le stockage privé et la vérification KPB. Il n’autorise ni publication de témoignage ni statistique publique.',
  'success_lab_outcome_add_complement': 'Ajouter le complément demandé',
  'success_lab_outcome_granting_consent': 'Enregistrement de ton consentement…',
  'success_lab_outcome_uploading': 'Envoi et analyse de la preuve…',
  'success_lab_outcome_attaching': 'Ajout du complément…',
  'success_lab_outcome_saving_admission':
      'Enregistrement de la décision d’admission…',
  'success_lab_outcome_saving_funding':
      'Enregistrement de la décision de financement…',
  'success_lab_outcome_online_required':
      'Reconnecte-toi : les preuves et décisions ne sont jamais mises en attente sur cet appareil.',
  'success_lab_outcome_unavailable_title': 'Déclarations indisponibles',
  'success_lab_outcome_guardian_required':
      'Une autorisation du responsable légal est requise.',
  'success_lab_outcome_evidence_required':
      'Accepte la notice et joins une preuve avant de continuer.',
  'success_lab_outcome_scan_pending':
      'La preuve est encore en cours d’analyse. Réessaie dans un instant.',
  'success_lab_outcome_evidence_rejected':
      'Cette preuve a été refusée. Choisis un autre fichier propre et lisible.',
  'success_lab_outcome_superseded':
      'Cette décision a déjà été remplacée. Actualise l’historique.',
  'success_lab_outcome_changed':
      'Le dossier a changé. Les données ont été actualisées ; vérifie-les avant de réessayer.',
  'success_lab_outcome_invalid_amount':
      'Indique un montant entier positif et une devise ISO à trois lettres, ou laisse les deux champs vides.',
  'success_lab_outcome_file_too_large':
      'Le fichier dépasse la limite de 10 Mo.',
  'success_lab_outcome_file_not_allowed': 'Choisis un fichier PDF, JPG ou PNG.',
  'success_lab_outcome_error_body':
      'Le serveur n’a pas confirmé cette opération. Vérifie les données puis réessaie.',
  'success_lab_verification_declared': 'Déclarée par l’étudiant',
  'success_lab_verification_pending': 'Vérification en cours',
  'success_lab_verification_verified': 'Preuve vérifiée par KPB',
  'success_lab_verification_needs_information': 'Complément demandé par KPB',
  'success_lab_verification_rejected': 'Preuve rejetée par KPB',
  'success_lab_verification_unknown': 'Statut de vérification inconnu',
  'success_lab_admission_admitted': 'Admis(e)',
  'success_lab_admission_rejected': 'Non admis(e)',
  'success_lab_admission_waitlisted': 'Liste d’attente',
  'success_lab_admission_deferred': 'Décision reportée',
  'success_lab_admission_withdrawn': 'Candidature retirée',
  'success_lab_funding_full': 'Financement total',
  'success_lab_funding_partial': 'Financement partiel',
  'success_lab_funding_none': 'Aucun financement',
  'success_lab_funding_pending': 'Financement en attente',
  'success_lab_funding_not_applicable': 'Non applicable',
  'success_lab_outcome_unknown': 'Valeur inconnue',
  'success_lab_document_cv': 'CV',
  'success_lab_document_motivation': 'Lettre de motivation',
  'success_lab_document_essay': 'Essai',
  'success_lab_document_transcript': 'Relevé de notes',
  'success_lab_document_diploma': 'Diplôme',
  'success_lab_start_action': 'Préparer ma candidature',
  'success_lab_start_error_title': 'Atelier non créé',
  'success_lab_start_offline': 'Reconnecte-toi pour créer un nouvel atelier.',
  'success_lab_start_conflict':
      'Un atelier existe peut-être déjà. Actualise puis réessaie.',
  'success_lab_start_error_body':
      'Impossible de créer cet atelier pour le moment.',
  // ── Dossier / Application (App-engagement handoff) ─────────────
  'case_steps_heading': 'Étapes de ta demande',
  'case_step_your_turn': 'À toi',
  'case_document_photo_tip':
      'Pour les relevés de notes : prends une photo ou joins un PDF — '
          'les photos sont automatiquement compressées pour économiser '
          'tes données.',
  'case_interview_sim_title': 'Simulateur d\'entretien',
  'case_interview_sim_subtitle':
      'Entraîne-toi aux entretiens visa et admission avec un retour IA',
  'case_ai_review_subtitle':
      'Fais relire un document par l\'IA avant de l\'envoyer',
  // ── Bandeaux (KpbToast) ────────────────────────────────────────
  'toast_offline_pending_default':
      'C\'est gardé sur ton téléphone. On l\'envoie dès que tu es en ligne.',
  // ── États asynchrones (KpbAsyncView) ───────────────────────────
  'async_loading': 'Chargement…',
  'async_empty_title': 'Rien à afficher pour l\'instant',
  'async_updated_ago': 'Mis à jour @ago',
  'async_offline_data_from': 'Hors ligne — données du @date à @time',
  // ── Suivre une bourse, Mes suivis, notifications (chantier G) ──────
  'follow_scholarship_follow': 'Suivre',
  'follow_scholarship_following': 'Suivie',
  'follow_scholarship_a11y_follow': 'Suivre la bourse @title',
  'follow_scholarship_a11y_following':
      'Bourse suivie : @title. Touche pour ne plus la suivre',
  'push_primer_title': 'On te prévient dès qu\'elle ouvre',
  'push_primer_body':
      'Active les notifications pour savoir à temps quand une bourse que tu suis ouvre, et avant sa date limite. Tu peux les régler quand tu veux.',
  'push_primer_enable': 'Activer les notifications',
  'push_primer_later': 'Plus tard',
  'push_denied_title': 'Notifications coupées',
  'push_denied_body':
      'Tu ne recevras pas les alertes sur ton téléphone. Tu les retrouveras quand même dans l\'app, dans Notifications. Pour les rallumer, ouvre les réglages de l\'app.',
  'push_denied_open_settings': 'Ouvrir les réglages',
  'scholarship_notify_opening_title': 'Me prévenir à l\'ouverture',
  'scholarship_notify_opening_subtitle':
      'Une notification le jour où les candidatures ouvrent. Les rappels de date limite continuent.',
  'scholarship_notify_opening_global_off':
      'Tu as coupé les alertes d\'ouverture dans tes préférences de notification.',
  'scholarship_notify_opening_error':
      'Ton choix n\'a pas été enregistré. Réessaie quand tu es en ligne.',
  'scholarship_status_open': 'Ouverte · clôture le @date',
  'scholarship_status_open_no_date': 'Ouverte · date de clôture à confirmer',
  'scholarship_status_opens_on': 'Ouvre le @date',
  'scholarship_status_opening_estimated': 'Ouverture estimée : @date',
  'scholarship_status_opening_unknown': 'Date d\'ouverture à confirmer',
  'scholarship_status_closed': 'Clôturée',
  // ── Fiche d'une bourse : en-tête d'urgence, vérification, actions (I2) ──
  'scholarship_urgency_open': 'Ouverte · clôture @date',
  'scholarship_urgency_closing_soon': 'Clôture proche · @date',
  'scholarship_urgency_closing_estimated': 'Clôture estimée @date',
  'scholarship_urgency_date_to_confirm': 'Date à confirmer',
  'scholarship_urgency_last_day': 'Dernier jour pour candidater',
  'scholarship_urgency_one_day_left': 'Il te reste 1 jour pour candidater',
  'scholarship_urgency_days_left': 'Il te reste @count jours pour candidater',
  'scholarship_urgency_estimated_hint':
      'Estimation tirée des sessions précédentes : suis la bourse, on te prévient dès que les dates sont confirmées.',
  'scholarship_urgency_unknown_hint':
      'Les dates de la prochaine session ne sont pas encore publiées.',
  'scholarship_urgency_closed_hint':
      'Suis-la : on te prévient à l\'ouverture de la prochaine session.',
  'scholarship_verified_on': 'Vérifiée le @date',
  'scholarship_official_source': 'Source officielle',
  'scholarship_official_source_a11y':
      'Ouvrir la source officielle de cette bourse (site externe)',
  'scholarship_action_apply': 'Postuler',
  'scholarship_action_apply_a11y':
      'Postuler à @title sur le site officiel (site externe)',
  'scholarship_action_support': 'Être accompagné',
  'scholarship_action_support_a11y': 'Être accompagné par KPB pour @title',
  // ── Test « Mes 10 bourses » (chantier H) ──────────────────────────────
  'scholarship_match_entry_title': 'Test : quelles bourses pour moi ?',
  'scholarship_match_entry_body':
      '2 min · jusqu\'à 10 bourses · on t\'explique pourquoi',
  'scholarship_match_entry_guest_body':
      'Avec un compte, fais le test : jusqu\'à 10 bourses pour ton profil.',
  'scholarship_match_entry_cta': 'Faire le test',
  'scholarship_match_entry_run_title': 'Tes bourses : @counts',
  'scholarship_match_entry_run_body': 'Mis à jour le @date',
  'scholarship_match_entry_run_body_undated': 'Tes résultats du test',
  'scholarship_match_entry_view': 'Voir',
  'scholarship_match_entry_update': 'Mettre à jour',
  'scholarship_match_count_compatible': '@count compatibles',
  'scholarship_match_count_compatible_one': '1 compatible',
  'scholarship_match_count_to_verify': '@count à vérifier',
  'scholarship_match_count_to_verify_one': '1 à vérifier',
  'scholarship_match_flow_title': 'Mes bourses',
  'scholarship_match_flow_close': 'Quitter le test',
  'scholarship_match_leave_title': 'Quitter le test ?',
  'scholarship_match_leave_body':
      'Tes réponses sont gardées sur ce téléphone. Tu reprendras au même endroit.',
  'scholarship_match_leave_stay': 'Continuer le test',
  'scholarship_match_leave_quit': 'Quitter',
  'scholarship_match_intro_title': 'Quelles bourses pour moi ?',
  'scholarship_match_intro_body':
      '2 minutes. Tu réponds seulement à ce qui manque (@count questions).',
  'scholarship_match_intro_body_one':
      '2 minutes. Tu réponds seulement à ce qui manque (1 question).',
  'scholarship_match_intro_body_none':
      'Tes infos sont déjà là : vérifie-les, et c\'est parti.',
  'scholarship_match_intro_privacy':
      'Ta nationalité et ta date de naissance servent uniquement à vérifier les conditions des bourses.',
  'scholarship_match_intro_privacy_link': 'Politique de confidentialité',
  'scholarship_match_start': 'Commencer',
  'scholarship_match_apply': 'Valider',
  'scholarship_match_progress_a11y': 'Question @index sur @total',
  'scholarship_match_q_nationality': 'Ta nationalité',
  'scholarship_match_q_nationality_help': 'Celle de ton passeport.',
  // Consentement explicite à l'usage de la nationalité (décision du
  // propriétaire, 18/10/2026 : base légale = consentement, saisie facultative,
  // effaçable). Rédigé le 18/10/2026 — à relire par le propriétaire avant
  // soumission.
  'scholarship_match_nationality_optional':
      'C\'est facultatif : elle ne sert qu\'à ce test, et seulement avec ton accord.',
  'scholarship_match_nationality_consent':
      'J\'accepte que KPB Education utilise ma nationalité pour vérifier les conditions des bourses.',
  'scholarship_match_nationality_consent_help':
      'Elle reste sur ton profil tant que ton compte existe et n\'est transmise à aucune école. Tu peux retirer ton accord à tout moment avec « Effacer ma nationalité » dans « Mes 10 bourses », ou en écrivant à privacy@kpbeducation.com ; elle est aussi effacée avec ton compte.',
  'scholarship_match_nationality_consent_required':
      'Coche la case de consentement pour voir tes bourses.',
  'scholarship_match_nationality_suggestion':
      'Tu vis au pays « @country » : c\'est aussi ta nationalité ?',
  'scholarship_match_second_nationality': 'J\'ai une deuxième nationalité',
  'scholarship_match_second_nationality_set': 'Deuxième nationalité : @country',
  'scholarship_match_country_search': 'Chercher un pays',
  'scholarship_match_country_none': 'Aucun pays ne correspond.',
  'scholarship_match_q_residence': 'Ton pays de résidence',
  'scholarship_match_q_residence_help':
      'Certaines bourses dépendent du pays où tu vis.',
  'scholarship_match_q_birth_date': 'Ta date de naissance',
  'scholarship_match_q_birth_date_help':
      'Beaucoup de bourses ont une limite d\'âge.',
  'scholarship_match_q_diploma': 'Ton plus haut diplôme obtenu',
  'scholarship_match_q_target': 'Tu vises une bourse pour…',
  'scholarship_match_q_target_help':
      'Le niveau d\'études que tu veux faire avec la bourse.',
  'scholarship_match_target_diploma_hint':
      'Ce niveau demande en général un diplôme que tu n\'as pas encore. Tu peux le garder si tu l\'obtiens avant le départ.',
  'scholarship_match_q_fields': 'Tes domaines d\'études',
  'scholarship_match_q_fields_help': 'Jusqu\'à 3.',
  'scholarship_match_fields_undecided': 'Pas encore décidé',
  'scholarship_match_q_grade': 'Ta moyenne de la dernière année (sur 20)',
  'scholarship_match_q_grade_help': 'Une estimation suffit.',
  'scholarship_match_grade_other_scale': 'Mon système n\'est pas sur 20',
  'scholarship_match_grade_scale': 'Sur @scale',
  'scholarship_match_grade_scale_value': 'Ta moyenne',
  'scholarship_match_grade_converted': 'Sur 20 : @band',
  'scholarship_match_q_english': 'Ton niveau d\'anglais',
  'scholarship_match_q_french_optional': 'Et en français ? (facultatif)',
  'scholarship_match_q_french': 'Ton niveau de français',
  'scholarship_match_has_test_score': 'J\'ai un score de test',
  'scholarship_match_test_value': '@test : @score',
  'scholarship_match_test_score_label': 'Ton score (de @min à @max)',
  'scholarship_match_q_experience': 'Ton expérience professionnelle',
  'scholarship_match_q_experience_help':
      'Les stages comptent si tu étais payé à temps plein.',
  'scholarship_match_recap_title': 'Vérifie tes infos',
  'scholarship_match_recap_help':
      'Le test s\'appuie sur ces réponses. Corrige ce qui n\'est pas juste.',
  'scholarship_match_recap_nationality': 'Nationalité',
  'scholarship_match_recap_residence': 'Pays de résidence',
  'scholarship_match_recap_birth_date': 'Date de naissance',
  'scholarship_match_recap_guardian_done': 'Accord donné',
  'scholarship_match_recap_diploma': 'Plus haut diplôme',
  'scholarship_match_recap_target': 'Bourse visée',
  'scholarship_match_recap_fields': 'Domaines',
  'scholarship_match_recap_grade': 'Moyenne',
  'scholarship_match_recap_english': 'Anglais',
  'scholarship_match_recap_french': 'français : @level',
  'scholarship_match_recap_experience': 'Expérience professionnelle',
  'scholarship_match_recap_boosters': 'Pour plus de précision (facultatif)',
  'scholarship_match_recap_destinations': 'Pays visés',
  'scholarship_match_recap_test': 'Score de test',
  'scholarship_match_recap_improves_precision': 'Améliore la précision',
  'scholarship_match_recap_missing': 'À compléter',
  'scholarship_match_recap_edit': 'Modifier',
  'scholarship_match_recap_fill': 'Compléter',
  'scholarship_match_recap_edit_a11y': 'Modifier : @field',
  'scholarship_match_recap_complete_first':
      'Complète les lignes en rouge pour voir tes bourses.',
  'scholarship_match_submit': 'C\'est bon, voir mes bourses',
  'scholarship_match_analysing': 'On analyse @count bourses…',
  'scholarship_match_analysing_generic': 'On analyse les bourses…',
  'scholarship_match_still_missing': 'Il manque encore une information.',
  'scholarship_match_draft_kept': 'Tes réponses sont gardées.',
  'scholarship_match_load_error_title': 'Le test ne s\'ouvre pas',
  'scholarship_match_error_offline':
      'Pas de connexion. Réessaie quand tu es en ligne.',
  'scholarship_match_error_timeout': 'Le serveur met trop de temps à répondre.',
  'scholarship_match_error_rate_limited':
      'Trop d\'essais d\'un coup. Réessaie dans une minute.',
  'scholarship_match_error_session':
      'Ta session a expiré. Reconnecte-toi, puis réessaie.',
  'scholarship_match_error_unavailable':
      'Le test n\'est pas disponible pour le moment.',
  'scholarship_match_error_server': 'Le calcul n\'a pas abouti.',
  'scholarship_match_results_title': 'Tes bourses',
  'scholarship_match_results_header': 'Tes bourses — @date',
  'scholarship_match_offline': 'Hors ligne — résultats du @date',
  'scholarship_match_updating': 'Mise à jour de tes résultats…',
  'scholarship_match_needs_review':
      'Tes infos ont changé : vérifie-les pour mettre tes résultats à jour.',
  'scholarship_match_edit_info': 'Modifier mes infos',
  'scholarship_match_precision_kpb':
      'Une bonne partie de ces bourses n\'est pas encore entièrement analysée par KPB : lis leurs conditions officielles avant de postuler.',
  'scholarship_match_precision_answers':
      'Il nous manque des infos pour être plus précis : complète tes réponses.',
  'scholarship_match_empty':
      'Pas encore de bourse compatible dans notre catalogue.',
  'scholarship_match_empty_closed_return':
      'Certaines bourses fermées reviendront à l\'ouverture de leur prochaine session.',
  'scholarship_match_none_compatible':
      'Aucune bourse n\'est clairement compatible aujourd\'hui, @count sont à vérifier.',
  'scholarship_match_none_compatible_one':
      'Aucune bourse n\'est clairement compatible aujourd\'hui, 1 est à vérifier.',
  'scholarship_match_fewer': '@count bourses trouvées pour ton profil.',
  'scholarship_match_fewer_one': '1 bourse trouvée pour ton profil.',
  'scholarship_match_see_more_title': 'Comment en voir plus',
  'scholarship_match_see_more_edit': 'Vérifier mes réponses',
  'scholarship_match_section_compatible': 'Compatibles avec ton profil',
  'scholarship_match_section_to_verify': 'À vérifier avant de postuler',
  'scholarship_match_status_compatible': 'Compatible',
  'scholarship_match_status_to_verify': 'À vérifier',
  'scholarship_match_status_a11y': 'Statut : @status',
  'scholarship_match_unavailable': 'Plus disponible',
  'scholarship_match_new': 'Nouveau',
  'scholarship_match_window_a11y': 'Candidatures : @window',
  'scholarship_match_window_closed': 'Clôturée',
  'scholarship_match_window_suspended': 'Suspendue',
  'scholarship_match_window_open': 'Ouverte',
  'scholarship_match_window_open_until': 'Ouverte · clôture le @date',
  'scholarship_match_window_open_estimated_close':
      'Ouverte · clôture estimée : @month',
  'scholarship_match_window_opens_on': 'Ouvre le @date',
  'scholarship_match_window_estimated_open': 'Ouverture estimée : @month',
  'scholarship_match_window_estimated_close': 'Clôture estimée : @month',
  'scholarship_match_official_show': 'Voir la condition officielle',
  'scholarship_match_official_hide': 'Masquer la condition officielle',
  'scholarship_match_official_quote_label': 'Texte de l\'organisme :',
  'scholarship_match_official_source': 'Voir la source',
  'scholarship_match_case_cta': 'Être accompagné',
  'scholarship_match_case_title': 'Candidature — @title',
  'scholarship_match_success_lab_cta': 'Préparer avec Success Lab',
  'scholarship_match_whatsapp_a11y':
      'Écrire à un conseiller sur WhatsApp à propos de @title',
  'scholarship_match_whatsapp_prefill':
      'Bonjour KPB, le test « Mes bourses » m\'a proposé « @title ». Pouvez-vous m\'aider ?',
  'scholarship_match_advisor_prefill':
      'Bonjour KPB, j\'ai fait le test « Mes bourses » et j\'aimerais en parler avec un conseiller.',
  'scholarship_match_report_prefill':
      'Bonjour KPB, je pense qu\'il y a une erreur dans le test « Mes bourses » : « @group ».',
  'scholarship_match_needs_connection': 'Connexion nécessaire',
  'scholarship_match_excluded_title':
      'Pourquoi certaines bourses n\'apparaissent pas (@count)',
  'scholarship_match_excluded_report': 'Signaler une erreur',
  'scholarship_match_follow_all': 'Suivre les @count compatibles',
  'scholarship_match_follow_all_one': 'Suivre la bourse compatible',
  'scholarship_match_follow_all_done':
      'Tu suis maintenant @count bourses : on te prévient à l\'ouverture et avant la date limite.',
  'scholarship_match_share': 'Partager mes bourses',
  'scholarship_match_share_text':
      'Mes bourses trouvées avec KPB Education :\n@list\n\nFais le test toi aussi : @link',
  'scholarship_match_redo': 'Refaire le test',
  'scholarship_match_advisor': 'Parler à un conseiller',
  'scholarship_match_alerts_title':
      'Préviens-moi quand une nouvelle bourse compatible arrive',
  'scholarship_match_alerts_error':
      'Le réglage n\'a pas été enregistré. Réessaie.',
  // Accueil, fiche bourse, Profil et notifications (chantier H3).
  'home_hero_cta_find_scholarships_test': 'Trouve tes bourses (2 min)',
  'home_match_title': 'Tes bourses',
  'home_match_see_all': 'Voir mes @count bourses',
  'home_match_see_all_one': 'Voir ma bourse',
  // ── Accueil « Ta prochaine étape » (chantier K) ──
  'home_next_step_eyebrow': 'TA PROCHAINE ÉTAPE',
  'home_next_step_plan_a11y': 'Ton plan : @value sur 100',
  'home_next_step_label_deadline': 'Clôture proche',
  'home_next_step_subtitle_profile_test':
      'Le test des bourses (2 min) complète ton profil et trie les bourses pour toi.',
  'home_next_step_cta_case': 'Ouvrir le dossier',
  'home_next_step_cta_scholarship': 'Voir la bourse',
  'home_next_step_cta_test': 'Faire le test',
  'home_next_step_cta_profile': 'Compléter mon profil',
  'home_next_step_cta_orientation': 'Commencer le test',
  'home_next_step_cta_start_case': 'Démarrer mon dossier',
  'home_next_step_cta_explore': 'Explorer',
  'home_deadlines_title': 'Tes échéances',
  'home_intelligence_title': 'KPB Intelligence',
  'home_intelligence_body':
      'Pose tes questions sur les écoles, les bourses ou le budget.',
  'scholarship_match_assessment_title': 'Ton résultat au test',
  'scholarship_match_assessment_date': 'D\'après ton test du @date',
  'scholarship_match_assessment_not_in_run':
      'Cette bourse ne fait pas partie de tes résultats du test.',
  'scholarship_match_assessment_see_results': 'Voir mes résultats',
  'profile_quick_scholarship_match': 'Mes bourses compatibles',
  'scholarship_match_alerts_pref_title':
      'Nouvelles bourses compatibles (hebdo)',
  'scholarship_match_alerts_pref_subtitle':
      'Au plus une notification par semaine, quand une nouvelle bourse compatible avec ton test arrive.',
  'scholarship_match_disclaimer':
      'Le test vérifie les conditions principales publiées. La sélection reste décidée par l\'organisme.',
  'scholarship_match_diff_added': '@count nouvelles',
  'scholarship_match_diff_added_one': '1 nouvelle',
  'scholarship_match_diff_removed': '@count retirées',
  'scholarship_match_diff_removed_one': '1 retirée',
  'scholarship_match_diploma_none': 'Pas encore le bac',
  'scholarship_match_diploma_bac': 'Bac',
  'scholarship_match_diploma_bac_plus_2': 'Bac+2',
  'scholarship_match_diploma_licence': 'Licence',
  'scholarship_match_diploma_master': 'Master',
  'scholarship_match_diploma_doctorat': 'Doctorat',
  'scholarship_match_target_secondary': 'Lycée international (UWC)',
  'scholarship_match_target_bachelor': 'Licence',
  'scholarship_match_target_master': 'Master',
  'scholarship_match_target_doctorate': 'Doctorat',
  'scholarship_match_grade_lt10': 'Moins de 10',
  'scholarship_match_grade_10_12': '10 à 11,9',
  'scholarship_match_grade_12_14': '12 à 13,9',
  'scholarship_match_grade_14_16': '14 à 15,9',
  'scholarship_match_grade_16_plus': '16 ou plus',
  'scholarship_match_lang_none': 'Aucun',
  'scholarship_match_lang_a1_a2': 'Débutant',
  'scholarship_match_lang_b1': 'Je me débrouille (B1)',
  'scholarship_match_lang_b2': 'À l\'aise (B2)',
  'scholarship_match_lang_c1_c2': 'Courant',
  'scholarship_match_exp_none': 'Aucune',
  'scholarship_match_exp_lt12': 'Moins d\'1 an',
  'scholarship_match_exp_12_24': '1 à 2 ans',
  'scholarship_match_exp_24_36': '2 à 3 ans',
  'scholarship_match_exp_36_60': '3 à 5 ans',
  'scholarship_match_exp_60_plus': '5 ans ou plus',
  'scholarship_match_test_ielts': 'IELTS',
  'scholarship_match_test_toefl_ibt': 'TOEFL iBT',
  'scholarship_match_test_duolingo': 'Duolingo',
  'scholarship_match_test_tcf': 'TCF',
  'scholarship_match_test_tef': 'TEF',
  'followed_title': 'Mes suivis',
  'followed_scholarships_section': 'Bourses suivies',
  'followed_sort_label': 'Trier par',
  'followed_sort_status': 'Statut',
  'followed_sort_deadline': 'Date limite',
  'followed_sort_name': 'A–Z',
  'followed_empty_title': 'Tu ne suis encore aucune bourse',
  'followed_empty_body':
      'Touche « Suivre » sur une bourse : on te prévient à son ouverture et avant sa date limite.',
  'followed_empty_cta': 'Découvrir les bourses',
  'followed_removed': 'Tu ne suis plus « @title »',
  'followed_undo': 'Annuler',
  'followed_offline': 'Hors ligne — données du @date',
  'followed_detail_unavailable': 'Fiche indisponible pour le moment',
  'followed_opening_muted': 'Alerte d\'ouverture coupée',
  'followed_remove_a11y': 'Ne plus suivre @title',
  'notifications_group_today': 'Aujourd\'hui',
  'notifications_group_week': 'Cette semaine',
  'notifications_group_earlier': 'Plus tôt',
  'notif_cta_open_scholarship': 'Voir la bourse',
  'notif_cta_open_followed': 'Voir mes suivis',
  'notif_cta_deadline': 'Voir l\'échéance',
  'notif_cta_case': 'Ouvrir le dossier',
  'notif_cta_message': 'Lire le message',
  'notif_cta_open': 'Ouvrir',
  'followed_scholarship_pref_title': 'Bourses que je suis : ouverture',
  'followed_scholarship_pref_subtitle':
      'Une notification quand une bourse que tu suis ouvre. Les rappels de date limite continuent.',
  'notifications_push_granted_title': 'Notifications activées',
  'notifications_push_granted_subtitle':
      'Tu reçois les alertes sur ce téléphone.',
  'notifications_push_denied_subtitle':
      'Rallume-les dans les réglages de l\'app pour recevoir les alertes.',
  'notifications_push_settings_action': 'Réglages',
  // ── Visas étudiants américains suspendus (décision du 17/10/2026) ──────────
  // La liste des pays vient de /config/app (repli embarqué) : @countries.
  'us_visa_notice_title': 'Visa étudiant pour les États-Unis',
  'us_visa_notice_concerned': 'Ton pays est concerné.',
  'us_visa_notice_body':
      'Les demandes de visa étudiant sont actuellement suspendues pour les ressortissants de : @countries.',
  'us_visa_notice_check':
      'Vérifie ta situation sur travel.state.gov, ou écris-nous sur WhatsApp pour en parler.',
  'us_visa_notice_verified': 'Liste vérifiée le @date.',
  'us_visa_notice_official_cta': 'Voir la page officielle',
  'us_visa_notice_whatsapp_cta': 'En parler sur WhatsApp',
  'us_visa_whatsapp_prefill':
      'Bonjour KPB Education, je regarde les études aux États-Unis et j\'aimerais savoir si la suspension des visas étudiants me concerne.',
  // ── Universités : vue Partenaires / Tous (décision du 17/10/2026) ──────────
  'uni_view_switch_label': 'Universités à afficher',
  'uni_view_partners': 'Partenaires',
  'uni_view_all': 'Tous',
  'uni_view_count_semantics': '@label : @count formation(s)',
  'uni_partner_notice_title': 'Universités partenaires de KPB',
  // Décision du propriétaire du 17/10/2026 : pas de chiffre ni de garantie,
  // le lien direct avec l'université. Toujours suivi de
  // `uni_partner_notice_caveat`.
  'uni_partner_notice_body':
      'Cette vue montre les universités partenaires de KPB Éducation. KPB est en contact direct avec elles pour faciliter et accélérer ta procédure.',
  'uni_partner_notice_caveat': 'Attention : cela dépend de ton dossier.',
  'uni_partner_notice_switch_hint':
      'Pour voir toutes les universités et choisir n\'importe quelle destination, passe sur l\'onglet « Tous ».',
  'uni_partner_notice_cta': 'Voir toutes les universités',
  'uni_partner_notice_close': 'Fermer ce message',
  'uni_partner_reminder': 'Tu vois seulement les universités partenaires.',
  'uni_partner_reminder_cta': 'Voir tout',
  // ── Communauté d'entraide (C1 + C2) — docs/community-api-contract.md ──
  'comm_title': 'Communauté',
  'comm_home_title': 'Communauté KPB',
  'comm_home_body':
      'Pose ta question à des élèves, des alumni et des conseillers KPB. Partage ton expérience.',
  'comm_ask_question': 'Poser une question',
  'comm_articles': 'Articles et groupe WhatsApp',
  'comm_unavailable_title': 'La communauté arrive bientôt',
  'comm_unavailable_body':
      'Elle n\'est pas encore ouverte sur ton compte. Reviens un peu plus tard.',
  'comm_tab_for_you': 'Pour toi',
  'comm_tab_recent': 'Récents',
  'comm_tab_unanswered': 'Sans réponse',
  'comm_for_you_intro':
      'Des discussions liées aux bourses que tu suis, à tes pays visés et à ton niveau.',
  'comm_type_all': 'Tout',
  'comm_type_question': 'Question',
  'comm_type_experience': 'Retour d\'expérience',
  'comm_type_advice': 'Conseil',
  'comm_type_question_hint':
      'Tu cherches une info ? Les autres élèves et l\'équipe KPB t\'aident.',
  'comm_type_experience_hint':
      'Raconte ton parcours : ce qui a marché, ce qui a été dur.',
  'comm_type_advice_hint': 'Partage une astuce utile aux autres élèves.',
  'comm_trending': 'Sujets du moment',
  'comm_hashtag_filter': 'Voir les discussions #@tag',
  'comm_hashtag_clear': 'Retirer le filtre #@tag',
  'comm_hashtag_new': 'Nouveau sujet : #@tag',
  'comm_hashtag_posts': '@n discussions',
  'comm_badge_team': 'Équipe KPB',
  'comm_badge_advisor': 'Conseiller KPB',
  'comm_badge_alumni': 'Alumni vérifié',
  'comm_badge_ambassador': 'Ambassadeur',
  'comm_badge_assistant': 'Assistant KPB',
  'comm_assistant_notice':
      'Réponse préparée à partir des données vérifiées de KPB',
  'comm_assistant_notice_dated':
      'Réponse préparée à partir des données vérifiées de KPB · vérifié le @date',
  'comm_verified_answer': 'Réponse vérifiée',
  'comm_verified_answer_long': 'Réponse vérifiée par KPB',
  'comm_pinned': 'Épinglée',
  'comm_replies_none': 'Aucune réponse',
  'comm_replies_one': '1 réponse',
  'comm_replies_many': '@n réponses',
  'comm_helpful_one': '1 utile',
  'comm_helpful_many': '@n utiles',
  'comm_helpful_action': 'Utile',
  'comm_a11y_helpful_marked': 'Marqué utile, appuie pour retirer',
  'comm_a11y_by': 'Par @name',
  'comm_a11y_open_member': 'Voir le profil de @name',
  'comm_a11y_mention': '@type : @label',
  'comm_a11y_open_entity': '@type : @label. Ouvrir la fiche',
  'comm_entity_scholarship': 'Bourse',
  'comm_entity_country': 'Pays',
  'comm_entity_institution': 'École',
  'comm_entity_program': 'Formation',
  'comm_entity_open': 'Ouvrir la fiche',
  'comm_mentioned_title': 'Cité dans cette discussion',
  'comm_discussion': 'Discussion',
  'comm_edited': 'modifié',
  'comm_load_more': 'Voir plus',
  'comm_load_more_replies': 'Voir plus de réponses',
  'comm_offline_title': 'Tu es hors ligne',
  'comm_load_failed_title': 'Impossible de charger',
  'comm_empty_title': 'Pas encore de discussion',
  'comm_empty_body':
      'Pose la première question : d\'autres élèves se la posent sûrement aussi.',
  'comm_empty_unanswered_title': 'Toutes les questions ont une réponse',
  'comm_empty_unanswered_body':
      'Reviens plus tard pour aider d\'autres élèves.',
  'comm_empty_filtered_title': 'Aucune discussion avec ces filtres',
  'comm_clear_filters': 'Retirer les filtres',
  'comm_search_hint': 'Chercher une discussion ou un #sujet',
  'comm_search_action': 'Rechercher',
  'comm_search_intro_title': 'Cherche dans la communauté',
  'comm_search_intro_body':
      'Tape au moins 2 lettres : une bourse, un pays, une école ou un #sujet.',
  'comm_search_empty_title': 'Aucun résultat',
  'comm_search_empty_body': 'Essaie un autre mot, ou pose ta question.',
  'comm_my_posts': 'Mes publications',
  'comm_my_posts_empty': 'Tu n\'as encore rien publié.',
  'comm_following': 'Discussions suivies',
  'comm_following_empty': 'Tu ne suis aucune discussion pour l\'instant.',
  'comm_menu_tooltip': 'Plus d\'options',
  'comm_menu_edit': 'Modifier',
  'comm_menu_delete': 'Supprimer',
  'comm_menu_report_post': 'Signaler la publication',
  'comm_menu_report_reply': 'Signaler la réponse',
  'comm_menu_report_member': 'Signaler ce membre',
  'comm_menu_block': 'Bloquer @name',
  'comm_follow_tooltip': 'Suivre la discussion',
  'comm_unfollow_tooltip': 'Ne plus suivre la discussion',
  'comm_follow_on':
      'Tu suis cette discussion : tu seras prévenu des nouvelles réponses.',
  'comm_follow_off': 'Tu ne suis plus cette discussion.',
  'comm_no_replies': 'Pas encore de réponse. Tu sais ? Aide cet élève.',
  'comm_no_replies_author':
      'Pas encore de réponse. Tu seras prévenu dès qu\'il y en a une.',
  'comm_reply_hint': 'Écris une réponse… (@ pour citer une bourse)',
  'comm_reply_send': 'Envoyer la réponse',
  'comm_reply_sent': 'Réponse publiée. Merci pour ton aide !',
  'comm_reply_updated': 'Réponse modifiée.',
  'comm_edit_reply_title': 'Modifier ta réponse',
  'comm_delete_post_title': 'Supprimer ta publication ?',
  'comm_delete_reply_title': 'Supprimer ta réponse ?',
  'comm_delete_body': 'Elle ne sera plus visible. Cette action est définitive.',
  'comm_delete_action': 'Supprimer',
  'comm_deleted': 'Supprimé.',
  'comm_blocked_content':
      'Tu as bloqué ce membre : tu ne vois plus ses contenus.',
  'comm_block_action': 'Bloquer',
  'comm_unblock_action': 'Débloquer',
  'comm_block_confirm_title': 'Bloquer @name ?',
  'comm_block_confirm_body':
      'Tu ne verras plus ses publications ni ses réponses, et il ne verra plus les tiennes. Il n\'est pas prévenu. Tu peux le débloquer à tout moment dans Profil.',
  'comm_block_done': '@name est bloqué.',
  'comm_unblock_done': '@name est débloqué.',
  'comm_blocked_title': 'Utilisateurs bloqués',
  'comm_blocked_intro':
      'Tu ne vois pas leurs publications et ils ne voient pas les tiennes.',
  'comm_blocked_empty_title': 'Aucun utilisateur bloqué',
  'comm_blocked_empty_body':
      'Si un membre te dérange, ouvre son profil ou le menu ⋯ d\'une publication.',
  'comm_member_title': 'Profil du membre',
  'comm_member_not_found': 'Ce profil n\'est pas disponible.',
  'comm_member_helpful': 'Réponses utiles',
  'comm_member_posts': 'Publications',
  'comm_member_replies': 'Réponses',
  'comm_member_since': 'Membre depuis @month',
  'comm_member_privacy':
      'Pour ta sécurité, la communauté ne montre jamais d\'e-mail, de téléphone ni d\'âge, et il n\'y a pas de messages privés.',
  'comm_report_post_title': 'Signaler la publication',
  'comm_report_reply_title': 'Signaler la réponse',
  'comm_report_member_title': 'Signaler ce membre',
  'comm_report_intro':
      'Ton signalement reste anonyme. L\'équipe KPB le regarde sous 24 h.',
  'comm_report_reason_scam': 'Arnaque ou demande d\'argent',
  'comm_report_reason_harassment': 'Harcèlement ou insulte',
  'comm_report_reason_inappropriate': 'Contenu choquant',
  'comm_report_reason_spam': 'Publicité ou spam',
  'comm_report_reason_personal_info': 'Coordonnées ou infos personnelles',
  'comm_report_reason_misinformation': 'Fausse information',
  'comm_report_reason_other': 'Autre chose',
  'comm_report_details_label': 'Détails (facultatif)',
  'comm_report_details_hint': 'Explique en quelques mots ce qui ne va pas.',
  'comm_report_send': 'Envoyer le signalement',
  'comm_report_sent': 'Merci. L\'équipe KPB va regarder sous 24 h.',
  'comm_charter_title': 'Charte de la communauté',
  'comm_charter_intro':
      'Quatre règles simples pour que chacun se sente en sécurité.',
  'comm_charter_rule_1_title': 'Bienveillance',
  'comm_charter_rule_1_body':
      'Respecte chaque élève. Pas d\'insulte, pas de moquerie.',
  'comm_charter_rule_2_title': 'Jamais d\'argent',
  'comm_charter_rule_2_body':
      'Ne demande et n\'envoie jamais d\'argent. Un « agent » qui promet une bourse contre des frais est une arnaque.',
  'comm_charter_rule_3_title': 'Pas de coordonnées',
  'comm_charter_rule_3_body':
      'Ne partage ni numéro, ni WhatsApp, ni adresse. Tout se passe ici.',
  'comm_charter_rule_4_title': 'Des infos vérifiables',
  'comm_charter_rule_4_body':
      'Partage ce que tu sais vraiment, avec la source officielle si tu l\'as.',
  'comm_charter_footer':
      'Les messages qui ne respectent pas la charte peuvent être masqués par l\'équipe KPB.',
  'comm_charter_accept': 'J\'ai compris',
  'comm_charter_failed':
      'Impossible d\'enregistrer ton accord. Vérifie ta connexion, puis réessaie.',
  'comm_got_it': 'J\'ai compris',
  'comm_restriction_read_only_title': 'Lecture seule',
  'comm_restriction_ban_title': 'Publication suspendue',
  'comm_restriction_reason': 'Motif : @reason',
  'comm_restriction_read_ok': 'Tu peux toujours lire les discussions.',
  'comm_composer_title': 'Nouvelle publication',
  'comm_composer_edit_title': 'Modifier ta publication',
  'comm_composer_type_label': 'Type de publication',
  'comm_composer_title_label': 'Titre',
  'comm_composer_title_hint': 'Ex. : Délai de réponse de Campus France ?',
  'comm_composer_title_min': 'Au moins @n caractères.',
  'comm_composer_body_label': 'Ton message',
  'comm_composer_body_hint':
      'Donne le contexte : ton niveau, le pays visé, ce que tu as déjà fait.',
  'comm_composer_body_helper':
      'Tape @ pour citer une bourse, un pays, une école ou une formation, et # pour un sujet.',
  'comm_composer_body_min': 'Ton message doit faire au moins @n caractères.',
  'comm_composer_mentions_label': 'Citées dans ton message :',
  'comm_composer_safety':
      'Ne partage jamais ton numéro ni ton WhatsApp, et n\'envoie jamais d\'argent. Un message avec ces éléments est relu par l\'équipe KPB avant d\'être visible.',
  'comm_composer_preview': 'Aperçu',
  'comm_composer_edit': 'Modifier',
  'comm_composer_preview_note': 'Voici ce que les autres élèves verront.',
  'comm_composer_publish': 'Publier',
  'comm_composer_save': 'Enregistrer',
  'comm_discard_title': 'Abandonner ta publication ?',
  'comm_discard_body': 'Ce que tu as écrit sera perdu.',
  'comm_discard_keep': 'Continuer à écrire',
  'comm_discard_confirm': 'Abandonner',
  'comm_post_published': 'Publié ! Tu seras prévenu des réponses.',
  'comm_post_updated': 'Publication modifiée.',
  'comm_pending_title': 'Ta publication est en cours de vérification',
  'comm_pending_body':
      'Pour protéger la communauté des arnaques, certains messages sont relus par l\'équipe KPB avant d\'être visibles. Ça arrive à beaucoup d\'élèves : ton message n\'est pas perdu.',
  'comm_pending_tip':
      'La vérification prend en général moins de 24 h. Tu la retrouves dans « Mes publications ».',
  'comm_moderation_pending_title': 'En cours de vérification',
  'comm_moderation_pending_body':
      'Seul toi la vois pour l\'instant. L\'équipe KPB la relit, en général sous 24 h.',
  'comm_moderation_hidden_title': 'Masquée par l\'équipe KPB',
  'comm_moderation_hidden_body':
      'Elle ne respectait pas la charte. Seul toi la vois.',
  'comm_mention_type_more':
      'Tape le nom d\'une bourse, d\'un pays, d\'une école ou d\'une formation.',
  'comm_suggest_loading': 'Recherche des suggestions',
  'comm_suggest_failed':
      'Suggestions indisponibles. Tu peux continuer à écrire.',
  'comm_suggest_none': 'Rien trouvé dans le catalogue KPB.',
  'comm_section_title': 'Discussions (@n)',
  'comm_section_intro': 'Ce que les élèves disent de @label.',
  'comm_section_empty':
      'Aucune discussion sur @label pour l\'instant. Pose la première question.',
  'comm_section_ask': 'Poser une question sur @label',
  'comm_space_empty_title': 'Aucune discussion sur @label',
  'comm_space_empty_body':
      'Pose la première question : un élève ou un conseiller KPB te répondra.',
  'comm_discussions_count': '@n discussions',
  'comm_notif_pref_title': 'Communauté',
  'comm_notif_pref_subtitle':
      'Réponses à tes publications et aux discussions que tu suis',
  'notif_cta_open_discussion': 'Voir la discussion',
  'comm_err_offline': 'Pas de connexion. Vérifie ton réseau, puis réessaie.',
  'comm_err_timeout': 'Le réseau est lent. Réessaie dans un instant.',
  'comm_err_generic': 'Un souci est survenu. Réessaie dans un instant.',
  'comm_err_disabled': 'La communauté n\'est pas disponible pour le moment.',
  'comm_err_students_only': 'La communauté est réservée aux comptes élèves.',
  'comm_err_charter': 'Accepte la charte de la communauté pour publier.',
  'comm_err_read_only':
      'Ton compte est en lecture seule : tu ne peux pas publier pour l\'instant.',
  'comm_err_read_only_until':
      'Ton compte est en lecture seule jusqu\'au @date.',
  'comm_err_banned':
      'Tu ne peux plus publier dans la communauté. Tu peux toujours lire les discussions.',
  'comm_err_rate_posts':
      'Tu as atteint la limite de @limit publications par jour. Réessaie demain.',
  'comm_err_rate_replies':
      'Tu as atteint la limite de @limit réponses par heure. Réessaie un peu plus tard.',
  'comm_err_rate_replies_wait':
      'Tu as atteint la limite de @limit réponses par heure. Réessaie dans @minutes min.',
  'comm_err_rate_reports':
      'Tu as envoyé beaucoup de signalements aujourd\'hui. Réessaie demain.',
  'comm_err_rate_wait': 'Trop de demandes. Réessaie dans @minutes min.',
  'comm_err_rate_generic': 'Trop de demandes. Réessaie un peu plus tard.',
  'comm_err_not_found': 'Cette discussion n\'est plus disponible.',
  'comm_err_not_author': 'Seul l\'auteur peut modifier ce contenu.',
  'comm_err_edit_window':
      'Le délai de modification (15 min) est passé. Tu peux toujours supprimer.',
  'comm_err_post_not_open':
      'Les réponses s\'ouvriront une fois la publication vérifiée.',
  'comm_err_invalid_mention':
      'Une bourse, un pays ou une école cité n\'est plus disponible. Retire la puce, puis réessaie.',
  'comm_err_too_many_mentions': '10 mentions au maximum par message.',
  'comm_err_too_many_hashtags': '10 sujets (#) au maximum par publication.',
  'comm_err_react_own':
      'Tu ne peux pas marquer ton propre message comme utile.',
  'comm_err_self': 'Impossible sur ton propre compte.',
  'comm_err_block_team':
      'L\'équipe KPB ne peut pas être bloquée. Tu peux signaler un message.',
  'comm_err_validation':
      'Vérifie la longueur du titre et du message, puis réessaie.',
  'comm_month_1': 'janvier @year',
  'comm_month_2': 'février @year',
  'comm_month_3': 'mars @year',
  'comm_month_4': 'avril @year',
  'comm_month_5': 'mai @year',
  'comm_month_6': 'juin @year',
  'comm_month_7': 'juillet @year',
  'comm_month_8': 'août @year',
  'comm_month_9': 'septembre @year',
  'comm_month_10': 'octobre @year',
  'comm_month_11': 'novembre @year',
  'comm_month_12': 'décembre @year',
  // Bot « Passerelle » (C3 bis) — notification privée `assist_bridge`.
  'assist_bridge_badge': 'Assistant KPB',
  'assist_bridge_from': 'Un message de l\'équipe KPB',
  'assist_bridge_sheet_title': 'Tu peux le faire directement dans l\'app',
  'assist_bridge_body_document_review':
      'Colle ton CV ou ta lettre de motivation dans l\'outil de relecture : tu reçois des conseils pour l\'améliorer.',
  'assist_bridge_body_scholarship_match':
      'Fais le test « Mes 10 bourses » : il te montre les bourses qui correspondent à ton profil, d\'après leurs conditions officielles.',
  'assist_bridge_body_etudes_en_france':
      'L\'espace « Études en France » t\'aide à préparer ta procédure, avec le catalogue des formations.',
  'assist_bridge_body_accompaniment':
      'Ouvre un dossier dans l\'app : un conseiller KPB t\'aide à préparer ta candidature.',
  'assist_bridge_body_visa':
      'La page Services présente l\'aide de KPB pour préparer ta demande de visa.',
  'assist_bridge_body_school_choice':
      'Fais le test d\'orientation : il t\'aide à repérer les formations et les écoles qui vont avec ton profil.',
  'assist_bridge_body_generic':
      'Une fonction de l\'app peut t\'aider pour ce que tu cherches.',
  'assist_bridge_cta_document_review': 'Faire relire mon CV ou ma lettre',
  'assist_bridge_cta_scholarship_match': 'Faire le test « Mes 10 bourses »',
  'assist_bridge_cta_etudes_en_france': 'Ouvrir Études en France',
  'assist_bridge_cta_accompaniment': 'Ouvrir un dossier',
  'assist_bridge_cta_visa': 'Voir l\'aide visa',
  'assist_bridge_cta_school_choice': 'Faire le test d\'orientation',
  'assist_bridge_cta_generic': 'Ouvrir la fonction',
  'assist_bridge_whatsapp': 'Écrire à KPB sur WhatsApp',
  'assist_bridge_later': 'Plus tard',
  'assist_bridge_settings_hint':
      'Tu peux couper ces suggestions dans tes préférences de notification.',
  'assist_bridge_document_review_prefill':
      'Bonjour KPB Education, j\'aimerais de l\'aide pour relire mon CV ou ma lettre de motivation.',
  'assist_bridge_scholarship_match_prefill':
      'Bonjour KPB Education, j\'aimerais de l\'aide pour trouver une bourse.',
  'assist_bridge_etudes_en_france_prefill':
      'Bonjour KPB Education, j\'aimerais de l\'aide pour ma procédure Études en France.',
  'assist_bridge_accompaniment_prefill':
      'Bonjour KPB Education, j\'aimerais être accompagné(e) pour mon dossier de candidature.',
  'assist_bridge_visa_prefill':
      'Bonjour KPB Education, j\'aimerais de l\'aide pour préparer ma demande de visa.',
  'assist_bridge_school_choice_prefill':
      'Bonjour KPB Education, j\'aimerais de l\'aide pour choisir une école ou une formation.',
  'assist_bridge_generic_prefill':
      'Bonjour KPB Education, j\'aimerais de l\'aide pour mon projet d\'études.',
  'assist_bridge_pref_title': 'Suggestions de l\'équipe KPB',
  'assist_bridge_pref_subtitle':
      'Quand tu cherches de l\'aide, on te montre la fonction de l\'app qui peut t\'aider',
  'notif_cta_assist_bridge': 'Voir comment faire',
  // Correctifs 57 (XC-06) — nouvelles et offres de KPB.
  // Chantier juridique 57 (App Store 4.5.4) : le push promotionnel est un
  // OPT-IN, désactivé par défaut.
  'kpb_promotions_pref_title': 'Nouvelles et offres de KPB par notification',
  'kpb_promotions_pref_subtitle':
      'Désactivé par défaut. Active-le pour recevoir par notification les annonces et offres de l\'équipe KPB ; tu peux le couper à tout moment (les messages sur ton compte et tes dossiers continuent)',
  'profile_promotions_email': 'Nouvelles et offres de KPB par e-mail',
  'profile_promotions_email_desc':
      'Recevoir par e-mail les nouvelles et offres de KPB Education (désinscription à tout moment)',
  // Correctifs 57 — « Effacer ma nationalité ».
  'scholarship_match_erase_nationality': 'Effacer ma nationalité',
  'scholarship_match_erase_nationality_title': 'Effacer ta nationalité ?',
  'scholarship_match_erase_nationality_body':
      'Ta nationalité sera effacée de ton profil, avec les résultats du test calculés avec elle. Pour revoir tes bourses, il faudra refaire le test.',
  'scholarship_match_erase_nationality_cancel': 'Annuler',
  'scholarship_match_erase_nationality_confirm': 'Effacer',
  'scholarship_match_erase_nationality_done':
      'Ta nationalité et tes résultats ont été effacés.',
  'scholarship_match_erase_nationality_error':
      'L\'effacement n\'a pas abouti. Vérifie ta connexion et réessaie.',
  // ── Parrainage côté app (build 57 / 2.3.1) ───────────────────────────────
  'onb_ref_title': 'Tu as un code de parrain ?',
  'onb_ref_subtitle':
      'Si un ami t’a invité, saisis son code pour qu’il soit crédité. C’est facultatif.',
  'onb_ref_prefilled_note':
      'Code repris de ton lien d’invitation. Vérifie-le avant de le valider.',
  'onb_ref_later_note':
      'Tu pourras aussi le saisir plus tard dans Profil → Parrainer un ami.',
  'referral_pending_note':
      'Code repris de ton lien d’invitation : vérifie-le, puis valide-le.',
  'referral_pending_typed_note':
      'Code saisi pendant ton inscription, pas encore validé.',
  'referral_err_unknown': 'Ce code n’existe pas. Vérifie chaque caractère.',
  'referral_err_self':
      'C’est ton propre code : il sert à inviter tes amis, pas à toi.',
  'referral_err_not_allowed':
      'Ce code ne peut pas être utilisé avec ton compte.',
  'referral_err_rate_limited':
      'Ce code a beaucoup servi dans l’heure. Il est gardé : réessaie plus tard depuis Profil → Parrainer un ami.',
  'referral_err_offline':
      'Pas de connexion. Ton code est gardé : valide-le plus tard depuis Profil → Parrainer un ami.',
  'referral_err_generic':
      'Le code n’a pas pu être vérifié. Il est gardé : réessaie plus tard depuis Profil → Parrainer un ami.',
  'comp_title': 'Compétition ambassadeurs',
  'comp_phase_upcoming': 'À venir',
  'comp_phase_running': 'En cours',
  'comp_phase_ended': 'Terminée',
  'comp_starts_in': 'Début dans @time',
  'comp_ends_in': 'Fin dans @time',
  'comp_ended_body': 'La compétition est terminée.',
  'comp_time_dhm': '@d j @h h @m min',
  'comp_time_hm': '@h h @m min',
  'comp_time_m': '@m min',
  'comp_provisional':
      'Classement provisoire : il peut encore changer après la vérification des filleuls.',
  'comp_rank_label': 'Ton rang',
  'comp_rank_value': 'N° @rank',
  'comp_rank_none': 'Pas encore classé',
  'comp_rank_a11y': 'Ton rang : @rank',
  'comp_unrankable':
      'Tu n’apparais pas encore dans le classement public : l’équipe KPB doit finaliser ta participation (par exemple l’autorisation parentale si tu es mineur).',
  'comp_qualified': 'Qualifiés',
  'comp_qualified_hint': 'Comptent pour ton rang',
  'comp_to_review': 'À vérifier',
  'comp_to_review_hint': 'Vérifiés par l’équipe avant de compter',
  'comp_pending': 'En attente',
  'comp_pending_hint': 'Inscrits, profil pas encore complété',
  'comp_rule_explainer':
      'Un filleul compte quand son profil est complété. Seuls les ambassadeurs sont classés : tes filleuls, eux, ne gagnent rien.',
  'comp_your_code': 'Ton code ambassadeur',
  'comp_share_cta': 'Partager mon lien',
  'comp_share_message':
      'Rejoins-moi sur KPB Education ! Inscris-toi avec mon code @code : @link',
  'comp_public_cta': 'Voir le classement public',
  'comp_rules_cta': 'Lire le règlement',
  'comp_organizer_note':
      'Organisateur : KPB Global L.L.C-FZ. Apple et Google ne sont ni organisateurs ni partenaires de cette compétition.',
  'comp_not_participating_title': 'Tu ne participes pas à la compétition',
  'comp_not_participating_body':
      'Les ambassadeurs participants sont inscrits par l’équipe KPB. Tu peux toujours inviter tes amis avec ton code de parrainage.',
  'comp_offline_title': 'Hors ligne',
  'comp_offline_body': 'Connecte-toi à Internet pour voir ton classement.',
  'comp_error_title': 'Classement indisponible',
  'comp_error_body': 'Réessaie dans un instant.',
  'comp_entry_sub': 'Voir ton classement',
  'comp_name_city': '@name — @city',
  'referral_err_rate_limited_here':
      'Ce code a beaucoup servi dans l’heure. Réessaie plus tard.',
  'referral_err_offline_here':
      'Pas de connexion. Réessaie quand tu seras en ligne.',
  'referral_err_generic_here':
      'Le code n’a pas pu être vérifié. Réessaie plus tard.',
};
