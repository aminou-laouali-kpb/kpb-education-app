// English strings of the app.
// Clés partagées avec l'autre langue : toute clé ajoutée ici doit l'être aussi
// dans l'autre fichier (vérifié par les tests de parité).
const Map<String, String> appTranslationsEn = {
  'app_title': 'KPB Education',
  'app_tagline': 'Orientation, study abroad, and support for African students.',
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
  'onboarding_newsletter_consent': 'Receive newly available scholarships',
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
      'Scholarships are checked by KPB. You need an account to see and follow them. It is free and takes two minutes.',
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
  'flight_no_results': 'No prices found for this search. Try other dates.',
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
  'coach_suggestion_budget_schools': 'Which schools fit a budget of €10,000?',
  'coach_suggestion_top_business_schools': 'Top business schools in France',
  'coach_suggestion_tech_programs': 'Tech programs (EPITA, Epitech...)',
  'file_size_bytes': '@size B',
  'file_size_kb': '@size KB',
  'file_size_mb': '@size MB',
  'security_biometric_reason': 'Unlock to access your secure KPB documents',
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
  'academy_benefit_senior_advisor_tips': 'Tips from senior KPB advisors',
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
  'budget_note_fr_rent': 'Outside the capital, shared flat or modest studio',
  'budget_note_uk_health': 'IHS surcharge spread across the year',
  'budget_note_de_health': 'Mandatory student health insurance',
  'budget_note_cn_rent':
      'University residence or shared flat outside the city center',
  'budget_note_cn_health': 'Mandatory student insurance ~600-800 CNY/year',
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
  'parent_no_updates': 'Updates shared by the advisor will appear here.',
  'parent_appbar': 'Parent space',
  'parent_linked_ok': 'Account linked ✓',
  'parent_link_error': 'Invalid or expired code. Try again.',
  'parent_greeting_generic': 'Hello',
  'parent_hello': 'Hello, @name',
  'parent_linked_readonly': 'Parent account — linked to @child (read-only)',
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
  'parent_premium_sub': 'Unlimited copilot · unlimited letters · VIP live',
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
  'profile_premium_card_sub': 'Coming soon — activate via a KPB advisor',
  'premium_screen_title': 'Karatou Premium',
  'premium_badge_soon': 'Coming soon',
  'premium_hero_title': 'Upgrade to Karatou Premium',
  'premium_hero_sub':
      'Premium is coming soon. In the meantime, a KPB advisor can help you — with no in-app payment.',
  'premium_value_ai_coach':
      'Unlimited KPB Intelligence — the free plan includes @count messages per week.',
  'premium_value_advisors': 'Priority guidance from a verified KPB advisor.',
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
  'premium_waitlist_student_only': 'The waiting list is for student accounts.',
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
  'parent_onboarding_b3': 'Direct contact with the KPB advisor on WhatsApp',
  'parent_wa_advisor':
      'Hello, I\'m the parent of a student supported by KPB. I\'d like to talk to the advisor.',
  'parent_wa_ask_access':
      'Hello, I\'d like to request access to some information in my child\'s application.',
  'parent_wa_upload':
      'Hello, I\'d like to send a proof of funds for my child\'s application.',
  'parent_wa_pay': 'Hello, I\'d like to pay for “@item” for my child via KPB.',
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
  'orientation_matched_programs_subtitle_field': 'Programs related to @field.',
  'deadlines_missing_document': 'Missing document · @code',
  'deadlines_status_days': '@n days',
  'compare_program_count': '@n programs',
  'compare_open_case_for': '@name case',
  'compare_subtitle': 'Tap a column to switch universities',
  'compare_pick': 'PICK',
  'compare_picker_title': 'Choose a university',
  'compare_search_hint': 'Search a university…',
  'compare_picker_empty': 'No university matches your search.',
  'compare_verdict_higher_match': '@name is a better match for your profile.',
  'compare_verdict_partner': '@name is a verified KPB partner.',
  'compare_verdict_more_programs': '@name offers more programs (@hi vs @lo).',
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
  'salon_load_error': 'Unable to load the Salon. Check your connection.',
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
  'parcours_empty_error_subtitle': 'Unable to load the journeys right now.',
  'parcours_intro_title': 'They did it before you',
  'parcours_free_badge': 'FREE',
  'parcours_convert_title': 'Want to follow a similar path?',
  'parcours_convert_subtitle': 'Chat with a KPB advisor about your plan.',
  'parcours_whatsapp_prefill':
      'Hello KPB, a journey in the app inspired me and I\'d like to discuss my study plan.',
  'parcours_search_hint': 'Search a career, a school, a name…',
  'parcours_filter_all': 'All',
  'parcours_kind_written': 'Written story',
  'parcours_empty_filter_title': 'No results',
  'parcours_empty_filter_subtitle': 'Try another theme or another search.',
  'parcours_up_next': 'Up next',
  'parcours_story_appbar': 'Testimonial',
  'parcours_video_unavailable': 'This video is not available right now.',
  'orientation_roadmap_appbar_title': 'My journey',
  'orientation_consultation_case_title': 'KPB advisory session',
  'case_message_send_failed':
      'Your message could not be sent. Check it and try again.',
  'orientation_consultation_case_context': 'Orientation support',
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
  'orientation_ia_resilience_high': 'Future-proof career · AI-resistant',
  'orientation_ia_resilience_medium': 'Good resilience to AI',
  'orientation_ia_resilience_low': 'Needs to evolve alongside AI',
  'france_step_choose_school':
      'Choose the partner private school (OMNES, ICN, Schiller, IGENSIA…)',
  'france_step_build_dossier': 'Build the admission dossier with KPB',
  'france_step_interview_validation': 'Interview / school admission validation',
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
  'last_updated_october_2026': 'Last updated: October 2026',
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
      '• "My 10 scholarships" test, if you take it (feature being opened gradually): nationality or nationalities, country of residence, date of birth, highest diploma, scholarship level sought, fields, grade band out of 20, English and French levels, language test scores, work experience band and, if you are 16 or 17, your legal guardian\'s agreement. You are never required to answer: without these answers the test computes no result, and the rest of the app stays usable\n'
      '• Followed scholarships and notifications: the scholarships you follow, your alert settings, the notifications received in the app and when you open one\n'
      '• Case messages and texts submitted to the coach (KPB Intelligence)\n'
      // Voir le commentaire du bloc `fr` : le repli réseau d'Android est
      // nommé parce qu'il subsiste dans le greffon.
      '• Voice dictation: the microphone captures your voice, the app asks your phone to turn it into text on the device and keeps only that text; the audio recording is never sent to us. On iPhone, if on-device recognition is unavailable, dictation does not start. On Android, on-device recognition is only a preference: without a local model installed, your phone\'s recognition service (Google) may process your voice off the device\n'
      '• Documents (passport, transcripts, case files): in-app upload is masked. These files reach your advisor over WhatsApp, not through an in-app upload\n'
      '• Usage data: orientation results, saved items, search history\n'
      '• Technical data: device push token, version and build number of the app in use, local biometrics (app lock), location declared in the iOS configuration but never requested or used\n'
      '• Analytics: Firebase Analytics and PostHog; PostHog session recordings (text and images masked)\n'
      '• Diagnostics: Firebase Crashlytics; aggregated sync metrics',
  'privacy_s3_body': 'Your data is used to:\n\n'
      '• Personalise programme, country and scholarship recommendations\n'
      '• Manage your applications and appointments\n'
      '• Send relevant notifications (case updates, deadlines, openings and deadlines of the scholarships you follow; new scholarships matching your test only if you turn it on)\n'
      '• For the "My 10 scholarships" test: compare your answers with the official conditions of scholarships (nationality, age, level, grades, languages, experience) and show you up to 10 matching or to-check scholarships. The result is indicative: no decision is made for you, and only the scholarship body decides on your application\n'
      '• Email newly listed scholarships only if you opted in (checkbox — unsubscribe any time from your profile or the email footer)\n'
      '• Improve our services through aggregated, anonymised statistics\n'
      '• Communicate with you about your applications\n'
      '• Contact you about a space or a guidance offer you declared an interest in, where you agreed to it when declaring. That declaration is readable by our counsellors and our sales team, and you can withdraw it at any time from the screen where you made it',
  'privacy_s4_body': '• Consent: you accept this policy when you create an account\n'
      '• Contract: processing is required to provide the service\n'
      '• Legitimate interest: improving the service and securing the platform\n'
      '• Minors aged 16 and 17: the declared agreement of a legal guardian (name and contact) is required before completing the profile, using KPB Intelligence or taking the "My 10 scholarships" test. The app is not intended for anyone under 16',
  'privacy_s5_body': 'Your data is NOT sold to third parties.\n\n'
      'It may be shared with:\n'
      '• Our KPB backend (Hostinger VPS, api.kpbeducation.cloud) to run the app\n'
      '• Supabase (authentication: email, session, Google)\n'
      '• OpenRouter and Groq (United States): coach texts and a pseudonymised profile — OpenRouter routing is limited to AI services with zero data retention; never sold\n'
      // Voir le commentaire du bloc `fr`.
      '• Firebase / Google (Analytics, Crashlytics, Cloud Messaging) for analytics, stability and notification delivery — Cloud Messaging only receives the device push token, no account identifier or profile data\n'
      '• OneSignal (United States): only for earlier versions of the app, being phased out — push token, account identifier and four targeting tags (account type, study level, target country, language); never your email address\n'
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
      '• Your nationality, date of birth and other answers to the "My 10 scholarships" test are not sent to any school, scholarship body or our sales team, and never go into analytics or notifications. When you open a case from a scholarship, your advisor sees that scholarship, not your answers. The test may update profile fields already used elsewhere (country of residence, English level, grades): they then follow the rules of this section\n'
      '• Institutional partners (universities) only with your explicit agreement when you submit a case\n'
      '• Competent authorities if the law requires it',
  'privacy_transfers_body':
      'Some recipients are established in the United States (OpenRouter, Groq, PostHog, OneSignal, Resend, Firebase / Google — including YouTube and the speech recognition services — and Wikimedia). The transfer rests on your consent to this policy and, where applicable, the processor\'s standard contractual clauses. You can turn analytics off in Profile → "Usage analytics" and decline KPB Intelligence: the rest of the app stays usable.',
  'privacy_s6_body': '• Profile data: kept while your account is active\n'
      '• Case data: kept while the case is open, then deleted with the account\n'
      '• "My 10 scholarships" test answers: kept on your profile while your account is active, and editable by taking the test again; only your last 5 results are kept, older ones are erased automatically\n'
      '• Followed scholarships and in-app notifications: kept while your account is active\n'
      '• On your phone: the test draft is erased when you finish the test and when you sign out; scholarships kept for offline viewing are erased when you sign out\n'
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
          'The export of your data includes your "My 10 scholarships" test answers, your latest results and your scholarship alerts.\n\n'
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
  'deadlines_filter_saved': 'Followed scholarships',
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
  'compare_share_header': 'University comparison with KPB Education:\\n\\n',
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
  'alumni_apply_submit_failed': 'Could not send the application right now.',
  'alumni_apply_title': 'Become an alumni mentor',
  'alumni_apply_university': 'University / school',
  'form_required': 'Required',
  'alumni_apply_programme': 'Programme / major',
  'alumni_apply_year': 'Admission / graduation year',
  'alumni_apply_year_invalid': 'Invalid year',
  'alumni_apply_year_out_of_range': 'Year out of range',
  'alumni_apply_country': 'University country (ISO code, e.g. FR, CA)',
  'alumni_apply_proof_url': 'Link to admission letter / diploma',
  'alumni_apply_proof_helper': 'Google Drive, Dropbox, or another public link',
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
  'coach_quota_info_body': 'You have @rem of @total messages left this week.',
  'coach_generate_letter': 'Generate a letter',
  'letters_header_subtitle': 'Pick a model, personalize it with AI (FR + EN).',
  'letters_regenerate': 'Regenerate',
  'letters_export': 'Export',
  'interview_header_subtitle': 'Practice with an AI examiner.',
  'interview_header_progress':
      'Question @current/@total · answer as if facing the jury',
  'interview_jury_label': 'JURY',
  'interview_score_line': 'Score: @score/100',
  'interview_complete_title': 'Interview complete!',
  'interview_verdict_strong': 'Excellent — you\'re ready to convince the jury.',
  'interview_verdict_promising':
      'Good start — refine your answers and try again.',
  'interview_verdict_practice': 'Keep practicing — every run gets you closer.',
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
  'eligibility_pdf_generated_on': 'Generated on @date',
  'eligibility_pdf_budget_per_month': '@budget € / month',
  // --- KPB-89 batch ---
  'cv_default_languages': 'French, English',
  'tools_ai_error_check_connection': 'AI error — check your connection',
  'tools_ai_error_unavailable':
      'The AI service is temporarily unavailable. Please try again shortly.',
  'tools_ai_error_slow':
      'Generation is taking longer than expected. Please try again shortly.',
  'tools_ai_error_rate_limited': 'Too many requests. Try again in a minute.',
  'tools_ai_error_daily_quota':
      'You have reached today\'s AI usage limit. Try again tomorrow.',
  'tools_ai_error_input_too_large':
      'Your text is too long. Shorten it and try again.',
  'tools_ai_error_signin_required': 'Please sign in again to use the AI.',
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
  'letter_tpl_admission_general_title': 'University Admission (general)',
  'letter_tpl_admission_master_title':
      'Master / Specialised Programme Admission',
  'letter_tpl_scholarship_kpb_title': 'KPB Education Scholarship',
  'letter_tpl_scholarship_international_title':
      'International Excellence Scholarship',
  'letter_tpl_visa_student_title': 'Student Visa Motivation Letter',
  'letter_tpl_internship_title': 'International Internship / Work-Study',
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
  'scholarships_empty_subtitle': 'Try changing your criteria or orientation.',
  'scholarship_tab_info_criteria': 'Info & Criteria',
  'scholarship_tab_success_path': 'My Success Path',
  'scholarship_detail_level_label': 'Level: ',
  'scholarship_detail_funding_label': 'Funding: ',
  'scholarship_detail_deadline_label': 'Deadline: ',
  'scholarship_apply_with_kpb': 'Apply with KPB',
  'scholarship_academy_continue': 'Continue your course',
  'scholarship_academy_prepare': 'Prepare your application with experts',
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
  'live_scholarships_empty_catalog_title': 'No scholarship published yet',
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
  'live_scholarships_view_official_application':
      'View the official application site',
  'live_scholarships_official_form': 'Official application form',
  'live_scholarships_no_deadline': 'No fixed deadline',
  'live_scholarships_funding_tile': 'Funding',
  'live_scholarships_alert': 'Notify me',
  'live_scholarships_alert_enabled': 'Alert enabled',
  'live_scholarships_alert_error':
      'Unable to update this alert. Please try again.',
  // ── Scholarship list (chantier I): status line, filters, sort, offline.
  'scholarships_filter_button': 'Filter',
  'scholarships_filter_button_count': 'Filter · @count',
  'scholarships_filter_title': 'Filter scholarships',
  'scholarships_filter_clear': 'Clear all',
  'scholarships_filter_status_section': 'Status',
  'scholarships_filter_status_open': 'Open now',
  'scholarships_filter_status_upcoming': 'Confirmed upcoming opening',
  'scholarships_filter_status_forecast': 'Estimated or unconfirmed dates',
  'scholarships_filter_funding_section': 'Funding',
  'scholarships_filter_apply': 'Show scholarships',
  'scholarships_sort_button': 'Sort: @sort',
  'scholarships_sort_sheet_title': 'Sort by',
  'scholarships_sort_relevance': 'Relevance to your profile',
  'scholarships_sort_deadline': 'Closing soonest',
  'scholarships_sort_verified': 'Recently verified',
  'scholarships_sort_title': 'Name (A–Z)',
  'scholarships_offline_count': '@count scholarship(s) saved on your phone',
  'scholarship_detail_title': 'Scholarship details',
  'scholarship_detail_not_found': 'Scholarship not found',
  'scholarship_detail_not_found_body':
      'This scholarship is no longer available or its link has expired.',
  'scholarship_how_to_apply_unavailable':
      'Detailed steps will be added soon. Check the official form for current instructions.',
  'scholarship_videos_title': 'Explanation videos',
  'scholarship_video_explanation': 'Understand this scholarship',
  'scholarship_video_play': 'Play video',
  'scholarship_video_unavailable': 'This video is not available right now.',
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
      'Scholarships checked by KPB and not yet closed. Enable an alert so you do not miss the opening.',
  'roadmap_redirect_writing_tutorials': 'Redirecting to writing tutorials...',
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
  'case_documents_handoff_title': 'Your documents go through your advisor',
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
  'case_whatsapp_has_advisor_subtitle': 'Chat directly with your KPB advisor.',
  'case_whatsapp_no_advisor_subtitle':
      'Join the KPB group while we assign your advisor.',
  'case_timeline_heading': 'Track your request',
  'case_timeline_status_submitted': 'Submitted',
  'case_timeline_status_counselor_assigned': 'Assigned to an advisor',
  'case_timeline_status_under_review': 'Under review',
  'case_timeline_status_documents_needed': 'Documents required',
  'case_timeline_status_awaiting_student': 'Awaiting your response',
  'case_timeline_status_in_progress': 'In progress',
  'case_timeline_status_application_submitted': 'Submitted to the institution',
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
  'case_stepper_analysis_desc_docs': 'Additional documents are required.',
  'case_stepper_analysis_desc_awaiting':
      'Your advisor is waiting for your reply.',
  'case_stepper_analysis_desc_default':
      'Our experts are reviewing your profile.',
  'case_stepper_processing_title': 'Processing',
  'case_stepper_processing_desc': 'Preparing and submitting your applications.',
  'case_stepper_decision_title': 'Decision',
  'case_stepper_decision_desc': 'Awaiting responses from the institutions.',
  'case_stepper_finalization_title': 'Finalization',
  'case_stepper_finalization_desc_rejected': 'Case rejected.',
  'case_stepper_finalization_desc_cancelled': 'Case cancelled.',
  'case_stepper_finalization_desc_done': 'Procedure completed successfully!',
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
  'program_available_on_one_campus': 'Available on 1 campus',
  'program_recognition': 'Degree recognition',
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
  'program_step_eligibility_choice': 'Eligibility quiz & program choice',
  'program_step_build_file': 'Building your file with KPB',
  'program_step_submission': 'Submission to the partner school',
  'program_step_submission_direct':
      'Sending your application to the institution (not a KPB partner)',
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
  'explore_no_fields_body': 'Check back later to discover our new programs.',
  'explore_no_countries_title': 'No countries available',
  'explore_no_countries_body':
      'We are currently expanding our catalog of destinations.',
  'explore_no_programs_title': 'No programs available',
  'explore_no_programs_body':
      'Sync the app with the server to load the catalog.',
  'explore_search_program': 'Search a program',
  'explore_share_university': 'Discover this university on KPB Education.',
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
  'institution_premium_support_guaranteed': 'Guaranteed Premium Support',
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
  'onboarding_select_field_body': 'Choose at least one field of interest.',
  'onboarding_select_country_body': 'Choose at least one destination country.',
  'onboarding_fields_required_inline':
      'Pick at least one field you\'re interested in.',
  'onboarding_countries_required_inline':
      'Pick at least one country where you\'d like to study.',
  'onboarding_welcome_title': 'Welcome 👋',
  'onboarding_welcome_subtitle': 'Let\'s create your KPB Education profile.',
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
  'profile_missing_email_impact': 'How schools and our advisors reply to you',
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
  'home_hero_cta_find_scholarships': 'Find your scholarships',
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
  'home_next_step_title_discover_opportunities': 'Discover new opportunities',
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
  'stale_catalog_notice': 'Server unreachable — real data from your last load',
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
  'eef_hub_hero_title': 'Prepare your application to French universities',
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
  'eef_help_procedure_question': 'Procedure, dates, submission: unclear?',
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
  'eef_help_step_catalog_procedure': 'application procedure of a programme',
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
  'eef_help_line_neutral_subject': 'Talk to an advisor about “@subject”',
  'eef_help_catalog_filters_question': 'Torn between these programmes?',
  'eef_help_tool_cv_question': 'Need help writing your CV?',
  'eef_help_tool_letters_question': 'Need help with your motivation letter?',
  'eef_help_tool_interview_question': 'Need help preparing for your interview?',
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
  'eef_tour_1_body': 'Here you explore programmes and prepare your plans. Your '
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
  'eef_help_bubble_assistance_label': 'Contact the KPB team for assistance',
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
  'eef_help_bubble_choose_label': 'I don\'t know which programme to choose',
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
  'eef_help_private_option_label': 'I want to know more about private schools',
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
  'eef_catalog_city_error_network': 'No connection. Check it, then try again.',
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
  'eef_catalog_attribution': 'Data: @producer (@sources). Licence: @licence. '
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
  'eef_cta_body': 'Tell us: we will let you know as soon as it opens, and your '
      'answer tells us where to start.',
  'eef_cta_declare': 'I am interested',
  'eef_guest_body': 'Create your account so we can tell you when it opens.',
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
  'impact_proof_line': '@students students guided · @admissions admissions',
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
  'kpb_offer_partner_discount': '−30% if you study at a KPB partner school',
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
  'commercial_no_leads_body': 'New requests assigned to you will appear here.',
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
  'key_criteria': 'Key criteria:',
  'privacy_policy': 'Privacy Policy',
  'parent_create_invite': 'Create an invite code',
  'salon_rsvp_error': 'Could not update your RSVP.',
  'intake_label': 'Intake',
  'offering_intake_spring_month': 'Spring intake · @month @year',
  'offering_intake_spring_year': 'Spring intake · @year',
  'offering_intake_fall_month': '@month @year intake',
  'offering_intake_fall_year': 'Fall @year intake',
  'offering_rhythm_alternance': 'Work-study',
  'offering_rhythm_initiale': 'Full-time study',
  'program_intakes_one': 'Intake:',
  'program_intakes_many': 'Intakes:',
  'program_intakes_school_one': 'School intake:',
  'program_intakes_school_many': 'School intakes:',
  'program_intakes_more': '+ @count',
  'program_intakes_none_upcoming': 'Next intake not yet published',
  'program_offerings_all_past':
      'The published intakes (@campuses) have passed. The next date is not published yet: ask your KPB advisor.',
  'program_intake_spring_tag': 'spring',
  'program_intake_spring_a11y': 'spring intake',
  'program_intake_fall_year_short': 'Fall @year',
  'offering_intake_estimated_note':
      'Date carried over from @year, to be confirmed · @tuitionYear fee',
  'offering_intake_estimated_a11y':
      'Date carried over from the @year intake, to be confirmed by the school. Fee for @tuitionYear.',
  'offering_intake_estimated_plain': 'Date and fee to be confirmed',
  'program_intake_estimated_tag': 'to be confirmed',
  'program_intake_estimated_a11y': 'date to be confirmed',
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
  'orientation_results_intro': 'Here are the fields that suit you best.',
  'target_careers': 'Target careers',
  'recommended_countries': 'Recommended countries',
  'track_admission_deadlines': 'Track your admission deadlines',
  'item_deleted': 'Item deleted',
  'documents_ready': 'documents ready',
  'france_admission_title': 'France admission — Private schools',
  'france_sept_intake': '@intake intake',
  'programs_available': 'programs available',
  'france_public_unis_soon': 'Public universities — Coming soon · @intake',
  'france_why_private': 'Why private at launch?',
  'france_private_intro':
      'KPB partner French private schools offer a direct admission path, with flexible intakes and personalized support for African students.',
  'france_sync_catalog': 'Sync the catalogue to see OMNES and partner schools.',
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
  'eligibility_hook': 'In 1 minute, check the basic criteria',
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
  'parent_cost_note': 'Indicative estimate — confirm details with the advisor.',
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
  'scholarship_tutorials':
      'Access the exclusive video tutorial pack to ace your application.',
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
  'roadmap_objective':
      'Goal: @intake intake · @field. Here are the steps, dated backward from the deadline — tick them off as you go.',
  'parent_share_case_title': 'Share with my parent',
  'parent_share_case_subtitle':
      'Your linked parent can follow this case (read-only).',
  'parent_visibility_error': 'Could not update sharing. Please try again.',
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
  'home_scholarships_title': 'Scholarships to follow',
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
  'auth_intelligence_title': 'KPB Intelligence, your guide to studying abroad',
  'auth_intelligence_body':
      'Build your profile in 3 steps and discover universities ranked by your answers.',
  'auth_intelligence_benefit_fit': 'Universities ranked for your profile',
  // Voir le commentaire du bloc `fr` : ne nomme que le coach, la seule
  // surface KPB Intelligence atteignable en build 49.
  'auth_intelligence_benefit_ai':
      'KPB Intelligence answers in French: schools, budget, programs',
  'auth_intelligence_benefit_support': 'Human KPB guidance via WhatsApp',
  'auth_receive_email_link': 'Receive a link by email',
  'auth_explore_guest': 'Explore without an account',
  'auth_intelligence_note': 'Free · FCFA · designed for French-speaking Africa',
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
  'auth_magic_verify_body': 'Enter the code sent to @email (valid 15 min).',
  'auth_magic_verify_error': 'Invalid or expired code.',
  'auth_magic_verify_code_label': '6-digit code',
  'auth_magic_verify_button': 'Verify',
  'auth_magic_resend': 'Resend code',
  'auth_magic_resend_wait': 'Resend in @seconds s',
  'auth_magic_resend_cooldown': 'Please wait before requesting another code.',
  'auth_guest_profile_title': 'Sign in to access your profile',
  'auth_guest_profile_body':
      'Create an account to track cases, save programs, and personalize your journey.',
  // Match explanations
  'match_complete_profile': 'Complete your profile for a personalised match',
  'match_field_in_interests': 'In your fields of interest',
  'match_from_orientation': 'Recommended by your orientation',
  'match_available_target_country': 'Available in your target countries',
  'match_target_country': 'Target country',
  'match_in_target_country': 'Located in a target country',
  'match_kpb_partner': 'KPB partner',
  'match_field_match': 'Matching field',
  'match_general': 'General match',
  // Case snackbar
  'case_created_title': 'Case created ✅',
  'case_created_body': 'Your case @code has been submitted.',
  // Content of a case created on the device, before the server answers
  // (`submitCase`). Stored in both languages with the case.
  'case_local_next_step_title': 'Your case is under review',
  'case_local_next_step_body':
      'The KPB team will review your request and check your information. Then they will assign you a counselor.',
  'case_local_submitted_title': 'Request submitted',
  'case_local_submitted_body':
      'Your request is in the “My Cases” tab. The KPB team has received it.',
  'case_local_welcome_sender': 'KPB team',
  'case_local_welcome_body':
      'Thanks for your request. We will come back to you with the next step.',
  'case_local_doc_profile_title': 'Complete academic profile',
  'case_local_student_reply_title': 'Student reply',
  'case_local_student_reply_body':
      'The case has been updated with a new message.',
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
  'verified_advisor_prefill_label': 'PREFILLED MESSAGE — EDITABLE IN WHATSAPP',
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
  'offline_body': 'No internet connection. Some features are unavailable.',
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
  'forgot_password_error': 'An error occurred. Check the email address.',
  // Register errors
  'register_error_generic': 'An error occurred. Please try again.',
  'register_error_email_exists': 'An account with this email already exists.',
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
  'commercial_sla': 'Goal: first reply within 24h. @n lead(s) in your queue.',
  'commercial_filter_all': 'All',
  'commercial_filter_new': 'To answer',
  'commercial_filter_qualified': 'Qualified',
  'commercial_filter_converted': 'Signed',
  'commercial_leads_empty': 'No leads in this view.',
  'commercial_cases_title': 'Tracked cases',
  'commercial_cases_sub': '@n active case(s)',
  'commercial_cases_empty': 'No active cases yet.',
  'commercial_converted_toast': 'Lead converted 🎉 @name is now a KPB client',
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
  'referral_become_ambassador_sub': 'Earn FCFA by referring · Wave payouts',
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
  'amb_toast_withdraw': 'Wave withdrawal requested — @amount within 48h ✓',
  'amb_referrals_empty': 'No referrals yet. Share your code to get started!',
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
  'referral_redeemed_ok': 'Code applied — thanks! Your referrer is credited.',
  'referral_redeemed_already': 'You have already used a referral code.',
  'referral_redeem_error': 'Invalid code. Check it and try again.',
  // ── No-cash referral rewards (KPB-77) ──
  'referral_credits_title': 'My referral credits',
  'referral_credits_label': 'credit(s)',
  'referral_credits_intro':
      'A friend who creates their case = 1 credit. Redeem your credits for an in-depth review of your application by a KPB advisor.',
  'referral_redeem_voucher_cta': 'Redeem for an advisor review',
  'referral_credits_none': 'No credits yet — invite a friend to earn one.',
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
  'onboarding_birthdate_required': 'Enter your date of birth to continue.',
  'minor_guardian_title': 'Parent / guardian consent',
  'minor_guardian_intro':
      'You are under 18. A parent or guardian must consent and provide their details for you to use KPB (data sync and KPB Intelligence).',
  'guardian_name': 'Parent / guardian name',
  'guardian_contact': 'Parent / guardian contact (WhatsApp or email)',
  'guardian_consent_checkbox': 'My parent / guardian has given their consent.',
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
  'aha_title_named': '@name, here are your @count matching universities',
  'aha_subtitle':
      'Based on your profile, here are the schools that match you best.',
  'aha_empty_body': 'No matches yet — explore the catalog to discover schools.',
  'aha_estimate_note': 'Estimate — complete your profile for more precision.',
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
  'dest_list_subtitle': 'Full guides: visa, costs, universities, support',
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
  'success_lab_missing_identity': 'An active student session is required.',
  'success_lab_cached_label': 'Showing a saved version while it is updated.',
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
  'success_lab_diagnostic_promise': 'One priority improvement you can make now',
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
  'success_lab_study_status_submitted': 'Request sent to the counsellor',
  'success_lab_study_status_triaged': 'Request reviewed',
  'success_lab_study_status_more_information_needed':
      'Additional information required',
  'success_lab_study_status_call_offered': 'Time slots offered',
  'success_lab_study_status_scheduled': 'Appointment scheduled',
  'success_lab_study_status_converted_to_case': 'KPB support case created',
  'success_lab_study_status_autonomy_recommended':
      'Independent continuation recommended',
  'success_lab_study_status_declined': 'Request declined',
  'success_lab_study_status_closed': 'Study completed',
  'success_lab_study_status_unknown': 'Updated state — refresh the application',
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
  'success_lab_study_next_none': 'No further action is needed right now.',
  'success_lab_study_next_unknown': 'Refresh to receive the next action.',
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
  'success_lab_schedule_booking': 'Confirming the appointment with the server…',
  'success_lab_schedule_booked_title': 'Appointment confirmed',
  'success_lab_schedule_booked_body':
      '@date (your device time: @deviceZone). Booking timezone: @zone.',
  'success_lab_schedule_booked_recovered_body':
      'The server confirms that an appointment is scheduled. Check your KPB notifications for details.',
  'success_lab_schedule_empty_title': 'No time slots are available right now',
  'success_lab_schedule_empty_body':
      'Expired slots are never shown. Refresh later to see new offers.',
  'success_lab_schedule_waiting_title': 'Time-slot booking is not open yet',
  'success_lab_schedule_waiting_body':
      'Your request is being tracked, but booking opens only after a counsellor offers time slots.',
  'success_lab_schedule_no_request_title': 'No active study request',
  'success_lab_schedule_no_request_body':
      'First submit a study request from your Success Lab workspace.',
  'success_lab_schedule_online_required':
      'Reconnect to view and book a time slot.',
  'success_lab_schedule_error_title': 'Time slots temporarily unavailable',
  'success_lab_schedule_error_body':
      'The server did not confirm the booking. Retry with the same selection.',
  'success_lab_schedule_expired':
      'This offer has expired. Select another time slot.',
  'success_lab_schedule_taken':
      'This time slot was just taken. Select another offer.',
  'success_lab_schedule_changed':
      'The request changed. Refresh the offers before booking.',
  'success_lab_schedule_no_offer': 'This time slot is no longer offered.',
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
  'success_lab_submission_reference': 'Application reference (optional)',
  'success_lab_submission_reference_private':
      'Sent over encrypted transport; the server stores only an HMAC fingerprint.',
  'success_lab_submission_date': 'Submission date',
  'success_lab_submission_action': 'Declare submission',
  'success_lab_submission_sending': 'Saving on the server…',
  'success_lab_submission_confirmed_body':
      'The server recorded the declaration. Its verification status remains visible below.',
  'success_lab_submission_history': 'Submission history',
  'success_lab_submission_history_empty': 'No submission has been declared.',
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
  'success_lab_outcome_no_funding': 'No funding decision has been declared.',
  'success_lab_outcome_declare_admission': 'Declare an admission decision',
  'success_lab_outcome_update_admission': 'Declare a new admission decision',
  'success_lab_outcome_declare_funding': 'Declare a funding decision',
  'success_lab_outcome_update_funding': 'Declare a new funding decision',
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
  'success_lab_outcome_saving_admission': 'Saving the admission decision…',
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
  'success_lab_outcome_file_too_large': 'The file is larger than 10 MB.',
  'success_lab_outcome_file_not_allowed': 'Choose a PDF, JPG or PNG file.',
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
  'success_lab_start_error_body': 'This workspace cannot be created right now.',
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
  // ── Toasts (KpbToast) ──────────────────────────────────────────
  'toast_offline_pending_default':
      'Saved on your phone. We\'ll send it as soon as you\'re online.',
  // ── Async states (KpbAsyncView) ────────────────────────────────
  'async_loading': 'Loading…',
  'async_empty_title': 'Nothing to show yet',
  'async_updated_ago': 'Updated @ago',
  'async_offline_data_from': 'Offline — data from @date at @time',
  // ── Follow a scholarship, Followed, notifications (chantier G) ──────
  'follow_scholarship_follow': 'Follow',
  'follow_scholarship_following': 'Following',
  'follow_scholarship_a11y_follow': 'Follow the @title scholarship',
  'follow_scholarship_a11y_following': 'Following @title. Tap to unfollow',
  'push_primer_title': 'We\'ll tell you as soon as it opens',
  'push_primer_body':
      'Turn on notifications to know in time when a scholarship you follow opens, and before its deadline. You can change this anytime.',
  'push_primer_enable': 'Turn on notifications',
  'push_primer_later': 'Not now',
  'push_denied_title': 'Notifications are off',
  'push_denied_body':
      'You won\'t get alerts on your phone. You\'ll still find them in the app, under Notifications. To turn them back on, open the app settings.',
  'push_denied_open_settings': 'Open settings',
  'scholarship_notify_opening_title': 'Notify me when it opens',
  'scholarship_notify_opening_subtitle':
      'One notification the day applications open. Deadline reminders keep coming.',
  'scholarship_notify_opening_global_off':
      'You turned off opening alerts in your notification preferences.',
  'scholarship_notify_opening_error':
      'Your choice wasn\'t saved. Try again when you\'re online.',
  'scholarship_status_open': 'Open · closes @date',
  'scholarship_status_open_no_date': 'Open · closing date to be confirmed',
  'scholarship_status_opens_on': 'Opens @date',
  'scholarship_status_opening_estimated': 'Expected to open: @date',
  'scholarship_status_opening_unknown': 'Opening date to be confirmed',
  'scholarship_status_closed': 'Closed',
  // ── Scholarship detail: urgency header, verification, actions (I2) ──
  'scholarship_urgency_open': 'Open · closes @date',
  'scholarship_urgency_closing_soon': 'Closing soon · @date',
  'scholarship_urgency_closing_estimated': 'Expected to close @date',
  'scholarship_urgency_date_to_confirm': 'Date to be confirmed',
  'scholarship_urgency_last_day': 'Last day to apply',
  'scholarship_urgency_one_day_left': 'You have 1 day left to apply',
  'scholarship_urgency_days_left': 'You have @count days left to apply',
  'scholarship_urgency_estimated_hint':
      'Estimated from previous sessions: follow the scholarship and we will tell you as soon as the dates are confirmed.',
  'scholarship_urgency_unknown_hint':
      'The dates of the next session have not been published yet.',
  'scholarship_urgency_closed_hint':
      'Follow it: we will tell you when the next session opens.',
  'scholarship_verified_on': 'Verified on @date',
  'scholarship_official_source': 'Official source',
  'scholarship_official_source_a11y':
      'Open the official source of this scholarship (external site)',
  'scholarship_action_apply': 'Apply',
  'scholarship_action_apply_a11y':
      'Apply to @title on the official website (external site)',
  'scholarship_action_support': 'Get support',
  'scholarship_action_support_a11y': 'Get support from KPB for @title',
  // ── « My 10 scholarships » test (chantier H) ──────────────────────────
  'scholarship_match_entry_title': 'Test: which scholarships fit me?',
  'scholarship_match_entry_body':
      '2 min · up to 10 scholarships · we explain why',
  'scholarship_match_entry_guest_body':
      'With an account, take the test: up to 10 scholarships for your profile.',
  'scholarship_match_entry_cta': 'Take the test',
  'scholarship_match_entry_run_title': 'Your scholarships: @counts',
  'scholarship_match_entry_run_body': 'Updated on @date',
  'scholarship_match_entry_run_body_undated': 'Your test results',
  'scholarship_match_entry_view': 'View',
  'scholarship_match_entry_update': 'Update',
  'scholarship_match_count_compatible': '@count compatible',
  'scholarship_match_count_compatible_one': '1 compatible',
  'scholarship_match_count_to_verify': '@count to check',
  'scholarship_match_count_to_verify_one': '1 to check',
  'scholarship_match_flow_title': 'My scholarships',
  'scholarship_match_flow_close': 'Leave the test',
  'scholarship_match_leave_title': 'Leave the test?',
  'scholarship_match_leave_body':
      'Your answers are kept on this phone. You will pick up where you left off.',
  'scholarship_match_leave_stay': 'Keep going',
  'scholarship_match_leave_quit': 'Leave',
  'scholarship_match_intro_title': 'Which scholarships fit me?',
  'scholarship_match_intro_body':
      '2 minutes. You only answer what is missing (@count questions).',
  'scholarship_match_intro_body_one':
      '2 minutes. You only answer what is missing (1 question).',
  'scholarship_match_intro_body_none':
      'Your details are already here: check them, and off you go.',
  'scholarship_match_intro_privacy':
      'Your nationality and date of birth are only used to check scholarship conditions.',
  'scholarship_match_intro_privacy_link': 'Privacy policy',
  'scholarship_match_start': 'Start',
  'scholarship_match_apply': 'Confirm',
  'scholarship_match_progress_a11y': 'Question @index of @total',
  'scholarship_match_q_nationality': 'Your nationality',
  'scholarship_match_q_nationality_help': 'The one on your passport.',
  'scholarship_match_nationality_suggestion':
      'You live in « @country »: is it also your nationality?',
  'scholarship_match_second_nationality': 'I have a second nationality',
  'scholarship_match_second_nationality_set': 'Second nationality: @country',
  'scholarship_match_country_search': 'Search for a country',
  'scholarship_match_country_none': 'No country matches.',
  'scholarship_match_q_residence': 'Your country of residence',
  'scholarship_match_q_residence_help':
      'Some scholarships depend on the country you live in.',
  'scholarship_match_q_birth_date': 'Your date of birth',
  'scholarship_match_q_birth_date_help': 'Many scholarships have an age limit.',
  'scholarship_match_q_diploma': 'Your highest diploma',
  'scholarship_match_q_target': 'You want a scholarship for…',
  'scholarship_match_q_target_help':
      'The level of study you want to do with the scholarship.',
  'scholarship_match_target_diploma_hint':
      'This level usually asks for a diploma you do not have yet. Keep it if you will get it before you leave.',
  'scholarship_match_q_fields': 'Your fields of study',
  'scholarship_match_q_fields_help': 'Up to 3.',
  'scholarship_match_fields_undecided': 'Not decided yet',
  'scholarship_match_q_grade': 'Your average last year (out of 20)',
  'scholarship_match_q_grade_help': 'An estimate is enough.',
  'scholarship_match_grade_other_scale': 'My system is not out of 20',
  'scholarship_match_grade_scale': 'Out of @scale',
  'scholarship_match_grade_scale_value': 'Your average',
  'scholarship_match_grade_converted': 'Out of 20: @band',
  'scholarship_match_q_english': 'Your English level',
  'scholarship_match_q_french_optional': 'And in French? (optional)',
  'scholarship_match_q_french': 'Your French level',
  'scholarship_match_has_test_score': 'I have a test score',
  'scholarship_match_test_value': '@test: @score',
  'scholarship_match_test_score_label': 'Your score (@min to @max)',
  'scholarship_match_q_experience': 'Your work experience',
  'scholarship_match_q_experience_help':
      'Internships count if you were paid full time.',
  'scholarship_match_recap_title': 'Check your details',
  'scholarship_match_recap_help':
      'The test uses these answers. Fix anything that is wrong.',
  'scholarship_match_recap_nationality': 'Nationality',
  'scholarship_match_recap_residence': 'Country of residence',
  'scholarship_match_recap_birth_date': 'Date of birth',
  'scholarship_match_recap_guardian_done': 'Consent given',
  'scholarship_match_recap_diploma': 'Highest diploma',
  'scholarship_match_recap_target': 'Scholarship for',
  'scholarship_match_recap_fields': 'Fields',
  'scholarship_match_recap_grade': 'Average',
  'scholarship_match_recap_english': 'English',
  'scholarship_match_recap_french': 'French: @level',
  'scholarship_match_recap_experience': 'Work experience',
  'scholarship_match_recap_boosters': 'For more precision (optional)',
  'scholarship_match_recap_destinations': 'Target countries',
  'scholarship_match_recap_test': 'Test score',
  'scholarship_match_recap_improves_precision': 'Improves precision',
  'scholarship_match_recap_missing': 'To fill in',
  'scholarship_match_recap_edit': 'Edit',
  'scholarship_match_recap_fill': 'Fill in',
  'scholarship_match_recap_edit_a11y': 'Edit: @field',
  'scholarship_match_recap_complete_first':
      'Fill in the lines in red to see your scholarships.',
  'scholarship_match_submit': 'All good, show my scholarships',
  'scholarship_match_analysing': 'Checking @count scholarships…',
  'scholarship_match_analysing_generic': 'Checking the scholarships…',
  'scholarship_match_still_missing': 'One detail is still missing.',
  'scholarship_match_draft_kept': 'Your answers are kept.',
  'scholarship_match_load_error_title': 'The test will not open',
  'scholarship_match_error_offline':
      'No connection. Try again when you are online.',
  'scholarship_match_error_timeout': 'The server is taking too long to answer.',
  'scholarship_match_error_rate_limited':
      'Too many tries at once. Try again in a minute.',
  'scholarship_match_error_session':
      'Your session has expired. Sign in again, then try again.',
  'scholarship_match_error_unavailable': 'The test is not available right now.',
  'scholarship_match_error_server': 'The check did not go through.',
  'scholarship_match_results_title': 'Your scholarships',
  'scholarship_match_results_header': 'Your scholarships — @date',
  'scholarship_match_offline': 'Offline — results from @date',
  'scholarship_match_updating': 'Updating your results…',
  'scholarship_match_needs_review':
      'Your details changed: check them to update your results.',
  'scholarship_match_edit_info': 'Edit my details',
  'scholarship_match_precision_kpb':
      'Many of these scholarships are not fully analysed by KPB yet: read their official conditions before you apply.',
  'scholarship_match_precision_answers':
      'We are missing some details to be more precise: complete your answers.',
  'scholarship_match_empty': 'No compatible scholarship in our catalogue yet.',
  'scholarship_match_empty_closed_return':
      'Some closed scholarships will come back when their next session opens.',
  'scholarship_match_none_compatible':
      'No scholarship is clearly compatible today, @count need checking.',
  'scholarship_match_none_compatible_one':
      'No scholarship is clearly compatible today, 1 needs checking.',
  'scholarship_match_fewer': '@count scholarships found for your profile.',
  'scholarship_match_fewer_one': '1 scholarship found for your profile.',
  'scholarship_match_see_more_title': 'How to see more',
  'scholarship_match_see_more_edit': 'Check my answers',
  'scholarship_match_section_compatible': 'Compatible with your profile',
  'scholarship_match_section_to_verify': 'Check before you apply',
  'scholarship_match_status_compatible': 'Compatible',
  'scholarship_match_status_to_verify': 'To check',
  'scholarship_match_status_a11y': 'Status: @status',
  'scholarship_match_unavailable': 'No longer available',
  'scholarship_match_new': 'New',
  'scholarship_match_window_a11y': 'Applications: @window',
  'scholarship_match_window_closed': 'Closed',
  'scholarship_match_window_suspended': 'Suspended',
  'scholarship_match_window_open': 'Open',
  'scholarship_match_window_open_until': 'Open · closes on @date',
  'scholarship_match_window_open_estimated_close':
      'Open · estimated close: @month',
  'scholarship_match_window_opens_on': 'Opens on @date',
  'scholarship_match_window_estimated_open': 'Estimated opening: @month',
  'scholarship_match_window_estimated_close': 'Estimated close: @month',
  'scholarship_match_official_show': 'See the official condition',
  'scholarship_match_official_hide': 'Hide the official condition',
  'scholarship_match_official_quote_label': 'Text from the organisation:',
  'scholarship_match_official_source': 'See the source',
  'scholarship_match_case_cta': 'Get support',
  'scholarship_match_case_title': 'Application — @title',
  'scholarship_match_success_lab_cta': 'Prepare with Success Lab',
  'scholarship_match_whatsapp_a11y':
      'Message an advisor on WhatsApp about @title',
  'scholarship_match_whatsapp_prefill':
      'Hello KPB, the « My scholarships » test suggested « @title ». Can you help me?',
  'scholarship_match_advisor_prefill':
      'Hello KPB, I took the « My scholarships » test and would like to talk to an advisor.',
  'scholarship_match_report_prefill':
      'Hello KPB, I think there is a mistake in the « My scholarships » test: « @group ».',
  'scholarship_match_needs_connection': 'Connection needed',
  'scholarship_match_excluded_title':
      'Why some scholarships are not shown (@count)',
  'scholarship_match_excluded_report': 'Report a mistake',
  'scholarship_match_follow_all': 'Follow the @count compatible ones',
  'scholarship_match_follow_all_one': 'Follow the compatible scholarship',
  'scholarship_match_follow_all_done':
      'You now follow @count scholarships: we will tell you when they open and before the deadline.',
  'scholarship_match_share': 'Share my scholarships',
  'scholarship_match_share_text':
      'My scholarships found with KPB Education:\n@list\n\nTake the test too: @link',
  'scholarship_match_redo': 'Take the test again',
  'scholarship_match_advisor': 'Talk to an advisor',
  'scholarship_match_alerts_title':
      'Tell me when a new compatible scholarship arrives',
  'scholarship_match_alerts_error': 'The setting was not saved. Try again.',
  // Home, scholarship page, Profile and notifications (H3).
  'home_hero_cta_find_scholarships_test': 'Find your scholarships (2 min)',
  'home_match_title': 'Your scholarships',
  'home_match_see_all': 'See my @count scholarships',
  'home_match_see_all_one': 'See my scholarship',
  // ── Home "Your next step" (chantier K) ──
  'home_next_step_eyebrow': 'YOUR NEXT STEP',
  'home_next_step_plan_a11y': 'Your plan: @value out of 100',
  'home_next_step_label_deadline': 'Closing soon',
  'home_next_step_subtitle_profile_test':
      'The scholarship test (2 min) completes your profile and sorts scholarships for you.',
  'home_next_step_cta_case': 'Open the case',
  'home_next_step_cta_scholarship': 'See the scholarship',
  'home_next_step_cta_test': 'Take the test',
  'home_next_step_cta_profile': 'Complete my profile',
  'home_next_step_cta_orientation': 'Start the test',
  'home_next_step_cta_start_case': 'Start my case',
  'home_next_step_cta_explore': 'Explore',
  'home_deadlines_title': 'Your deadlines',
  'home_intelligence_title': 'KPB Intelligence',
  'home_intelligence_body':
      'Ask your questions about schools, scholarships or budget.',
  'scholarship_match_assessment_title': 'Your test result',
  'scholarship_match_assessment_date': 'Based on your test of @date',
  'scholarship_match_assessment_not_in_run':
      'This scholarship is not among your test results.',
  'scholarship_match_assessment_see_results': 'See my results',
  'profile_quick_scholarship_match': 'My matching scholarships',
  'scholarship_match_alerts_pref_title': 'New matching scholarships (weekly)',
  'scholarship_match_alerts_pref_subtitle':
      'At most one notification a week, when a new scholarship matching your test arrives.',
  'scholarship_match_disclaimer':
      'The test checks the main published conditions. The organisation still makes the selection.',
  'scholarship_match_diff_added': '@count new',
  'scholarship_match_diff_added_one': '1 new',
  'scholarship_match_diff_removed': '@count removed',
  'scholarship_match_diff_removed_one': '1 removed',
  'scholarship_match_diploma_none': 'No baccalaureate yet',
  'scholarship_match_diploma_bac': 'Baccalaureate',
  'scholarship_match_diploma_bac_plus_2': 'Two years after the bac',
  'scholarship_match_diploma_licence': 'Bachelor\'s degree',
  'scholarship_match_diploma_master': 'Master\'s degree',
  'scholarship_match_diploma_doctorat': 'Doctorate',
  'scholarship_match_target_secondary': 'International high school (UWC)',
  'scholarship_match_target_bachelor': 'Bachelor',
  'scholarship_match_target_master': 'Master',
  'scholarship_match_target_doctorate': 'Doctorate',
  'scholarship_match_grade_lt10': 'Below 10',
  'scholarship_match_grade_10_12': '10 to 11.9',
  'scholarship_match_grade_12_14': '12 to 13.9',
  'scholarship_match_grade_14_16': '14 to 15.9',
  'scholarship_match_grade_16_plus': '16 or more',
  'scholarship_match_lang_none': 'None',
  'scholarship_match_lang_a1_a2': 'Beginner',
  'scholarship_match_lang_b1': 'I get by (B1)',
  'scholarship_match_lang_b2': 'Comfortable (B2)',
  'scholarship_match_lang_c1_c2': 'Fluent',
  'scholarship_match_exp_none': 'None',
  'scholarship_match_exp_lt12': 'Less than 1 year',
  'scholarship_match_exp_12_24': '1 to 2 years',
  'scholarship_match_exp_24_36': '2 to 3 years',
  'scholarship_match_exp_36_60': '3 to 5 years',
  'scholarship_match_exp_60_plus': '5 years or more',
  'scholarship_match_test_ielts': 'IELTS',
  'scholarship_match_test_toefl_ibt': 'TOEFL iBT',
  'scholarship_match_test_duolingo': 'Duolingo',
  'scholarship_match_test_tcf': 'TCF',
  'scholarship_match_test_tef': 'TEF',
  'followed_title': 'Followed',
  'followed_scholarships_section': 'Followed scholarships',
  'followed_sort_label': 'Sort by',
  'followed_sort_status': 'Status',
  'followed_sort_deadline': 'Deadline',
  'followed_sort_name': 'A–Z',
  'followed_empty_title': 'You\'re not following any scholarship yet',
  'followed_empty_body':
      'Tap "Follow" on a scholarship: we\'ll tell you when it opens and before its deadline.',
  'followed_empty_cta': 'Browse scholarships',
  'followed_removed': 'You unfollowed "@title"',
  'followed_undo': 'Undo',
  'followed_offline': 'Offline — data from @date',
  'followed_detail_unavailable': 'Details unavailable for now',
  'followed_opening_muted': 'Opening alert off',
  'followed_remove_a11y': 'Unfollow @title',
  'notifications_group_today': 'Today',
  'notifications_group_week': 'This week',
  'notifications_group_earlier': 'Earlier',
  'notif_cta_open_scholarship': 'See the scholarship',
  'notif_cta_open_followed': 'See followed scholarships',
  'notif_cta_deadline': 'See the deadline',
  'notif_cta_case': 'Open the case',
  'notif_cta_message': 'Read the message',
  'notif_cta_open': 'Open',
  'followed_scholarship_pref_title': 'Scholarships I follow: opening',
  'followed_scholarship_pref_subtitle':
      'A notification when a scholarship you follow opens. Deadline reminders keep coming.',
  'notifications_push_granted_title': 'Notifications are on',
  'notifications_push_granted_subtitle': 'You get alerts on this phone.',
  'notifications_push_denied_subtitle':
      'Turn them back on in the app settings to get alerts.',
  'notifications_push_settings_action': 'Settings',
  // ── US student visas suspended (owner decision, 17/10/2026) ──────────────
  'us_visa_notice_title': 'Student visa for the United States',
  'us_visa_notice_concerned': 'Your country is affected.',
  'us_visa_notice_body':
      'Student visa applications are currently suspended for nationals of: @countries.',
  'us_visa_notice_check':
      'Check your situation on travel.state.gov, or message us on WhatsApp to talk about it.',
  'us_visa_notice_verified': 'List checked on @date.',
  'us_visa_notice_official_cta': 'See the official page',
  'us_visa_notice_whatsapp_cta': 'Talk about it on WhatsApp',
  'us_visa_whatsapp_prefill':
      'Hello KPB Education, I\'m looking at studying in the United States and I\'d like to know if the student visa suspension affects me.',
  // ── Universities: Partners / All view (owner decision, 17/10/2026) ───────
  'uni_view_switch_label': 'Universities to show',
  'uni_view_partners': 'Partners',
  'uni_view_all': 'All',
  'uni_view_count_semantics': '@label: @count program(s)',
  'uni_partner_notice_title': 'KPB partner universities',
  // Owner's text, translated faithfully (decision of 17/10/2026). See the FR
  // file and honest_labels_guard_test.dart for the named exception.
  'uni_partner_notice_body':
      'This view shows KPB Education\'s partner universities. With them, KPB can speed up your application by up to 70% and can even get you admission guarantees.',
  'uni_partner_notice_caveat': 'Important: this depends on your application.',
  'uni_partner_notice_switch_hint':
      'To see all universities and choose any destination, switch to the “All” tab.',
  'uni_partner_notice_cta': 'See all universities',
  'uni_partner_notice_close': 'Close this message',
  'uni_partner_reminder': 'You\'re only seeing partner universities.',
  'uni_partner_reminder_cta': 'See all',
};
