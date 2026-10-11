import 'package:get/get.dart';

class AppTranslations extends Translations {
  @override
  Map<String, Map<String, String>> get keys => {
        'fr': {
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
          'guest_ai_tool_gate_title':
              'Connecte-toi pour utiliser les outils IA',
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
          'scholarships_auth_required_title':
              'Crée ton compte pour voir les bourses',
          'scholarships_auth_required_body':
              'Les bourses sont sélectionnées et vérifiées pour ton profil : ton niveau, tes pays visés, ton domaine. C\'est pour ça qu\'un compte est nécessaire. C\'est gratuit et ça prend deux minutes.',
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
          'profile_avatar_remove_confirm_title': 'Retirer votre photo ?',
          'profile_avatar_remove_confirm_body':
              'Vos initiales seront affichées à la place. Vous pourrez ajouter une nouvelle photo à tout moment.',
          'profile_avatar_updated': 'Votre photo de profil a été mise à jour.',
          'profile_avatar_removed': 'Votre photo de profil a été retirée.',
          'profile_avatar_a11y_label': 'Modifier la photo de profil',
          'profile_avatar_error_too_large':
              'Cette image est trop lourde. Choisissez une photo plus légère.',
          'profile_avatar_error_unsupported_type':
              'Ce format n\'est pas accepté. Utilisez une photo JPEG, PNG ou WebP.',
          'profile_avatar_error_unreadable':
              'Cette image n\'a pas pu être lue. Choisissez une autre photo.',
          'profile_avatar_error_infected':
              'Cette image a été refusée par notre analyse antivirus. Choisissez une autre photo — réessayer avec la même ne fonctionnera pas.',
          'profile_avatar_error_scan_unavailable':
              'Notre analyse antivirus est momentanément indisponible, donc rien n\'a été enregistré. Votre photo n\'est pas en cause : réessayez dans quelques minutes.',
          'profile_avatar_error_service_unavailable':
              'Notre service d\'images est momentanément indisponible. Votre photo n\'est pas en cause : réessayez dans quelques minutes.',
          'profile_avatar_error_conflict':
              'Une autre modification de votre photo a été enregistrée avant celle-ci. Réessayez.',
          'profile_avatar_error_profile_missing':
              'Votre profil n\'a pas été retrouvé sur le serveur. Reconnectez-vous, puis réessayez.',
          'profile_avatar_error_unauthorized':
              'Votre session a expiré. Reconnectez-vous, puis réessayez.',
          'profile_avatar_error_rate_limited':
              'Trop de tentatives. Attendez une minute avant de réessayer.',
          'profile_avatar_error_permission_denied':
              'KPB Education n\'a pas accès à votre appareil photo ou à vos photos. Autorisez-le dans les réglages de votre téléphone.',
          'profile_avatar_error_network':
              'Impossible de joindre le serveur. Vérifiez votre connexion, puis réessayez.',
          'profile_avatar_error_server':
              'Le serveur a rencontré une erreur. Réessayez plus tard.',
          'profile_avatar_error_unknown':
              'L\'envoi de la photo a échoué pour une raison inattendue. Réessayez ; si cela persiste, contactez un conseiller KPB.',
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
          'flight_same_airports':
              'Le départ et l\'arrivée doivent être différents.',
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
          'api_client_session_expired_message':
              'Votre session a expiré. Veuillez vous reconnecter.',
          'coach_suggestion_budget_schools':
              'Quelles écoles pour un budget de 10 000€ ?',
          'coach_suggestion_top_business_schools':
              'Top écoles de commerce en France',
          'coach_suggestion_tech_programs':
              'Formations Tech (EPITA, Epitech...)',
          'file_size_bytes': '@size o',
          'file_size_kb': '@size Ko',
          'file_size_mb': '@size Mo',
          'security_biometric_reason':
              'Déverrouillez pour accéder à vos documents sécurisés KPB',
          'error_state_default_title': 'Connexion impossible',
          'error_state_default_subtitle':
              'Vérifiez votre connexion internet et réessayez.',
          'scholarship_status_badge_open': 'Ouvert',
          'scholarship_status_badge_closing_soon': 'Bientôt clôturé',
          'scholarship_status_badge_closed': 'Clôturé',
          'academy_course_expert_badge': 'COURS EXPERT',
          'academy_sessions_count_single': '@count session',
          'academy_sessions_count_plural': '@count sessions',
          'academy_course_program_title': 'Programme de la formation',
          'academy_benefit_senior_advisor_tips':
              'Astuces de conseillers senior KPB',
          'academy_continue_course_cta': 'Continuer la formation',
          'academy_buy_pack_cta': 'Acheter le pack',
          'academy_finalize_purchase_title': 'Finaliser l\'achat',
          'academy_confirm_pay_cta': 'Confirmer et payer',
          'academy_purchase_success_title': 'Félicitations !',
          'academy_purchase_success_body':
              'Formation débloquée avec succès. Vous pouvez maintenant suivre les cours.',
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
          'budget_note_cn_rent':
              'Résidence universitaire ou coloc hors centre-ville',
          'budget_note_cn_health':
              'Assurance étudiante obligatoire ~600-800 CNY/an',
          'case_reference_provisional': '⏳ provisoire',
          'case_contact_inapp': 'Dans l\'application',
          'commercial_response_time_minutes': '@count min',
          'commercial_response_time_hours': '@count h',
          'commercial_response_time_days': '@count j',
          'housing_auto_search_soon':
              'La recherche de logement automatisée pour le @country arrive très bientôt. Nos conseillers peuvent vous aider dans vos dossiers.',
          'housing_studapart_open_error': 'Impossible d\'ouvrir Studapart.',
          'housing_find_your_nest': 'Trouvez votre cocon',
          'housing_studapart_partnership_title': 'Partenariat Studapart',
          'housing_studapart_partnership_desc':
              'Louez votre logement en France facilement avec ou sans garant local.',
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
          'parent_linked_readonly':
              'Compte parent — lié à @child (lecture seule)',
          'parent_advisor_title': 'Parler au conseiller KPB',
          'parent_advisor_sub': 'WhatsApp · réponse en ~2 h',
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
          'parent_pay_sub':
              'Payez pour votre enfant — via votre conseiller KPB',
          'parent_premium_title': 'Karatou Premium pour @child',
          'parent_premium_sub':
              'Copilote illimité · lettres illimitées · live VIP',
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
              'Vous reverrez l\'intro de démarrage. Vos informations de profil sont conservées.',
          'profile_replay_confirm_cta': 'Revoir',
          'profile_parent_access': 'Accès parent',
          'profile_parent_access_desc':
              'Reliez un parent avec un code d\'invitation pour partager votre progression. Vous choisissez ce qu\'il peut voir, dossier par dossier.',
          'profile_parent_access_cta': 'Relier un parent',
          'profile_premium_card_title': 'Karatou Premium',
          'profile_premium_card_sub': 'Bientôt — activez via un conseiller KPB',
          'premium_screen_title': 'Karatou Premium',
          'premium_badge_soon': 'Bientôt disponible',
          'premium_hero_title': 'Passez à Karatou Premium',
          'premium_hero_sub':
              'Premium arrive bientôt. En attendant, un conseiller KPB peut vous accompagner — sans aucun paiement dans l\'application.',
          'premium_value_ai_coach':
              'KPB Intelligence illimité — l\'offre gratuite inclut @count messages par semaine.',
          'premium_value_advisors':
              'Accompagnement prioritaire par un conseiller KPB vérifié.',
          'premium_value_more_soon':
              'De nouveaux avantages Premium arrivent bientôt.',
          'premium_compare_title': 'Gratuit vs Premium',
          'premium_compare_feature': 'Ce que vous obtenez',
          'premium_compare_free': 'Gratuit',
          'premium_compare_premium': 'Premium',
          'premium_row_ai_coach': 'Messages KPB Intelligence',
          'premium_free_ai_coach': '@count / sem.',
          'premium_unlimited_soon': 'Illimité (bientôt)',
          'premium_how_title': 'Comment activer Premium',
          'premium_how_body':
              'Aucun paiement dans l\'application. Premium arrive bientôt — un conseiller KPB vous guidera pour l\'activer.',
          'premium_wa_prefill':
              'Bonjour KPB, je souhaite en savoir plus sur Karatou Premium.',
          'premium_no_payment_note':
              'Karatou ne propose aucun paiement intégré.',
          // ── Ce qu'est le Pass, en une carte ──────────────────────────
          //
          // Décrit un service À VENIR, jamais un produit achetable ici : ni
          // prix, ni bouton d'achat, ni verbe « s'abonner ». Karatou n'encaisse
          // rien dans l'application (règle App Store 3.1.1), et le badge
          // « Bientôt disponible » de l'écran reste affiché au-dessus.
          'premium_pitch_title': 'Postuler de A à Z, accompagné',
          'premium_pitch_body':
              'Le Pass Karatou, c\'est votre candidature aux bourses prise en main du début à la fin : KPB Intelligence pour préparer, des conseillers KPB pour relire et valider.',
          'premium_pitch_point_shortlist':
              'Une sélection de bourses faite pour votre profil, pas une liste générique.',
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
          'premium_waitlist_title': 'Soyez prévenu à l\'ouverture',
          'premium_waitlist_body':
              'Le Pass n\'est pas encore ouvert. Inscrivez-vous sur la liste d\'attente : nous vous préviendrons en premier.',
          'premium_waitlist_notice':
              'En vous inscrivant, vous acceptez que KPB vous contacte au sujet du Pass Karatou. C\'est gratuit et sans engagement, et vous pouvez vous retirer à tout moment.',
          'premium_waitlist_cta': 'M\'inscrire sur la liste d\'attente',
          'premium_waitlist_joined_title': 'Vous êtes sur la liste',
          'premium_waitlist_joined_body':
              'Inscrit le @date. Nous vous préviendrons dès l\'ouverture du Pass.',
          'premium_waitlist_leave': 'Me retirer de la liste',
          'premium_waitlist_error_network':
              'Connexion impossible. Vérifiez votre réseau et réessayez.',
          'premium_waitlist_error_unauthorized':
              'Votre session a expiré. Reconnectez-vous puis réessayez.',
          'premium_waitlist_error_server':
              'Inscription impossible pour l\'instant. Réessayez dans un moment.',
          'premium_waitlist_student_only':
              'La liste d\'attente est réservée aux comptes étudiants.',
          'guest_premium_waitlist_title': 'Créez votre compte',
          'guest_premium_waitlist_body':
              'La liste d\'attente sert à vous prévenir à l\'ouverture du Pass. Sans compte, nous n\'aurions personne à prévenir.',
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
          'parent_onboarding_b3':
              'Contact direct avec le conseiller KPB sur WhatsApp',
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
          'parent_no_shared_cases':
              'Ton enfant n\'a pas encore partagé de dossier.',
          'partners_strip_trust_title': 'Ils nous font confiance',
          'recommandations_title_sc': 'Bourses recommandées',
          'recommandations_desc_sc':
              'Une sélection de bourses adaptées à ton profil.',
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
          'flight_launch_failed':
              'Impossible d\'ouvrir le comparateur de vols.',
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
          'sync_data_stale_offline':
              'Données potentiellement obsolètes — hors ligne',
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
          'compare_picker_empty':
              'Aucune université ne correspond à ta recherche.',
          'compare_verdict_higher_match':
              '@name correspond mieux à ton profil.',
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
          'coach_online_status':
              'En ligne • @rem/@total restants cette semaine',
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
          'commercial_performance_30_days':
              'Mes performances — 30 derniers jours',
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
          'salon_load_error':
              'Impossible de charger le Salon. Vérifie ta connexion.',
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
          'parcours_convert_subtitle':
              'Discute avec un conseiller KPB de ton projet.',
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
          'orientation_roadmap_heading': 'Ton parcours de candidature',
          'orientation_roadmap_create_case_button': 'Créer mon dossier',
          'case_application_title': 'Dossier de candidature',
          'orientation_next_button': 'Continuer →',
          'orientation_see_results_button': 'Voir mes résultats',
          'orientation_matched_programs_title':
              'Formations qui te correspondent',
          'orientation_matched_programs_subtitle_generic':
              'Des programmes liés à tes résultats.',
          'orientation_your_results_fallback': 'tes résultats',
          'orientation_case_context_label': 'Suite orientation',
          'orientation_results_congrats': 'Bravo ! 🎉',
          'orientation_best_match_label': 'MEILLEURE CORRESPONDANCE',
          'orientation_best_match_badge': '⭐ Meilleur match',
          'orientation_ai_resilient_badge': '🛡 Résilient à l\'IA',
          'orientation_why_it_fits_label': 'Pourquoi c\'est fait pour vous',
          'orientation_available_scholarships_label': 'Bourses disponibles',
          'orientation_ia_resilience_high':
              'Métier d\'avenir · résistant à l\'IA',
          'orientation_ia_resilience_medium': 'Bonne résilience face à l\'IA',
          'orientation_ia_resilience_low': 'À faire évoluer face à l\'IA',
          'france_step_choose_school':
              'Choix de l\'école privée partenaire (OMNES, ICN, Schiller, IGENSIA…)',
          'france_step_build_dossier':
              'Constitution du dossier d\'admission avec KPB',
          'france_step_interview_validation':
              'Entretien / validation admission école',
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
          'privacy_s9_title':
              '9. Analytique produit & enregistrement de session',
          'privacy_s10_title': '10. Modifications',
          'privacy_transfers_title': 'Transferts hors de votre pays',
          'last_updated_september_2026':
              'Dernière mise à jour : septembre 2026',
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
              '• Données techniques : identifiant de l\'appareil (notifications), biométrie locale (verrouillage), localisation déclarée par le SDK OneSignal mais jamais demandée ni utilisée\n'
              '• Analytique : Firebase Analytics et PostHog ; enregistrements de session PostHog (textes et images masqués)\n'
              '• Diagnostics : Firebase Crashlytics ; métriques agrégées de synchronisation',
          'privacy_s3_body': 'Vos données sont utilisées pour :\n\n'
              '• Personnaliser vos recommandations de filières, pays et bourses\n'
              '• Gérer vos dossiers de candidature et vos rendez-vous\n'
              '• Vous envoyer des notifications pertinentes (mises à jour de dossier, deadlines)\n'
              '• Vous envoyer par email les nouvelles bourses d\'études disponibles, uniquement si vous y avez consenti (case à cocher — désinscription possible à tout moment depuis votre profil ou le lien de désinscription des emails)\n'
              '• Améliorer nos services via des statistiques agrégées et anonymisées\n'
              '• Communiquer avec vous dans le cadre de vos démarches\n'
              '• Vous rappeler au sujet d\'un espace ou d\'un accompagnement pour lequel vous avez déclaré votre intérêt, si vous l\'avez accepté au moment de le déclarer. Cette déclaration est lisible par nos conseillers et notre équipe commerciale, et vous pouvez la retirer à tout moment depuis l\'écran où vous l\'avez faite',
          'privacy_s4_body':
              '• Consentement : vous acceptez cette politique lors de la création de votre compte\n'
                  '• Exécution du contrat : le traitement est nécessaire pour fournir nos services\n'
                  '• Intérêt légitime : amélioration de nos services et sécurité de la plateforme',
          'privacy_s5_body': 'Vos données ne sont PAS vendues à des tiers.\n\n'
              'Elles peuvent être partagées avec :\n'
              '• Notre backend KPB (VPS Hostinger, api.kpbeducation.cloud) pour faire fonctionner l\'application\n'
              '• Supabase (authentification : e-mail, session, Google)\n'
              '• OpenRouter et Groq (États-Unis) : textes du coach et profil pseudonymisé — le routage OpenRouter est limité à des services d\'IA sans conservation des données ; jamais vendus\n'
              // Les quatre étiquettes partaient déjà sans être déclarées, et
              // l'e-mail partait aussi — ce dernier a été retiré du code (voir
              // `OneSignalService`), les étiquettes sont GARDÉES parce que le
              // ciblage sert vraiment, donc elles sont nommées ici. Le « jamais
              // votre adresse e-mail » est une promesse que le code tient
              // maintenant, pas une intention.
              '• OneSignal (États-Unis) : jeton de notifications, identifiant de compte et quatre étiquettes de ciblage (type de compte, niveau d\'études, pays visé, langue) — jamais votre adresse e-mail\n'
              '• Firebase / Google (Analytics, Crashlytics) pour l\'analytique et la stabilité\n'
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
              '• Nos partenaires institutionnels (universités) uniquement avec votre accord explicite lors de la soumission d\'un dossier\n'
              '• Les autorités compétentes si la loi l\'exige',
          'privacy_transfers_body':
              'Certains destinataires sont établis aux États-Unis (OpenRouter, Groq, PostHog, OneSignal, Resend, Firebase / Google — YouTube et les services de reconnaissance vocale compris — et Wikimedia). Le transfert repose sur votre consentement à cette politique et, le cas échéant, sur les clauses contractuelles types du sous-traitant. Vous pouvez refuser l\'analytique depuis Profil → « Analyse d\'usage » et refuser KPB Intelligence : le reste de l\'app reste utilisable.',
          'privacy_s6_body':
              '• Données de profil : conservées tant que votre compte est actif\n'
                  '• Données de dossier : conservées tant que le dossier est ouvert, puis supprimées avec le compte\n'
                  '• Données analytiques : agrégées et anonymisées, conservées indéfiniment\n'
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
                  'Pour exercer ces droits, contactez-nous à : privacy@kpbeducation.com',
          'privacy_s9_body': 'Nous utilisons Firebase Analytics (Google) et PostHog pour comprendre l\'usage de l\'application et l\'améliorer :\n\n'
              '• Écrans consultés, actions effectuées (orientation, recherche, sauvegarde)\n'
              '• PostHog enregistre également des sessions (captures d\'écran de votre navigation) ; les textes et les images sont masqués automatiquement, donc aucun document, note ou coordonnée n\'est visible dans l\'enregistrement\n'
              '• Aucune donnée personnelle identifiable n\'est transmise à des fins publicitaires ; il n\'y a aucun SDK publicitaire ni suivi inter-applications\n'
              '• Cette mesure est ACTIVE PAR DÉFAUT : elle fait partie du fonctionnement normal du service et sert uniquement à l\'améliorer (voir les CGU, « Mesure d\'audience »)\n'
              '• Vous pouvez la désactiver à tout moment, ainsi que les enregistrements, depuis Profil → « Analyse d\'usage » : la collecte s\'arrête immédiatement, et votre refus est conservé — il n\'est jamais réactivé par une mise à jour',
          'privacy_s10_body':
              'Cette politique peut être mise à jour. Nous vous informerons de tout changement significatif via une notification dans l\'application.\n\n'
                  'En continuant à utiliser l\'application après une mise à jour, vous acceptez la nouvelle politique.',
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
          'terms_analytics_body':
              'Pour maintenir et améliorer le service, KPB Education mesure l\'usage de l\'application. Cette mesure est ACTIVE PAR DÉFAUT dès la première ouverture.\n\n'
                  'Ce qui est mesuré : les écrans consultés et les actions effectuées (orientation, recherche, sauvegarde, candidature), les diagnostics de plantage, et des enregistrements de session dont les textes et les images sont masqués automatiquement — aucun document, note ou coordonnée n\'y est lisible.\n\n'
                  'Ce qui n\'est PAS fait : aucune revente de données, aucun SDK publicitaire, aucun suivi inter-applications, aucun profilage publicitaire.\n\n'
                  'Vous gardez la main : Profil → « Analyse d\'usage » coupe la mesure et les enregistrements immédiatement. Votre refus est conservé et n\'est jamais réactivé par une mise à jour de l\'application. Refuser n\'enlève aucune fonctionnalité.\n\n'
                  'Le détail des destinataires et des durées de conservation figure dans la Politique de confidentialité, section « Analyse d\'usage ».',
          'deadlines_date_to_confirm': 'Date à confirmer',
          'deadlines_filter_all': 'Toutes',
          'deadlines_filter_saved': 'Sauvegardées',
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
          'compare_share_header':
              'Comparaison d\'universités avec KPB Education :\n\n',
          'compare_share_footer':
              'Découvrez KPB Education pour votre orientation universitaire.',
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
          'alumni_apply_proof_helper':
              "Google Drive, Dropbox, ou autre lien public",
          'alumni_apply_proof_required': 'Requis pour la vérification',
          'alumni_apply_bio': 'Bio courte (facultatif)',
          'alumni_apply_submit': 'Envoyer ma candidature',
          'alumni_status_pending':
              'Ta candidature est en attente de vérification.',
          'alumni_status_approved':
              'Tu es vérifié comme alumni. Ton badge est visible.',
          'alumni_status_rejected':
              'Ta dernière candidature a été refusée. Tu peux la renvoyer.',
          'coach_quota_reached_title': 'Quota KPB Intelligence atteint',
          'coach_unavailable': 'KPB Intelligence indisponible.',
          'coach_unreachable':
              'Impossible de joindre KPB Intelligence pour le moment.',
          'coach_ai_title': 'KPB Intelligence',
          'coach_input_hint': 'Posez votre question sur les écoles, budgets...',
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
          'interview_verdict_strong':
              'Excellent — tu es prêt(e) à convaincre le jury.',
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
          'eligibility_whatsapp_prefill':
              'Bonjour KPB Education, je m\'intéresse à la bourse « @name » et j\'aimerais vérifier mon éligibilité / être accompagné(e).',
          'eligibility_pdf_generated_on': 'Généré le @date',
          'eligibility_pdf_budget_per_month': '@budget € / mois',
          // --- KPB-89 batch ---
          // Les accents s'affichent correctement dans le PDF (Latin-1 ⊂ WinAnsi) :
          // l'orthographe prudente « Francais » n'avait pas lieu d'être.
          'cv_default_languages': 'Français, Anglais',
          // Réservé au VRAI échec réseau. Un 404/503 ne doit pas accuser la
          // connexion de l'utilisateur : voir les trois clés suivantes.
          'tools_ai_error_check_connection':
              'Erreur IA — vérifiez votre connexion',
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
          'tools_ai_error_signin_required':
              'Reconnecte-toi pour utiliser l\'IA.',
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
              'Remplissez les champs et laissez l\'IA rédiger votre profil professionnel.',
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
          'letter_tpl_admission_general_title':
              'Admission universitaire (général)',
          'letter_tpl_admission_master_title':
              'Admission en Master / Programme spécialisé',
          'letter_tpl_scholarship_kpb_title': 'Bourse d\'études KPB Education',
          'letter_tpl_scholarship_international_title':
              'Bourse d\'excellence internationale',
          'letter_tpl_visa_student_title': 'Lettre de motivation visa étudiant',
          'letter_tpl_internship_title':
              'Stage ou alternance à l\'international',
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
          'student_tools_intro':
              'Des outils pratiques pour préparer ta candidature.',
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
          'search_field_not_found_body':
              'Cette filière n\'est plus disponible.',
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
          'scholarship_academy_prepare':
              'Prépare ta candidature avec des experts',
          'scholarship_academy_open_pack': 'Ouvrir mon pack',
          'scholarship_academy_view_pack': 'Voir le Pack Réussite',
          'live_scholarships_filter_all': 'Toutes',
          'live_scholarships_filter_fully_funded': 'Entièrement financées',
          'live_scholarships_filter_partially_funded':
              'Partiellement financées',
          'live_scholarships_connection_error_title': 'Erreur de connexion',
          'live_scholarships_connection_error_subtitle':
              'Vérifie ta connexion et réessaie.',
          // Le vide a deux causes très différentes, et les confondre faisait
          // porter à l'étudiant la responsabilité d'un catalogue non publié.
          'live_scholarships_empty_filtered_title':
              'Aucune bourse pour ces filtres',
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
          'live_scholarships_match_excellent':
              'Excellent profil pour cette bourse !',
          'live_scholarships_match_compatible':
              'Profil compatible — renforce ton dossier.',
          'live_scholarships_match_partial':
              'Profil partiel — les critères sont exigeants.',
          'live_scholarships_section_description': 'Description',
          'live_scholarships_section_advantages': 'Avantages',
          'live_scholarships_section_eligibility': 'Critères d\'éligibilité',
          'live_scholarships_section_key_requirements':
              'Documents et exigences clés',
          'live_scholarships_section_application_steps': 'Comment postuler',
          'live_scholarships_requirement_automatic': 'Attribution automatique',
          'live_scholarships_requirement_separate_application':
              'Candidature séparée requise',
          'live_scholarships_step_duration': 'Durée estimée : @days jour(s)',
          'live_scholarships_apply_with_kpb': '🎯  Candidater avec KPB',
          'live_scholarships_view_official_application':
              'Voir le site officiel de candidature',
          'live_scholarships_official_form': 'Formulaire officiel',
          'live_scholarships_deadline_soon': 'Deadline imminente',
          'live_scholarships_deadline_closed': 'Clôturée',
          'live_scholarships_deadline_days': 'J-@count',
          'live_scholarships_no_deadline': 'Pas de date limite',
          'live_scholarships_funding_tile': 'Financement',
          'live_scholarships_alert': 'M\'avertir',
          'live_scholarships_alert_enabled': 'Alerte activée',
          'live_scholarships_alert_error':
              'Impossible de modifier cette alerte. Réessaie.',
          'live_scholarships_open_now': 'Candidatures ouvertes',
          'live_scholarships_open_estimated': 'Ouverture estimée : @date',
          'live_scholarships_period_estimated':
              'Période estimée : @open – @close',
          // ── Bourses « à venir » (revue du build 49, point 9) ─────────────
          // Quand la fenêtre estimée couvre des MOIS entiers, on l'annonce en
          // mois. Afficher « 01/03/2027 – 30/04/2027 » était plus précis que
          // ce qu'on sait réellement : ces deux dates sont les bornes du mois,
          // pas une date de campagne publiée.
          'live_scholarships_upcoming_months':
              'À venir, généralement aux mois de @from – @to',
          'live_scholarships_upcoming_month':
              'À venir, généralement au mois de @from',
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
          'scholarships_sorted_hint':
              'Classées selon ton profil. Active une alerte pour ne pas rater l\'ouverture.',
          'eligibility_see_my_result': 'Voir mon résultat',
          'answer_yes': 'Oui',
          'answer_maybe': 'Peut-être',
          'answer_no': 'Non',
          'eligibility_verdict_eligible_title': '🟢 Tu sembles éligible',
          'eligibility_verdict_eligible_body':
              'Tu remplis les critères annoncés. Prépare ton dossier — un conseiller KPB peut t’accompagner pour maximiser tes chances.',
          'eligibility_verdict_conditional_title': '🟡 Éligibilité à confirmer',
          'eligibility_verdict_conditional_body':
              'Tu remplis une partie des critères mais certains restent à vérifier. Un conseiller peut t’aider à confirmer ton éligibilité.',
          'eligibility_verdict_unlikely_title': '🔴 Probablement non éligible',
          'eligibility_verdict_unlikely_body':
              'Au moins un critère clé ne semble pas rempli. Des exceptions existent parfois — parles-en à un conseiller, ou explore d’autres bourses.',
          'talk_to_advisor': 'Discuter avec un conseiller',
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
          'eligibility_export_failed_body':
              'Le PDF n\'a pas pu être généré. Réessaie.',
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
          'case_not_found_subtitle':
              'Retourne à la liste des dossiers pour continuer.',
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
          'case_documents_handoff_title':
              'Tes documents passent par ton conseiller',
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
          'case_timeline_status_counselor_assigned':
              'Attribuée à un conseiller',
          'case_timeline_status_under_review': 'En revue',
          'case_timeline_status_documents_needed': 'Documents requis',
          'case_timeline_status_awaiting_student': 'En attente de ta réponse',
          'case_timeline_status_in_progress': 'En cours',
          'case_timeline_status_application_submitted':
              'Soumise à l\'établissement',
          'case_timeline_status_waiting_decision': 'Décision en attente',
          'case_timeline_status_awaiting_payment': 'Paiement en attente',
          'case_timeline_status_completed': 'Acceptée',
          'case_timeline_status_cancelled': 'Demande annulée',
          'case_timeline_status_rejected': 'Refusée',
          'case_stepper_heading': 'Progression',
          'case_stepper_creation_title': 'Création du dossier',
          'case_stepper_creation_desc_draft':
              'Complétez votre profil pour soumettre la demande.',
          'case_stepper_creation_desc_done': 'Dossier soumis avec succès.',
          'case_stepper_analysis_title': 'Analyse et Conseiller',
          'case_stepper_analysis_desc_docs':
              'Des documents supplémentaires sont requis.',
          'case_stepper_analysis_desc_awaiting':
              'Votre conseiller attend votre retour.',
          'case_stepper_analysis_desc_default':
              'Examen de votre profil par nos experts.',
          'case_stepper_processing_title': 'Traitement',
          'case_stepper_processing_desc':
              'Préparation et soumission de vos candidatures.',
          'case_stepper_decision_title': 'Décision',
          'case_stepper_decision_desc':
              'En attente des retours des institutions.',
          'case_stepper_finalization_title': 'Finalisation',
          'case_stepper_finalization_desc_rejected': 'Dossier refusé.',
          'case_stepper_finalization_desc_cancelled': 'Dossier annulé.',
          'case_stepper_finalization_desc_done':
              'Procédure terminée avec succès !',
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
          'case_tunnel_add_file_failed':
              'Impossible d\'ajouter ce fichier. Réessaie.',
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
              'Votre téléphone ne peut pas convertir la voix en texte hors ligne. Pour dicter, votre voix serait envoyée au service de reconnaissance de votre téléphone (Apple ou Google) et traitée hors de l\'appareil. Vous pouvez aussi écrire votre message.',
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
          'doc_viewer_download_body':
              'Le téléchargement va bientôt commencer...',
          // --- KPB-89 batch ---
          'country_study_in': 'Étudier en @country',
          'program_available_on_campuses': 'Disponible sur @count campus',
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
          'program_step_eligibility_choice':
              'Quiz d\'éligibilité & choix du programme',
          'program_step_build_file': 'Constitution du dossier avec KPB',
          'program_step_submission': 'Soumission à l\'école partenaire',
          'program_step_admission_letter':
              'Obtention de la lettre d\'admission',
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
          'explore_share_university':
              'Découvrez cette université sur KPB Education.',
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
          'institution_premium_support_guaranteed':
              'Accompagnement Premium Garanti',
          'institution_premium_support': 'Accompagnement Premium',
          'institution_kpb_benefits': 'Avantages KPB Education',
          'institution_priority_admission': 'Admission Prioritaire',
          'institution_priority_admission_desc':
              'Dossier traité en priorité par l\'université.',
          'institution_dedicated_coach': 'Coach Dédié',
          'institution_dedicated_coach_desc':
              'Un expert vous suit de l\'inscription au visa.',
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
          'onboarding_select_field_body':
              'Choisissez au moins une filière d\'intérêt.',
          'onboarding_select_country_body':
              'Choisissez au moins un pays de destination.',
          'onboarding_welcome_title': 'Bienvenue 👋',
          'onboarding_welcome_subtitle': 'Créons votre profil KPB Education.',
          'onboarding_academic_title': 'Votre parcours 🎓',
          'onboarding_academic_subtitle': 'Dites-nous où vous en êtes.',
          'onboarding_partner_title': 'Votre structure 🤝',
          'onboarding_partner_subtitle': 'Parlez-nous de votre organisation.',
          'onboarding_interests_title': 'Vos intérêts 🌍',
          'onboarding_interests_subtitle': 'Personnalisez vos recommandations.',
          'skip': 'Passer',
          'onboarding_i_am': 'Je suis',
          'account_type_parent_short': 'Parent',
          'onboarding_consent_accept_prefix': 'J\'accepte la ',
          'onboarding_consent_and': ' et les ',
          'onboarding_terms_of_use_inline': 'conditions d\'utilisation',
          'onboarding_partnership_space': 'Espace partenariat',
          'intro_slide1_title': 'Explorez vos destinations',
          'intro_slide1_body':
              "Découvrez des centaines de programmes au Canada, en France et partout dans le monde.",
          'intro_slide2_title': 'Bourses & accompagnement',
          'intro_slide2_body':
              "Trouvez la bourse idéale et obtenez une feuille de route adaptée à votre profil.",
          'intro_slide3_title': 'Suivi en temps réel',
          'intro_slide3_body':
              "Suivez l'avancement de votre dossier et échangez avec nos conseillers, dans l'app.",
          'get_started': 'Commencer',
          'continue_action': 'Continuer',
          'profile_data_saver_desc':
              'Economise la data (masque les images lourdes)',
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
              'Email de connexion à votre compte — il ne se modifie pas ici.',
          'profile_field_country_of_residence': 'Pays de résidence',
          'profile_field_current_study_level': 'Niveau d\'études actuel',
          'profile_field_bac_series': 'Série du bac',
          'profile_updated_title': 'Profil mis à jour',
          'profile_updated_body': 'Vos informations ont été sauvegardées.',
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
          'home_subtitle_student': 'Votre tableau de bord',
          'home_subtitle_parent': 'Espace parent',
          'home_subtitle_partner': 'Espace partenaire',
          'home_active_cases_title': 'Dossiers actifs',
          'see_all': 'Voir tout',
          'home_recommended_universities_title': 'Écoles pour ton profil',
          'home_hero_title_partner': 'Développons\nvotre réseau',
          'home_hero_title_parent': 'Accompagnez\nvotre enfant',
          'home_hero_title_student': 'Votre parcours\nvers l\'étranger',
          'home_hero_subtitle_student':
              'Une étape à la fois — on avance ensemble.',
          'home_hero_subtitle_other': 'Démarrez dès aujourd\'hui.',
          'home_hero_cta_consultation': 'Consultation',
          'home_hero_cta_become_partner': 'Devenir partenaire',
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
          'home_next_step_title_take_orientation':
              'Fais ton test d\'orientation',
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
          'home_parcours_subtitle':
              'Parcours vidéo d\'étudiants africains — gratuit',
          // ── Contact conseiller KPB (Home, App-engagement handoff) ──
          'home_counselor_cta_title': 'Parler à un conseiller KPB',
          'home_counselor_cta_subtitle':
              'Sur WhatsApp, avec ton profil déjà partagé. Réponse en ~2h.',
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
          'eef_hub_hero_title':
              'Prépare ta candidature aux universités françaises',
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
          'eef_help_procedure_question':
              'Procédure, dates, dépôt : c\'est flou ?',
          'eef_help_documents_question':
              'Tu ne sais pas quels documents préparer ?',
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
          'eef_help_catalog_unpublished_cta':
              'Demander de l\'aide sur WhatsApp',
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
          'eef_help_step_catalog_unpublished':
              'catalogue pas encore disponible',
          // ── Build 55 : déclencheurs d'aide (EefHelpLine) ─────────────────
          // Sous chaque formation, sous les filtres actifs, dans les trois
          // outils du dossier. Mêmes règles que ci-dessus : aucune promesse,
          // aucun prix, jamais le nom de l'opérateur de l'État ; et pour un
          // pays suspendu un libellé et un message NEUTRES — jamais « dossier »,
          // jamais un pays, jamais un pays de remplacement.
          'eef_help_line_cta': 'Demander de l\'aide',
          'eef_help_line_neutral_cta': 'Parler à un conseiller',
          'eef_help_line_subject':
              'Demander de l\'aide à propos de « @subject »',
          'eef_help_line_neutral_subject':
              'Parler à un conseiller à propos de « @subject »',
          'eef_help_catalog_filters_question':
              'Tu hésites entre ces formations ?',
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
          'eef_help_bubble_dossier_label':
              'Je veux de l\'aide pour mon dossier',
          'eef_help_bubble_dossier_message':
              'Bonjour KPB Education, je suis dans @place et j\'aimerais de '
                  'l\'aide pour préparer mon dossier de candidature.',
          'eef_help_bubble_choose_label':
              'Je ne sais pas quelle formation choisir',
          'eef_help_bubble_choose_message':
              'Bonjour KPB Education, je suis dans @place. J\'hésite sur le '
                  'choix de ma formation et j\'aimerais en parler.',
          'eef_help_bubble_question_label': 'J\'ai une autre question',
          'eef_help_bubble_question_message':
              'Bonjour KPB Education, j\'ai une question sur @place.',
          'eef_help_bubble_question_message_neutral':
              'Bonjour KPB Education, je suis dans @place. La procédure est '
                  'suspendue dans mon pays et j\'ai une question.',
          'eef_help_bubble_number':
              'Numéro officiel de KPB Education : @number',
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
          'eef_help_private_title':
              'Les écoles privées : ce qu\'il faut savoir',
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
          'eef_help_private_note_link':
              'Les écoles privées : ce qu\'il faut savoir',
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
          'eef_premium_documents':
              'Lettres, CV et projet d\'études sans limite',
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
          'eef_field_wants_premium':
              'La version Premium m\'intéresserait aussi',
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
          'onboarding_title': 'Construisons votre parcours',
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
          'am_i_eligible': 'Suis-je éligible ?',
          'to_check': 'À vérifier :',
          'key_criteria': 'Critères clés :',
          'privacy_policy': 'Politique de Confidentialité',
          'parent_create_invite': 'Créer un code d\'invitation',
          'salon_rsvp_error': 'Impossible de mettre à jour l\'inscription.',
          'intake_label': 'Rentrée',
          'turnaround_label': 'Délai',
          'home_find_school_desc':
              'Trouvez votre école privée en France selon votre budget et vos objectifs. Discutez instantanément !',
          'closing_label': 'Clôture',
          'home_apply_world_desc':
              'Postulez dans les meilleures universités du monde (Canada, USA, UK, Allemagne, Maroc).',
          'discover': 'Découvrir',
          'home_destinations_desc':
              'Découvrez les destinations d\'études où KPB Education vous accompagne de A à Z : orientation, admission et visa.',
          'tuition_prefix': 'Scolarité : ',
          'analyzing_answers': 'Analyse de vos réponses…',
          'multiple_answers_allowed': 'Plusieurs réponses possibles',
          'orientation_results_intro':
              'Voici les filières qui vous correspondent le mieux.',
          'target_careers': 'Métiers visés',
          'recommended_countries': 'Pays recommandés',
          'track_admission_deadlines': 'Suivez les échéances de vos admissions',
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
              'Anticipez vos dépenses mensuelles selon votre destination et votre mode de vie.',
          'estimated_monthly_budget': 'Budget Mensuel Estimé',
          'details_by_category': 'Détails par catégorie',
          'budget_subtitle_monthly': 'coût de la vie mensuel',
          'budget_monthly_range': 'Fourchette mensuelle',
          'budget_sources_note':
              'Estimations du coût de la vie compilées par KPB Education · montants mensuels indicatifs.',
          'budget_see_scholarships_cta': 'Voir les bourses disponibles',
          'app_locked': 'Application Verrouillée',
          'app_lock_prompt':
              'Veuillez vous authentifier pour accéder à vos documents et suivis KPB.',
          'auth_failed': 'Authentification échouée.',
          'logout_title': 'Déconnexion',
          'private_schools_admission': 'Admission écoles privées',
          'dedicated_path_intake': 'Parcours dédié · @intake',
          'eligibility_simulator_title': 'Simulateur d\'éligibilité',
          'eligibility_hook': 'En 1 minute, découvre tes chances',
          'eligibility_intro':
              'Réponds à 5 questions et obtiens un verdict 🟢 🟡 🔴 pour chacune des 9 destinations KPB, puis exporte ton bilan en PDF.',
          'offline_cache_notice':
              'Mode hors ligne. Affichage des données en cache.',
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
          'review_prompt_thanks':
              'Merci ! Ton avis sera publié après modération.',
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
          'scholarship_gap_msg':
              'Ton dossier actuel est à @score%. Pour une bourse comme "@name", le seuil de sécurité est de 85%.',
          'scholarship_tutorials':
              'Accède au pack de tutoriels vidéos exclusifs pour réussir ton dossier.',
          'answer_all_criteria':
              'Réponds à tous les critères pour voir ton résultat.',
          'scholarships_title': 'Bourses d\'études',
          'recommended_opportunities': 'Opportunités recommandées',
          'ranked_by_profile':
              'Classées selon ton profil et tes objectifs académiques.',
          'profile_compatibility': 'Compatibilité avec ton profil',
          'protect_app_access': 'Protéger l\'accès à l\'application',
          'logout_redirect_notice':
              'Vous serez redirigé vers l\'écran d\'accueil. Vos données locales seront effacées.',
          'profile_complete_optimized':
              'Profil complet — recommandations optimisées ✨',
          'remaining_to_pay': 'Reste à payer',
          'academy_unlock_msg':
              'Vous allez débloquer la formation "@title" définitivement sur votre compte.',
          'coach_quota_exhausted':
              'Quota épuisé — Premium bientôt disponible ou contacte un conseiller KPB.',
          'application_sent_admin':
              'Candidature envoyée. Un admin examinera ton dossier sous 48h.',
          'no_verified_mentor':
              'Aucun mentor vérifié ne correspond à cette recherche pour l\'instant.',
          'community_intro':
              'Articles, guides et conseils de nos experts pour réussir votre projet d\'études.',
          'community_members': '+2 000 étudiants — Conseils, entraide & actu',
          'published_on': 'Publié le',
          'choose_second_uni': 'Choisissez une 2ème université',
          'compare_selected': '@n/2 sélectionnée(s)',
          'register_abroad_title': 'Inscriptions à l\'Étranger',
          'register_abroad_cta': 'S\'inscrire à l\'Étranger',
          'housing_intro':
              'Garantir votre hébergement est primordial pour l\'obtention de votre visa étudiant.',
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
          'prepare_departure': 'Préparez votre départ',
          'travel_intro':
              'Estimez le prix du billet pour votre pays d\'études et achetez au meilleur moment.',
          'travel_powered_by':
              'Propulsé par le comparateur indépendant Kayak. Les prix sont affichés en direct.',
          'other_results': 'autres résultats',
          'search_results_count': '@n résultat(s)',
          'doc_review_paste_hint':
              'Colle ton brouillon et obtiens un retour structuré en quelques secondes — points forts, axes d’amélioration et éléments manquants.',
          'eligibility_honest_hint':
              'Réponds honnêtement à chaque critère pour estimer ton éligibilité. Ce n’est qu’une indication — un conseiller confirmera ton cas.',
          'eligibility_not_detailed':
              'Les critères d’éligibilité de cette bourse ne sont pas encore détaillés. Un conseiller KPB peut vérifier ton cas directement.',
          'roadmap_objective':
              'Objectif : rentrée @intake · @field. Voici les étapes, datées à rebours de l’échéance — coche-les au fur et à mesure.',
          'parent_share_case_title': 'Partager avec mon parent',
          'parent_share_case_subtitle':
              'Ton parent lié pourra suivre ce dossier (lecture seule).',
          'parent_visibility_error':
              'Impossible de mettre à jour le partage. Réessaie.',
          'view_official_source': 'Voir la source officielle',
          'nav_community': 'Communauté',
          'home_for_student': 'Votre tableau de bord',
          'home_for_parent': 'Tableau de bord parent',
          'home_for_partner': 'Espace partenariat',
          'book_consultation': 'Réserver une consultation',
          'request_support': 'Demander un accompagnement',
          'view_cases': 'Voir mes dossiers',
          'continue_orientation': 'Continuer mon orientation',
          'explore_fields': 'Explorer les filières',
          'explore_countries': 'Explorer les pays',
          'scholarships_for_you': 'Bourses pour toi',
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
              'Répondez à quelques questions. KPB vous propose des pistes de filières, des pays et des grandes écoles cohérents.',
          'start_orientation': 'Commencer',
          'restart_orientation': 'Recommencer',
          'orientation_results': 'Résultats de votre orientation',
          'why_it_fits': 'Pourquoi cela vous correspond',
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
          'request_submitted': 'Votre demande a été envoyée.',
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
              'Connectez-vous par email pour sauvegarder votre parcours, ou explorez l’app en mode invité.',
          'auth_intelligence_title':
              'KPB Intelligence, ton guide pour étudier à l’étranger',
          'auth_intelligence_body':
              'Réponds à 12 questions et découvre les universités qui correspondent à ton profil.',
          'auth_intelligence_benefit_fit':
              'Universités classées selon ton profil',
          // Ne nomme QUE le coach, seule surface KPB Intelligence en ligne en
          // build 49. La version précédente promettait « lettre, entretien » :
          // le générateur de lettres et le simulateur d'entretien sont masqués
          // par `AppConfig.aiToolsEnabled` (faux par défaut), donc le premier
          // écran vantait deux outils qu'un testeur ne peut pas atteindre.
          // Les trois sujets cités sont ceux du coach lui-même
          // (`coach_welcome_message`), pas une liste d'outils.
          'auth_intelligence_benefit_ai':
              'KPB Intelligence répond en français : écoles, budget, filières',
          'auth_intelligence_benefit_support':
              'Accompagnement humain KPB via WhatsApp',
          'auth_receive_email_link': 'Recevoir un lien par email',
          'auth_explore_guest': 'Explorer sans compte',
          'auth_intelligence_note':
              'Gratuit · FCFA · pensé pour l’Afrique francophone',
          'auth_continue_google': 'Continuer avec Google',
          'auth_google_error': 'Connexion Google impossible. Réessayez.',
          'auth_continue_email': 'Continuer avec mon email',
          'auth_continue_guest': 'Explorer sans compte',
          'auth_guest_hint':
              'Mode invité : consultation du catalogue uniquement. Connexion requise pour créer un dossier.',
          'auth_magic_email_title': 'Connexion par email',
          'auth_magic_email_body':
              'Nous vous enverrons un code à 6 chiffres pour vous connecter sans mot de passe.',
          'auth_magic_send_button': 'Envoyer le code',
          'auth_magic_send_error': 'Impossible d’envoyer le code. Réessayez.',
          'auth_magic_verify_title': 'Vérification',
          'auth_magic_verify_body':
              'Saisissez le code reçu à @email (valide 15 min).',
          'auth_magic_verify_error': 'Code invalide ou expiré.',
          'auth_magic_verify_code_label': 'Code à 6 chiffres',
          'auth_magic_verify_button': 'Valider',
          'auth_magic_resend': 'Renvoyer le code',
          'auth_magic_resend_wait': 'Renvoyer dans @seconds s',
          'auth_magic_resend_cooldown':
              'Veuillez patienter avant de renvoyer un code.',
          'auth_guest_profile_title':
              'Connectez-vous pour accéder à votre profil',
          'auth_guest_profile_body':
              'Créez un compte pour suivre vos dossiers, sauvegarder des programmes et personnaliser votre parcours.',
          // Match explanations
          'match_complete_profile':
              'Complétez votre profil pour un matching personnalisé',
          'match_field_in_interests': 'Filière dans vos intérêts',
          'match_from_orientation': 'Recommandée par votre orientation',
          'match_available_target_country': 'Disponible dans vos pays cibles',
          'match_target_country': 'Pays cible',
          'match_in_target_country': 'Situé dans un pays cible',
          'match_kpb_partner': 'Partenaire KPB',
          'match_field_match': 'Filière correspondante',
          'match_scholarship_interest': 'Budget & Financement',
          'match_general': 'Correspondance générale',
          // Case snackbar
          'case_created_title': 'Dossier créé ✅',
          'case_created_body': 'Votre dossier @code a bien été soumis.',
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
          'case_empty_hint':
              'Crée ton premier dossier pour commencer avec KPB.',
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
          'login_subtitle': 'Connectez-vous pour continuer',
          'login_button': 'Se connecter',
          'forgot_password_link': 'Mot de passe oublié ?',
          'no_account_prompt': 'Pas encore de compte ? ',
          'create_account_link': 'Créer un compte',
          'create_account_title': 'Créer un compte',
          'create_account_subtitle':
              'Rejoignez +5 000 étudiants sur KPB Education',
          'create_account_button': 'Créer mon compte',
          'already_have_account': 'Déjà un compte ? ',
          'login_link': 'Se connecter',
          'full_name_required': 'Votre nom complet est requis',
          'full_name_hint': 'Entrez votre prénom et nom',
          'email_required': 'Entrez votre email',
          'email_invalid': 'Adresse email invalide',
          'phone_optional': 'Téléphone (optionnel)',
          'password_required': 'Entrez votre mot de passe',
          'password_choose': 'Choisissez un mot de passe',
          'password_min_length':
              'Le mot de passe doit contenir au moins 8 caractères',
          'password_helper': 'Minimum 8 caractères',
          // Forgot password
          'forgot_password_title': 'Mot de passe oublié',
          'reset_password_title': 'Réinitialiser le mot de passe',
          'reset_password_body':
              'Entrez votre adresse email et nous vous enverrons un lien pour réinitialiser votre mot de passe.',
          'email_label': 'Adresse email',
          'send_link_button': 'Envoyer le lien',
          'back_to_login': 'Retour à la connexion',
          'email_sent_title': 'Email envoyé !',
          'email_sent_body':
              'Vérifiez votre boîte email et suivez le lien pour réinitialiser votre mot de passe.',
          'forgot_password_error':
              'Une erreur est survenue. Vérifiez l\'adresse email.',
          // Register errors
          'register_error_generic': 'Une erreur est survenue. Réessayez.',
          'register_error_email_exists':
              'Un compte avec cet email existe déjà.',
          'register_error_network':
              'Problème de connexion. Vérifiez votre réseau.',
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
          'commercial_converted_toast':
              'Lead converti 🎉 @name est client(e) KPB',
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
          'commercial_docs_empty':
              'Aucun document sur ce dossier pour le moment.',
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
              'Le programme Ambassadeur (parrainage rémunéré) ouvre sur candidature. Contacte un conseiller KPB pour le rejoindre, ou découvre notre programme de parrainage gratuit.',
          'amb_apply_cta_advisor': 'Contacter un conseiller',
          'amb_apply_cta_referral': 'Découvrir le parrainage',
          'amb_apply_wa_prefill':
              'Bonjour KPB, je souhaite candidater au programme Ambassadeur.',
          'amb_load_error': 'Impossible de charger ton espace ambassadeur.',
          'amb_sample_banner':
              'Aperçu — active ton espace pour gagner des FCFA.',
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
          'amb_toast_share':
              'WhatsApp s\'ouvre — code + lien d\'invitation prêts 📤',
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
          'referral_redeemed_ok':
              'Code validé — merci ! Ton parrain est crédité.',
          'referral_redeemed_already':
              'Tu as déjà utilisé un code de parrainage.',
          'referral_redeem_error': 'Code invalide. Vérifie et réessaie.',
          // ── Récompenses parrainage no-cash (KPB-77) ──
          'referral_credits_title': 'Mes crédits parrainage',
          'referral_credits_label': 'crédit(s)',
          'referral_credits_intro':
              'Un ami qui crée son dossier = 1 crédit. Échange tes crédits contre une relecture approfondie de ton dossier par un conseiller KPB.',
          'referral_redeem_voucher_cta':
              'Échanger contre une relecture conseiller',
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
          'coach_quota_handoff_cta':
              'Continuer avec un conseiller sur WhatsApp',
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
          'coach_load_error':
              'Impossible de charger KPB Intelligence pour le moment.',
          // ── Mes données / RGPD ──
          'data_rights_section': 'Mes données',
          'export_data': 'Exporter mes données',
          'export_data_subject': 'Export de mes données KPB',
          'export_data_error':
              'Impossible d\'exporter tes données pour le moment. Réessaie.',
          'delete_account': 'Supprimer mon compte',
          'delete_account_confirm_title':
              'Supprimer définitivement ton compte ?',
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
          'guardian_consent_checkbox':
              'Mon parent / tuteur a donné son accord.',
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
          'success_lab_study_message_label':
              'Message au conseiller (facultatif)',
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
          'success_lab_study_status_converted_to_case':
              'Accompagnement KPB créé',
          'success_lab_study_status_autonomy_recommended':
              'Poursuite autonome recommandée',
          'success_lab_study_status_declined': 'Demande non retenue',
          'success_lab_study_status_closed': 'Étude terminée',
          'success_lab_study_status_unknown':
              'État mis à jour — actualise l’application',
          'success_lab_study_next_complete_request':
              'Termine puis envoie ta demande.',
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
          'success_lab_study_next_none':
              'Aucune action supplémentaire pour le moment.',
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
          'success_lab_schedule_empty_title':
              'Aucun créneau disponible actuellement',
          'success_lab_schedule_empty_body':
              'Les créneaux expirés ne sont jamais affichés. Actualise plus tard pour voir les nouvelles propositions.',
          'success_lab_schedule_waiting_title': 'Créneaux pas encore ouverts',
          'success_lab_schedule_waiting_body':
              'Ta demande est suivie, mais tu ne peux réserver qu’après la proposition d’un conseiller.',
          'success_lab_schedule_no_request_title':
              'Aucune demande d’étude active',
          'success_lab_schedule_no_request_body':
              'Envoie d’abord une demande d’étude depuis ton atelier Success Lab.',
          'success_lab_schedule_online_required':
              'Reconnecte-toi pour consulter et réserver un créneau.',
          'success_lab_schedule_error_title':
              'Créneaux momentanément indisponibles',
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
          'success_lab_submission_reference':
              'Référence de candidature (facultatif)',
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
          'success_lab_outcome_no_admission':
              'Aucune décision d’admission déclarée.',
          'success_lab_outcome_no_funding':
              'Aucune décision de financement déclarée.',
          'success_lab_outcome_declare_admission':
              'Déclarer une décision d’admission',
          'success_lab_outcome_update_admission':
              'Déclarer une nouvelle décision d’admission',
          'success_lab_outcome_declare_funding':
              'Déclarer une décision de financement',
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
          'success_lab_outcome_save_admission':
              'Enregistrer la décision d’admission',
          'success_lab_outcome_save_funding': 'Enregistrer le financement',
          'success_lab_outcome_amount_minor':
              'Montant en unité monétaire mineure',
          'success_lab_outcome_amount_optional':
              'Facultatif. À renseigner avec la devise, uniquement pour un financement total ou partiel.',
          'success_lab_outcome_currency': 'Devise ISO à 3 lettres',
          'success_lab_outcome_history': 'Historique des décisions',
          'success_lab_outcome_history_empty':
              'Aucune ancienne décision enregistrée.',
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
          'success_lab_outcome_granting_consent':
              'Enregistrement de ton consentement…',
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
          'success_lab_outcome_file_not_allowed':
              'Choisis un fichier PDF, JPG ou PNG.',
          'success_lab_outcome_error_body':
              'Le serveur n’a pas confirmé cette opération. Vérifie les données puis réessaie.',
          'success_lab_verification_declared': 'Déclarée par l’étudiant',
          'success_lab_verification_pending': 'Vérification en cours',
          'success_lab_verification_verified': 'Preuve vérifiée par KPB',
          'success_lab_verification_needs_information':
              'Complément demandé par KPB',
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
          'success_lab_start_offline':
              'Reconnecte-toi pour créer un nouvel atelier.',
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
        },
        'en': {
          'app_title': 'KPB Education',
          'app_tagline':
              'Orientation, study abroad, and support for African students.',
          'student': 'Student',
          'parent': 'Parent',
          'partner': 'Partner',
          'continue': 'Continue',
          'create_account': 'Get started',
          'full_name': 'Full name',
          'email': 'Email',
          'phone': 'Phone',
          'whatsapp': 'WhatsApp',
          'country': 'Country',
          'current_level': 'Current level',
          'target_level': 'Target level',
          'language_level': 'English level',
          'grade_range': 'Academic average over the last 3 years',
          'monthly_budget': 'Monthly budget (per month)',
          'tuition_budget_annual': 'Annual tuition budget',
          'preferred_currency': 'Display currency',
          'currency_eur': 'Euro (€)',
          'currency_xof': 'CFA franc (XOF)',
          'currency_usd': 'US dollar (\$)',
          'scholarship_interest': 'Searching private schools',
          'onboarding_newsletter_consent':
              'Receive newly available scholarships',
          'available_documents': 'Available documents',
          'preferred_language': 'Preferred language',
          'app_language': 'App language',
          // ── Guest gating for cases ─────────────────────────────
          'guest_case_gate_title': 'Sign in to create a case',
          'guest_case_gate_body':
              'You need an account so a KPB advisor can process your request and reply to you.',
          'guest_case_gate_cta': 'Sign in',
          'guest_ai_tool_gate_title': 'Sign in to use the AI tools',
          'guest_ai_tool_gate_body':
              'The CV generator, cover letters and interview simulator work from your profile. An account is required to personalise them.',
          'guest_ai_tool_gate_cta': 'Create my account',
          'profile_sync_pending_title': 'Profile not synced yet',
          'profile_sync_pending_body':
              'Your information has not been retrieved yet. Check your connection and try again in a moment.',
          // ── Guest wall on the Scholarships tab (PARC-04) ──
          'scholarships_auth_required_title':
              'Create your account to see the scholarships',
          'scholarships_auth_required_body':
              'Scholarships are selected and verified for your profile: your level, your target countries, your field. That is why an account is needed. It is free and takes two minutes.',
          'scholarships_auth_required_cta': 'Create my account',
          'guest_cases_title': 'All your cases in one place',
          'guest_cases_body':
              'Sign in to create requests and track their progress with a KPB advisor.',
          // ── KPB tools (drawer) ─────────────────────────────────
          'tools_drawer_title': 'KPB Tools',
          'tools_drawer_subtitle': 'Everything to prepare your application',
          'tools_cv': 'CV',
          'tools_motivation_letter': 'Motivation letter',
          'tools_interview': 'Interview simulator',
          'tools_doc_scanner': 'Document scanner',
          'tools_budget': 'Budget calculator',
          'tools_flight': 'Flight estimator',
          'tools_housing': 'Housing estimator',
          'tools_doc_review': 'AI review',
          'tools_impact': 'Impact dashboard',
          // ── Batch C2: screen i18n (buttons + titles) ───────────
          'cancel': 'Cancel',
          'retry': 'Retry',
          'logout': 'Sign out',
          'logout_confirm_title': 'Sign out?',
          'save_changes': 'Save',
          'compare': 'Compare',
          'levels': 'Levels',
          'fees_per_year': 'Fees / year',
          'profile_edit': 'Edit',
          'profile_avatar_sheet_title': 'Profile photo',
          'profile_avatar_take_photo': 'Take a photo',
          'profile_avatar_choose_photo': 'Choose from gallery',
          'profile_avatar_remove': 'Remove photo',
          'profile_avatar_remove_confirm_title': 'Remove your photo?',
          'profile_avatar_remove_confirm_body':
              'Your initials will be shown instead. You can add a new photo at any time.',
          'profile_avatar_updated': 'Your profile photo has been updated.',
          'profile_avatar_removed': 'Your profile photo has been removed.',
          'profile_avatar_a11y_label': 'Change profile photo',
          'profile_avatar_error_too_large':
              'This image is too heavy. Please choose a lighter photo.',
          'profile_avatar_error_unsupported_type':
              'This format isn\'t supported. Please use a JPEG, PNG or WebP photo.',
          'profile_avatar_error_unreadable':
              'This image couldn\'t be read. Please choose another photo.',
          'profile_avatar_error_infected':
              'This image was rejected by our antivirus scan. Please choose a different photo — retrying the same one won\'t work.',
          'profile_avatar_error_scan_unavailable':
              'Our antivirus scan is temporarily unavailable, so nothing was saved. There\'s nothing wrong with your photo — please try again in a few minutes.',
          'profile_avatar_error_service_unavailable':
              'Our image service is temporarily unavailable. There\'s nothing wrong with your photo — please try again in a few minutes.',
          'profile_avatar_error_conflict':
              'Another change to your photo was saved first. Please try again.',
          'profile_avatar_error_profile_missing':
              'Your profile couldn\'t be found on the server. Please sign in again, then retry.',
          'profile_avatar_error_unauthorized':
              'Your session has expired. Please sign in again, then retry.',
          'profile_avatar_error_rate_limited':
              'Too many attempts. Please wait a minute before retrying.',
          'profile_avatar_error_permission_denied':
              'KPB Education doesn\'t have access to your camera or photos. Please allow it in your phone settings.',
          'profile_avatar_error_network':
              'Could not reach the server. Check your connection, then try again.',
          'profile_avatar_error_server':
              'The server hit an error. Please try again later.',
          'profile_avatar_error_unknown':
              'Uploading the photo failed for an unexpected reason. Please retry; if it persists, contact a KPB advisor.',
          'profile_edit_title': 'Edit profile',
          'profile_security': 'Security',
          'profile_biometric': 'Biometric lock',
          'profile_data_saver': 'Data saver mode',
          'profile_academic_info': 'Academic information',
          'profile_contact': 'Contact',
          'profile_quick_access': 'Quick access',
          'profile_legal_info': 'Legal information',
          'profile_my_journey': 'My journey',
          'profile_target_countries': 'Target countries',
          'profile_fields_of_interest': 'Fields you are interested in',
          'profile_completed': 'Profile completed',
          'profile_complete_cta': 'Complete my profile',
          'see_schools': 'See schools',
          'my_application_journey': 'My application journey',
          'explore_my_results': 'Explore my results',
          'start_a_case': 'Start a case',
          'retake_test': 'Retake the test',
          'get_support': 'Get support',
          'explore_title': 'Explore',
          'apply_with_kpb': 'Apply with KPB',
          'talk_to_expert': 'Talk to an expert',
          'country_not_found': 'Country not found',
          'program_not_found': 'Program not found',
          'take_eligibility_quiz': 'Take the eligibility quiz',
          'chat_on_whatsapp': 'Chat on WhatsApp',
          'eligibility_quiz_short': 'Eligibility quiz',
          'enroll_with_kpb': 'Enroll with KPB',
          'alternative_destinations': 'Alternative destinations',
          'back_to_country': 'Back to country page',
          'student_tools_title': 'Student tools',
          'updated_on': 'Updated @date',
          // ── Trust signal: verified badge + freshness ───────────
          'verified_on': 'Verified on @date',
          'verified_semantics': 'Information verified on @date',
          'reverify_label': 'Re-verify',
          'reverify_semantics': 'Information to re-verify — verified on @date',
          'to_confirm_label': 'To confirm',
          'to_confirm_semantics': 'Information to confirm, not verified',
          'offline_mode': 'Offline mode',
          // --- flight search (Kayak) ---
          'flight_search_prices': 'Find the best prices',
          'flight_same_airports': 'Departure and arrival must be different.',
          'flight_searching': 'Finding the best prices…',
          'flight_results_title': 'Best prices found',
          'flight_visa_advice':
              'Only buy your ticket once your visa is granted — or pick a refundable fare.',
          'flight_cached_note': 'Recently seen prices',
          'flight_cheapest_badge': 'Cheapest',
          'flight_direct': 'Direct',
          'flight_stops_one': '1 stop',
          'flight_stops_many': '@count stops',
          'flight_book_on_kayak': 'Book on Kayak',
          'flight_calendar_title': 'Prices by day this month',
          'flight_calendar_predicted': 'estimated',
          'flight_no_results':
              'No prices found for this search. Try other dates.',
          'flight_prices_unavailable':
              'Live search is temporarily unavailable. Open Kayak to compare.',
          'flight_picker_search_hint': 'City, airport or country',
          'flight_picker_no_match': 'No matching airport.',
          'flight_field_return_date': 'Return date',
          'flight_trip_one_way': 'One way',
          'flight_trip_round_trip': 'Round trip',
          'flight_round_trip_hint': 'round trip',
          'flight_round_trip_label': 'Round trip',
          'a11y_back': 'Back',
          'a11y_close': 'Close',
          'a11y_save': 'Save',
          'a11y_refresh': 'Refresh',
          'a11y_share': 'Share',
          'a11y_download': 'Download',
          'a11y_clear_search': 'Clear search',
          'a11y_send_message': 'Send message',
          'a11y_remove': 'Remove',
          'a11y_rate': 'Rate',
          'a11y_whatsapp_advisor': 'Message advisor on WhatsApp',
          'parent_case_view_title': 'Case (read-only)',
          // --- KPB-89 wave2 ---
          'api_client_session_expired_title': 'Session Expired',
          'api_client_session_expired_message':
              'Your session has expired. Please sign in again.',
          'coach_suggestion_budget_schools':
              'Which schools fit a budget of €10,000?',
          'coach_suggestion_top_business_schools':
              'Top business schools in France',
          'coach_suggestion_tech_programs': 'Tech programs (EPITA, Epitech...)',
          'file_size_bytes': '@size B',
          'file_size_kb': '@size KB',
          'file_size_mb': '@size MB',
          'security_biometric_reason':
              'Unlock to access your secure KPB documents',
          'error_state_default_title': 'Connection failed',
          'error_state_default_subtitle':
              'Check your internet connection and try again.',
          'scholarship_status_badge_open': 'Open',
          'scholarship_status_badge_closing_soon': 'Closing soon',
          'scholarship_status_badge_closed': 'Closed',
          'academy_course_expert_badge': 'EXPERT COURSE',
          'academy_sessions_count_single': '@count session',
          'academy_sessions_count_plural': '@count sessions',
          'academy_course_program_title': 'Course program',
          'academy_benefit_senior_advisor_tips':
              'Tips from senior KPB advisors',
          'academy_continue_course_cta': 'Continue course',
          'academy_buy_pack_cta': 'Buy the pack',
          'academy_finalize_purchase_title': 'Complete purchase',
          'academy_confirm_pay_cta': 'Confirm and pay',
          'academy_purchase_success_title': 'Congratulations!',
          'academy_purchase_success_body':
              'Course unlocked successfully. You can now start the lessons.',
          'academy_player_no_session': 'No session available',
          'academy_player_session_progress': 'Session @current of @total',
          'budget_calculator_title': 'Cost simulator',
          'budget_lifestyle_econome': 'Thrifty',
          'budget_lifestyle_standard': 'Standard',
          'budget_lifestyle_confort': 'Comfort',
          'budget_category_rent': 'Rent',
          'budget_category_utilities': 'Utilities & energy',
          'budget_category_food': 'Food',
          'budget_category_transport': 'Transport',
          'budget_category_health': 'Health & insurance',
          'budget_category_phone_internet': 'Phone plan & Internet',
          'budget_category_supplies': 'Supplies & books',
          'budget_category_clothing_hygiene': 'Clothing & hygiene',
          'budget_category_leisure': 'Leisure & miscellaneous',
          'budget_note_fr_rent':
              'Outside the capital, shared flat or modest studio',
          'budget_note_uk_health': 'IHS surcharge spread across the year',
          'budget_note_de_health': 'Mandatory student health insurance',
          'budget_note_cn_rent':
              'University residence or shared flat outside the city center',
          'budget_note_cn_health':
              'Mandatory student insurance ~600-800 CNY/year',
          'case_reference_provisional': '⏳ provisional',
          'case_contact_inapp': 'In-app',
          'commercial_response_time_minutes': '@count min',
          'commercial_response_time_hours': '@count h',
          'commercial_response_time_days': '@count d',
          'housing_auto_search_soon':
              'Automated housing search for @country is coming very soon. Our advisors can help you with your applications.',
          'housing_studapart_open_error': 'Unable to open Studapart.',
          'housing_find_your_nest': 'Find your nest',
          'housing_studapart_partnership_title': 'Studapart Partnership',
          'housing_studapart_partnership_desc':
              'Rent your home in France easily, with or without a local guarantor.',
          'parent_load_error': 'Could not load. Check your connection.',
          'parent_child_default': 'your child',
          'parent_readonly_chip': 'Read-only',
          'parent_create_cta': 'Generate an invite code',
          'parent_share_cta': 'Share on WhatsApp',
          'parent_link_refresh': 'I\'ve shared — refresh',
          'parent_code_share_note':
              'Share this code with your child. They enter it in their app (Profile → Parent access) to link your accounts.',
          'parent_invite_share_msg':
              'Hi, here\'s my KPB parent code: @code. Add it in your KPB app (Profile → Parent access) to share your journey with me.',
          'parent_waiting_title': '@child hasn\'t shared an application yet',
          'parent_waiting_body':
              'As soon as your child shares an application from their app, their progress will appear here.',
          'parent_nextstep_label': 'NEXT STEP',
          'parent_docs_managed_note':
              'Read-only — documents are managed by your child and their advisor.',
          'parent_financing_body':
              'You can send a proof of funds (statement, attestation) to your KPB advisor.',
          'parent_no_updates':
              'Updates shared by the advisor will appear here.',
          'parent_appbar': 'Parent space',
          'parent_linked_ok': 'Account linked ✓',
          'parent_link_error': 'Invalid or expired code. Try again.',
          'parent_greeting_generic': 'Hello',
          'parent_hello': 'Hello, @name',
          'parent_linked_readonly':
              'Parent account — linked to @child (read-only)',
          'parent_advisor_title': 'Talk to the KPB advisor',
          'parent_advisor_sub': 'WhatsApp · replies in ~2h',
          'parent_privacy_note':
              'Your child controls what you see, field by field, from their app. Case progress and deadlines always stay visible.',
          'parent_case_title': 'Shared application',
          'parent_docs_locked_title': 'Documents not shared',
          'parent_docs_locked_body':
              '@child hasn\'t shared an application with you yet.',
          'parent_financing_label': 'Financing',
          'parent_fin_upload': 'Send a proof of funds',
          'parent_updates_title': 'Updates',
          'parent_updates_sub': 'Progress shared by the advisor',
          'parent_msg_locked_title': 'Messages not shared',
          'parent_msg_locked_body':
              'Private messages between your child and their advisor aren\'t shared.',
          'parent_pay_title': 'Payments',
          'parent_pay_sub': 'Pay for your child — via your KPB advisor',
          'parent_premium_title': 'Karatou Premium for @child',
          'parent_premium_sub':
              'Unlimited copilot · unlimited letters · VIP live',
          'parent_premium_item': 'Karatou Premium',
          'parent_premium_cta': 'Activate via the KPB advisor',
          // --- App-engagement: Student Profil + honest Premium ---
          'profile_target_universities': 'My target universities',
          'profile_universities_see_all': 'See all',
          'profile_universities_empty': 'No saved universities yet.',
          'profile_explore_schools': 'Explore schools',
          'profile_preferences': 'Preferences',
          'profile_replay_onboarding': 'Replay the getting-started tutorial',
          'profile_replay_confirm_title': 'Replay the tutorial?',
          'profile_replay_confirm_body':
              'You\'ll see the getting-started intro again. Your profile details are kept.',
          'profile_replay_confirm_cta': 'Replay',
          'profile_parent_access': 'Parent access',
          'profile_parent_access_desc':
              'Link a parent with an invite code to share your progress. You choose what they can see, case by case.',
          'profile_parent_access_cta': 'Link a parent',
          'profile_premium_card_title': 'Karatou Premium',
          'profile_premium_card_sub':
              'Coming soon — activate via a KPB advisor',
          'premium_screen_title': 'Karatou Premium',
          'premium_badge_soon': 'Coming soon',
          'premium_hero_title': 'Upgrade to Karatou Premium',
          'premium_hero_sub':
              'Premium is coming soon. In the meantime, a KPB advisor can help you — with no in-app payment.',
          'premium_value_ai_coach':
              'Unlimited KPB Intelligence — the free plan includes @count messages per week.',
          'premium_value_advisors':
              'Priority guidance from a verified KPB advisor.',
          'premium_value_more_soon': 'More Premium benefits are coming soon.',
          'premium_compare_title': 'Free vs Premium',
          'premium_compare_feature': 'What you get',
          'premium_compare_free': 'Free',
          'premium_compare_premium': 'Premium',
          'premium_row_ai_coach': 'KPB Intelligence messages',
          'premium_free_ai_coach': '@count / week',
          'premium_unlimited_soon': 'Unlimited (coming soon)',
          'premium_how_title': 'How to activate Premium',
          'premium_how_body':
              'No in-app payment. Premium is coming soon — a KPB advisor will guide you to activate it.',
          'premium_wa_prefill':
              'Hello KPB, I\'d like to learn more about Karatou Premium.',
          'premium_no_payment_note': 'Karatou has no in-app payment.',
          'premium_pitch_title': 'Apply from A to Z, with support',
          'premium_pitch_body':
              'The Karatou Pass takes your scholarship application from start to finish: KPB Intelligence to prepare it, KPB advisers to review and approve it.',
          'premium_pitch_point_shortlist':
              'A shortlist built for your profile, not a generic list.',
          'premium_pitch_point_documents':
              'CVs, motivation letters and answers prepared with KPB Intelligence.',
          'premium_pitch_point_review':
              'A human review by a KPB adviser before you submit.',
          'premium_pitch_point_deadlines':
              'Deadline tracking, so you never miss a date.',
          'premium_waitlist_title': 'Be told when it opens',
          'premium_waitlist_body':
              'The Pass is not open yet. Join the waiting list and we will tell you first.',
          'premium_waitlist_notice':
              'By joining, you agree that KPB may contact you about the Karatou Pass. It is free, there is no commitment, and you can leave the list at any time.',
          'premium_waitlist_cta': 'Join the waiting list',
          'premium_waitlist_joined_title': 'You are on the list',
          'premium_waitlist_joined_body':
              'Joined on @date. We will tell you as soon as the Pass opens.',
          'premium_waitlist_leave': 'Leave the list',
          'premium_waitlist_error_network':
              'Could not connect. Check your network and try again.',
          'premium_waitlist_error_unauthorized':
              'Your session expired. Sign in again, then retry.',
          'premium_waitlist_error_server':
              'Cannot join right now. Please try again in a moment.',
          'premium_waitlist_student_only':
              'The waiting list is for student accounts.',
          'guest_premium_waitlist_title': 'Create your account',
          'guest_premium_waitlist_body':
              'The waiting list exists so we can tell you when the Pass opens. Without an account there would be nobody to tell.',
          'guest_premium_waitlist_cta': 'Create my account',
          'parent_packs_label': 'KPB support',
          'parent_pack_review': 'KPB application review',
          'parent_pack_review_desc':
              'A verified advisor reviews the whole application before submission',
          'parent_pack_full': 'Full support',
          'parent_pack_full_desc':
              '3 advisor sessions + Campus France follow-up to submission',
          'parent_pay_cta': 'Book',
          'parent_pay_history_label': 'History',
          'parent_pay_history_empty': 'Your receipts will appear here',
          'parent_pay_note':
              'Payment arranged with your KPB advisor on WhatsApp — receipt by message. Never pay “agents” outside the KPB channel.',
          'parent_ask_access': 'Request access',
          'parent_nav_overview': 'Overview',
          'parent_nav_case': 'Application',
          'parent_nav_updates': 'Updates',
          'parent_nav_pay': 'Payments',
          'parent_onboarding_title': 'Follow your child\'s journey',
          'parent_onboarding_sub':
              'Generate an invite code and share it with your child. They enter it in their app to link your accounts.',
          'parent_invite_code_label': 'Invite code',
          'parent_onboarding_b1': 'Always visible: case progress and deadlines',
          'parent_onboarding_b2':
              'Controlled by your child: documents, messages, finances',
          'parent_onboarding_b3':
              'Direct contact with the KPB advisor on WhatsApp',
          'parent_wa_advisor':
              'Hello, I\'m the parent of a student supported by KPB. I\'d like to talk to the advisor.',
          'parent_wa_ask_access':
              'Hello, I\'d like to request access to some information in my child\'s application.',
          'parent_wa_upload':
              'Hello, I\'d like to send a proof of funds for my child\'s application.',
          'parent_wa_pay':
              'Hello, I\'d like to pay for “@item” for my child via KPB.',
          'parent_invite_create_error': 'Could not create the invitation.',
          'parent_invite_code_title': 'Invite code',
          'parent_code_copied': 'Code copied.',
          'parent_invite_whatsapp_message':
              'Join me on KPB Education with this code: @code',
          'parent_code_length_error': 'The code is 8 characters long.',
          'parent_link_activated': 'Link activated.',
          'parent_invite_child_title': 'Invite your child',
          'parent_link_account_title': 'Link a parent account',
          'parent_no_shared_cases': 'Your child hasn\'t shared any case yet.',
          'partners_strip_trust_title': 'They trust us',
          'recommandations_title_sc': 'Recommended scholarships',
          'recommandations_desc_sc':
              'A selection of scholarships matched to your profile.',
          'service_packages_load_error':
              'Could not load the list. Check your connection.',
          'service_packages_title': 'KPB Services',
          'service_packages_empty': 'No service available at the moment.',
          'service_packages_category_dossier_pret': 'Ready-to-submit file',
          'service_packages_category_scholarship_kit': 'Scholarship kit',
          'service_packages_category_visa_kit': 'Visa kit',
          'service_packages_category_default': 'Service',
          'flight_picker_select_origin': 'Select departure',
          'flight_picker_select_destination': 'Select arrival',
          'flight_launch_failed': 'Unable to open the flight comparison site.',
          'flight_estimator_appbar_title': 'Flight Simulator',
          'flight_field_departure': 'Departure',
          'flight_field_arrival': 'Arrival',
          'flight_field_choose': 'Choose',
          'flight_field_date': 'Date',
          'flight_view_on_kayak': 'View flights on Kayak',
          'flight_hero_select': 'Select',
          'm6_level_bachelor': 'Bachelor',
          'm6_level_master': 'Master',
          'm6_level_mba': 'MBA / DBA',
          'm6_level_doctorate': 'Doctorate',
          'm6_level_other': 'Other',
          'm6_language_fr': 'French',
          'm6_language_en': 'English',
          'm6_language_de': 'German',
          'm6_language_es': 'Spanish',
          'm6_language_tr': 'Turkish',
          'm6_language_ar': 'Arabic',
          // --- KPB-89 lock-in ---
          'sync_data_stale_offline': 'Data may be out of date — offline',
          'coach_requires_connection':
              'KPB Intelligence needs a connection to the KPB server. ',
          'academy_hd_videos': 'Step-by-step HD videos',
          'academy_letter_templates': 'Motivation letter templates',
          'housing_view_offers_in': 'View offers in @city',
          'parent_no_children_linked': 'No children linked yet.',
          'lang_name_french': '🇫🇷 Français',
          'lang_name_english': '🇬🇧 English',
          // --- KPB-89 batch4b interp ---
          'time_ago_minutes': '@n min ago',
          'time_ago_hours': '@n h ago',
          'time_ago_days': '@n d ago',
          'time_ago_weeks': '@n wk ago',
          'time_ago_months': '@n mo ago',
          'time_ago_just_now': 'just now',
          'lead_motive_prefix': 'Reason: @motive',
          'saved_count_one': '@count saved item',
          'saved_count_other': '@count saved items',
          'salon_session_host': 'With @host',
          'orientation_question_number_badge': 'Question @n',
          'orientation_matched_programs_subtitle_field':
              'Programs related to @field.',
          'deadlines_missing_document': 'Missing document · @code',
          'deadlines_status_days': '@n days',
          'compare_program_count': '@n programs',
          'compare_open_case_for': '@name case',
          'compare_subtitle': 'Tap a column to switch universities',
          'compare_pick': 'PICK',
          'compare_picker_title': 'Choose a university',
          'compare_search_hint': 'Search a university…',
          'compare_picker_empty': 'No university matches your search.',
          'compare_verdict_higher_match':
              '@name is a better match for your profile.',
          'compare_verdict_partner': '@name is a verified KPB partner.',
          'compare_verdict_more_programs':
              '@name offers more programs (@hi vs @lo).',
          'compare_share_line': '🏛 @name — @fit\n',
          'compare_share_line_plain': '🏛 @name\n',
          'compare_share_tuition': '   Fees: @tuition\n',
          'compare_share_language': '   Language: @lang\n\n',
          'community_empty_articles_for_tag': 'No articles for #@tag',
          'alumni_programme_label': 'Program: @programme',
          'alumni_country_label': 'Country: @country',
          'coach_welcome_message':
              'Hi @name! I\'m KPB Intelligence. 🤖\n\nAsk me anything about schools, budget, or partner programs.',
          'coach_quota_reached_body':
              'You\'ve reached the limit of @quota messages this week. Come back next week or contact a human advisor.',
          'coach_online_status': 'Online • @rem/@total left this week',
          'ai_report_action': 'Report',
          'ai_report_title': 'Report this AI response',
          'ai_report_body':
              'Choose a reason. The response and your note will be sent securely to the KPB team for review.',
          'ai_report_reason_label': 'Why are you reporting it?',
          'ai_report_reason_inaccurate': 'Inaccurate or misleading',
          'ai_report_reason_unsafe': 'Unsafe or harmful',
          'ai_report_reason_offensive': 'Offensive or biased',
          'ai_report_reason_privacy': 'Privacy concern',
          'ai_report_reason_other': 'Other',
          'ai_report_note_label': 'Optional details',
          'ai_report_note_hint': 'Explain what is wrong…',
          'ai_report_submit': 'Send report',
          'ai_report_submitting': 'Sending…',
          'ai_report_submit_error':
              'The report was not saved. Check your connection and try again.',
          'ai_report_success_title': 'Report sent',
          'ai_report_success_body':
              'The KPB team will review case @code. Thank you for telling us.',
          // --- KPB-89 batch ---
          'commercial_my_profile': 'My profile',
          'commercial_refresh_stats': 'Refresh stats',
          'commercial_default_name': 'Sales Rep',
          'commercial_performance_30_days': 'My performance — last 30 days',
          'commercial_total_leads': 'Total leads',
          'commercial_converted': 'Converted',
          'commercial_first_response': 'First response',
          'commercial_conversion_rate': 'Conversion rate',
          'loading_error_title': 'Loading error',
          'lead_tag_qualified': 'Qualified',
          'lead_tag_not_qualified': 'Not qualified',
          'lead_tag_awaiting_payment': 'Awaiting payment',
          'lead_tag_converted': 'Converted',
          'lead_tag_lost': 'Lost',
          'lead_tag_to_follow_up': 'To follow up',
          'refresh': 'Refresh',
          'leads_filter_all': 'All',
          'leads_filter_new': 'New',
          'leads_filter_today': 'Today',
          'leads_filter_qualified': 'Qualified',
          'lead_tag_none': 'No tag',
          'lead_change_status': 'Change status',
          'error': 'Error',
          'lead_status_update_failed': 'Unable to update the status.',
          'lead_status_sheet_title': 'Lead status',
          'saved_none_yet': 'No saved items',
          'saved_empty_title': 'Nothing saved',
          'saved_empty_subtitle':
              'Explore fields, countries, universities and programs, then save them to find them here.',
          'saved_group_fields': 'Fields',
          'saved_group_countries': 'Countries',
          'saved_group_institutions': 'Universities',
          'saved_partner_badge': 'Partner',
          'saved_group_programs': 'Programs',
          'salon_load_error':
              'Unable to load the Salon. Check your connection.',
          'salon_title': 'Virtual KPB Salon',
          'salon_unavailable_title': 'Salon unavailable',
          'salon_no_edition_title': 'No edition scheduled',
          'salon_no_edition_subtitle':
              'Come back soon — the next edition will be announced in notifications.',
          'salon_live_now': 'Live',
          'salon_view_sessions': 'View sessions',
          'salon_program_load_error': 'Unable to load the program.',
          'salon_fallback_title': 'KPB Salon',
          'salon_program_unavailable_title': 'Program unavailable',
          'salon_program_upcoming_title': 'Program coming soon',
          'salon_program_upcoming_subtitle':
              'The program has not been published yet. Come back soon.',
          'salon_session_live': 'Live',
          'salon_join': 'Join',
          'salon_registration_confirmed': 'Registration confirmed',
          'salon_register': 'Register',
          'parcours_appbar_title': 'KPB Journeys',
          'parcours_empty_soon_title': 'Coming soon',
          'parcours_empty_soon_subtitle':
              'Journey and testimonial videos are coming very soon. Check back soon!',
          'parcours_empty_error_title': 'Content unavailable',
          'parcours_empty_error_subtitle':
              'Unable to load the journeys right now.',
          'parcours_intro_title': 'They did it before you',
          'parcours_free_badge': 'FREE',
          'parcours_convert_title': 'Want to follow a similar path?',
          'parcours_convert_subtitle':
              'Chat with a KPB advisor about your plan.',
          'parcours_whatsapp_prefill':
              'Hello KPB, a journey in the app inspired me and I\'d like to discuss my study plan.',
          'parcours_search_hint': 'Search a career, a school, a name…',
          'parcours_filter_all': 'All',
          'parcours_kind_written': 'Written story',
          'parcours_empty_filter_title': 'No results',
          'parcours_empty_filter_subtitle':
              'Try another theme or another search.',
          'parcours_up_next': 'Up next',
          'parcours_story_appbar': 'Testimonial',
          'parcours_video_unavailable':
              'This video is not available right now.',
          'orientation_roadmap_appbar_title': 'My journey',
          'orientation_roadmap_heading': 'Your application journey',
          'orientation_roadmap_create_case_button': 'Create my case',
          'case_application_title': 'Application case',
          'orientation_next_button': 'Continue →',
          'orientation_see_results_button': 'See my results',
          'orientation_matched_programs_title': 'Programs that fit you',
          'orientation_matched_programs_subtitle_generic':
              'Programs related to your results.',
          'orientation_your_results_fallback': 'your results',
          'orientation_case_context_label': 'Following orientation',
          'orientation_results_congrats': 'Well done! 🎉',
          'orientation_best_match_label': 'BEST MATCH',
          'orientation_best_match_badge': '⭐ Best match',
          'orientation_ai_resilient_badge': '🛡 AI-resilient',
          'orientation_why_it_fits_label': 'Why it fits you',
          'orientation_available_scholarships_label': 'Available scholarships',
          'orientation_ia_resilience_high':
              'Future-proof career · AI-resistant',
          'orientation_ia_resilience_medium': 'Good resilience to AI',
          'orientation_ia_resilience_low': 'Needs to evolve alongside AI',
          'france_step_choose_school':
              'Choose the partner private school (OMNES, ICN, Schiller, IGENSIA…)',
          'france_step_build_dossier': 'Build the admission dossier with KPB',
          'france_step_interview_validation':
              'Interview / school admission validation',
          'france_step_student_visa': 'Long-stay student visa',
          'france_step_housing_departure': 'Housing & departure preparation',
          'france_step_arrival': 'Arrival in France with KPB follow-up',
          'france_case_title': 'France procedure — private schools',
          'france_case_context_label': 'France · @intake',
          'privacy_s1_title': '1. Data controller',
          'privacy_s2_title': '2. Data collected',
          'privacy_s3_title': '3. Purposes of processing',
          'privacy_s4_title': '4. Legal basis',
          'privacy_s5_title': '5. Data sharing',
          'privacy_s6_title': '6. Retention period',
          'privacy_s7_title': '7. Security',
          'privacy_s8_title': '8. Your rights',
          'privacy_s9_title': '9. Product analytics & session recording',
          'privacy_s10_title': '10. Changes',
          'privacy_transfers_title': 'Transfers outside your country',
          'last_updated_september_2026': 'Last updated: September 2026',
          'privacy_s1_body':
              'KPB Education (hereafter "we", "our", "KPB") is a service of KPB Global L.L.C-FZ, a free-zone limited liability company registered with the Meydan Free Zone (Meydan City Corporation, Emirate of Dubai) under licence no. 2537631.01. KPB Global L.L.C-FZ is the controller of personal data collected through the KPB Education mobile app.\n\n'
                  'Registered office: Meydan Grandstand, 6th floor, Meydan Road, Nad Al Sheba, Dubai, United Arab Emirates\n'
                  'Contact: contact@kpbeducation.com\n'
                  'Website: https://kpbeducation.cloud\n\n'
                  'Processing is governed by UAE Federal Decree-Law no. 45 of 2021 on the Protection of Personal Data. You may lodge a complaint with the UAE Data Office. Where the law of your country of residence gives you a remedy before a local data protection authority, that remedy remains available.',
          'privacy_s2_body': 'We collect the following data:\n\n'
              '• Identity: full name, email address, phone number, WhatsApp\n'
              '• Date of birth (students); guardian name and contact if you are under 18\n'
              '• Profile photo, if you add one (camera or photo library)\n'
              '• Academic profile: current level, target level, language skills, grades, fields of interest, destination countries\n'
              '• Case messages and texts submitted to the coach (KPB Intelligence)\n'
              // Voir le commentaire du bloc `fr` : le repli réseau d'Android est
              // nommé parce qu'il subsiste dans le greffon.
              '• Voice dictation: the microphone captures your voice, the app asks your phone to turn it into text on the device and keeps only that text; the audio recording is never sent to us. On iPhone, if on-device recognition is unavailable, dictation does not start. On Android, on-device recognition is only a preference: without a local model installed, your phone\'s recognition service (Google) may process your voice off the device\n'
              '• Documents (passport, transcripts, case files): in-app upload is masked. These files reach your advisor over WhatsApp, not through an in-app upload\n'
              '• Usage data: orientation results, saved items, search history\n'
              '• Technical data: device identifier (notifications), local biometrics (app lock), location declared by the OneSignal SDK but never requested or used\n'
              '• Analytics: Firebase Analytics and PostHog; PostHog session recordings (text and images masked)\n'
              '• Diagnostics: Firebase Crashlytics; aggregated sync metrics',
          'privacy_s3_body': 'Your data is used to:\n\n'
              '• Personalise programme, country and scholarship recommendations\n'
              '• Manage your applications and appointments\n'
              '• Send relevant notifications (case updates, deadlines)\n'
              '• Email newly listed scholarships only if you opted in (checkbox — unsubscribe any time from your profile or the email footer)\n'
              '• Improve our services through aggregated, anonymised statistics\n'
              '• Communicate with you about your applications\n'
              '• Contact you about a space or a guidance offer you declared an interest in, where you agreed to it when declaring. That declaration is readable by our counsellors and our sales team, and you can withdraw it at any time from the screen where you made it',
          'privacy_s4_body':
              '• Consent: you accept this policy when you create an account\n'
                  '• Contract: processing is required to provide the service\n'
                  '• Legitimate interest: improving the service and securing the platform',
          'privacy_s5_body': 'Your data is NOT sold to third parties.\n\n'
              'It may be shared with:\n'
              '• Our KPB backend (Hostinger VPS, api.kpbeducation.cloud) to run the app\n'
              '• Supabase (authentication: email, session, Google)\n'
              '• OpenRouter and Groq (United States): coach texts and a pseudonymised profile — OpenRouter routing is limited to AI services with zero data retention; never sold\n'
              // Voir le commentaire du bloc `fr`.
              '• OneSignal (United States): push token, account identifier and four targeting tags (account type, study level, target country, language) — never your email address\n'
              '• Firebase / Google (Analytics, Crashlytics) for analytics and stability\n'
              // Voir le commentaire du bloc `fr` : un destinataire de données
              // techniques est un destinataire, il se nomme.
              '• YouTube (Google): testimonial and scholarship videos play through the embedded YouTube player (youtube-nocookie.com domain) and their thumbnails load from YouTube — as soon as they are displayed, Google receives your IP address and technical data, even without an account\n'
              '• Wikimedia Commons (Wikimedia Foundation, United States): Études en France catalogue institution logos load from Wikimedia — as soon as they are displayed, the Foundation receives your IP address and technical data, even without an account\n'
              '• Your phone\'s speech recognition service (Apple or Google): for dictation only — the app requests on-device recognition first and only reaches this service with your agreement; on Android the system may also fall back to it on its own when the local model is missing (see "Voice dictation", section 2)\n'
              '• PostHog (United States): product analytics and content-masked session recordings\n'
              '• Resend (United States): transactional and campaign email\n'
              '• Mautic (email tool self-hosted by KPB) for the scholarship newsletter, only if you opted in\n'
              '• PayDunya and CinetPay: payment intents if you buy paid accompaniment\n'
              '• Our internal advisors for case follow-up, and our sales team for the interest declarations you made. When a case request is submitted, the account contact details (name, email, phone, WhatsApp and, where provided, the guardian contact) are emailed to the active sales team\n'
              '• Institutional partners (universities) only with your explicit agreement when you submit a case\n'
              '• Competent authorities if the law requires it',
          'privacy_transfers_body':
              'Some recipients are established in the United States (OpenRouter, Groq, PostHog, OneSignal, Resend, Firebase / Google — including YouTube and the speech recognition services — and Wikimedia). The transfer rests on your consent to this policy and, where applicable, the processor\'s standard contractual clauses. You can turn analytics off in Profile → "Usage analytics" and decline KPB Intelligence: the rest of the app stays usable.',
          'privacy_s6_body': '• Profile data: kept while your account is active\n'
              '• Case data: kept while the case is open, then deleted with the account\n'
              '• Analytics data: aggregated and anonymised, kept indefinitely\n'
              '• If you delete your account: personal data is erased within 30 days',
          'privacy_s7_body': '• Encrypted transport via HTTPS/TLS\n'
              '• Passwords hashed (bcrypt)\n'
              '• Secured authentication tokens (JWT)\n'
              '• Sensitive data (tokens) stored in the Keychain (iOS) / Keystore (Android)\n'
              '• Restricted access to production data',
          'privacy_s8_body':
              'Under UAE Federal Decree-Law no. 45 of 2021, under the GDPR where it applies, and under the law of your country of residence, you have the right to:\n\n'
                  '• Access your personal data\n'
                  '• Rectify your data\n'
                  '• Delete your account and your data\n'
                  '• Restrict processing\n'
                  '• Object to processing\n'
                  '• Data portability\n\n'
                  'To exercise these rights, contact us at: privacy@kpbeducation.com',
          'privacy_s9_body': 'We use Firebase Analytics (Google) and PostHog to understand and improve the app:\n\n'
              '• Screens viewed, actions taken (orientation, search, save)\n'
              '• PostHog also records sessions (screenshots of your navigation); text and images are masked automatically, so no document, note or contact detail is visible\n'
              '• No identifiable personal data is sent for advertising; there is no ad SDK and no cross-app tracking\n'
              '• This measurement is ON BY DEFAULT: it is part of the normal operation of the service and is used solely to improve it (see the Terms, "Audience measurement")\n'
              '• You can turn it off at any time, along with the recordings, from Profile → "Usage analytics": collection stops immediately, and your refusal is kept — no update ever turns it back on',
          'privacy_s10_body':
              'This policy may be updated. We will notify you of any material change via an in-app notification.\n\n'
                  'By continuing to use the app after an update, you accept the new policy.',
          'terms_s10_body':
              'These Terms are governed by the laws of the United Arab Emirates and by the regulations of the Meydan Free Zone (Emirate of Dubai), where KPB Global L.L.C-FZ, the publisher of KPB Education, is established.\n\n'
                  'In case of dispute, the parties will first seek an amicable resolution; failing agreement, the competent courts of Dubai shall settle it.\n\n'
                  'Where the law of your country of residence grants you mandatory consumer protections, those protections still apply.',
          'terms_s11_body': 'For any question about these Terms:\n\n'
              'Publisher: KPB Global L.L.C-FZ (Meydan Free Zone licence no. 2537631.01)\n'
              'Address: Meydan Grandstand, 6th floor, Meydan Road, Nad Al Sheba, Dubai, United Arab Emirates\n'
              'Email: contact@kpbeducation.com\n'
              'Website: https://kpbeducation.cloud',
          'onboarding_under_16_title': 'Minimum age: 16',
          'onboarding_under_16_body':
              'The Terms require you to be at least 16 to create an account. The date you entered is under 16.',
          'terms_of_use_2': 'Terms of Use',
          'terms_s1_title': '1. Purpose',
          'terms_s2_title': '2. Acceptance',
          'terms_s3_title': '3. Registration',
          'terms_s4_title': '4. Services offered',
          'terms_analytics_title': '5. Audience measurement',
          'terms_s5_title': '6. Paid services',
          'terms_s6_title': '7. User obligations',
          'terms_s7_title': '8. Intellectual property',
          'terms_s8_title': '9. Limitation of liability',
          'terms_s9_title': '10. Termination',
          'terms_s10_title': '11. Governing law',
          'terms_s11_title': '12. Contact',
          'terms_analytics_body':
              'To maintain and improve the service, KPB Education measures how the app is used. This measurement is ON BY DEFAULT from first launch.\n\n'
                  'What is measured: screens viewed and actions taken (orientation, search, save, application), crash diagnostics, and session recordings in which text and images are masked automatically — no document, note or contact detail is readable in them.\n\n'
                  'What is NOT done: no sale of data, no advertising SDK, no cross-app tracking, no advertising profiling.\n\n'
                  'You stay in control: Profile → "Usage analytics" stops the measurement and the recordings immediately. Your refusal is kept and is never turned back on by an app update. Declining removes no feature.\n\n'
                  'Recipients and retention periods are detailed in the Privacy Policy, section "Usage analytics".',
          'deadlines_date_to_confirm': 'Date to be confirmed',
          'deadlines_filter_all': 'All',
          'deadlines_filter_saved': 'Saved',
          'deadlines_filter_cases': 'Cases',
          'deadlines_filter_upcoming': 'Upcoming',
          'deadlines_empty_title': 'No deadlines',
          'deadlines_empty_subtitle':
              'Save a scholarship or open a case to build your tracker.',
          'deadlines_stat_within_30_days': '≤ 30 days',
          'deadlines_badge_tracked': 'Tracked',
          'deadlines_kind_scholarship': 'Scholarship',
          'deadlines_kind_roadmap': 'Roadmap',
          'deadlines_kind_case': 'Case',
          'deadlines_kind_document': 'Document',
          'deadlines_status_past': 'Past',
          'deadlines_status_today_tomorrow': 'Today / tomorrow',
          'compare_title': 'Compare',
          'compare_row_match': 'Profile match',
          'compare_row_location': 'Location',
          'compare_row_tuition': 'Tuition',
          'compare_row_language': 'Language',
          'compare_row_levels': 'Levels',
          'compare_row_intakes': 'Intakes',
          'compare_row_kpb_partner': 'KPB partner',
          'compare_need_help_choosing': 'Need help choosing?',
          'compare_help_choosing_university': 'Help choosing a university',
          'compare_share_header':
              'University comparison with KPB Education:\\n\\n',
          'compare_share_footer':
              'Discover KPB Education for your university guidance.',
          'compare_yes': 'Yes',
          'compare_no': 'No',
          'community_search_tooltip': 'Search',
          'community_hero_title': 'Learning together 🌍',
          'community_articles_section': 'Articles',
          'community_empty_articles_title': 'No articles',
          'community_articles_coming_soon': 'Articles are coming soon.',
          'community_see_all_articles': 'See all articles',
          'community_forum_section': 'Forum',
          'community_join_whatsapp_group': 'Join the WhatsApp group',
          'whatsapp_open_failed':
              'Could not open WhatsApp. Make sure the app is installed.',
          // ── External link that will not open (PARC-15) ──
          'external_link_failed_title': 'Could not open this link',
          'external_link_failed_body':
              'Your phone could not open this page. A KPB advisor can send you the link directly.',
          'external_link_failed_cta': 'Ask for the link',
          'external_link_failed_prefill':
              'Hello KPB Education, I cannot open the official form for "@title". Could you send it to me?',
          'kpb_prefill_case':
              'Hello KPB Education, I\'m getting back to you about case @ref.',
          'kpb_prefill_program':
              'Hello KPB Education, I\'m interested in the "@program" programme and would like some guidance.',
          'kpb_prefill_program_with_country':
              'Hello KPB Education, I\'m interested in the "@program" programme (@country) and would like some guidance.',
          'kpb_prefill_program_full':
              'Hello KPB Education, I just saw the "@program" programme (@institution, @country) and I\'m interested.',
          'kpb_prefill_program_with_institution':
              'Hello KPB Education, I just saw the "@program" programme (@institution) and I\'m interested.',
          'kpb_prefill_service':
              'Hello KPB Education, I\'d like to know more about the "@service" service.',
          'kpb_prefill_country':
              'Hello KPB Education, I\'d like guidance for my studies — destination: @country.',
          'kpb_prefill_generic':
              'Hello KPB Education, I\'d like some guidance with my study plans.',
          'community_featured_badge': '📌 Featured',
          'community_safety_note':
              'AI moderation + reports. Report any paid private « scholarship offer » — it is a scam.',
          'match_card_eyebrow': 'MY SCHOOL MATCH',
          'match_card_applying_via': '@name · applying with KPB Education',
          'match_card_student_fallback': 'Future student',
          'match_card_domain_tagline': 'find your schools',
          'match_card_share_whatsapp': 'Share on WhatsApp',
          'match_card_download': 'Download',
          'match_card_whatsapp_prefill':
              '@school: @fit for my profile. Find the schools that match you on Karatou: @link',
          'match_card_share_error': 'Could not generate the card. Try again.',
          'forum_no_articles_tagged':
              'No articles tagged yet. Join the WhatsApp group to ask questions.',
          'forum_filter_by_topic': 'Filter by topic',
          'forum_filter_all': 'All',
          'forum_related_articles': 'Related articles',
          'forum_join_conversation_title': 'Join the conversation',
          'forum_join_conversation_body':
              'The in-app forum is launching soon. Connect on WhatsApp to discuss with other students and KPB counselors now.',
          'forum_open_whatsapp_group': 'Open WhatsApp group',
          'alumni_load_error': 'Could not load mentors. Check your connection.',
          'alumni_directory_title': 'KPB Mentors — Alumni',
          'alumni_search_hint': 'Search by university…',
          'alumni_apply_submit_failed':
              'Could not send the application right now.',
          'alumni_apply_title': 'Become an alumni mentor',
          'alumni_apply_university': 'University / school',
          'form_required': 'Required',
          'alumni_apply_programme': 'Programme / major',
          'alumni_apply_year': 'Admission / graduation year',
          'alumni_apply_year_invalid': 'Invalid year',
          'alumni_apply_year_out_of_range': 'Year out of range',
          'alumni_apply_country': 'University country (ISO code, e.g. FR, CA)',
          'alumni_apply_proof_url': 'Link to admission letter / diploma',
          'alumni_apply_proof_helper':
              'Google Drive, Dropbox, or another public link',
          'alumni_apply_proof_required': 'Required for verification',
          'alumni_apply_bio': 'Short bio (optional)',
          'alumni_apply_submit': 'Send my application',
          'alumni_status_pending': 'Your application is pending verification.',
          'alumni_status_approved':
              'You are verified as an alumnus. Your badge is visible.',
          'alumni_status_rejected':
              'Your last application was rejected. You can resubmit it.',
          'coach_quota_reached_title': 'KPB Intelligence quota reached',
          'coach_unavailable': 'KPB Intelligence unavailable.',
          'coach_unreachable': 'Unable to reach KPB Intelligence right now.',
          'coach_ai_title': 'KPB Intelligence',
          'coach_input_hint': 'Ask your question about schools, budgets...',
          // ── App-engagement handoff: coaching tools + post-decision ──
          'coach_status_tagline': 'Knows your profile · replies instantly',
          'coach_quota_info_title': 'KPB Intelligence messages',
          'coach_quota_info_body':
              'You have @rem of @total messages left this week.',
          'coach_generate_letter': 'Generate a letter',
          'letters_header_subtitle':
              'Pick a model, personalize it with AI (FR + EN).',
          'letters_regenerate': 'Regenerate',
          'letters_export': 'Export',
          'interview_header_subtitle': 'Practice with an AI examiner.',
          'interview_header_progress':
              'Question @current/@total · answer as if facing the jury',
          'interview_jury_label': 'JURY',
          'interview_score_line': 'Score: @score/100',
          'interview_complete_title': 'Interview complete!',
          'interview_verdict_strong':
              'Excellent — you\'re ready to convince the jury.',
          'interview_verdict_promising':
              'Good start — refine your answers and try again.',
          'interview_verdict_practice':
              'Keep practicing — every run gets you closer.',
          'interview_replay': 'Replay',
          'interview_back_to_application': 'Back to application',
          'post_decision_title': 'Decision received',
          'post_decision_encouragement':
              'This isn\'t the end of the road. Your profile stays strong — with a few adjustments, a next application can succeed.',
          'post_decision_plan_b_title': 'Your plan B — already computed',
          'post_decision_counselor_title': 'Free counselor session',
          'post_decision_counselor_subtitle':
              '15 min with a KPB counselor to prepare your next application.',
          'post_decision_whatsapp_prefill':
              'Hello KPB Education, my application "@title" was refused. I\'d like guidance on a plan B.',
          'post_decision_entry_title': 'Decision received — see your plan B',
          'post_decision_entry_subtitle':
              'Alternative universities + counselor session.',
          'notifications_title': 'Notifications',
          'notifications_mark_all_read': 'Mark all read',
          'notifications_empty_title': 'You\'re all caught up',
          'notifications_empty_body':
              'We\'ll notify you here about your applications and decisions.',
          'notif_action_needed_title': 'Action needed: @step',
          'notif_action_needed_fallback': 'A step needs your attention',
          'notif_decision_received_title': 'Decision received',
          'notif_decision_received_body':
              'A decision arrived for « @title » — see your plan B.',
          'notifications_push_section': 'PUSH NOTIFICATIONS',
          'notifications_enable_push_title': 'Enable push notifications',
          'notifications_enable_push_subtitle':
              'Get alerts on this device about your applications and decisions.',
          'notifications_push_enable_action': 'Enable',
          'notifications_push_os_note':
              'Notification delivery is managed by your device. '
                  'You can change this anytime in your phone settings.',
          'notifications_push_requested':
              'If prompted, allow notifications to stay informed.',
          'scanner_pages_scanned': '@count page(s) scanned',
          'interview_question_progress': 'Question @current / @total',
          'search_no_results_title': 'No results for « @query »',
          'scholarship_boost_analysis_title': 'Boost Analysis: @name',
          'live_scholarships_result_count': '@count scholarship(s) found',
          'eligibility_whatsapp_prefill':
              'Hello KPB Education, I\'m interested in the « @name » scholarship and would like to check my eligibility / get support.',
          'eligibility_pdf_generated_on': 'Generated on @date',
          'eligibility_pdf_budget_per_month': '@budget € / month',
          // --- KPB-89 batch ---
          'cv_default_languages': 'French, English',
          'tools_ai_error_check_connection': 'AI error — check your connection',
          'tools_ai_error_unavailable':
              'The AI service is temporarily unavailable. Please try again shortly.',
          'tools_ai_error_slow':
              'Generation is taking longer than expected. Please try again shortly.',
          'tools_ai_error_rate_limited':
              'Too many requests. Try again in a minute.',
          'tools_ai_error_daily_quota':
              'You have reached today\'s AI usage limit. Try again tomorrow.',
          'tools_ai_error_input_too_large':
              'Your text is too long. Shorten it and try again.',
          'tools_ai_error_signin_required':
              'Please sign in again to use the AI.',
          'tools_ai_error_birthdate_required':
              'Add your date of birth in your profile to use the AI tools.',
          'cv_field_residence': 'Country of residence',
          'cv_objective_prefill': 'Goal: join a @level programme in @field.',
          'cv_objective_destination': 'Target destination: @country.',
          'cv_generator_title': 'CV Generator',
          'cv_generator_intro':
              'Fill in the fields and let the AI write your professional profile.',
          'cv_field_full_name': 'Full name',
          'cv_field_phone': 'Phone',
          'cv_field_study_level': 'Study level',
          'cv_field_field_of_study': 'Field of study',
          'cv_field_target_country': 'Target country',
          'cv_field_skills': 'Skills (comma-separated)',
          'cv_field_languages': 'Languages',
          'cv_field_experience': 'Experience / Internships',
          'cv_field_objective': 'Career objective',
          'cv_generating': 'Generating...',
          'cv_enhance_with_ai': 'Enhance with AI',
          'cv_ai_summary_heading': 'AI-generated summary',
          'cv_export_pdf': 'Export as PDF',
          'scanner_doc_passport': 'Passport',
          'scanner_doc_passport_hint': 'ID page, valid at least 6 months.',
          'scanner_doc_diploma': 'Diploma / Certificate',
          'scanner_doc_diploma_hint': 'Most recent diploma obtained',
          'scanner_doc_transcripts': 'Transcripts',
          'scanner_doc_transcripts_hint': 'Report cards from the last 2 years',
          'scanner_doc_language_test': 'Language test',
          'scanner_doc_language_test_hint': 'TOEFL / IELTS / TCF if available',
          'scanner_doc_financial': 'Proof of funds',
          'scanner_doc_financial_hint': 'Bank statement or certificate',
          'scanner_doc_id_photo': 'ID photo',
          'scanner_doc_id_photo_hint': 'Light background, official format',
          'scanner_title': 'Scan my documents',
          'scanner_application_folder': 'Application folder',
          'scanner_add_page': 'Add a page',
          'scanner_scan': 'Scan',
          'scanner_reset_tooltip': 'Reset',
          'impact_title': 'Our impact',
          'impact_unavailable_title': 'Statistics unavailable',
          'impact_unavailable_subtitle':
              'Impact data cannot be verified right now. Please try again later.',
          'impact_hero_title': 'Education without borders',
          'impact_hero_subtitle':
              'KPB Education guides African talents toward the best study destinations.',
          'impact_stat_students_guided': 'Students guided',
          'impact_stat_admissions': 'Admissions secured',
          'impact_stat_scholarships': 'Scholarships referenced',
          'impact_stat_countries': 'Destination countries',
          'impact_stat_partner_institutions': 'Partner institutions',
          'impact_stat_orientation_sessions': 'AI orientation sessions',
          'impact_satisfaction_rate': 'Satisfaction rate',
          'interview_title': 'Interview simulator',
          'interview_picker_intro':
              'Practice with an AI examiner. Choose an interview type:',
          'interview_type_visa_title': 'Student visa interview',
          'interview_type_visa_subtitle':
              'Consular questions: funding, return, study plan.',
          'interview_type_admission_title': 'Admission interview',
          'interview_type_admission_subtitle':
              'Motivation, background, fit with the program.',
          'interview_type_scholarship_title': 'Scholarship interview',
          'interview_type_scholarship_subtitle':
              'Impact, leadership, return plan and commitment.',
          'interview_answer_hint': 'Type your answer here...',
          'interview_evaluating': 'Evaluating...',
          'interview_submit_answer': 'Submit my answer',
          'interview_feedback_strengths': 'Strengths',
          'interview_feedback_improvements': 'To improve',
          'interview_next_question': 'Next question',
          'interview_finish': 'Finish',
          'letter_tpl_admission_general_title':
              'University Admission (general)',
          'letter_tpl_admission_master_title':
              'Master / Specialised Programme Admission',
          'letter_tpl_scholarship_kpb_title': 'KPB Education Scholarship',
          'letter_tpl_scholarship_international_title':
              'International Excellence Scholarship',
          'letter_tpl_visa_student_title': 'Student Visa Motivation Letter',
          'letter_tpl_internship_title':
              'International Internship / Work-Study',
          'letter_category_admission': 'Admissions',
          'letter_category_scholarship': 'Scholarships',
          'letter_category_internship': 'Internship / Work-Study',
          'letters_title': 'Motivation letters',
          'letters_filter_all': 'All',
          'letters_personalized_badge': 'Personalized',
          'letters_personalizing': 'Personalizing...',
          'letters_field_strengths': '3 strengths to highlight',
          'letters_field_strengths_hint': 'Leadership, rigour, volunteering…',
          'letters_field_event': 'A defining event (optional)',
          'letters_field_event_hint': 'A project, a challenge you overcame…',
          'letters_adapt_to_profile': 'Adapt to my profile',
          'letters_copy_tooltip': 'Copy',
          'letters_copied_snackbar': 'Copied to clipboard',
          'letters_share_tooltip': 'Share',
          'student_tools_intro': 'Practical tools to prepare your application.',
          'student_tools_cv_subtitle':
              'Create a professional CV pre-filled from your profile, enhanced by AI.',
          'student_tools_letters_subtitle':
              '6 templates (admissions, scholarships, visa, internship) customizable with AI in FR and EN.',
          'student_tools_interview_subtitle':
              'Practice visa, admission and scholarship interviews with an AI examiner that scores you.',
          'student_tools_scanner_subtitle':
              'Scan and organize your application documents (passport, diplomas...) into PDF.',
          'student_tools_impact_subtitle':
              'Discover KPB Education\'s impact: students guided, admissions, scholarships.',
          'search_field_not_found_title': 'Field not found',
          'search_field_not_found_body': 'This field is no longer available.',
          'search_hint': 'Search a field, country, school...',
          'search_clear_history': 'Clear',
          'search_suggestions': 'Suggestions',
          'search_suggestion_france': 'France',
          'search_suggestion_school': 'School',
          'search_suggestion_engineering': 'Engineering',
          'search_no_results_subtitle': 'Try other keywords',
          'search_section_fields': 'Fields',
          'search_section_countries': 'Countries',
          'search_section_institutions': 'Universities',
          'search_section_programs': 'Programs',
          'match_why_this_match': 'Why this match?',
          'scholarships_empty_title': 'No matching scholarships',
          'scholarships_empty_subtitle':
              'Try changing your criteria or orientation.',
          'scholarship_tab_info_criteria': 'Info & Criteria',
          'scholarship_tab_success_path': 'My Success Path',
          'scholarship_detail_level_label': 'Level: ',
          'scholarship_detail_funding_label': 'Funding: ',
          'scholarship_detail_deadline_label': 'Deadline: ',
          'scholarship_apply_with_kpb': 'Apply with KPB',
          'scholarship_academy_continue': 'Continue your course',
          'scholarship_academy_prepare':
              'Prepare your application with experts',
          'scholarship_academy_open_pack': 'Open my pack',
          'scholarship_academy_view_pack': 'View the Success Pack',
          'live_scholarships_filter_all': 'All',
          'live_scholarships_filter_fully_funded': 'Fully funded',
          'live_scholarships_filter_partially_funded': 'Partially funded',
          'live_scholarships_connection_error_title': 'Connection error',
          'live_scholarships_connection_error_subtitle':
              'Check your connection and try again.',
          'live_scholarships_empty_filtered_title':
              'No scholarship matches these filters',
          'live_scholarships_empty_filtered_subtitle':
              'Your filters or academic profile are narrowing the list. You can view every available scholarship.',
          'live_scholarships_show_all': 'View all scholarships',
          'live_scholarships_empty_catalog_title':
              'No scholarship published yet',
          'live_scholarships_empty_catalog_subtitle':
              'Our team verifies and publishes new scholarships regularly. Check back soon or turn on alerts.',
          'live_scholarships_unfiltered_notice':
              'No scholarship matches your profile exactly — showing all available scholarships.',
          'live_scholarships_fully_funded': 'Fully funded',
          'live_scholarships_partially_funded': 'Partially funded',
          'live_scholarships_funding_unknown': 'Funding unknown',
          'live_scholarships_funding_unspecified': 'Funding not specified',
          'live_scholarships_level_label': 'Level',
          'live_scholarships_all_levels': 'All levels',
          'live_scholarships_deadline_label': 'Deadline',
          'live_scholarships_see_official_site': 'See official site',
          'live_scholarships_match_excellent':
              'Excellent profile for this scholarship!',
          'live_scholarships_match_compatible':
              'Compatible profile — strengthen your application.',
          'live_scholarships_match_partial':
              'Partial profile — the criteria are demanding.',
          'live_scholarships_section_description': 'Description',
          'live_scholarships_section_advantages': 'Benefits',
          'live_scholarships_section_eligibility': 'Eligibility criteria',
          'live_scholarships_section_key_requirements':
              'Key documents and requirements',
          'live_scholarships_section_application_steps': 'How to apply',
          'live_scholarships_requirement_automatic': 'Automatically awarded',
          'live_scholarships_requirement_separate_application':
              'Separate application required',
          'live_scholarships_step_duration': 'Estimated duration: @days day(s)',
          'live_scholarships_apply_with_kpb': '🎯  Apply with KPB',
          'live_scholarships_view_official_application':
              'View the official application site',
          'live_scholarships_official_form': 'Official application form',
          'live_scholarships_deadline_soon': 'Deadline soon',
          'live_scholarships_deadline_closed': 'Closed',
          'live_scholarships_deadline_days': 'D-@count',
          'live_scholarships_no_deadline': 'No fixed deadline',
          'live_scholarships_funding_tile': 'Funding',
          'live_scholarships_alert': 'Notify me',
          'live_scholarships_alert_enabled': 'Alert enabled',
          'live_scholarships_alert_error':
              'Unable to update this alert. Please try again.',
          'live_scholarships_open_now': 'Applications open',
          'live_scholarships_open_estimated': 'Estimated opening: @date',
          'live_scholarships_period_estimated':
              'Estimated period: @open – @close',
          'live_scholarships_upcoming_months':
              'Upcoming, usually in @from – @to',
          'live_scholarships_upcoming_month': 'Upcoming, usually in @from',
          'scholarship_detail_title': 'Scholarship details',
          'scholarship_detail_not_found': 'Scholarship not found',
          'scholarship_detail_not_found_body':
              'This scholarship is no longer available or its link has expired.',
          'scholarship_how_to_apply_unavailable':
              'Detailed steps will be added soon. Check the official form for current instructions.',
          'scholarship_videos_title': 'Explanation videos',
          'scholarship_video_explanation': 'Understand this scholarship',
          'scholarship_video_play': 'Play video',
          'scholarship_video_unavailable':
              'This video is not available right now.',
          'scholarship_video_open_youtube': 'Watch on YouTube',
          'scholarship_video_more': 'More videos',
          'scholarship_guide_short_title': 'The Ultimate Scholarship Guide',
          'scholarship_guide_promo_body':
              'A clear method for preparing competitive international scholarship applications.',
          'scholarship_guide_learn_more': 'Learn more',
          'scholarship_guide_whatsapp_cta': 'Ask an advisor about the guide',
          'scholarship_guide_whatsapp_prefill':
              'Hello KPB, I would like to obtain the Ultimate Scholarship Guide. Could you tell me how it works?',
          'scholarship_guide_title': 'The Ultimate African Scholarship Guide',
          'scholarship_guide_intro':
              'A practical path from the dream of studying abroad to a structured and competitive application.',
          'scholarship_guide_inside_title': 'What you will learn',
          'scholarship_guide_item_opportunities':
              'Identify international scholarships open to African students.',
          'scholarship_guide_item_documents':
              'Build a CV and motivation letter suited to your study level.',
          'scholarship_guide_item_recommendations':
              'Prepare recommendation requests and letter templates.',
          'scholarship_guide_item_steps':
              'Organize every application with clear steps and checklists.',
          'scholarship_guide_item_bonus':
              'Strengthen your English and avoid the most common mistakes.',
          'scholarship_guide_author':
              'Created by a 2024 Chevening scholar who has supported hundreds of African students.',
          'scholarships_sorted_hint':
              'Ranked for your profile. Enable an alert so you do not miss the opening.',
          'eligibility_see_my_result': 'See my result',
          'answer_yes': 'Yes',
          'answer_maybe': 'Maybe',
          'answer_no': 'No',
          'eligibility_verdict_eligible_title': '🟢 You appear eligible',
          'eligibility_verdict_eligible_body':
              'You meet the stated criteria. Prepare your application — a KPB advisor can help you maximise your chances.',
          'eligibility_verdict_conditional_title':
              '🟡 Eligibility to be confirmed',
          'eligibility_verdict_conditional_body':
              'You meet some of the criteria but some remain to be verified. An advisor can help you confirm your eligibility.',
          'eligibility_verdict_unlikely_title': '🔴 Probably not eligible',
          'eligibility_verdict_unlikely_body':
              'At least one key criterion does not appear to be met. Exceptions sometimes exist — talk to an advisor, or explore other scholarships.',
          'talk_to_advisor': 'Talk to an advisor',
          'roadmap_redirect_writing_tutorials':
              'Redirecting to writing tutorials...',
          'roadmap_redirect_kpb_expert': 'Redirecting to the KPB expert...',
          'roadmap_view_tutorials': 'View tutorials',
          'roadmap_book_expert': 'Book an expert',
          'eligibility_export_pdf': 'Export / share as PDF',
          'eligibility_your_info': 'Your information',
          'eligibility_current_study_level': 'Current study level',
          'eligibility_bac_series': 'Baccalauréat track',
          'eligibility_monthly_budget_eur': 'Monthly budget (EUR)',
          'eligibility_budget_hint': 'e.g. 900',
          'eligibility_french_level': 'French level',
          'eligibility_english_level': 'English level',
          'eligibility_export_failed_title': 'Export failed',
          'eligibility_export_failed_body':
              'The PDF could not be generated. Please try again.',
          'eligibility_summary_eligible': 'Eligible',
          'eligibility_summary_conditions': 'With conditions',
          'eligibility_summary_to_prepare': 'To prepare',
          'eligibility_pdf_title': 'Eligibility simulator',
          'eligibility_pdf_your_profile': 'Your profile',
          'eligibility_pdf_name': 'Name',
          'eligibility_pdf_study_level': 'Study level',
          'eligibility_pdf_not_provided': 'Not provided',
          'eligibility_pdf_monthly_budget': 'Monthly budget',
          'eligibility_pdf_to_confirm': 'To be confirmed',
          'eligibility_pdf_verdicts_by_destination': 'Verdicts by destination',
          'eligibility_pdf_disclaimer':
              'Indicative estimate generated by KPB Education. Final conditions depend on each school and consulate. Contact your KPB advisor to validate your file.',
          'lang_level_beginner': 'Beginner',
          'lang_level_intermediate': 'Intermediate',
          'lang_level_fluent': 'Fluent',
          'eligibility_verdict_conditions': 'Eligible with conditions',
          'eligibility_verdict_not_eligible': 'Not eligible for now',
          'case_whatsapp_advisor_prefill_provisional':
              'Hello, I\'m getting back to you about my request « @title » (reference being registered).',
          'case_whatsapp_advisor_prefill':
              'Hello, I\'m getting back to you about case @reference.',
          'case_whatsapp_continue_prefill_provisional':
              'Hello KPB, I\'d like to continue with my request « @title » (reference being registered).',
          'case_whatsapp_continue_prefill':
              'Hello KPB, I\'d like to continue with case @reference.',
          'case_section_messages': 'Messages',
          'case_unread_suffix': 'unread',
          'case_timeline_since_date': 'Since @date',
          'case_timeline_on_date': 'On @date',
          'case_tunnel_attached_documents_prefix': 'Attached documents:',
          'case_recap_files_count': '@count file(s)',
          'cases_count': '@count case(s)',
          'cases_new_messages_badge': '@count new',
          'cases_messages_count': '@count message(s)',
          // --- KPB-89 batch ---
          'case_upload_take_photo': 'Take a photo',
          'case_upload_from_gallery': 'Choose from gallery',
          'case_upload_pick_pdf': 'Choose a file (PDF)',
          'common_error': 'Error',
          'case_not_found_title': 'Case not found',
          'case_not_found_body_title': 'This case is no longer available',
          'case_not_found_subtitle': 'Go back to your cases list to continue.',
          'case_not_found_action': 'Open my cases',
          'case_advisor_role': 'KPB Education advisor',
          'case_section_documents': 'Documents',
          'case_document_send': 'Send',
          'case_document_received': '✓ Received',
          // ── M2: documents go through the advisor ──
          'case_document_send_whatsapp': 'Send on WhatsApp',
          'case_document_whatsapp_prefill':
              'Hello KPB Education, here is "@document" for my case @reference.',
          'case_documents_handoff_title':
              'Your documents go through your advisor',
          'case_documents_handoff_body':
              'For now, attachments cannot be sent from the app: your advisor receives them on WhatsApp and confirms they arrived. Get your CV, transcripts and passport ready — you can scan them from the app\'s toolbox.',
          'case_documents_handoff_cta': 'Send my documents on WhatsApp',
          'case_documents_handoff_prefill':
              'Hello KPB Education, I am preparing my "@title" request and would like to send you my documents.',
          'case_documents_handoff_footnote':
              'You can continue without sending anything now: your advisor will tell you which documents are needed.',
          'case_ai_review_cta': '✨ AI review of my documents',
          'case_section_history': 'History',
          'case_continue_whatsapp': 'Continue on WhatsApp',
          'case_whatsapp_has_advisor_subtitle':
              'Chat directly with your KPB advisor.',
          'case_whatsapp_no_advisor_subtitle':
              'Join the KPB group while we assign your advisor.',
          'case_timeline_heading': 'Track your request',
          'case_timeline_status_submitted': 'Submitted',
          'case_timeline_status_counselor_assigned': 'Assigned to an advisor',
          'case_timeline_status_under_review': 'Under review',
          'case_timeline_status_documents_needed': 'Documents required',
          'case_timeline_status_awaiting_student': 'Awaiting your response',
          'case_timeline_status_in_progress': 'In progress',
          'case_timeline_status_application_submitted':
              'Submitted to the institution',
          'case_timeline_status_waiting_decision': 'Decision pending',
          'case_timeline_status_awaiting_payment': 'Payment pending',
          'case_timeline_status_completed': 'Accepted',
          'case_timeline_status_cancelled': 'Request cancelled',
          'case_timeline_status_rejected': 'Rejected',
          'case_stepper_heading': 'Progress',
          'case_stepper_creation_title': 'Case creation',
          'case_stepper_creation_desc_draft':
              'Complete your profile to submit the request.',
          'case_stepper_creation_desc_done': 'Case submitted successfully.',
          'case_stepper_analysis_title': 'Analysis and advisor',
          'case_stepper_analysis_desc_docs':
              'Additional documents are required.',
          'case_stepper_analysis_desc_awaiting':
              'Your advisor is waiting for your reply.',
          'case_stepper_analysis_desc_default':
              'Our experts are reviewing your profile.',
          'case_stepper_processing_title': 'Processing',
          'case_stepper_processing_desc':
              'Preparing and submitting your applications.',
          'case_stepper_decision_title': 'Decision',
          'case_stepper_decision_desc':
              'Awaiting responses from the institutions.',
          'case_stepper_finalization_title': 'Finalization',
          'case_stepper_finalization_desc_rejected': 'Case rejected.',
          'case_stepper_finalization_desc_cancelled': 'Case cancelled.',
          'case_stepper_finalization_desc_done':
              'Procedure completed successfully!',
          'case_tunnel_step_type': 'Type',
          'case_tunnel_step_context': 'Context',
          'case_tunnel_step_message': 'Message',
          'case_tunnel_step_confirmation': 'Confirmation',
          'case_tunnel_incomplete_profile_title': 'Incomplete profile',
          'case_tunnel_incomplete_profile_body':
              'Complete your profile so a KPB advisor can handle your request. It takes two minutes, and you will come back here afterwards.',
          'case_tunnel_incomplete_profile_cta': 'Complete my profile',
          'case_tunnel_pick_photo': 'Photo',
          'case_tunnel_pick_gallery': 'Gallery',
          'case_tunnel_file_too_large_title': 'File too large',
          'file_too_large_body':
              'This file is @size MB; the limit is @max MB. Take a smaller photo, or send it to your advisor on WhatsApp.',
          'case_tunnel_add_file_failed': 'Couldn\'t add this file. Try again.',
          'common_back': 'Back',
          'common_next': 'Next',
          'case_type_application_support': 'School enrollment',
          'case_type_scholarship': 'Scholarship',
          'case_type_consultation': 'Visa / application',
          'case_type_housing': 'Housing',
          'case_type_other': 'Other',
          'case_context_country': 'Country',
          'case_context_school': 'School',
          'case_context_program': 'Program',
          'case_doc_transcripts': 'Transcripts',
          'case_doc_passport': 'Passport',
          'case_documents_step_hint':
              'Add your documents now (optional). You can also send them later with your advisor.',
          'common_add': 'Add',
          'common_replace': 'Replace',
          'case_message_mic_required_title': 'Microphone required',
          'case_message_mic_required_body':
              'Allow microphone access to dictate your message.',
          // Voir le commentaire du bloc `fr` : le refus de la reconnaissance
          // LOCALE est un cas distinct d'une panne de dictée ordinaire.
          'case_message_dictation_unavailable_title': 'Dictation unavailable',
          'case_message_dictation_unavailable_body':
              'Speech recognition isn\'t available on this device.',
          // Voir le commentaire du bloc `fr` : après l'accord d'envoi au service
          // de la plateforme, la reconnaissance est disponible et c'est la
          // session qui n'a pas démarré — deux causes, deux messages.
          'case_message_dictation_not_started_title': 'Dictation didn\'t start',
          'case_message_dictation_not_started_body':
              'The dictation session couldn\'t start right now. Check that no other app is using the microphone, then try again.',
          'case_message_dictation_on_device_unavailable_title':
              'On-device recognition unavailable',
          'case_message_dictation_on_device_unavailable_body':
              'Your phone cannot turn speech into text offline. To dictate, your voice would be sent to your phone\'s recognition service (Apple or Google) and processed off the device. You can also type your message instead.',
          'case_message_dictation_use_platform_service': 'Dictate anyway',
          'case_message_stop_dictation': 'Stop dictation',
          'case_message_dictate': 'Dictate my message',
          'case_contact_phone': 'Phone',
          'case_recap_contact': 'Contact',
          'cases_filter_all': 'All',
          'case_type_filter_consultation': 'Consultation',
          'case_type_filter_application': 'Application',
          'case_type_filter_mentorship': 'Mentorship',
          'cases_new_message_badge': 'New message',
          'cases_action_send_documents': '📎 Send my documents',
          'cases_action_chat_advisor': '💬 Chat with my advisor',
          'cases_action_reply_advisor': '✉️ Reply to advisor',
          'cases_action_view_appointment': '📅 View my appointment',
          'case_status_short_submitted': 'Sent',
          'case_status_short_counselor': 'Advisor',
          'case_status_short_action_required': 'Action required',
          'case_status_short_scheduled': 'Scheduled',
          'case_status_short_application_submitted': 'Submitted',
          'case_status_short_payment': 'Payment',
          'case_status_short_completed': 'Completed',
          'case_status_short_rejected': 'Rejected',
          'case_status_short_cancelled': 'Cancelled',
          'case_status_short_draft': 'Draft',
          'doc_review_kind_motivation': 'Motivation letter',
          'doc_review_hint_motivation':
              'Paste the text of your motivation letter here…',
          'doc_review_hint_cv': 'Paste the content of your CV here…',
          'doc_review_unavailable': 'Review unavailable right now.',
          'doc_review_title': 'AI review',
          'doc_review_kind_label': 'Document type',
          'doc_review_draft_label': 'Your draft',
          'doc_review_analyze_cta': 'Analyze my document',
          'doc_review_strengths': 'Strengths',
          'doc_review_missing': 'Missing elements',
          'doc_review_disclaimer':
              'Indicative review — for an in-depth review, ask a KPB advisor.',
          'doc_review_score_label': 'Overall score',
          'doc_review_improvements': 'To improve',
          'doc_viewer_download_title': 'Download',
          'doc_viewer_download_body': 'The download will start shortly...',
          // --- KPB-89 batch ---
          'country_study_in': 'Study in @country',
          'program_available_on_campuses': 'Available on @count campuses',
          'quiz_title_with_country': 'Quiz · @country',
          'quiz_question_progress': 'Question @current/@total',
          'quiz_enrollment_with_program': 'Enrollment — @program',
          'explore_campus_count': '📍 @count campuses',
          'explore_programs_count': '@count programs',
          'country_why_this_country': 'Why this country?',
          'country_how_it_works': 'How it works',
          'country_costs': 'Costs',
          'country_tuition_fees': 'Tuition fees',
          'country_living_cost_per_month': 'Cost of living / month',
          'country_visa_and_insurance': 'Visa & insurance',
          'country_required_language': 'Required language',
          'country_partner_schools': 'Partner schools in this country',
          'country_available_scholarships': 'Available scholarships',
          'program_step_eligibility_choice':
              'Eligibility quiz & program choice',
          'program_step_build_file': 'Building your file with KPB',
          'program_step_submission': 'Submission to the partner school',
          'program_step_admission_letter': 'Receiving the admission letter',
          'program_step_visa_departure': 'Visa & departure preparation',
          'badge_kpb_partner': 'KPB Partner',
          'program_at_a_glance': 'The program at a glance',
          'program_level': 'Level',
          'program_duration': 'Duration',
          'program_language': 'Language',
          'program_country': 'Country',
          'program_campus': 'Campus',
          'program_intake': 'Intake',
          'program_field': 'Field',
          'program_admission_requirements': 'Admission requirements',
          'program_application_process': 'Application process',
          'quiz_unavailable_for_country': 'Quiz unavailable for this country.',
          'quiz_load_failed': 'Unable to load the quiz.',
          'eligibility_quiz_title': 'Eligibility quiz',
          'quiz_unavailable_title': 'Quiz unavailable',
          'back': 'Back',
          'quiz_see_verdict': 'See my verdict',
          'next': 'Next',
          'explore_tab_fields': 'Fields',
          'explore_tab_programs': 'Programs',
          'explore_tab_universities': 'Universities',
          'explore_tab_support': 'Support',
          'explore_no_fields_title': 'No fields available',
          'explore_no_fields_body':
              'Check back later to discover our new programs.',
          'explore_no_countries_title': 'No countries available',
          'explore_no_countries_body':
              'We are currently expanding our catalog of destinations.',
          'explore_no_programs_title': 'No programs available',
          'explore_no_programs_body':
              'Sync the app with the server to load the catalog.',
          'explore_search_program': 'Search a program',
          'explore_share_university':
              'Discover this university on KPB Education.',
          'compare_selected_label': 'Selected',
          'field_careers': 'Careers',
          'field_key_subjects': 'Key subjects',
          'field_skills_developed': 'Skills developed',
          'badge_official_partner': 'Official Partner',
          'institution_overview': 'Overview',
          'institution_popular_programs': 'Popular programs',
          'institution_kpb_expert': 'KPB Expert',
          'institution_enroll_via_kpb': 'Enroll via KPB',
          'learn_more': 'Learn more',
          'institution_premium_support_guaranteed':
              'Guaranteed Premium Support',
          'institution_premium_support': 'Premium Support',
          'institution_kpb_benefits': 'KPB Education benefits',
          'institution_priority_admission': 'Priority Admission',
          'institution_priority_admission_desc':
              'Your file is processed as a priority by the university.',
          'institution_dedicated_coach': 'Dedicated Coach',
          'institution_dedicated_coach_desc':
              'An expert guides you from enrollment to visa.',
          'institution_exclusive_scholarships': 'Exclusive Scholarships',
          'institution_exclusive_scholarships_desc':
              'Access to financial aid reserved for partners.',
          'account_type_student': 'Student',
          'account_type_parent': 'Parent',
          'account_type_partner': 'Partner (school / agency)',
          'account_type_commercial': 'KPB Sales Rep',
          'onboarding_consent_required_title': 'Consent required',
          'onboarding_consent_required_body':
              'Please accept the privacy policy and terms of use.',
          'onboarding_selection_required_title': 'Selection required',
          'onboarding_select_field_body':
              'Choose at least one field of interest.',
          'onboarding_select_country_body':
              'Choose at least one destination country.',
          'onboarding_welcome_title': 'Welcome 👋',
          'onboarding_welcome_subtitle':
              'Let\'s create your KPB Education profile.',
          'onboarding_academic_title': 'Your background 🎓',
          'onboarding_academic_subtitle': 'Tell us where you stand.',
          'onboarding_partner_title': 'Your organization 🤝',
          'onboarding_partner_subtitle': 'Tell us about your organization.',
          'onboarding_interests_title': 'Your interests 🌍',
          'onboarding_interests_subtitle': 'Personalize your recommendations.',
          'skip': 'Skip',
          'onboarding_i_am': 'I am',
          'account_type_parent_short': 'Parent',
          'onboarding_consent_accept_prefix': 'I accept the ',
          'onboarding_consent_and': ' and the ',
          'onboarding_terms_of_use_inline': 'terms of use',
          'onboarding_partnership_space': 'Partnership space',
          'intro_slide1_title': 'Explore your destinations',
          'intro_slide1_body':
              'Discover hundreds of programs in Canada, France, and around the world.',
          'intro_slide2_title': 'Scholarships & support',
          'intro_slide2_body':
              'Find the ideal scholarship and get a roadmap tailored to your profile.',
          'intro_slide3_title': 'Real-time tracking',
          'intro_slide3_body':
              'Track your file\'s progress and chat with our counselors, right in the app.',
          'get_started': 'Get started',
          'continue_action': 'Continue',
          'profile_data_saver_desc': 'Save data (hides heavy images)',
          'profile_analytics': 'Usage analytics',
          // Voir le commentaire du bloc `fr`.
          'profile_analytics_desc':
              'Allow anonymous usage analytics, crash diagnostics and session recording (content masked) to improve the app',
          'profile_newsletter': 'Scholarship newsletter',
          'profile_newsletter_desc':
              'Receive newly available scholarships by email (unsubscribe anytime)',
          'profile_quick_orientation_test': 'Orientation test',
          'profile_quick_eligibility_simulator': 'Eligibility simulator',
          'profile_quick_journeys_testimonials': 'Journeys & testimonials',
          'profile_quick_saved_items': 'Saved items',
          'profile_quick_budget_calculator': 'Budget calculator',
          'profile_quick_flight_simulator': 'Flight simulator (Kayak)',
          'profile_quick_student_housing': 'Student housing (France)',
          'profile_quick_community_articles': 'Community & Articles',
          'profile_quick_parent_space': 'Parent space',
          'profile_quick_parent_mode': 'Parent mode',
          'profile_quick_kpb_services': 'KPB Services (Ready dossier)',
          'profile_quick_verified_alumni_mentors': 'Verified alumni mentors',
          'profile_quick_become_alumni_mentor': 'Become an alumni mentor',
          'profile_quick_virtual_salon': 'Virtual KPB Salon',
          'profile_privacy_policy': 'Privacy policy',
          'profile_terms_of_service': 'Terms of service',
          'account_type_commercial_2': 'Sales',
          'profile_field_full_name': 'Full name',
          'required': 'Required',
          'profile_field_phone': 'Phone',
          'profile_field_email_helper':
              'The email you sign in with — it can\'t be changed here.',
          'profile_field_country_of_residence': 'Country of residence',
          'profile_field_current_study_level': 'Current study level',
          'profile_field_bac_series': 'Baccalaureate track',
          'profile_updated_title': 'Profile updated',
          'profile_updated_body': 'Your information has been saved.',
          'profile_missing_grade_field': 'Academic average',
          'profile_missing_grade_impact':
              'Improves the accuracy of your school recommendations',
          'profile_missing_current_level_impact':
              'Essential to match available programs',
          'profile_missing_target_level_field': 'Target level',
          'profile_missing_target_level_impact':
              'Helps advisors guide your application',
          'profile_missing_documents_field': 'Available documents',
          'profile_missing_documents_impact':
              'Our advisors need them to assess your application',
          'profile_missing_language_level_field': 'Language level',
          'profile_missing_language_level_impact':
              'Some universities have minimum thresholds',
          'profile_missing_full_name_field': 'Full name',
          'profile_missing_full_name_impact':
              'This is the name that will appear on your applications',
          'profile_missing_email_field': 'Email address',
          'profile_missing_email_impact':
              'How schools and our advisors reply to you',
          'profile_missing_phone_field': 'Phone',
          'profile_missing_phone_impact':
              'Lets an advisor reach you about an urgent application',
          'profile_missing_country_field': 'Country of residence',
          'profile_missing_country_impact':
              'Determines which scholarships and procedures are open to you',
          'profile_missing_language_field': 'App language',
          'profile_missing_language_impact':
              'Sets the language of your content and notifications',
          'profile_missing_fields_field': 'Fields of study',
          'profile_missing_fields_impact':
              'Without them, no programme recommendation is possible',
          'profile_missing_target_countries_field': 'Target countries',
          'profile_missing_target_countries_impact':
              'Drives your scholarships, costs and processing times',
          'profile_missing_budget_field': 'Annual tuition budget',
          'profile_missing_budget_impact':
              'Rules out programmes beyond reach and targets useful scholarships',
          'universities_empty_sync_subtitle':
              'Sync the app with the server to load the catalog.',
          // --- KPB-89 home ---
          'home_greeting': 'Hi 👋',
          'home_greeting_named': 'Hi, @name 👋',
          'home_design_greeting': 'Hi 👋',
          'home_design_greeting_named': 'Hi, @name 👋',
          'home_design_header_subtitle': 'Your destinations @countries',
          'home_design_discovery_title': 'Discovery path',
          'home_design_discovery_subtitle':
              'Your next mission — created with your account',
          'home_design_tools_title': 'Your tools',
          'home_profile_pct_notice':
              'At @pct% — missing fields limit your recommendations',
          'home_admission_prefix': 'Admission: @value',
          'home_subtitle_student': 'Your dashboard',
          'home_subtitle_parent': 'Parent space',
          'home_subtitle_partner': 'Partner space',
          'home_active_cases_title': 'Active cases',
          'see_all': 'See all',
          'home_recommended_universities_title': 'Schools for your profile',
          'home_hero_title_partner': 'Let\'s grow\\nyour network',
          'home_hero_title_parent': 'Support\\nyour child',
          'home_hero_title_student': 'Your journey\\nto study abroad',
          'home_hero_subtitle_student':
              'One step at a time — we move forward together.',
          'home_hero_subtitle_other': 'Get started today.',
          'home_hero_cta_consultation': 'Consultation',
          'home_hero_cta_become_partner': 'Become a partner',
          'home_case_title_book_appointment': 'Book an appointment',
          'home_hero_profile_ring_label': 'Profile',
          'home_next_step_label_action_required': 'Action required',
          'home_next_step_title_talk_advisor': 'Talk with your advisor',
          'home_next_step_title_documents_to_send': 'Documents to send',
          'home_next_step_title_response_expected': 'Your response is expected',
          'home_next_step_label_your_profile': 'Your profile',
          'home_next_step_title_complete_profile': 'Complete your profile',
          'home_next_step_subtitle_missing_info':
              'Some info is missing to personalize your recommendations',
          'home_next_step_label_discovery': 'Discovery',
          'home_next_step_title_take_orientation': 'Take your orientation test',
          'home_next_step_subtitle_orientation':
              '5 questions to find the fields that fit you',
          'home_next_step_label_next_step': 'Next step',
          'home_next_step_title_start_case': 'Start your case',
          'home_next_step_subtitle_start_case':
              'Profile and orientation ready — now is the right time to get started',
          'home_case_title_new_case': 'New case',
          'home_next_step_label_explore': 'Explore',
          'home_next_step_title_discover_opportunities':
              'Discover new opportunities',
          'home_next_step_subtitle_explore':
              'Browse the fields, countries and scholarships that match your profile',
          'home_quick_action_scholarships': 'Scholarships',
          'home_quick_action_cases': 'Cases',
          'home_ai_advisor_title': 'AI Orientation Advisor',
          'home_badge_new': 'New',
          'home_ai_advisor_cta': 'Chat with the AI',
          'case_status_documents_needed': 'Docs required',
          'case_status_awaiting_payment': 'Payment',
          'case_status_awaiting_student': 'Your response',
          'case_status_scheduled': 'Appointment set',
          'case_status_in_progress': 'In progress',
          'case_status_under_review': 'Under review',
          'case_status_counselor_assigned': 'Advisor assigned',
          'case_status_submitted': 'Submitted',
          'case_status_application_submitted': 'Application sent',
          'case_status_waiting_decision': 'Awaiting decision',
          'badge_partner': 'Partner',
          'home_days_left_label': 'days',
          'home_deadline_near_label': '⏰ DEADLINE APPROACHING',
          'home_deadline_see_button': 'View →',
          'home_badge_guidance': 'Guidance',
          'home_student_tools_title': 'Student tools',
          'home_student_tools_subtitle': 'CV, cover letters, and more',
          // ── Progress gauge card (App-engagement handoff) ──
          'home_gauge_eyebrow': 'PROGRESS GAUGE',
          'home_gauge_bar_level': 'Level',
          'home_gauge_bar_interests': 'Interests',
          'home_gauge_bar_documents': 'Documents',
          'home_gauge_bar_budget': 'Budget',
          'home_case_documents_ratio': '@done/@total documents provided',
          // ── Parcours preview (Home) ──
          'home_parcours_title': 'They did it before you',
          'home_parcours_subtitle': 'Video journeys of African students — free',
          // ── Contact KPB counselor (Home, App-engagement handoff) ──
          'home_counselor_cta_title': 'Talk to a KPB counselor',
          'home_counselor_cta_subtitle':
              'On WhatsApp, with your profile already shared. Replies in ~2h.',
          'sample_data_notice':
              'Sample data — couldn’t reach the server. The catalog shown isn’t live yet.',
          'freshness_saved': 'saved data',
          'freshness_today': 'data saved today',
          'freshness_yesterday': 'data saved yesterday',
          'freshness_days': 'data saved @n days ago',
          'freshness_date': 'data from @date',
          'stale_catalog_notice':
              'Server unreachable — real data from your last load',
          // ── "Études en France" space (Phase 0 — teaser) ──
          // The procedure is named, never the agency. See the FR block.
          'eef_title': 'Studying in France',
          'eef_status_preparing': 'In preparation',
          'eef_hero_title': 'Your France application,\nend to end',
          'eef_hero_body':
              'A space dedicated to the French campaign: find the programmes '
                  'that fit your profile, build your file, prepare your '
                  'interview. We are building it right now.',
          'eef_opens_in_days': 'opens in @days days',
          'eef_opens_tomorrow': 'opens tomorrow',
          'eef_deadline_varies_notice':
              'Closing dates vary by country and by procedure. We will confirm '
                  'yours inside the space.',
          'eef_official_platform_link': 'Open the official platform',
          'eef_official_suspension_link': 'See the official source',
          'eef_suspended_notice':
              'In your country, processing of Études en France applications is '
                  'currently suspended by the French authorities. The platform '
                  'opening does not change that. Talk to a KPB counsellor: '
                  'other destinations remain open.',
          'eef_pillars_heading': 'What you will be able to do',
          // ── Space hub (build 54) ──────────────────────────────────────────
          'eef_hub_hero_title':
              'Prepare your application to French universities',
          'eef_hub_hero_body':
              'Find the programmes that suit you, then prepare your file: CV, '
                  'motivation letters, interview. The application itself is '
                  'submitted through the official services, following the '
                  'procedure shown on each programme (the Études en France '
                  'platform run by Campus France, pre-admission request…).',
          'eef_hub_formations_title': 'Find my programme',
          'eef_hub_formations_body':
              'Public universities and a few public institutions: search by '
                  'name, city, level and admission procedure.',
          'eef_hub_tools_heading': 'Prepare my file',
          'eef_hub_advisor_title': 'Talk to an advisor',
          'eef_hub_advisor_body':
              'A question about your application? A KPB advisor answers you on '
                  'WhatsApp.',
          'eef_hub_whatsapp_prefill':
              'Hello, I have a question about my application to French '
                  'universities (Études en France).',
          // ── Help at every unclear step (EefHelpCard) ─────────────────────
          // No promise of admission or a visa (`eef_help_fineprint` says so),
          // no price, and a NEUTRAL set (`eef_help_neutral_*`) for a suspended
          // country that never talks about opening a file.
          'eef_help_hub_question': 'Unclear? Want some help?',
          'eef_help_hub_body':
              'To move on to the next step, contact us on WhatsApp to start a '
                  'review of your file.',
          'eef_help_hub_cta': 'Start my file review on WhatsApp',
          'eef_help_procedure_question':
              'Procedure, dates, submission: unclear?',
          'eef_help_documents_question': 'Not sure which documents to prepare?',
          'eef_help_catalog_results_question': 'Unsure about your programme?',
          'eef_help_catalog_results_body':
              'Tell us where you are on WhatsApp: a KPB advisor starts a '
                  'review of your file with you, to choose and move on to the '
                  'next step.',
          'eef_help_catalog_results_cta': 'Start my file review on WhatsApp',
          'eef_help_catalog_procedure_question':
              'Not sure about the procedure for these programmes?',
          'eef_help_catalog_empty_question': 'Can\'t find your programme?',
          'eef_help_catalog_empty_body':
              'A KPB advisor can search with you, based on your profile and '
                  'your plans.',
          'eef_help_catalog_empty_cta': 'Ask for help on WhatsApp',
          'eef_help_catalog_unpublished_question': 'Don\'t want to wait?',
          'eef_help_catalog_unpublished_body':
              'A KPB advisor can already look at your plans with you, without '
                  'waiting for the catalogue to arrive.',
          'eef_help_catalog_unpublished_cta': 'Ask for help on WhatsApp',
          'eef_help_compact_cta': 'Ask for help on WhatsApp',
          'eef_help_neutral_question': 'Need a clearer picture?',
          'eef_help_neutral_body':
              'A KPB advisor can go over the other study options with you.',
          'eef_help_neutral_cta': 'Talk to an advisor about other options',
          'eef_help_fineprint':
              'Guidance is not a guarantee: admission and visas depend on '
                  'institutions and authorities.',
          'eef_help_prefill':
              'Hello KPB Education, I am in the Études en France space of the '
                  'app (step: @step). To move on to the next step, I would like '
                  'to start a review of my file.',
          'eef_help_prefill_suspended':
              'Hello KPB Education, I am in the Études en France space of the '
                  'app (step: @step). The procedure is suspended in my '
                  'country: I would like to talk about other study options.',
          'eef_help_step_hub': 'space home',
          'eef_help_step_procedure': 'procedure, dates and submission',
          'eef_help_step_documents': 'documents to provide',
          'eef_help_step_catalog_results': 'choosing my programme',
          'eef_help_step_catalog_procedure':
              'application procedure of a programme',
          'eef_help_step_catalog_empty': 'programme search with no result',
          'eef_help_step_catalog_unpublished': 'catalogue not yet available',
          // ── Build 55: help triggers (EefHelpLine) ─────────────────────────
          // Under each programme, under the active filters, in the three file
          // tools. Same rules as above: no promise, no price, never the name of
          // the State operator; and for a suspended country a NEUTRAL label and
          // message — never "file", never a country, never a replacement
          // country.
          'eef_help_line_cta': 'Ask for help',
          'eef_help_line_neutral_cta': 'Talk to an advisor',
          'eef_help_line_subject': 'Ask for help about “@subject”',
          'eef_help_line_neutral_subject':
              'Talk to an advisor about “@subject”',
          'eef_help_catalog_filters_question': 'Torn between these programmes?',
          'eef_help_tool_cv_question': 'Need help writing your CV?',
          'eef_help_tool_letters_question':
              'Need help with your motivation letter?',
          'eef_help_tool_interview_question':
              'Need help preparing for your interview?',
          'eef_help_tool_cv_label': 'CV',
          'eef_help_tool_letters_label': 'motivation letter',
          'eef_help_tool_interview_label': 'interview preparation',
          'eef_help_filters_family': '@family: @values',
          'eef_help_prefill_program':
              'Hello KPB Education, I am looking at the programme “@program”'
                  '@place in the Études en France space of the app and I would '
                  'like some help with my file.',
          'eef_help_prefill_program_suspended':
              'Hello KPB Education, I am looking at the programme “@program”'
                  '@place in the Études en France space of the app. The '
                  'procedure is suspended in my country: I would like to know '
                  'which options exist.',
          'eef_help_prefill_filters':
              'Hello KPB Education, I am looking at the programmes in the '
                  'Études en France space of the app (@filters) and I cannot '
                  'decide. I would like some help choosing.',
          'eef_help_prefill_filters_suspended':
              'Hello KPB Education, I am looking at the programmes in the '
                  'Études en France space of the app (@filters). The procedure '
                  'is suspended in my country: I would like to know which '
                  'options exist.',
          // No filter to quote (an id the app cannot name, or — for a suspended
          // country — a procedure on its own): never empty parentheses.
          'eef_help_prefill_filters_none':
              'Hello KPB Education, I am looking at the programmes in the '
                  'Études en France space of the app and I cannot decide. I '
                  'would like some help choosing.',
          'eef_help_prefill_filters_none_suspended':
              'Hello KPB Education, I am looking at the programmes in the '
                  'Études en France space of the app. The procedure is '
                  'suspended in my country: I would like to know which options '
                  'exist.',
          'eef_help_prefill_tool':
              'Hello KPB Education, I am in the Études en France space of the '
                  'app, on the “@tool” tool. I would like some help.',
          'eef_help_prefill_tool_suspended':
              'Hello KPB Education, I am looking at the “@tool” tool in the '
                  'Études en France space of the app. The procedure is '
                  'suspended in my country: I would like to know which options '
                  'exist.',
          // ── The hub tour (build 56) ───────────────────────────────────────────
          // Three or four cards on first open, replayable from the "?". Steps 2
          // to 4 are the same for everyone; only step 1 has a NEUTRAL variant
          // (account whose country is suspended): no "application" or "file",
          // no country named. The tour never mentions private schools, quotes
          // no price and promises nothing.
          'eef_tour_title': 'Space tour',
          'eef_tour_counter': 'Step @n of @total',
          'eef_tour_skip': 'Skip',
          'eef_tour_next': 'Next',
          'eef_tour_done': 'Got it',
          'eef_tour_replay': 'Replay the tour',
          'eef_tour_1_title': 'Welcome to Études en France',
          'eef_tour_1_body':
              'Here you explore programmes and prepare your plans. Your '
                  'application itself is submitted to the official services: '
                  'KPB is a private support service, not a government service.',
          'eef_tour_1_neutral_body':
              'Here you explore programmes and prepare your study plans. '
                  'Official procedures take place on the State\'s platforms: '
                  'KPB is a private support service, not a government service.',
          'eef_tour_2_title': 'Find a programme',
          'eef_tour_2_body':
              'Search public university programmes, then filter by level, '
                  'field, city and admission procedure.',
          'eef_tour_3_title': 'Prepare your documents',
          'eef_tour_3_body':
              'A CV builder, motivation letters and an interview simulator '
                  'help you get ready.',
          'eef_tour_4_title': 'A question? Write to us',
          'eef_tour_4_body':
              'The green button at the bottom right connects you with the KPB '
                  'team on WhatsApp. The message is already written and you can '
                  'edit it before sending.',
          // ── The green WhatsApp bubble (build 56) ─────────────────────────────
          // The circle, then the topic sheet. Every message carries `@place`
          // (where the student is) and NOTHING else: no name, country or
          // contact. The "neutral" set (account whose country is suspended)
          // never talks about opening a file or starting one, and never names
          // a country.
          'eef_help_bubble_tooltip': 'Message the KPB team on WhatsApp',
          'eef_help_bubble_hint': 'Opens a list of ready-made messages',
          'eef_help_bubble_title': 'Message the KPB team',
          'eef_help_bubble_subtitle':
              'Pick your topic. WhatsApp opens with a message already '
                  'written: you can edit it, and nothing is sent without you.',
          'eef_help_bubble_place_hub': 'the Études en France space of the app',
          'eef_help_bubble_place_catalog':
              'the catalogue of the Études en France space of the app',
          'eef_help_bubble_assistance_label':
              'Contact the KPB team for assistance',
          'eef_help_bubble_assistance_label_neutral': 'Talk to an advisor',
          'eef_help_bubble_assistance_message':
              'Hello KPB Education, I\'m in @place and I\'d like help from the '
                  'KPB team.',
          'eef_help_bubble_assistance_message_neutral':
              'Hello KPB Education, I\'m in @place. The procedure is suspended '
                  'in my country: I\'d like to know what options exist.',
          'eef_help_bubble_dossier_label': 'I want help with my application',
          'eef_help_bubble_dossier_message':
              'Hello KPB Education, I\'m in @place and I\'d like help '
                  'preparing my application.',
          'eef_help_bubble_choose_label':
              'I don\'t know which programme to choose',
          'eef_help_bubble_choose_message':
              'Hello KPB Education, I\'m in @place. I\'m unsure which '
                  'programme to choose and I\'d like to talk about it.',
          'eef_help_bubble_question_label': 'I have another question',
          'eef_help_bubble_question_message':
              'Hello KPB Education, I have a question about @place.',
          'eef_help_bubble_question_message_neutral':
              'Hello KPB Education, I\'m in @place. The procedure is suspended '
                  'in my country and I have a question.',
          'eef_help_bubble_number': 'Official KPB Education number: @number',
          'eef_help_bubble_copy': 'Copy number',
          'eef_help_bubble_copied': 'Copied',
          'eef_help_bubble_email':
              'No WhatsApp? Write to us at contact@kpbeducation.com',
          // ── Private schools (build 56, PR 3) ─────────────────────────────────
          // The "KPB service" info sheet, the line in the catalogue's "no
          // results" state and the option of the bubble menu. NO amount, NO
          // currency, NO school or country name. The fees fallback
          // (`..._fees_fallback`) is NOT displayed by default.
          'eef_help_private_chip': 'KPB service',
          'eef_help_private_title': 'Private schools: what to know',
          'eef_help_private_point_terms':
              'Each private school sets its own admission requirements, fees '
                  'and calendar.',
          'eef_help_private_point_fees':
              'Fees are generally higher than at public universities. Ask for '
                  'them in writing before you commit.',
          'eef_help_private_point_fees_fallback':
              'Fees vary a lot from one school to another. Ask for them in '
                  'writing before you commit.',
          'eef_help_private_point_steps':
              'Official steps (admission, visa) depend on your country and the '
                  'school. Check them on the official websites.',
          'eef_help_private_point_status':
              'KPB Education is a private support service, not a government '
                  'service.',
          'eef_help_private_cta': 'Talk to an advisor',
          'eef_help_private_dismiss': 'Not now',
          'eef_help_private_message_label': 'Message that will be written:',
          'eef_help_private_message':
              'Hello KPB Education, I\'m in @place. I\'d like to know more about '
                  'private schools: admission requirements, fees and calendar.',
          'eef_help_private_option_label':
              'I want to know more about private schools',
          'eef_help_private_note_text':
              'Private schools have different requirements and calendars.',
          'eef_help_private_note_link': 'Private schools: what to know',
          'eef_hub_guest_body':
              'Create your account to save your profile and ask to be called '
                  'back by an advisor.',
          'eef_students_only_title': 'A space for students',
          'eef_students_only_body':
              'This space prepares a student\'s application and uses their '
                  'profile. Sign in with the student\'s account, or talk to a KPB '
                  'advisor.',
          // ── My Études en France profile ───────────────────────────────────
          'eef_profile_title': 'My Études en France profile',
          'eef_profile_read_failed':
              'We could not read your profile right now. If you already '
                  'answered, your answer is still saved.',
          'eef_profile_empty_body':
              'Tell us your level and your fields: a KPB advisor will be able '
                  'to call you back with the right information.',
          'eef_profile_declare_cta': 'Complete my profile',
          'eef_profile_level_line': 'Current level: @level',
          'eef_profile_target_line': 'Target level: @level',
          'eef_profile_fields_line': 'Fields: @fields',
          'eef_profile_no_fields': 'No field chosen',
          'eef_profile_recorded_body':
              'A KPB advisor may call you back about this space. You can '
                  'withdraw at any time.',
          'eef_profile_edit_cta': 'Edit my profile',
          'eef_profile_edit_title': 'Edit my profile',
          'eef_profile_edit_body':
              'You are only changing your level and your fields. Your consent '
                  'to be called back does not change.',
          'eef_field_domains': 'Your fields (several choices possible)',
          // ── "Études en France" catalogue (Phase 1) ────────────────────
          'eef_catalog_title': 'Programmes',
          'eef_catalog_open': 'Open the catalogue',
          'eef_catalog_search_hint': 'Programme, city…',
          'eef_catalog_facet_cycle': 'Level',
          'eef_catalog_facet_procedure': 'Procedure',
          'eef_catalog_facet_field': 'Field',
          'eef_catalog_facet_city': 'City',
          // Filters: buttons, choice sheet, active filters.
          'eef_catalog_filter_clear': 'Clear',
          'eef_catalog_filter_semantics_none': 'None selected',
          'eef_catalog_filter_semantics_count': '@count selected',
          'eef_catalog_filter_semantics_hint': 'Opens the list of choices',
          'eef_catalog_option_semantics': '@label, @count programme(s)',
          'eef_catalog_sheet_apply_zero': 'Show 0 programmes',
          'eef_catalog_sheet_apply_one': 'Show 1 programme',
          'eef_catalog_sheet_apply_many': 'Show @count programmes',
          'eef_catalog_sheet_apply_generic': 'Show programmes',
          'eef_catalog_active_filters': 'Active filters',
          'eef_catalog_active_clear_all': 'Clear all',
          'eef_catalog_active_remove': 'Remove filter @label',
          'eef_catalog_city_search_hint': 'Search a city',
          'eef_catalog_city_loading': 'Loading cities…',
          'eef_catalog_city_error_title': "Couldn't load the cities",
          'eef_catalog_city_error_network':
              'No connection. Check it, then try again.',
          'eef_catalog_city_error_server':
              "The server didn't respond. Try again in a moment.",
          'eef_catalog_city_retry': 'Retry',
          'eef_catalog_city_empty': 'No city matches',
          'eef_catalog_city_fallback':
              'Main cities — for another city, type it in the search',
          'eef_catalog_result_count': '@count programme(s)',
          'eef_catalog_empty_title': 'No programme matches',
          'eef_catalog_empty_body':
              'The server did answer: it is the search that is too narrow. '
                  'Remove a filter or widen your keywords.',
          'eef_catalog_empty_action': 'Clear all',
          'eef_catalog_unpublished_title': 'The catalogue is on its way',
          'eef_catalog_unpublished_body':
              'Universities are added one by one, after their listings are '
                  'checked. Come back soon, or ask a KPB counsellor.',
          'eef_catalog_more_failed': "Couldn't load more.",
          'eef_catalog_more_retry': 'Retry',
          'eef_catalog_sources_row': 'Data sources and notices',
          'eef_catalog_sources_title': 'About the data',
          'eef_catalog_attribution':
              'Data: @producer (@sources). Licence: @licence. '
                  'Retrieved on @date.',
          'eef_catalog_attribution_bare':
              'Data: @producer. Licence: @licence. Retrieved on @date.',
          'eef_catalog_licence_link': 'See the licence',
          'eef_catalog_error_network_title': 'No connection',
          'eef_catalog_error_server_title': 'Catalogue unavailable',
          'eef_catalog_error_body':
              'Nothing could be asked of the server — this is not an empty '
                  'catalogue. Try again in a moment.',
          'eef_catalog_value_cycle_licence1': 'Bachelor, year 1',
          'eef_catalog_value_cycle_licence2': 'Bachelor, year 2',
          'eef_catalog_value_cycle_licence3': 'Bachelor, final year',
          'eef_catalog_value_cycle_but1': 'BUT, year 1',
          'eef_catalog_value_cycle_deust': 'DEUST',
          'eef_catalog_value_cycle_sante': 'Health studies',
          'eef_catalog_badge_health_access': 'Health studies access',
          'eef_catalog_value_cycle_ingenieur': 'Engineering programme',
          'eef_catalog_value_cycle_master': "Master's",
          'eef_catalog_value_procedureType_dap_blanche': 'DAP, white form',
          'eef_catalog_value_procedureType_dap_jaune': 'DAP, yellow form',
          'eef_catalog_value_procedureType_eef': 'Études en France',
          'eef_catalog_value_procedureType_parcoursup': 'Parcoursup',
          'eef_catalog_value_procedureType_hors_eef': 'Outside the procedure',
          'eef_pillar_catalog_title': 'A dense catalogue',
          'eef_pillar_catalog_body':
              'Public universities and a few public institutions: bachelor\'s, '
                  'BUT, master\'s, engineering cycles. Search by name, city, '
                  'level and admission procedure.',
          'eef_pillar_shortlist_title': 'The programmes that fit you',
          'eef_pillar_shortlist_body':
              'A shortlist ranked in three tiers — reach, target, safety — with '
                  'the reason each programme is on it.',
          'eef_pillar_documents_title': 'Letters, CV, study project',
          'eef_pillar_documents_body':
              'Templates per procedure and writing help, including for the '
                  'study project — the piece your interview will judge.',
          'eef_pillar_endtoend_title': 'Your application, tracked',
          'eef_pillar_endtoend_body':
              'Deadlines, required documents, your file\'s progress, and a KPB '
                  'counsellor when you get stuck.',
          'eef_plans_heading': 'Free and Premium',
          'eef_plan_free_label': 'Free',
          'eef_plan_premium_label': 'With KPB Premium',
          'eef_free_catalog': 'The catalogue and basic filters',
          'eef_free_shortlist_preview': 'A preview of your shortlist',
          'eef_free_letter_preview': 'One letter template preview',
          'eef_free_deadlines': 'The deadline calendar',
          'eef_premium_shortlist_full':
              'The full shortlist, justified programme by programme',
          'eef_premium_documents': 'Unlimited letters, CV and study project',
          'eef_premium_interview': 'The interview simulator and its feedback',
          'eef_premium_review': 'A counsellor review of your file',
          'eef_plan_premium_footnote':
              'Pricing and terms will be announced at opening. No payment is '
                  'requested today.',
          'eef_cta_heading': 'Interested?',
          'eef_cta_body':
              'Tell us: we will let you know as soon as it opens, and your '
                  'answer tells us where to start.',
          'eef_cta_declare': 'I am interested',
          'eef_guest_body':
              'Create your account so we can tell you when it opens.',
          'eef_guest_cta': 'Create my account',
          'eef_interest_recorded_title': 'Noted',
          'eef_interest_recorded_body':
              'We will let you know as soon as the space opens.',
          'eef_interest_edit_cta': 'Change my answer',
          'eef_sheet_title': 'Tell us where you stand',
          'eef_sheet_body':
              'Everything is optional — one tap is enough. These answers help '
                  'us come back to you with the right information, and gauge '
                  'what we need to prepare.',
          'eef_field_current_level': 'Your current level',
          'eef_field_target_level': 'The level you want to prepare',
          'eef_field_wants_premium': 'I would also be interested in Premium',
          'eef_consent_notice':
              'By confirming, you agree that a KPB counsellor may contact you '
                  'about this space, and that your answer helps us prepare our '
                  'guidance. You can remove yourself at any time, from this '
                  'screen.',
          'eef_withdraw_cta': 'Remove me from the list',
          'eef_withdraw_confirm_title': 'Remove yourself from the list?',
          'eef_withdraw_confirm_body':
              'Your declaration will be deleted and nobody will call you about '
                  'this space. You can come back whenever you want.',
          'eef_withdraw_confirm_cta': 'Remove me',
          'eef_withdraw_cancel': 'Cancel',
          'eef_withdraw_done': 'You have been removed from the list.',
          'eef_withdraw_failed':
              'We could not remove you right now. Try again, or write to '
                  'privacy@kpbeducation.com.',
          'eef_sheet_confirm': 'Confirm',
          'eef_sheet_retry': 'Try again',
          'eef_sheet_cancel': 'Cancel',
          'eef_error_network':
              'Could not send: check your connection, then try again. Nothing '
                  'was saved.',
          'eef_error_unauthorized':
              'Your session expired. Sign in again, then try again. Nothing '
                  'was saved.',
          'eef_error_server':
              'Could not send right now. Nothing was saved — try again in a '
                  'moment.',
          'eef_level_unspecified': 'I would rather not say',
          'eef_level_terminale': 'Final year of secondary school',
          'eef_level_bac': 'Secondary school diploma obtained',
          'eef_level_licence': 'Bachelor',
          'eef_level_master': 'Master',
          'eef_level_doctorat': 'Doctorate',
          'eef_level_autre': 'Other',
          'eef_tools_subtitle':
              'Find your programme, build your file, prepare your interview',
          'eef_home_card_subtitle': 'The French campaign, guided end to end',
          'eef_modules_coming_heading': 'Modules on the way',
          'eef_affiliation_notice':
              'KPB Education is a private guidance provider, with no link to or '
                  'affiliation with Campus France or any French administration. '
                  'Official steps are taken on the State platforms.',
          'coming_soon_title': 'Coming soon',
          'coming_soon_body':
              'This module is arriving in an upcoming KPB version. Stay tuned!',
          // ── Social proof (impact) ──
          'impact_proof_title': 'Our impact, verified',
          'impact_proof_line':
              '@students students guided · @admissions admissions',
          'reviews_basis': 'based on @n reviews',
          // ── Testimonials carousel (Home social proof, KPB-79) ──
          'testimonials_carousel_title': 'Student reviews',
          'testimonials_carousel_body': '@count verified reviews',
          'testimonials_empty_state': 'No published reviews yet.',
          // ── KPB accompaniment offer (country detail) ───────────
          'kpb_offer_title': 'KPB support',
          'kpb_offer_intro':
              'Our advisors guide you from eligibility all the way to your visa.',
          'kpb_offer_conditions': 'Eligibility requirements',
          'kpb_cond_grades': 'Average ≥ 11/20 over your last 3 years',
          'kpb_cond_language': 'Good level in the language of instruction',
          'kpb_cond_guarantor': 'A sponsor for your visa file',
          'kpb_offer_formulas': 'Our support packages',
          'pack_admission': 'Admission',
          'pack_admission_desc': 'Secure your admission to a strong school.',
          'pack_envol': 'Envol Pack',
          'pack_envol_desc': 'Admission + end-to-end visa process.',
          'svc_school_search': 'Tailored school search',
          'svc_application': 'CV + motivation letter',
          'svc_interview': 'Interview preparation',
          'svc_visa': 'Guided visa process',
          'kpb_offer_partner_discount':
              '−30% if you study at a KPB partner school',
          'kpb_offer_price_note':
              'Indicative price · payable after talking to an advisor',
          'onboarding_title': 'Let’s build your journey',
          'partner_redirect':
              'Partnerships are handled through a dedicated form and KPB follow-up.',
          'nav_home': 'Home',
          'nav_orientation': 'Orientation',
          'nav_destinations': 'Destinations',
          'nav_universities': 'Universities',
          'nav_programs': 'Programs',
          'nav_institutions': 'Institutions',
          'catalog_filter_all': 'All',
          'catalog_filter_business': 'Business',
          'catalog_filter_cs': 'Computer science',
          'catalog_filter_engineering': 'Engineering',
          'catalog_program_count': '@count program(s)',
          'catalog_no_match_title': 'No results',
          'catalog_no_match_body': 'Try another keyword or filter.',
          'catalog_partner_badge': 'KPB partner',
          'm6_tab_partners': 'KPB Partners ⭐',
          'm6_tab_all': 'All schools',
          'm6_search_program': 'Search a program',
          'm6_filters_title': 'Filters',
          'm6_filters_active': 'Active filters',
          'm6_reset': 'Reset',
          'm6_reset_filters': 'Reset filters',
          'm6_filter_country': 'Country',
          'm6_filter_budget': 'Max budget: @max / year',
          'm6_filter_level': 'Level',
          'm6_filter_field': 'Field',
          'm6_filter_language': 'Language',
          'm6_see_details': 'See details →',
          'nav_commercial_leads': 'My leads',
          'nav_commercial_chat': 'Conversations',
          'commercial_no_leads_title': 'No leads yet',
          'commercial_no_leads_body':
              'New requests assigned to you will appear here.',
          'commercial_no_chat_title': 'No conversations',
          'commercial_no_chat_body':
              'Open a case from My leads to chat with a student.',
          'search': 'Search',
          'nav_scholarships': 'Scholarships',
          'nav_cases': 'My Cases',
          'nav_saved': 'Saved',
          'nav_profile': 'Profile',
          'model_answer': 'Sample answer',
          'france_path_steps': 'Your path in 6 steps',
          'france_partner_schools_title': 'France partner schools',
          'france_start_procedure': 'Start my application',
          'unlock': 'Unlock',
          'student_housing': 'Student housing',
          'evaluate_eligibility': 'Check my eligibility',
          'improve_profile': 'Improve my profile',
          'latest_messages': 'Latest messages',
          'verified_alumni': 'Verified alumni',
          'recent_searches': 'Recent searches',
          'possible_careers': 'Possible careers',
          'main_subjects': 'Main subjects',
          'linked_children': 'Linked children',
          'shared_cases': 'Shared cases',
          'am_i_eligible': 'Am I eligible?',
          'to_check': 'To check:',
          'key_criteria': 'Key criteria:',
          'privacy_policy': 'Privacy Policy',
          'parent_create_invite': 'Create an invite code',
          'salon_rsvp_error': 'Could not update your RSVP.',
          'intake_label': 'Intake',
          'turnaround_label': 'Turnaround',
          'home_find_school_desc':
              'Find your private school in France based on your budget and goals. Chat instantly!',
          'closing_label': 'Closing',
          'home_apply_world_desc':
              'Apply to the world\'s best universities (Canada, USA, UK, Germany, Morocco).',
          'discover': 'Discover',
          'home_destinations_desc':
              'Discover the study destinations where KPB Education guides you end to end: orientation, admission and visa.',
          'tuition_prefix': 'Tuition: ',
          'analyzing_answers': 'Analyzing your answers…',
          'multiple_answers_allowed': 'Multiple answers allowed',
          'orientation_results_intro':
              'Here are the fields that suit you best.',
          'target_careers': 'Target careers',
          'recommended_countries': 'Recommended countries',
          'track_admission_deadlines': 'Track your admission deadlines',
          'item_deleted': 'Item deleted',
          'documents_ready': 'documents ready',
          'france_admission_title': 'France admission — Private schools',
          'france_sept_intake': '@intake intake',
          'programs_available': 'programs available',
          'france_public_unis_soon':
              'Public universities — Coming soon · @intake',
          'france_why_private': 'Why private at launch?',
          'france_private_intro':
              'KPB partner French private schools offer a direct admission path, with flexible intakes and personalized support for African students.',
          'france_sync_catalog':
              'Sync the catalogue to see OMNES and partner schools.',
          'last_updated_april_2026': 'Last updated: April 2026',
          'terms_of_use': 'Terms of Use',
          'student_living_cost': 'Student living cost',
          'budget_intro':
              'Anticipate your monthly expenses based on your destination and lifestyle.',
          'estimated_monthly_budget': 'Estimated monthly budget',
          'details_by_category': 'Details by category',
          'budget_subtitle_monthly': 'monthly living cost',
          'budget_monthly_range': 'Monthly range',
          'budget_sources_note':
              'Living-cost estimates compiled by KPB Education · indicative monthly amounts.',
          'budget_see_scholarships_cta': 'See available scholarships',
          'app_locked': 'App locked',
          'app_lock_prompt':
              'Please authenticate to access your KPB documents and cases.',
          'auth_failed': 'Authentication failed.',
          'logout_title': 'Sign out',
          'private_schools_admission': 'Private schools admission',
          'dedicated_path_intake': 'Dedicated path · @intake',
          'eligibility_simulator_title': 'Eligibility simulator',
          'eligibility_hook': 'In 1 minute, discover your chances',
          'eligibility_intro':
              'Answer 5 questions and get a 🟢 🟡 🔴 verdict for each of the 9 KPB destinations, then export your report as a PDF.',
          'offline_cache_notice': 'Offline mode. Showing cached data.',
          'next_step': 'Next step',
          'deadlines_title': 'My deadlines',
          // ── Counsellor review at admission milestone (KPB-75) ──
          'review_prompt_title': 'Rate your advisor',
          'review_prompt_body':
              'Congrats on your admission! Your feedback helps other students choose KPB.',
          'review_prompt_later': 'Later',
          'review_prompt_cta': 'Leave a review',
          'review_prompt_sheet_body':
              'Give a rating and, if you like, a few words about your support.',
          'review_prompt_hint': 'Your testimonial (optional)',
          'review_prompt_submit': 'Send my review',
          'review_prompt_thanks':
              'Thanks! Your review will be published after moderation.',
          'review_prompt_error': 'Could not send. Try again later.',
          'case_prepare_package_title': 'Prepare my application',
          'case_prepare_package_subtitle':
              'CV, motivation letter and documents reviewed by KPB before WhatsApp payment.',
          // ── Parent view: money & deadlines (KPB-58) ──
          'parent_tuition_estimate': 'Estimated tuition',
          'parent_next_deadline': 'Next deadline',
          'parent_cost_note':
              'Indicative estimate — confirm details with the advisor.',
          'step_label': 'Step',
          'case_context_prefilled':
              'Context pre-filled from your browsing. You can continue or go back to edit.',
          'listening_speak_clearly': 'Listening… speak clearly.',
          // Voir le commentaire du bloc `fr`.
          'listening_via_platform_service':
              'Listening… your voice is being processed by your phone\'s recognition service.',
          'review_before_send':
              'Check the summary before sending. KPB replies within 24–48 h.',
          'upcoming': 'Upcoming',
          'scholarship_gap_msg':
              'Your current profile is at @score%. For a scholarship like "@name", the safety threshold is 85%.',
          'scholarship_tutorials':
              'Access the exclusive video tutorial pack to ace your application.',
          'answer_all_criteria': 'Answer all criteria to see your result.',
          'scholarships_title': 'Scholarships',
          'recommended_opportunities': 'Recommended opportunities',
          'ranked_by_profile': 'Ranked by your profile and academic goals.',
          'profile_compatibility': 'Compatibility with your profile',
          'protect_app_access': 'Protect access to the app',
          'logout_redirect_notice':
              'You\'ll be redirected to the home screen. Your local data will be erased.',
          'profile_complete_optimized':
              'Complete profile — optimized recommendations ✨',
          'remaining_to_pay': 'Remaining to pay',
          'academy_unlock_msg':
              'You\'re about to unlock the "@title" course permanently on your account.',
          'coach_quota_exhausted':
              'Quota reached — Premium coming soon, or contact a KPB advisor.',
          'application_sent_admin':
              'Application sent. An admin will review your file within 48h.',
          'no_verified_mentor': 'No verified mentor matches this search yet.',
          'community_intro':
              'Articles, guides and expert advice to succeed in your study project.',
          'community_members': '+2,000 students — Advice, support & news',
          'published_on': 'Published on',
          'choose_second_uni': 'Choose a 2nd university',
          'compare_selected': '@n/2 selected',
          'register_abroad_title': 'Register Abroad',
          'register_abroad_cta': 'Register abroad',
          'housing_intro':
              'Securing your accommodation is essential to obtain your student visa.',
          'estimated_monthly_rent_in': 'Estimated monthly rent in',
          'to_range': 'to',
          'privacy_policy_inline': 'privacy policy',
          'parcours_intro':
              'Testimonials, advice and journeys of students supported by KPB. Get inspired by their experience.',
          'parent_invite_share_hint':
              'Send this code to your child via WhatsApp. They\'ll enter it in their app to link with you.',
          'parent_create_code_hint':
              'Create an 8-character code and send it via WhatsApp. Your child can then share their cases with you.',
          'parent_accept_code_hint':
              'If a parent sent you an 8-character code, enter it below to give them read access to your cases.',
          'prepare_departure': 'Prepare your departure',
          'travel_intro':
              'Estimate the ticket price to your study country and buy at the best time.',
          'travel_powered_by':
              'Powered by the independent comparator Kayak. Prices shown live.',
          'other_results': 'more results',
          'search_results_count': '@n result(s)',
          'doc_review_paste_hint':
              'Paste your draft and get structured feedback in seconds — strengths, areas to improve and missing elements.',
          'eligibility_honest_hint':
              'Answer each criterion honestly to estimate your eligibility. It\'s only an indication — an advisor will confirm your case.',
          'eligibility_not_detailed':
              'This scholarship\'s eligibility criteria aren\'t detailed yet. A KPB advisor can check your case directly.',
          'roadmap_objective':
              'Goal: @intake intake · @field. Here are the steps, dated backward from the deadline — tick them off as you go.',
          'parent_share_case_title': 'Share with my parent',
          'parent_share_case_subtitle':
              'Your linked parent can follow this case (read-only).',
          'parent_visibility_error':
              'Could not update sharing. Please try again.',
          'view_official_source': 'View official source',
          'nav_community': 'Community',
          'home_for_student': 'Your dashboard',
          'home_for_parent': 'Parent dashboard',
          'home_for_partner': 'Partnership space',
          'book_consultation': 'Book consultation',
          'request_support': 'Request support',
          'view_cases': 'View my cases',
          'continue_orientation': 'Continue orientation',
          'explore_fields': 'Explore fields',
          'explore_countries': 'Explore countries',
          'scholarships_for_you': 'Scholarships for you',
          'my_plan_title': 'My plan',
          'my_plan_next_step': 'Next step: @step',
          'my_plan_step_profile': 'complete your profile',
          'my_plan_step_orientation': 'take the orientation test',
          'my_plan_step_dossier': 'open your support dossier',
          'my_plan_step_documents': 'provide the requested documents',
          'daily_scholarship_title': 'Scholarship of the day',
          'daily_scholarship_badge_new': 'NEW',
          'daily_scholarship_pref_title': 'Scholarship of the day',
          'daily_scholarship_pref_subtitle':
              'One featured scholarship each day. Does not affect other notifications.',
          'weekly_digest_pref_title': 'Weekly digest',
          'weekly_digest_pref_subtitle':
              'Every Monday morning: scholarships, deadlines and your next dossier step. Nothing is sent when there is nothing new.',
          'parcours_weekly_pref_title': 'Story of the week',
          'parcours_weekly_pref_subtitle':
              'One inspiring journey, hand-picked by the team, on Sunday evening. Nothing is sent when no story is featured.',
          'story_of_week_title': 'STORY OF THE WEEK',
          'parcours_feed_title': 'Stories',
          'parcours_feed_cta': 'Watch stories full screen',
          'parcours_feed_play': 'Play the video',
          'parcours_feed_read': 'Read the interview',
          'parcours_feed_swipe_hint': 'Swipe up for the next one',
          'profile_completion': 'Profile completion',
          'orientation_intro':
              'Answer a few questions. KPB will suggest fields, countries, and top schools that fit your profile.',
          'start_orientation': 'Start',
          'restart_orientation': 'Restart',
          'orientation_results': 'Your orientation results',
          'why_it_fits': 'Why this fits you',
          'recommended_scholarships': 'Related programs',
          'case_summary': 'Case summary',
          'assigned_advisor': 'Assigned advisor',
          'timeline': 'Timeline',
          'messages': 'Messages',
          'documents': 'Documents',
          'send': 'Send',
          'upload': 'Mark as provided',
          'no_cases': 'No cases yet',
          'saved_items': 'Saved items',
          'no_saved_items': 'No saved items yet',
          'partner_cta': 'Become a partner',
          'contact_advisor': 'Contact an advisor',
          'request_submitted': 'Your request has been submitted.',
          'create_case': 'Create a case',
          'case_type': 'Request type',
          'description': 'Description',
          'contact_method': 'Contact method',
          'submit': 'Submit',
          'close': 'Close',
          'saved': 'Saved',
          'save': 'Save',
          'profile': 'Profile',
          'parent_support':
              'Compare destinations, estimate costs, and request a conversation with an advisor.',
          'partner_support':
              'Share your organization details and we will arrange a follow-up with the KPB team.',
          'kpb_offers': 'KPB offers',
          'support_destinations': 'Support destinations',
          'latest_articles': 'Latest articles',
          'forum_categories': 'Forum categories',
          'topic_tags': 'Popular topics',
          // Study levels
          'level_high_school': 'High school',
          'level_bachelor': 'Bachelor',
          'level_master': 'Master',
          'level_phd': 'PhD',
          // Language levels
          'lang_beginner': 'Beginner',
          'lang_intermediate': 'Intermediate',
          'lang_advanced': 'Advanced',
          // Documents
          'doc_passport': 'Passport',
          'doc_cv': 'CV',
          'doc_transcripts': 'Transcripts',
          'doc_test_score': 'Test score',
          // Form fields
          'first_name': 'First name',
          'last_name': 'Last name',
          'field_required': 'This field is required',
          'whatsapp_same_as_phone': 'Same as phone number',
          // Auth
          'login_error': 'Incorrect email or password.',
          'auth_welcome_title': 'Welcome to KPB Education',
          'auth_welcome_subtitle':
              'Sign in with email to save your journey, or browse as a guest.',
          'auth_intelligence_title':
              'KPB Intelligence, your guide to studying abroad',
          'auth_intelligence_body':
              'Answer 12 questions and discover the universities that match your profile.',
          'auth_intelligence_benefit_fit':
              'Universities ranked for your profile',
          // Voir le commentaire du bloc `fr` : ne nomme que le coach, la seule
          // surface KPB Intelligence atteignable en build 49.
          'auth_intelligence_benefit_ai':
              'KPB Intelligence answers in French: schools, budget, programs',
          'auth_intelligence_benefit_support':
              'Human KPB guidance via WhatsApp',
          'auth_receive_email_link': 'Receive a link by email',
          'auth_explore_guest': 'Explore without an account',
          'auth_intelligence_note':
              'Free · FCFA · designed for French-speaking Africa',
          'auth_continue_google': 'Continue with Google',
          'auth_google_error': 'Google sign-in failed. Try again.',
          'auth_continue_email': 'Continue with email',
          'auth_continue_guest': 'Browse without account',
          'auth_guest_hint':
              'Guest mode: catalog browsing only. Sign in to create a case.',
          'auth_magic_email_title': 'Email sign-in',
          'auth_magic_email_body':
              'We will send a 6-digit code so you can sign in without a password.',
          'auth_magic_send_button': 'Send code',
          'auth_magic_send_error': 'Could not send the code. Try again.',
          'auth_magic_verify_title': 'Verification',
          'auth_magic_verify_body':
              'Enter the code sent to @email (valid 15 min).',
          'auth_magic_verify_error': 'Invalid or expired code.',
          'auth_magic_verify_code_label': '6-digit code',
          'auth_magic_verify_button': 'Verify',
          'auth_magic_resend': 'Resend code',
          'auth_magic_resend_wait': 'Resend in @seconds s',
          'auth_magic_resend_cooldown':
              'Please wait before requesting another code.',
          'auth_guest_profile_title': 'Sign in to access your profile',
          'auth_guest_profile_body':
              'Create an account to track cases, save programs, and personalize your journey.',
          // Match explanations
          'match_complete_profile':
              'Complete your profile for a personalised match',
          'match_field_in_interests': 'In your fields of interest',
          'match_from_orientation': 'Recommended by your orientation',
          'match_available_target_country':
              'Available in your target countries',
          'match_target_country': 'Target country',
          'match_in_target_country': 'Located in a target country',
          'match_kpb_partner': 'KPB partner',
          'match_field_match': 'Matching field',
          'match_scholarship_interest': 'Budget & Funding',
          'match_general': 'General match',
          // Case snackbar
          'case_created_title': 'Case created ✅',
          'case_created_body': 'Your case @code has been submitted.',
          'view': 'View',
          'anti_fraud_title': '🔒 KPB safety',
          'anti_fraud_body':
              'KPB NEVER asks for payment on a personal Mobile Money number, and no visa or scholarship is ever guaranteed. If in doubt, verify the advisor\'s identity before paying anything.',
          'report_fraud': 'Report fraud',
          'report_fraud_prefill':
              'Hello KPB, I would like to report a fraud attempt or suspicious behavior.',
          'verified_advisor_title': 'Verified KPB advisor',
          'verified_advisor_badge': 'Identity verified (KYC)',
          'verified_advisor_official_name': 'Official KPB advisor',
          'verified_advisor_expected': 'Official WhatsApp number to expect:',
          'verified_advisor_check':
              'Check the number matches exactly before messaging. KPB NEVER asks for payment on a personal Mobile Money number.',
          'verified_advisor_prefill_label':
              'PREFILLED MESSAGE — EDITABLE IN WHATSAPP',
          'continue_to_whatsapp': 'Open WhatsApp',
          // Case status labels
          'status_submitted': 'Submitted',
          'status_under_review': 'Under review',
          'status_documents_needed': 'Documents needed',
          'status_counselor_assigned': 'Counselor assigned',
          'status_awaiting_student': 'Action required',
          'status_scheduled': 'Scheduled',
          'status_in_progress': 'In progress',
          'status_application_submitted': 'Submitted',
          'status_waiting_decision': 'Awaiting decision',
          'status_awaiting_payment': 'Payment required',
          'status_completed': 'Completed',
          'status_rejected': 'Rejected',
          'status_cancelled': 'Cancelled',
          'status_draft': 'Draft',
          // Case detail
          'case_not_found': 'This case could not be found.',
          'no_messages': 'No messages',
          'send_message_hint': 'Send a message to your counselor.',
          'message_input_hint': 'Write a message…',
          // Cases screen
          'new_case': 'New request',
          'case_empty_hint': 'Create your first case to get started with KPB.',
          // Case composer
          'case_description_hint':
              'Tell KPB what you need, where you are in your project, and what you want to happen.',
          'case_default_title': 'I need help with @title',
          // Connectivity
          'offline_title': 'Offline',
          'offline_body':
              'No internet connection. Some features are unavailable.',
          'online_title': 'Online',
          'online_body': 'Connection restored.',
          // Auth screens
          'login_subtitle': 'Sign in to continue',
          'login_button': 'Sign in',
          'forgot_password_link': 'Forgot password?',
          'no_account_prompt': 'Don\'t have an account? ',
          'create_account_link': 'Create account',
          'create_account_title': 'Create an account',
          'create_account_subtitle': 'Join 5,000+ students on KPB Education',
          'create_account_button': 'Create my account',
          'already_have_account': 'Already have an account? ',
          'login_link': 'Sign in',
          'full_name_required': 'Your full name is required',
          'full_name_hint': 'Enter your first and last name',
          'email_required': 'Enter your email',
          'email_invalid': 'Invalid email address',
          'phone_optional': 'Phone (optional)',
          'password_required': 'Enter your password',
          'password_choose': 'Choose a password',
          'password_min_length': 'Password must be at least 8 characters',
          'password_helper': 'Minimum 8 characters',
          // Forgot password
          'forgot_password_title': 'Forgot password',
          'reset_password_title': 'Reset password',
          'reset_password_body':
              'Enter your email address and we will send you a link to reset your password.',
          'email_label': 'Email address',
          'send_link_button': 'Send link',
          'back_to_login': 'Back to sign in',
          'email_sent_title': 'Email sent!',
          'email_sent_body':
              'Check your inbox and follow the link to reset your password.',
          'forgot_password_error':
              'An error occurred. Check the email address.',
          // Register errors
          'register_error_generic': 'An error occurred. Please try again.',
          'register_error_email_exists':
              'An account with this email already exists.',
          'register_error_network': 'Connection issue. Check your network.',
          // ── Referral (KPB-69) ──
          'copy': 'Copy',
          'referral_title': 'Refer a friend',
          'commercial_age_min': '@n min ago',
          'commercial_age_hour': '@n h ago',
          'commercial_age_day': '@n d ago',
          'commercial_tag_new': 'To answer',
          'commercial_tag_qualified': 'Qualified',
          'commercial_tag_converted': 'Signed KPB',
          'commercial_leads_title': 'WhatsApp leads',
          'commercial_leads_sub': '@n to answer · round-robin assigned',
          'commercial_sla':
              'Goal: first reply within 24h. @n lead(s) in your queue.',
          'commercial_filter_all': 'All',
          'commercial_filter_new': 'To answer',
          'commercial_filter_qualified': 'Qualified',
          'commercial_filter_converted': 'Signed',
          'commercial_leads_empty': 'No leads in this view.',
          'commercial_cases_title': 'Tracked cases',
          'commercial_cases_sub': '@n active case(s)',
          'commercial_cases_empty': 'No active cases yet.',
          'commercial_converted_toast':
              'Lead converted 🎉 @name is now a KPB client',
          'commercial_convert_error': 'Couldn\'t convert right now.',
          'commercial_wa_reply':
              'Hi @name, I\'m your KPB advisor. How can I help with your study plan?',
          'commercial_field_level': 'Level',
          'commercial_field_ref': 'Reference',
          'commercial_field_case': 'Case',
          'commercial_field_status': 'Status',
          'commercial_profile_title': 'Submitted profile',
          'commercial_reply_wa': 'Reply on WhatsApp',
          'commercial_signed': 'Signed ✓',
          'commercial_mark_signed': 'Mark signed',
          'commercial_perf_role': 'KPB advisor',
          'commercial_stat_total': 'Leads (total)',
          'commercial_stat_converted': 'Signed (30d)',
          'commercial_stat_response': 'First reply (avg)',
          'commercial_perf_breakdown': 'Leads by status',
          'commercial_perf_empty': 'No leads yet.',
          'commercial_perf_note':
              'The qualified WhatsApp lead is KPB\'s #1 conversion metric.',
          'commercial_nav_leads': 'Leads',
          'commercial_nav_cases': 'Cases',
          'commercial_nav_perf': 'Performance',
          // ── Per-document review (Feature D) ──
          'commercial_docs_title': 'Case documents',
          'commercial_docs_sub': '@n document(s)',
          'commercial_docs_to_review': '@n to review',
          'commercial_docs_empty': 'No document on this case yet.',
          'commercial_doc_provided': 'Provided',
          'commercial_doc_pending': 'Awaiting upload',
          'commercial_doc_validate': 'Validate',
          'commercial_doc_redo': 'Redo',
          'commercial_doc_doubtful': 'Doubtful',
          'commercial_doc_status_validated': 'Validated',
          'commercial_doc_status_redo': 'To redo',
          'commercial_doc_status_doubtful': 'Doubtful',
          'commercial_doc_reviewed_by': 'Reviewed by @name',
          'commercial_doc_reviewed_meta': 'Reviewed by @name · @age',
          'commercial_doc_review_error': 'Could not save the review right now.',
          // ── Ambassador (App-engagement · US-032→035) ──
          'referral_become_ambassador': 'Ambassador space',
          'referral_become_ambassador_sub':
              'Earn FCFA by referring · Wave payouts',
          'amb_appbar': 'Ambassador space',
          'amb_apply_title': 'Ambassador programme',
          'amb_apply_body':
              'The Ambassador programme (paid referrals) is open by application. Contact a KPB advisor to join, or explore our free referral programme.',
          'amb_apply_cta_advisor': 'Contact an advisor',
          'amb_apply_cta_referral': 'Explore referrals',
          'amb_apply_wa_prefill':
              'Hello KPB, I would like to apply to the Ambassador programme.',
          'amb_load_error': 'Could not load your ambassador space.',
          'amb_sample_banner': 'Preview — activate your space to earn FCFA.',
          'amb_nav_dashboard': 'Dashboard',
          'amb_nav_referrals': 'Referrals',
          'amb_nav_payout': 'Withdrawals',
          'amb_code_label': 'YOUR REFERRAL CODE',
          'amb_share': 'Share',
          'amb_share_message':
              'Join KPB Education with my code @code and kick off your study-abroad plan 🎓\n@link',
          'amb_stat_active': 'Active referrals',
          'amb_stat_placed': 'Placed 🎉',
          'amb_stat_earned': 'FCFA earned',
          'amb_objective_title': 'Goal — @n referrals',
          'amb_objective_hint':
              '@n to go — @bonus bonus at @target signed-up referrals.',
          'amb_how_title': 'How you earn',
          'amb_reward_signup': 'Sign-up with your code + quiz completed',
          'amb_reward_placed': 'Referral placed in a school via KPB',
          'amb_leaderboard_title': '@city leaderboard',
          'amb_leaderboard_title_generic': 'Ambassador leaderboard',
          'amb_referrals_count': '@n referrals',
          'amb_referrals_title': 'My referrals',
          'amb_referrals_sub': '@n active · tracked in real time',
          'amb_referrals_tip':
              'Nudge your referrals: a completed quiz = +1,000 FCFA each.',
          'amb_status_placed': 'Placed',
          'amb_status_application': 'Application open',
          'amb_status_quiz': 'Quiz ✓',
          'amb_status_premium': 'Premium',
          'amb_status_churned': 'Churned',
          'amb_status_relance': 'Follow up',
          'amb_payout_title': 'Withdrawals',
          'amb_payout_sub': 'Wave payout · within 48h',
          'amb_balance_label': 'AVAILABLE BALANCE',
          'amb_wave_account': 'Wave account: @account',
          'amb_withdraw': 'Withdraw @amount',
          'amb_withdraw_pending': 'Withdrawal in progress — within 48h ✓',
          'amb_withdraw_min': 'Minimum withdrawal @amount',
          'amb_withdraw_error': 'Withdrawal unavailable right now.',
          'amb_history': 'HISTORY',
          'amb_toast_share': 'WhatsApp opens — code + invite link ready 📤',
          'amb_toast_withdraw':
              'Wave withdrawal requested — @amount within 48h ✓',
          'amb_referrals_empty':
              'No referrals yet. Share your code to get started!',
          'amb_history_empty': 'No activity yet.',
          'referral_intro':
              'Invite your friends to KPB. When they sign up and start a case with your code, we track your impact.',
          'referral_your_code': 'Your referral code',
          'referral_invite_whatsapp': 'Invite on WhatsApp',
          'referral_invite_message':
              'Hi! I use KPB Education for studying abroad (guidance, scholarships, visa support). Sign up and enter my referral code: @code\n@link',
          'referral_friends_joined': 'Friends joined',
          'referral_friends_cases': 'Started a case',
          'referral_have_code': 'Have a referral code?',
          'referral_code_hint': 'Enter the code',
          'referral_redeem_cta': 'Apply code',
          'referral_code_copied': 'Code copied',
          'referral_redeemed_ok':
              'Code applied — thanks! Your referrer is credited.',
          'referral_redeemed_already': 'You have already used a referral code.',
          'referral_redeem_error': 'Invalid code. Check it and try again.',
          // ── No-cash referral rewards (KPB-77) ──
          'referral_credits_title': 'My referral credits',
          'referral_credits_label': 'credit(s)',
          'referral_credits_intro':
              'A friend who creates their case = 1 credit. Redeem your credits for an in-depth review of your application by a KPB advisor.',
          'referral_redeem_voucher_cta': 'Redeem for an advisor review',
          'referral_credits_none':
              'No credits yet — invite a friend to earn one.',
          'referral_voucher_title': 'Your KPB voucher 🎁',
          'referral_voucher_body':
              'Show this code to your advisor on WhatsApp to unlock your in-depth review.',
          'referral_voucher_whatsapp_cta': 'Message my advisor',
          'referral_voucher_whatsapp_prefill':
              'Hello KPB Education, I would like to use my referral voucher @code for an in-depth review of my application.',
          'referral_voucher_error': 'Redemption failed. Try again later.',
          // ── AI consent (Coach) ──
          'coach_ai': 'KPB Intelligence',
          'coach_quota_handoff_title': 'Free quota reached',
          'coach_quota_handoff_body':
              'You\'ve used your @quota free messages this week. A KPB advisor can continue the conversation with you on WhatsApp, free of charge.',
          'coach_quota_handoff_cta': 'Continue with an advisor on WhatsApp',
          'coach_wa_prefill':
              'Hello KPB, I was chatting with KPB Intelligence and I\'d like to continue with an advisor.',
          'coach_wa_prefill_topic': 'My last topic: @topic',
          'ai_consent_title': 'Enable KPB Intelligence',
          'ai_consent_body':
              'To answer you, KPB Intelligence sends your messages and profile facts (study level, target countries, budget range, field) to a third-party AI service (OpenRouter or Groq) hosted outside your country. Your civil name is not copied into the prompt. Text you paste (letter, CV, message) is sent as-is — do not include information you do not want transmitted. No important decision relies on AI alone. You can decline and keep using the rest of the app.',
          'ai_consent_accept': 'Enable KPB Intelligence',
          'ai_consent_decline': 'Not now',
          'ai_tools_disclosure':
              'This tool sends the text you enter and profile facts (level, countries, field) to OpenRouter or Groq (United States). Your name is not copied into the prompt. No important decision relies on AI alone.',
          'coach_load_error': 'KPB Intelligence could not load right now.',
          // ── My data / GDPR ──
          'data_rights_section': 'My data',
          'export_data': 'Export my data',
          'export_data_subject': 'My KPB data export',
          'export_data_error':
              'Could not export your data right now. Please try again.',
          'delete_account': 'Delete my account',
          'delete_account_confirm_title': 'Permanently delete your account?',
          'delete_account_confirm_body':
              'This cannot be undone. All your data (profile, cases, messages, favourites) will be permanently deleted from our servers.',
          'delete_account_cta': 'Delete',
          'delete_account_error':
              'Deletion failed for now. Check your connection and try again.',
          // ── Age + guardian consent (minors) ──
          'birth_date': 'Date of birth',
          'birth_date_hint': 'Select your date of birth',
          'onboarding_birthdate_required_title': 'Birth date required',
          'onboarding_birthdate_required':
              'Enter your date of birth to continue.',
          'minor_guardian_title': 'Parent / guardian consent',
          'minor_guardian_intro':
              'You are under 18. A parent or guardian must consent and provide their details for you to use KPB (data sync and KPB Intelligence).',
          'guardian_name': 'Parent / guardian name',
          'guardian_contact': 'Parent / guardian contact (WhatsApp or email)',
          'guardian_consent_checkbox':
              'My parent / guardian has given their consent.',
          'guardian_consent_required_title': 'Guardian consent required',
          'guardian_consent_required':
              'Enter your guardian\'s name and contact and tick their consent to continue.',
          // ── Community & alumni (KPB-70) ──
          'contact_mentor': 'Contact this mentor',
          'mentor_intro_prefill':
              'Hello KPB Education, I\'d like to be connected with your verified mentor @who for advice on my study plans.',
          'community_hub_alumni': 'Mentors',
          'community_hub_salon': 'Fairs',
          'community_hub_parcours': 'Journeys',
          // ── Force update ──
          'update_recommended_title': 'An update is available',
          'update_recommended_body':
              'A new version of KPB Education is available. Update to get the latest improvements.',
          'update_recommended_cta': 'Update now',
          'update_recommended_dismiss': 'Later',
          'force_update_title': 'Update required',
          'force_update_body':
              'This version of the app is no longer supported. Update it to keep using KPB Education.',
          'force_update_cta': 'Update now',
          'force_update_contact_cta': 'Contact a KPB advisor',
          'force_update_prefill':
              'Hello, my KPB app is asking for an update but I cannot complete '
                  'it. Could you help me?',
          // ── AHA moment post-onboarding (P0-D) ──
          'aha_loading': 'Scoring your matches…',
          'aha_title': 'Your school matches',
          'aha_title_named':
              '@name, here are your @count matching universities',
          'aha_subtitle':
              'Based on your profile, here are the schools that match you best.',
          'aha_empty_body':
              'No matches yet — explore the catalog to discover schools.',
          'aha_estimate_note':
              'Estimate — complete your profile for more precision.',
          'aha_zone_green': 'Closely matches your profile',
          'aha_zone_yellow': 'Partly matches your profile',
          'aha_zone_blue': 'Less aligned with your current profile',
          'aha_cta': 'Explore my home',
          'aha_see_all_cta': 'See all universities',
          // ── PR2 · Écoles / Destinations / Fiche restyle (App-engagement) ──
          'uni_list_subtitle': 'Best matches first, based on your profile',
          'uni_list_subtitle_no_profile':
              'Complete your profile to see your best matches',
          'uni_filter_matches': 'Best matches',
          'uni_filter_france': '🇫🇷 France',
          'uni_filter_canada': '🇨🇦 Canada',
          'uni_filter_saved': '♥ My targets',
          'uni_filter_budget': '< CFA 3M',
          'full_guide': 'FULL GUIDE',
          'guide_short': 'GUIDE',
          'school_fees_per_year': 'TUITION / YR',
          'school_intake': 'INTAKE',
          'school_intake_on_request': 'On request',
          'match_zone_tap_hint': 'Tap to see why',
          'match_zone_strong': 'Closely matches your profile',
          'match_zone_good': 'Partly matches your profile',
          'match_zone_stretch': 'Few points in common with your profile',
          'match_zone_no_profile': 'Complete your profile to see your match',
          'profile_fit_strong': 'Great match',
          'profile_fit_good': 'Good match',
          'profile_fit_explore': 'Worth exploring',
          'create_application': 'Create an application',
          'ask_kpb_counselor': 'Ask a KPB counselor a question',
          'country_guide_badge': 'COUNTRY GUIDE',
          'country_overview_highlights': 'Overview & highlights',
          'country_admission_routes': 'Admission routes & process',
          'country_tuition_living': 'Tuition & cost of living',
          'country_visa_procedure': 'Student visa procedure',
          'country_verified_universities': 'Verified universities',
          'country_support_services': 'KPB support services',
          'country_cost_estimate_body':
              'Every situation is different: family budget, scholarships, '
                  'housing… Contact the KPB team for a personalized, up-to-date '
                  'estimate during your free consultation.',
          'get_supported': 'Get supported',
          'dest_countries_heading': 'Countries',
          'dest_list_subtitle':
              'Full guides: visa, costs, universities, support',
          'dest_more_coming_tip':
              'More destinations (UAE, China, South Korea…) are coming soon — '
                  'tell us which one you want.',
          // ── Success Lab ───────────────────────────────────────────────
          'success_lab_title': 'Success Lab',
          'success_lab_subtitle':
              'Prepare every application step by step and keep your progress available offline.',
          'success_lab_empty_title': 'No workspace yet',
          'success_lab_empty_body':
              'Choose a scholarship with an available cycle to start preparing.',
          'success_lab_empty_action': 'Browse scholarships',
          'success_lab_offline_title': 'You are offline',
          'success_lab_offline_empty_body':
              'No workspace is saved on this device. Reconnect to load them.',
          'success_lab_offline_cached_body':
              'Showing a saved version. Your changes will sync when the network returns.',
          'success_lab_forbidden_title': 'Access not allowed',
          'success_lab_forbidden_body':
              'Sign in with an eligible student account to use this workspace.',
          'success_lab_disabled_title': 'Workspace unavailable',
          'success_lab_disabled_body':
              'This feature is not enabled for your account yet.',
          'success_lab_error_title': 'Unable to load the workspace',
          'success_lab_error_body':
              'Something went wrong. Please try again in a moment.',
          'success_lab_missing_identity':
              'An active student session is required.',
          'success_lab_cached_label':
              'Showing a saved version while it is updated.',
          'success_lab_workspace_fallback': 'Scholarship application',
          'success_lab_workspace_title': 'My workspace',
          'success_lab_progress_label': 'Preparation progress',
          'success_lab_progress_disclaimer':
              'This progress tracks prepared steps, not your admission odds.',
          'success_lab_next_action': 'Next action',
          'success_lab_deadline_confirmed': 'Confirmed deadline',
          'success_lab_deadline_estimated': 'Estimated deadline',
          'success_lab_status_started': 'Started',
          'success_lab_status_preparing': 'Preparing',
          'success_lab_status_ready_for_review': 'Ready for review',
          'success_lab_status_review_requested': 'Review requested',
          'success_lab_status_submitted': 'Application submitted',
          'success_lab_status_decision_received': 'Decision received',
          'success_lab_status_archived': 'Archived',
          'success_lab_status_unknown': 'Status needs review',
          'success_lab_steps_title': 'Preparation steps',
          'success_lab_steps_empty':
              'The steps for this workspace are not available yet.',
          'success_lab_category_profile': 'Profile and eligibility',
          'success_lab_category_documents': 'Documents',
          'success_lab_category_form_essays': 'Form and essays',
          'success_lab_category_review_submission': 'Review and submission',
          'success_lab_category_unknown': 'Other step',
          'success_lab_step_not_started': 'Not started',
          'success_lab_step_in_progress': 'In progress',
          'success_lab_step_completed': 'Completed',
          'success_lab_step_not_applicable': 'Not applicable',
          'success_lab_step_status_unknown': 'Status needs review',
          'success_lab_step_required': 'Required',
          'success_lab_step_complete': 'Mark as completed',
          'success_lab_step_reopen': 'Reopen this step',
          'success_lab_step_queued': 'Waiting for network',
          'success_lab_step_sending': 'Syncing',
          'success_lab_step_conflict': 'Conflict to resolve',
          'success_lab_step_failed': 'Sync failed',
          'success_lab_retry': 'Retry sync',
          'success_lab_pending_changes_body':
              'Local changes are waiting to be synchronized.',
          'success_lab_diagnostic_title': 'Application diagnostic',
          'success_lab_diagnostic_body':
              'A structured preparation review, with explicit consent before any AI processing.',
          'success_lab_diagnostic_action': 'Start diagnostic',
          'success_lab_diagnostic_unavailable':
              'The diagnostic is closed for this account or pilot.',
          'success_lab_diagnostic_unavailable_title': 'Diagnostic unavailable',
          'success_lab_diagnostic_promise':
              'One priority improvement you can make now',
          'success_lab_diagnostic_disclaimer':
              'This diagnostic does not calculate admission chances, guarantee any result, or replace a KPB counsellor.',
          'success_lab_diagnostic_loading': 'Checking your diagnostic…',
          'success_lab_diagnostic_running':
              'Analysis in progress. We keep the response short to control cost and stay useful.',
          'success_lab_diagnostic_online_required':
              'Reconnect to start or view the secure diagnostic.',
          'success_lab_ai_consent_checkbox':
              'I have read this notice and accept this limited AI processing.',
          'success_lab_ai_consent_required':
              'You must accept the current notice before starting the diagnostic.',
          'success_lab_guardian_authorization_required':
              'Verified guardian authorization is required for this account.',
          'success_lab_excerpt_title': 'Optional excerpt',
          'success_lab_excerpt_body':
              'You may paste a short CV or motivation-letter excerpt. Remove names and contact details when possible.',
          'success_lab_excerpt_hint':
              'Example: a leadership experience or a paragraph to improve…',
          'success_lab_diagnostic_error_title': 'Diagnostic not completed',
          'success_lab_diagnostic_error_body':
              'The diagnostic could not be loaded. No new paid call will start without backend control.',
          'success_lab_diagnostic_strength': 'Your strength',
          'success_lab_diagnostic_priority': 'Your priority',
          'success_lab_diagnostic_rationale': 'Why this matters now',
          'success_lab_diagnostic_next_action': 'Next action',
          'success_lab_diagnostic_stale_title': 'Your application has changed',
          'success_lab_diagnostic_stale_body':
              'This diagnostic matches an earlier workspace version. It remains visible without automatically starting another AI call.',
          'success_lab_study_title': 'Counsellor study',
          'success_lab_study_body':
              'Request a human review of your preparation before submitting.',
          'success_lab_study_action': 'Request a study',
          'success_lab_study_unavailable':
              'This option is not enabled for your account.',
          'success_lab_study_unavailable_title': 'Study unavailable',
          'success_lab_study_free_title': 'First application study is free',
          'success_lab_study_decision_disclaimer':
              'The KPB counsellor provides guidance and next steps. The institution always makes the final decision.',
          'success_lab_study_consent_checkbox':
              'I have read this notice and agree to share only the selected versions with a KPB counsellor.',
          'success_lab_study_documents_title': 'Documents to share',
          'success_lab_study_document_kind': 'Document type',
          'success_lab_study_document_title': 'Document title',
          'success_lab_study_add_document': 'Add a secure document',
          'success_lab_study_version_label': 'Version @number · @file · @size',
          'success_lab_study_delete_action': 'Delete this version',
          'success_lab_study_deleting': 'Deletion in progress',
          'success_lab_study_delete_confirm_title': 'Delete this version?',
          'success_lab_study_delete_confirm_body':
              'You are about to permanently delete “@title” (@file) from KPB. This action is never automatic and cannot be undone.',
          'success_lab_study_delete_confirm_action': 'Delete permanently',
          'success_lab_study_delete_shared':
              'This version is already shared with an open study. It cannot be deleted until that study is closed.',
          'success_lab_study_message_label': 'Message to counsellor (optional)',
          'success_lab_study_message_hint':
              'State the scholarship you are targeting or the priority question to review.',
          'success_lab_study_submit_action': 'Send for study',
          'success_lab_study_uploading': 'Secure upload in progress…',
          'success_lab_study_submitting': 'Sending your request…',
          'success_lab_study_submitted_title': 'Request submitted',
          'success_lab_study_submitted_body':
              'Your request #@number is recorded. A KPB counsellor will review only the shared versions.',
          'success_lab_study_online_required':
              'Reconnect to share documents and submit the request securely.',
          'success_lab_study_error_title': 'Request not submitted',
          'success_lab_study_error_body':
              'The request could not be completed. Check your documents and try again.',
          'success_lab_study_file_too_large':
              'This file exceeds the 10 MB maximum size.',
          'success_lab_study_file_not_allowed':
              'Only PDF, JPG, and PNG files are accepted.',
          'success_lab_study_document_required':
              'Add and select at least one valid document.',
          'success_lab_study_already_open':
              'A study request is already open for this workspace.',
          'success_lab_study_consent_required':
              'You must accept the current notice before sharing documents.',
          'success_lab_study_complementing':
              'Securely sending the additional information…',
          'success_lab_study_request_number': 'Study request #@number',
          'success_lab_study_submitted_on':
              'Submitted on @date (your device time: @deviceZone). Request timezone: @zone.',
          'success_lab_study_missing_title': 'Requested items',
          'success_lab_study_shared_title': 'Documents already shared',
          'success_lab_study_complement_title': 'Complete my request',
          'success_lab_study_complement_body':
              'Answer the requested items precisely. You may send only a message or add new versions with explicit consent.',
          'success_lab_study_complement_message': 'Reply to the counsellor',
          'success_lab_study_complement_message_hint':
              'Explain what you corrected or provide the requested information.',
          'success_lab_study_complement_action': 'Send additional information',
          'success_lab_study_complement_not_allowed':
              'Additional information can be sent only when the counsellor requests it.',
          'success_lab_study_complement_changed':
              'The request changed. Refresh before sending your update again.',
          'success_lab_study_complement_required':
              'Add a reply or select at least one new document.',
          'success_lab_study_choose_slot_action': 'Choose a time slot',
          'success_lab_study_refresh_action': 'Refresh tracking',
          'success_lab_study_status_draft': 'Request in preparation',
          'success_lab_study_status_submitted':
              'Request sent to the counsellor',
          'success_lab_study_status_triaged': 'Request reviewed',
          'success_lab_study_status_more_information_needed':
              'Additional information required',
          'success_lab_study_status_call_offered': 'Time slots offered',
          'success_lab_study_status_scheduled': 'Appointment scheduled',
          'success_lab_study_status_converted_to_case':
              'KPB support case created',
          'success_lab_study_status_autonomy_recommended':
              'Independent continuation recommended',
          'success_lab_study_status_declined': 'Request declined',
          'success_lab_study_status_closed': 'Study completed',
          'success_lab_study_status_unknown':
              'Updated state — refresh the application',
          'success_lab_study_next_complete_request':
              'Complete and submit your request.',
          'success_lab_study_next_wait_for_triage':
              'No action: a counsellor will review your request.',
          'success_lab_study_next_provide_more_information':
              'Answer the requested items below.',
          'success_lab_study_next_wait_for_slot_offer':
              'No action: time slots will be offered soon.',
          'success_lab_study_next_choose_slot':
              'Choose one of the available time slots.',
          'success_lab_study_next_appointment_scheduled':
              'Your appointment is confirmed.',
          'success_lab_study_next_case_created':
              'Continue your support journey in your KPB case.',
          'success_lab_study_next_continue_autonomously':
              'Continue preparing with the guidance you received.',
          'success_lab_study_next_none':
              'No further action is needed right now.',
          'success_lab_study_next_unknown':
              'Refresh to receive the next action.',
          'success_lab_schedule_title': 'Choose an appointment',
          'success_lab_schedule_choose_title': 'Available time slots',
          'success_lab_schedule_choose_body':
              'Select one slot, check the displayed times, and confirm. Booking requires an internet connection.',
          'success_lab_schedule_offer_details':
              '@name · Displayed time: your device (@deviceZone) · Source timezone: @zone',
          'success_lab_schedule_confirm_action': 'Confirm time slot',
          'success_lab_schedule_confirm_title': 'Confirm this appointment?',
          'success_lab_schedule_confirm_body':
              '@date with @name. Displayed in your device time (@deviceZone); source timezone: @zone.',
          'success_lab_schedule_booking':
              'Confirming the appointment with the server…',
          'success_lab_schedule_booked_title': 'Appointment confirmed',
          'success_lab_schedule_booked_body':
              '@date (your device time: @deviceZone). Booking timezone: @zone.',
          'success_lab_schedule_booked_recovered_body':
              'The server confirms that an appointment is scheduled. Check your KPB notifications for details.',
          'success_lab_schedule_empty_title':
              'No time slots are available right now',
          'success_lab_schedule_empty_body':
              'Expired slots are never shown. Refresh later to see new offers.',
          'success_lab_schedule_waiting_title':
              'Time-slot booking is not open yet',
          'success_lab_schedule_waiting_body':
              'Your request is being tracked, but booking opens only after a counsellor offers time slots.',
          'success_lab_schedule_no_request_title': 'No active study request',
          'success_lab_schedule_no_request_body':
              'First submit a study request from your Success Lab workspace.',
          'success_lab_schedule_online_required':
              'Reconnect to view and book a time slot.',
          'success_lab_schedule_error_title':
              'Time slots temporarily unavailable',
          'success_lab_schedule_error_body':
              'The server did not confirm the booking. Retry with the same selection.',
          'success_lab_schedule_expired':
              'This offer has expired. Select another time slot.',
          'success_lab_schedule_taken':
              'This time slot was just taken. Select another offer.',
          'success_lab_schedule_changed':
              'The request changed. Refresh the offers before booking.',
          'success_lab_schedule_no_offer':
              'This time slot is no longer offered.',
          'success_lab_schedule_retry':
              'Confirmation is still in progress. Try again shortly.',
          'success_lab_submission_title': 'Declare my submission',
          'success_lab_submission_workspace_body':
              'Confirm that your application was actually sent and attach private evidence.',
          'success_lab_submission_open': 'Open my submissions',
          'success_lab_submission_intro_title':
              'A factual declaration, supported by evidence',
          'success_lab_submission_intro_body':
              'KPB records what you declare. Evidence verification is shown separately and does not guarantee any outcome.',
          'success_lab_submission_channel': 'Submission channel (optional)',
          'success_lab_submission_channel_hint': 'E.g. official portal, email',
          'success_lab_submission_reference':
              'Application reference (optional)',
          'success_lab_submission_reference_private':
              'Sent over encrypted transport; the server stores only an HMAC fingerprint.',
          'success_lab_submission_date': 'Submission date',
          'success_lab_submission_action': 'Declare submission',
          'success_lab_submission_sending': 'Saving on the server…',
          'success_lab_submission_confirmed_body':
              'The server recorded the declaration. Its verification status remains visible below.',
          'success_lab_submission_history': 'Submission history',
          'success_lab_submission_history_empty':
              'No submission has been declared.',
          'success_lab_submission_declared_label': 'Submission declared',
          'success_lab_outcome_title': 'Admission and funding',
          'success_lab_outcome_workspace_body':
              'Declare the admission decision and funding received separately.',
          'success_lab_outcome_open': 'Open my decisions',
          'success_lab_outcome_intro_title':
              'Declared decisions, without promises or inference',
          'success_lab_outcome_intro_body':
              'The institution issues the decision. KPB only verifies evidence; admission and funding remain separate facts.',
          'success_lab_outcome_current_admission': 'Current admission',
          'success_lab_outcome_current_funding': 'Current funding',
          'success_lab_outcome_no_admission':
              'No admission decision has been declared.',
          'success_lab_outcome_no_funding':
              'No funding decision has been declared.',
          'success_lab_outcome_declare_admission':
              'Declare an admission decision',
          'success_lab_outcome_update_admission':
              'Declare a new admission decision',
          'success_lab_outcome_declare_funding': 'Declare a funding decision',
          'success_lab_outcome_update_funding':
              'Declare a new funding decision',
          'success_lab_outcome_issuer': 'Issuing institution',
          'success_lab_outcome_issuer_helper':
              'KPB is not the issuer of this decision.',
          'success_lab_outcome_admission_decision': 'Admission decision',
          'success_lab_outcome_funding_decision': 'Funding decision',
          'success_lab_outcome_received_date': 'Date received',
          'success_lab_outcome_choose_date': 'Choose date',
          'success_lab_outcome_device_timezone':
              'Date entered in your device timezone: @zone',
          'success_lab_outcome_save_admission': 'Save admission decision',
          'success_lab_outcome_save_funding': 'Save funding decision',
          'success_lab_outcome_amount_minor': 'Amount in minor currency units',
          'success_lab_outcome_amount_optional':
              'Optional. Provide it with currency, only for full or partial funding.',
          'success_lab_outcome_currency': '3-letter ISO currency',
          'success_lab_outcome_history': 'Decision history',
          'success_lab_outcome_history_empty':
              'No previous decision has been recorded.',
          'success_lab_outcome_evidence_title': 'Private evidence is required',
          'success_lab_outcome_evidence_body':
              'PDF, JPG or PNG, up to 10 MB. The file is scanned before use.',
          'success_lab_outcome_evidence_choose': 'Choose evidence',
          'success_lab_outcome_evidence_change': 'Change evidence',
          'success_lab_outcome_consent_loading': 'Loading the privacy notice…',
          'success_lab_outcome_consent_private':
              'This consent covers private storage and KPB verification. It does not allow a public testimonial or public statistics.',
          'success_lab_outcome_add_complement': 'Add the requested information',
          'success_lab_outcome_granting_consent': 'Recording your consent…',
          'success_lab_outcome_uploading': 'Uploading and scanning evidence…',
          'success_lab_outcome_attaching': 'Adding information…',
          'success_lab_outcome_saving_admission':
              'Saving the admission decision…',
          'success_lab_outcome_saving_funding': 'Saving the funding decision…',
          'success_lab_outcome_online_required':
              'Reconnect: evidence and decisions are never queued on this device.',
          'success_lab_outcome_unavailable_title': 'Declarations unavailable',
          'success_lab_outcome_guardian_required':
              'Guardian authorization is required.',
          'success_lab_outcome_evidence_required':
              'Accept the notice and attach evidence before continuing.',
          'success_lab_outcome_scan_pending':
              'The evidence is still being scanned. Try again shortly.',
          'success_lab_outcome_evidence_rejected':
              'This evidence was rejected. Choose another clean, readable file.',
          'success_lab_outcome_superseded':
              'This decision has already been superseded. Refresh the history.',
          'success_lab_outcome_changed':
              'The workspace changed. Data was refreshed; review it before retrying.',
          'success_lab_outcome_invalid_amount':
              'Enter a positive integer amount and a three-letter ISO currency, or leave both fields empty.',
          'success_lab_outcome_file_too_large':
              'The file is larger than 10 MB.',
          'success_lab_outcome_file_not_allowed':
              'Choose a PDF, JPG or PNG file.',
          'success_lab_outcome_error_body':
              'The server did not confirm this operation. Check the data and retry.',
          'success_lab_verification_declared': 'Student-declared',
          'success_lab_verification_pending': 'Verification pending',
          'success_lab_verification_verified': 'Evidence verified by KPB',
          'success_lab_verification_needs_information':
              'More information requested by KPB',
          'success_lab_verification_rejected': 'Evidence rejected by KPB',
          'success_lab_verification_unknown': 'Unknown verification status',
          'success_lab_admission_admitted': 'Admitted',
          'success_lab_admission_rejected': 'Not admitted',
          'success_lab_admission_waitlisted': 'Waitlisted',
          'success_lab_admission_deferred': 'Deferred',
          'success_lab_admission_withdrawn': 'Application withdrawn',
          'success_lab_funding_full': 'Full funding',
          'success_lab_funding_partial': 'Partial funding',
          'success_lab_funding_none': 'No funding',
          'success_lab_funding_pending': 'Funding pending',
          'success_lab_funding_not_applicable': 'Not applicable',
          'success_lab_outcome_unknown': 'Unknown value',
          'success_lab_document_cv': 'CV',
          'success_lab_document_motivation': 'Motivation letter',
          'success_lab_document_essay': 'Essay',
          'success_lab_document_transcript': 'Transcript',
          'success_lab_document_diploma': 'Diploma',
          'success_lab_start_action': 'Prepare my application',
          'success_lab_start_error_title': 'Workspace not created',
          'success_lab_start_offline': 'Reconnect to create a new workspace.',
          'success_lab_start_conflict':
              'A workspace may already exist. Refresh and try again.',
          'success_lab_start_error_body':
              'This workspace cannot be created right now.',
          // ── Dossier / Application (App-engagement handoff) ─────────────
          'case_steps_heading': 'Steps of your application',
          'case_step_your_turn': 'Your turn',
          'case_document_photo_tip':
              'For transcripts: take a photo or attach a PDF — photos are '
                  'automatically compressed to save your data.',
          'case_interview_sim_title': 'Interview simulator',
          'case_interview_sim_subtitle':
              'Practice visa and admission interviews with AI feedback',
          'case_ai_review_subtitle':
              'Have the AI proofread a document before you send it',
        },
      };
}
