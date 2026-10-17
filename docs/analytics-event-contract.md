# Firebase Analytics event contract

Single source of truth for **custom event names** and **parameter keys** is [`lib/app/core/observability/analytics_event_contract.dart`](../lib/app/core/observability/analytics_event_contract.dart) (`AnalyticsEventName`, `AnalyticsParamKey`). Implementations must use these constants so GA4 / BigQuery exports stay stable.

> **PostHog mirror:** every event below is also sent to PostHog under the **same
> name and parameter keys** (see `AnalyticsService._mirror` / `_mirrorScreen`),
> so PostHog insights and GA4 stay aligned. PostHog is inert unless
> `POSTHOG_API_KEY` is set (`--dart-define`). Screen views additionally arrive
> via `PosthogObserver`, and taps via autocapture. Setup + privacy: see
> [`docs/posthog-analytics.md`](posthog-analytics.md).

## Conventions

| Rule | Detail |
|------|--------|
| Event names | `snake_case`, prefer ≤ 40 characters (GA4 limit). |
| Parameter keys | `snake_case`; reuse shared keys (`item_id`, `case_id`, …). |
| Booleans in Analytics | Use integers `0` / `1` where GA4 typing is ambiguous (see `success` on sync). |
| Screens | Use [`AnalyticsService.logScreen`](../lib/app/core/services/analytics_service.dart) (`logScreenView`) — screen class names are passed as Firebase expects. |

## Custom events (app-defined)

| Event (`AnalyticsEventName`) | Parameters | Purpose |
|------------------------------|------------|---------|
| `logout` | — | Session end |
| `orientation_start` | — | Quiz started |
| `orientation_complete` | `total_questions`, `match_count` | Quiz finished |
| `save_item` / `unsave_item` | `item_id`, `item_type` | Saved list |
| `compare_institutions` | `count`, `ids` | Compare flow |
| `case_created` | `case_type` | New dossier |
| `case_viewed` | `case_id` | Detail open |
| `document_uploaded` | `case_id` | Upload |
| `case_message_sent` | `case_id` | Messaging |
| `profile_updated` | — | Profile saved |
| `theme_toggled` | `theme` (`dark` / `light`) | Theme switch |

## Conversion & funnel

| Event | Parameters | Purpose |
|-------|------------|---------|
| `whatsapp_handoff` | `source` (call site, e.g. `program_detail`, `scholarship_official_form_failed`), `context_type` (e.g. `program`, `destination`, `case`, `case_documents`, `blocked_build`, `fraud_report`, `community_group`), `success` (0/1) | Lead→advisor-contact hand-off; `success = 0` means WhatsApp could not be opened (lost conversion). `success = 0` is now **trustworthy on Android 11+**: the hand-off attempts the launch instead of asking `canLaunchUrl`, which package visibility could make lie. |
| `referral_invite_shared` | — | Invite shared via WhatsApp (KPB-69) |
| `referral_redeemed` | — | Referral code redeemed by a referee (KPB-69) |
| `referral_code_prompt_viewed` | `surface` (`onboarding`/`referral_screen`), `prefill` (`install_referrer`/`typed`/`none`) | Build 57 (2.3.1) : le champ « code de ton parrain » est montré — étape de fin d'onboarding (drapeau `referralOnboardingCode`), ou écran Parrainage quand un code en attente y est prérempli. Jamais le code saisi ou prérempli : il désigne le parrain. |
| `referral_code_submitted` | `surface`, `prefill`, `result` (`attributed`/`already_referred`/`unknown_code`/`self_referral`/`not_allowed`/`rate_limited`/`offline`/`error`) | « Valider le code » : l'issue FERMÉE de `POST /referrals/redeem`. `referral_redeemed` part toujours en plus sur `attributed`. |
| `referral_code_skipped` | `surface`, `prefill` | « Passer » sur l'étape de fin d'onboarding. `prefill` = `install_referrer` dit combien de codes venus d'un lien d'invitation sont ignorés. |
| `referral_competition_viewed` | `campaign_phase` (`upcoming`/`running`/`ended`/`none`) | L'écran « Compétition ambassadeurs » (drapeau `referralLeaderboard`) est ouvert ; `none` = non-participant. Ni rang, ni compteur, ni nom public. |

## Acquisition, onboarding & auth (KPB-156 / KPB-158)

| Event | Parameters | Purpose |
|-------|------------|---------|
| `guest_mode_entered` | — | Visitor chose "Explore without an account" (KPB-156) |
| `guest_to_signup` | `source` (gate: `cases_gate`, `profile`, `scholarships_gate`, `case_create_gate`, `case_tunnel_gate`, `case_tunnel_profile`) | Guest headed to sign-up from a gated action (KPB-156). Every gate now routes through the shared `KpbGuestGate`, so the `source` breakdown finally shows **which** wall converts — `scholarships_gate` is the middle tab (previously a fake "connection problem" screen that converted nobody) and `case_tunnel_gate` covers all 19 tunnel entries at once. |
| `onboarding_step_viewed` | `step` (1-based), `step_count`, `account_type` | A stepper page became visible (KPB-158) |
| `onboarding_completed` | `account_type` | Finished the last onboarding step (KPB-158) |
| `onboarding_skipped` | `step` (1-based, where skipped) | Left onboarding via Skip (KPB-158) |
| `onboarding_validation_failed` | `step` (1-based), `reason` (`required_fields`/`consent_missing`/`birth_date_missing`/`under_minimum_age`/`guardian_incomplete`/`fields_missing`/`countries_missing`) | « Continuer » refusé sur une page. Avant lui, l'étape 1 était l'écran le plus rage-cliqué de l'app sans qu'on sache pourquoi (octobre 2026). Une seule raison par refus : la PREMIÈRE de la page, de haut en bas — celle vers laquelle la page défile. Jamais une valeur saisie. |
| `auth_failed` | `method` (`google`/`email`), `reason` (`oauth_error`/`rate_limited`/`send_error`/`verify_error`) | A sign-in/up attempt failed (KPB-158) |
| `sign_up` (GA4 built-in) | `method` (`google`/`email`) | New account created — the **signup method** (KPB-158) |
| `login` (GA4 built-in) | `method` (`google`/`email`) | Returning user signed in |

> Auth success is logged once, in `navigateAfterAuth`: a user with no completed
> onboarding is a new `sign_up` (carrying the signup method), otherwise a
> returning `login`. Callers no longer log it directly (avoids double-counting).

### Onboarding funnel (PostHog dashboard to build)

Funnel steps: `sign_up` → `onboarding_step_viewed` (step 1) → … → `onboarding_step_viewed` (step N) → `onboarding_completed`. The drop between consecutive `step` values localizes where onboarding leaks; split by `account_type` to compare student / parent / partner. `onboarding_skipped` (by `step`) shows where users bail via Skip, and `auth_failed` split by `method` shows whether email OTP or Google loses people **before** signup — the evidence that gates the deferred phone-OTP decision (KPB-158 → KPB-172 review).

## Consultation du catalogue (`view_item`)

| Event | Parameters | Purpose |
|-------|------------|---------|
| `view_item` (GA4 built-in) | `item_id`, `item_category` (`scholarship`/`program`/`country`/`institution`) | Une fiche du catalogue ouverte. Jusqu'en octobre 2026, seules les bourses étaient comptées : les fiches programme et pays — les plus ouvertes après l'accueil — n'émettaient rien, et `logViewInstitution` n'avait aucun appelant. La famille est dans `item_category` (clé GA4), **pas** `item_type` (celle de `save_item`). Programme : une fois par ouverture (`LogOnce`), pas à chaque reconstruction. |

## Coach IA (KPB Intelligence)

| Event | Parameters | Purpose |
|-------|------------|---------|
| `ai_coach_message_sent` | `source` (`input`/`suggestion`), `result` (`ok`/`quota_refused`/`error`/`unreachable`), `quota_remaining` (entier, `-1` si inconnu) | Un tour du coach terminé. **Jamais le texte de la question** : il peut contenir un nom, une note, une situation familiale. `source` dit si les suggestions servent ; `result` sépare un refus de quota d'une panne. |
| `ai_coach_load_failed` | — | L'écran n'a pas pu charger quota, suggestions et historique. Sans lui, une panne du coach se lirait comme « personne ne pose de question ». |

## Écran courant des événements natifs (`kpb_screen`)

Les événements captés par le SDK **natif** (`$rageclick`, cycle de vie) ne
voient qu'une vue native, celle de Flutter : leur `$screen_name` vaut
« Flutter » partout. `PosthogScreenContextObserver` enregistre donc la route
Flutter affichée en **super propriété** `kpb_screen` (via
`Posthog().register`, transmis au natif), avec le même nommage que
`$screen_name` des événements `$screen` (`root ('/')` pour `/`). Pour situer
un rage click : filtrer `$rageclick` par `kpb_screen`. Les feuilles et
dialogues ne la changent pas (seules les `PageRoute` comptent).

## Engagement & retention (KPB-162 / KPB-164 / KPB-165 / KPB-169)

| Event | Parameters | Purpose |
|-------|------------|---------|
| `daily_scholarship_viewed` / `daily_scholarship_opened` | `item_id` | Home "Bourse du jour" card CTR (KPB-162) |
| `my_plan_progress` | `percent`, `next_step` | Unified progress whenever it changes (KPB-164) |
| `share_card` | `source`, `with_image` | A result card was shared into a conversation (KPB-165) |
| `parcours_view` | `slug`, `item_type` (`video`/`text`), `source` (`feed`/`library`/`story_of_week`) | A story became the one on screen (KPB-169) |
| `parcours_complete` | same as above | The story was consumed — video ended, or written interview scrolled to the last answer (KPB-169) |
| `story_of_week_viewed` / `story_of_week_opened` | `slug` | Home "Récit de la semaine" card CTR (KPB-169) |
| `push_opened` | `kind` (`scholarship_opened`, `scholarship_opened_bundle`, `deadline_reminder`, … ; `unknown` sinon) | Tap sur une notification push (chantier G) — la part des taps qui arrivent sur la bonne page se lit avec `view_item` |
| `permission_primer_shown` | — | La feuille d'explication du premier « Suivre » s'est affichée (chantier G) |
| `permission_primer_granted` | `result` (`granted` / `denied` / `dismissed`) | Issue de cette feuille : opt-in push des élèves qui suivent une bourse |

### Parcours completion rate (KPB-169)

`parcours_complete ÷ parcours_view`, split by `source`, is the completion rate the
feed is judged on — a view count alone says nothing about whether a story lands.
Split by `item_type` too: a video that stalls at 20 % and an interview read to the
end are different problems. A drop in `feed` completion while `library` holds
steady points at the feed itself, not at the content.

## Test « Mes 10 bourses » (chantier H)

Derrière `features.scholarshipMatch` (fermé par défaut). Constantes :
`AnalyticsEventName.scholarshipMatch*` ; méthodes : `AnalyticsService.logScholarshipMatch*`.
Les propriétés passent par une LISTE FERMÉE (`AnalyticsService.scholarshipMatchAllowedParams`) :
toute autre clé est retirée avant l'envoi. **Jamais** la nationalité, l'âge, la date de
naissance, la moyenne ni le niveau de langue — ni ici, ni dans le push (l'enregistrement
d'appareil ne porte que le jeton et la plateforme). Booléens envoyés en `0`/`1`.

| Event | Parameters | Purpose |
|-------|------------|---------|
| `scholarship_match_entry_viewed` | `source` (`scholarships_tab`, `home`, `scholarship_detail`) | La carte d'entrée a été vue (une fois par source et par lancement) |
| `scholarship_match_started` | `source`, `missing_count` (questions posées), `is_rerun` | L'assistant démarre (pas à la reprise d'un brouillon) |
| `scholarship_match_step_viewed` | `match_step`, `index`, `total` | Une question (ou l'accueil / le récapitulatif) s'affiche |
| `scholarship_match_step_completed` | `match_step`, `changed_prefill` | « Continuer » sur une question ; `changed_prefill` = l'élève a changé la suggestion (sans la valeur) |
| `scholarship_match_abandoned` | `last_step` | L'assistant est quitté sans run (le brouillon reste) |
| `scholarship_match_completed` | `eligible_count`, `to_verify_count`, `excluded_count`, `duration_s`, `algorithm_version`, `is_rerun` | Run calculé depuis l'assistant |
| `scholarship_match_failed` | `reason` (`offline`, `timeout`, `rate_limited`, `unauthorized`, `forbidden`, `disabled`, `server`, `invalid`, `profile_incomplete`) | Échec d'un run — sans lui, une panne se lirait comme un abandon |
| `scholarship_match_result_opened` | `item_id`, `rank`, `status` (`eligible`/`to_verify`) | Une bourse du run ouverte (écran des résultats ou cartes « Tes bourses » de l'accueil) |
| `scholarship_match_follow` | `item_id`, `rank`, `bulk` | « Suivre » sur un résultat, ou « Suivre les N compatibles » (`bulk` = 1, un événement par bourse) |
| `scholarship_match_case_started` | `item_id`, `rank`, `reused_existing` | « Être accompagné » : dossier existant rouvert (1) ou compositeur ouvert (0) |
| `scholarship_match_broaden_tapped` | `suggestion` (`edit_answers`, `advisor`) | « Comment en voir plus » (moins de 10 résultats) |
| `scholarship_match_rerun` | `reason` (`stale`, `manual`) | Run périmé relancé à l'ouverture des résultats, ou « Mettre à jour » |
| `scholarship_match_alerts_toggled` | `enabled` | Opt-in explicite au push hebdomadaire « nouvelles bourses compatibles » (PUT confirmé), depuis les résultats ou les réglages de notification |

`match_step` et `last_step` sont des identifiants fermés (`intro`, `nationality`,
`birth_date`, `guardian`, `diploma`, `target_level`, `fields`, `grade`, `language`,
`work_experience`, `recap`, `residence`) — `match_step` et non `step`, qui est un entier
pour l'onboarding. Réutilisés : `guest_to_signup` (`source` = `scholarship_match_gate`, ou
`home_hero_scholarship_match` pour « Trouve tes bourses (2 min) » du héros invité) et
`whatsapp_handoff` (`source` = `scholarship_match_card`, `scholarship_match_results`,
`scholarship_match_broaden`, `scholarship_match_report` ; `context_type` = `scholarship_match`).

## Espace « Études en France » (Phase 0 — vitrine)

| Event | Parameters | Purpose |
|-------|------------|---------|
| `eef_teaser_viewed` | `source` (`home_card`/`tools_drawer`/`student_tools`/`deep_link`/`direct`) | Portée de la vitrine, et par quelle porte |
| `eef_interest_declared` | `wants_premium`, `field_count`, `current_level` | LA question posée par la vitrine : y a-t-il une demande, et pour le payant ? |
| `eef_interest_failed` | `reason` (`network`/`unauthorized`/`server`) | Un envoi qui échoue |
| `eef_space_viewed` | `source` (`home_card`/`tools_drawer`/`student_tools`/`deep_link`/`direct`) | L'espace réel (hub) vu, et par quelle porte (build 54) |
| `eef_hub_tile_opened` | `tile` (`catalogue`/`cv`/`lettres`/`entretien`/`profil`) | Ce que les étudiants viennent FAIRE dans l'espace. La tuile `conseiller` n'existe plus : la carte d'aide l'a remplacée (voir `eef_help_cta_tapped`, `help_step` = `hub`) |
| `eef_catalog_viewed` | `source` (`hub` quand l'étudiant vient du hub, `deep_link` sinon — lien profond ou notification) | Le catalogue ouvert, et par quelle porte |
| `eef_catalog_searched` | `has_query` (`1`/`0`), `filter_count`, `result_count`, `catalog_published` (`1`/`0`) | Une recherche aboutie. **Jamais le texte tapé** : une requête libre peut contenir un nom, une ville, un établissement |
| `eef_catalog_failed` | `reason` (`network`/`server`) | Le catalogue n'a pas pu répondre |
| `eef_help_card_shown` | `help_step` (`hub`/`procedure`/`documents`/`catalog_results`/`catalog_procedure`/`catalog_empty`/`catalog_unpublished`, et depuis la build 55 `catalog_filters`/`tool_cv`/`tool_letters`/`tool_interview`, et depuis la build 56 `bubble` et `private_note`), `surface` (`hub`/`catalog`, et depuis la build 55 `tools`), `variant` (`card`/`compact`, et depuis la build 56 `bubble` et `note`) | Une carte d'aide (« c'est flou ? tu veux de l'aide ? ») a été montée : la portée de CHAQUE emplacement |
| `eef_help_cta_tapped` | mêmes trois propriétés (et, depuis la build 55, `help_step` = `catalog_program` aussi ; depuis la build 56, `bubble_assistance`/`bubble_dossier`/`bubble_choose`/`bubble_question` et `private_sheet`, avec `variant` = `bubble` ou `sheet`) | Le bouton ou le lien de la carte d'aide a été tapé — part AVANT l'ouverture de WhatsApp |
| `eef_bubble_opened` | `surface` (`hub`/`catalog`) | Le menu de sujets de la bulle verte WhatsApp a été ouvert (build 56). Ce n'est PAS un envoi : voir « La bulle d'aide de la build 56 » |
| `eef_private_info_opened` | `entry` (`bubble`/`catalog_empty`) | La feuille d'information « Service KPB » des écoles privées a été ouverte (build 56). Ce n'est PAS un envoi : voir « Les écoles privées de la build 56 » |
| `eef_tour_shown` | `tour_trigger` (`first_open`/`replay`) | La visite guidée du hub s'est affichée (build 56) : voir « La visite guidée de la build 56 » |
| `eef_tour_completed` | `tour_exit` (`finished`/`skipped`), `tour_cards_seen` (entier) | La visite guidée s'est fermée (build 56) : voir « La visite guidée de la build 56 » |

### Lire la carte d'aide sans se tromper (build 54)

- **Le taux de clic d'un emplacement** est `eef_help_cta_tapped ÷ eef_help_card_shown`,
  par `help_step`. C'est la seule façon de savoir où l'incitation marche et où elle
  n'est que du bruit.
- **`eef_help_card_shown` part une fois par étape et par visite de l'écran** (la mémoire
  vit dans le `PageStorage` de la route) : défiler la liste de haut en bas ne compte
  pas dix vues. Une liste paresseuse monte la carte un peu avant qu'elle soit visible :
  c'est une borne haute de la portée, pas un compte d'yeux.
- **Une carte invisible n'est pas « vue »** : pour un pays suspendu, les formes
  compactes (`procedure`, `documents`, `catalog_procedure`) disparaissent et ne
  partent pas ; seule une carte pleine (au libellé neutre « autres options ») reste.
  La build 55 y ajoute des déclencheurs qui, eux, RESTENT visibles pour ces comptes
  (voir la section suivante).
  On ne mesure volontairement PAS le pays, ni un drapeau « suspendu » qui le
  désignerait presque : l'écart de clic entre pays se lirait sinon sur une donnée
  personnelle.
- **Le tap est distinct de la conversion** : `whatsapp_handoff` (`source` =
  `eef_help_<help_step>`, `context_type` = `eef_help`, `success` 0/1) dit ensuite si
  WhatsApp s'est ouvert. `tapped` sans `handoff` réussi = un téléphone qui n'ouvre pas
  WhatsApp, pas un étudiant qui hésite.
- **Aucune donnée personnelle** : trois identifiants fermés écrits dans le code. Le
  test `analytics_event_contract_test.dart` rougit si une propriété est ajoutée.

### Les déclencheurs d'aide de la build 55 (`EefHelpLine`)

Cinq valeurs de `help_step` s'ajoutent, **sans nouvelle propriété** : `help_step`,
`surface` et `variant` restent les trois seules clés (le test
`analytics_event_contract_test.dart` rougit si une quatrième apparaît).

| `help_step` | `surface` | `variant` | Où | `eef_help_card_shown` | `eef_help_cta_tapped` |
|---|---|---|---|---|---|
| `catalog_program` | `catalog` | `compact` | Le bouton « Demander de l'aide » sous **chaque** formation du catalogue | **jamais** (une par carte affichée serait du bruit) | oui |
| `catalog_filters` | `catalog` | `compact` | La ligne « Tu hésites entre ces formations ? » sous les filtres actifs (dès qu'un filtre est posé, et seulement si la ligne de procédure n'est pas affichée) | une fois par visite du catalogue | oui |
| `tool_cv` | `tools` | `compact` | La ligne « Besoin d'aide pour rédiger ton CV ? » de l'écran CV, **ouvert depuis le hub** | une fois par visite de l'écran | oui |
| `tool_letters` | `tools` | `compact` | Idem, écran des lettres de motivation | idem | oui |
| `tool_interview` | `tools` | `compact` | Idem, écran de l'entretien (choix du type d'entretien) | idem | oui |

`surface` = **`tools`** est nouveau : les écrans d'outils ne sont ni le hub ni le
catalogue. Ils n'émettent rien quand ils sont ouverts ailleurs (boîte à outils,
tiroir « Outils KPB », dossier d'un étudiant, coach).

- **Le taux de clic de `catalog_program` ne se lit PAS comme les autres.** Il n'a pas
  de dénominateur `eef_help_card_shown` : on le lit contre `eef_catalog_searched`
  (une recherche affiche des formations) ou, mieux, en **nombre de taps par visite**
  du catalogue. Les autres valeurs gardent `tapped ÷ shown`.
- **Ce qui n'est JAMAIS mesuré** : l'intitulé d'une formation, l'université, la ville,
  un libellé de filtre, l'outil autrement que par sa valeur de `help_step`. Le
  message WhatsApp les porte, l'analytique non : la seule porte (`EefHelpAnalytics`)
  n'accepte que trois identifiants fermés. `catalog_filters` ne dit donc pas QUELS
  filtres : seul `filter_count` d'`eef_catalog_searched` les compte.
- **Un compte dont le pays est suspendu VOIT ces cinq déclencheurs** (décision du
  03/10/2026), au libellé et au message neutres, et ils sont mesurés comme les
  autres : on ne mesure toujours ni le pays ni un drapeau « suspendu ». C'est
  l'inverse de la build 54, où les formes compactes disparaissaient pour ces
  comptes (voir ci-dessus).
- **`whatsapp_handoff`** : `source` = `eef_help_<help_step>` (par exemple
  `eef_help_catalog_program`), `context_type` = `eef_help`, `success` 0/1.
- **Une seule ligne d'aide à la fois sous les filtres** : `catalog_procedure` (build 54)
  a la priorité sur `catalog_filters` — pour une ligne qu'on VOIT : la ligne de
  procédure est invisible (donc non mesurée) pour un pays suspendu. Deux lignes ne
  sont donc jamais affichées ensemble ; mais l'étudiant qui change de filtres dans la
  même visite peut les produire l'une après l'autre.

### La bulle d'aide de la build 56 (`EefHelpBubble`)

Une pastille verte ronde dans le **hub** et le **catalogue** (jamais la vitrine, les
écrans d'outils, l'écran des comptes parent/partenaire, ni la coque de l'app). Elle ouvre
un menu de sujets ; chaque sujet ouvre WhatsApp avec un message déjà écrit. Elle
n'existe que si le serveur a ouvert l'espace (`eefSpace`) **et** la bulle
(`features.eefHelpBubble`, fermée par défaut).

La mesure **réutilise** les deux événements de la carte d'aide, avec **exactement** leurs
trois propriétés (`help_step`, `surface`, `variant` — le test
`analytics_event_contract_test.dart` rougit si une quatrième apparaît), et n'ajoute
qu'**un** événement.

| Événement | `help_step` | `surface` | `variant` | Quand |
|---|---|---|---|---|
| `eef_help_card_shown` | `bubble` | `hub` / `catalog` | `bubble` | La bulle est montée — **une fois par visite de l'écran** (même mémoire que les autres emplacements) |
| `eef_bubble_opened` | — (seule propriété : `surface`) | `hub` / `catalog` | — | Le menu est ouvert |
| `eef_help_cta_tapped` | `bubble_assistance` / `bubble_dossier` / `bubble_choose` / `bubble_question` | `hub` / `catalog` | `bubble` | Un sujet est choisi — **uniquement** ce qui part vers WhatsApp ; part AVANT l'ouverture, et APRÈS la fermeture de la feuille |

- **Fermer la feuille sans choisir ne mesure aucun `eef_help_cta_tapped`** : seul
  `eef_bubble_opened` est parti. C'est pourquoi l'ouverture a son propre événement : l'y
  mêler gonflerait `eef_help_cta_tapped`, qui dit toujours « un message part ».
- **`whatsapp_handoff`** : `source` = `eef_help_bubble_<sujet>` (`eef_help_bubble_assistance`,
  `eef_help_bubble_dossier`, `eef_help_bubble_choose`, `eef_help_bubble_question` — la même
  règle que `eef_help_<help_step>`), `context_type` = `eef_help`, `success` 0/1.
- **L'entonnoir** se lit : bulle vue (`eef_help_card_shown`, `help_step` = `bubble`) → menu
  ouvert (`eef_bubble_opened`) → sujet choisi (`eef_help_cta_tapped`) → envoi
  (`whatsapp_handoff`). Taux d'ouverture : `eef_bubble_opened ÷ eef_help_card_shown`.
- **Un compte dont le pays est suspendu garde la bulle**, avec un menu à deux lignes
  neutres (`bubble_assistance`, `bubble_question`). Les identifiants sont **les mêmes** que
  pour le menu standard : on ne mesure ni le pays ni un identifiant qui le désignerait. Un
  compte suspendu ne produit jamais `bubble_dossier` ni `bubble_choose`.
- **Ce qui n'est JAMAIS mesuré** : le texte du message, l'écran en toutes lettres, le pays.
  Le message ne porte lui non plus aucune donnée personnelle (il nomme seulement l'écran).
- **`whatsapp_handoff` `success = 1` SURÉVALUE les conversations** : le lancement est
  tenté sans demander à l'avance si WhatsApp est installé (cette question ment sur Android
  11 et plus), donc sans WhatsApp le lien s'ouvre dans le navigateur. Le tri se lit aussi
  côté équipe, par des étiquettes WhatsApp Business posées sur la première phrase de chaque
  sujet.
- **Cannibalisation** : la bulle ne doit pas seulement déplacer les cartes d'aide. Lire le
  total des `whatsapp_handoff` de `source` `eef_help_*` par session de hub, avant et après
  son ouverture : si le total n'augmente pas alors que les cartes d'aide baissent, elle
  déplace sans créer.

### Les écoles privées de la build 56 (`EefPrivateSchoolsNote`, `showEefPrivateSchoolsSheet`)

Trois endroits, un seul texte à faire relire : une **feuille d'information** « Les écoles
privées : ce qu'il faut savoir » (pastille « Service KPB »), une **ligne secondaire** dans
l'état « aucun résultat » du catalogue (jamais « rien n'est publié », jamais le hub), et une
**option** dans le menu de la bulle (4e sujet). Rien n'existe tant que le serveur n'a pas
ouvert `features.eefPrivateSchools` (fermé par défaut), et rien n'existe pour un compte dont
le pays est suspendu (ni ligne, ni option, ni feuille). La feuille ne s'ouvre jamais seule.

La mesure **réutilise** les deux événements de la carte d'aide, avec **exactement** leurs
trois propriétés, et n'ajoute qu'**un** événement — l'ouverture de la feuille, qui n'est pas
un envoi vers WhatsApp.

| Événement | `help_step` / propriété | `surface` | `variant` | Quand |
|---|---|---|---|---|
| `eef_help_card_shown` | `private_note` | `catalog` | `note` | La ligne du catalogue vide est montée — **une fois par visite de l'écran** (même mémoire que les autres emplacements ; une borne haute de la portée, la liste étant paresseuse) |
| `eef_private_info_opened` | — (seule propriété : `entry` = `bubble` / `catalog_empty`) | — | — | La feuille est ouverte : par l'option de la bulle (`bubble`) ou par le lien de la ligne (`catalog_empty`) |
| `eef_help_cta_tapped` | `private_sheet` | `hub` / `catalog` (l'écran qui porte la bulle ou le catalogue) | `sheet` | « En parler à un conseiller » — **uniquement** ce qui part vers WhatsApp ; part APRÈS la fermeture de la feuille et AVANT l'ouverture de WhatsApp |

- **Choisir l'option « écoles privées » dans le menu de la bulle ne mesure aucun
  `eef_help_cta_tapped`** : `bubble_private` n'est jamais un `help_step`. Lire n'est pas
  écrire ; seul `eef_private_info_opened` (`entry` = `bubble`) part, après `eef_bubble_opened`.
- **« Pas maintenant »** et la fermeture par le voile ne mesurent rien d'autre que
  l'ouverture déjà comptée, et n'ouvrent pas WhatsApp.
- **`whatsapp_handoff`** : `source` = `eef_help_private_sheet`, `context_type` = `eef_help`,
  `success` 0/1. WhatsApp **seul** : aucun lien vers l'écran de dossier d'admission privé.
- **Lecture** : l'option des écoles privées se juge sur `private_sheet` ÷
  `eef_private_info_opened`, et la ligne du catalogue sur `eef_private_info_opened`
  (`entry` = `catalog_empty`) ÷ `eef_help_card_shown` (`help_step` = `private_note`) — pas
  contre la carte d'aide du catalogue vide, dont le bouton plein n'est pas comparable à un
  lien.
- **Ce qui n'est JAMAIS mesuré** : le texte du message, le pays, la raison pour laquelle un
  compte n'a pas la ligne (un compte suspendu ne produit ni `private_note` ni
  `eef_private_info_opened`).

### La visite guidée de la build 56 (`EefTour`)

Trois ou quatre cartes dans une feuille, montrées **une fois** à la première ouverture du
**hub réel** (jamais la vitrine, jamais l'écran des comptes parent/partenaire, jamais
au-dessus d'un dialogue ou d'une autre feuille), invités compris, et **rejouables** par le
bouton « ? » de la barre du hub. Le drapeau « vue » (`kpb_relaunch_v1.eef_tour_v1`, local à
l'appareil) est posé à l'**affichage** ; une panne de lecture ou d'écriture du stockage vaut
« déjà vue » (pas de visite, aucun événement). La visite ne dépend d'aucun interrupteur
serveur : elle s'allume avec le hub.

Deux événements neufs, **propriétés fermées**, aucune donnée personnelle :

| Événement | Propriété | Valeurs | Quand |
|---|---|---|---|
| `eef_tour_shown` | `tour_trigger` | `first_open` / `replay` | La feuille s'affiche — à la première ouverture du hub, ou par le « ? » |
| `eef_tour_completed` | `tour_exit` | `finished` / `skipped` | « Compris » à la dernière carte (`finished`) ; « Passer », le retour Android, le voile ou un glissement vers le bas (`skipped`) |
| `eef_tour_completed` | `tour_cards_seen` | entier (1 à 4) | Le nombre de cartes **atteintes** (la plus haute carte vue, pas le nombre de pages tournées) |

- **Lire la portée** : `eef_tour_shown` (`first_open`). **Lire l'adhésion** :
  `eef_tour_completed` (`finished`) ÷ `eef_tour_shown`. **Lire l'usage du « ? »** :
  `eef_tour_shown` (`replay`) — un rejeu ne touche pas au drapeau.
- **`tour_cards_seen` est relatif au nombre de cartes de CE téléphone** : 3 cartes quand les
  outils IA sont masqués ou que la bulle est éteinte, 4 sinon, 2 si les deux. Une visite
  `finished` a donc `tour_cards_seen` = 2, 3 ou 4. Le nombre total n'est pas une propriété.
- **Ce qui n'est JAMAIS mesuré** : le pays, la variante de la première carte (neutre pour
  un pays suspendu : le texte seul change, jamais un identifiant), la langue, l'appareil. Un
  compte suspendu produit **exactement** les mêmes événements et les mêmes valeurs.
- **Pas de mesure sans affichage** : une visite qui ne s'ouvre pas (déjà vue, stockage en
  panne, dialogue ouvert) n'émet rien, pas même `eef_tour_completed`.
- **Pas de consentement dédié** : la visite ne lit ni n'écrit rien d'autre qu'un drapeau
  local non personnel ; ses deux événements suivent le régime de la mesure d'usage (coupée
  par l'opt-out analytique, comme tous les autres).

### Lire le catalogue sans se tromper (build 54)

- **`eef_catalog_failed` existe pour la même raison que `eef_interest_failed`** :
  une panne du catalogue le jour du lancement se lit, sans lui, exactement comme
  « personne ne cherche ».
- **`result_count = 0` n'est pas une panne** : c'est une recherche qui n'a rien
  trouvé. Croiser avec `catalog_published` : `0` ⇒ rien n'est publié (ce n'est pas
  un défaut de recherche), `1` ⇒ la recherche était trop étroite.
- **Une recherche par requête, pas par page** : `eef_catalog_searched` ne part
  pas au défilement.
- **`filter_count` compte les VALEURS choisies de toutes les familles** — niveau,
  domaine, ville et procédure : un niveau, deux villes et un domaine font `4`.
  Les filtres se posent par feuille (« Voir N formations ») : cocher dix cases puis
  valider est UNE recherche, donc UN événement, avec `filter_count = 10`. Ni le nom
  d'une ville, ni un identifiant de domaine, ni un libellé de filtre ne part
  jamais : une ville est une donnée de profil, au même titre que le texte tapé
  (le test `eef_catalog_controller_test.dart` lit les sources pour le garantir).
  L'ouverture d'une feuille, la recherche locale d'une ville et l'échec du
  chargement des villes ne produisent AUCUN événement — en particulier pas
  `eef_catalog_failed`, qui dit « le catalogue n'a pas pu répondre ».
- **Les booléens partent en `1`/`0`**, pas en `true`/`false`
  (`FirebaseAnalytics.logEvent` n'accepte que `String` ou `num`).

### Pourquoi `eef_interest_failed` existe

Sans lui, un backend en panne le jour du lancement produit exactement la même
courbe que « personne n'est intéressé » — et c'est la conclusion **inverse** de
la vérité qu'on tirerait du tableau de bord. Le taux à surveiller est donc
`eef_interest_failed ÷ (eef_interest_declared + eef_interest_failed)` : au-delà
de quelques pourcents, ce n'est pas le produit qui déçoit, c'est la chaîne
d'envoi qui casse.

`field_count` et non la liste des filières : un compte suffit à segmenter, et
n'expose pas le détail du profil d'un mineur dans une charge analytique.

### Entonnoir de la Phase 0

`eef_teaser_viewed` → `eef_interest_declared`, segmenté par `source`, dit
quelle porte convertit. La part de `wants_premium = true` parmi les
déclarations est le signal qui décide du modèle payant — c'est la seule mesure
directe de la demande pour le Premium dont l'app dispose aujourd'hui, faute de
tout produit payant existant.

> **`field_count` vaut 0 jusqu'à la build 53, puis varie.** Les builds 49 à 53 n'ont
> aucun sélecteur de domaine : le champ existe dans le DTO, en base et dans le
> CSV, mais ces écrans ne l'envoient jamais. La build 54 ajoute le sélecteur
> (domaines d01–d12, préremplis depuis le profil) : à partir d'elle seulement,
> `field_count` segmente. Ne pas comparer la distribution avant/après sans
> filtrer sur la version de l'app (la dimension de version de l'application que Firebase Analytics et PostHog renseignent d'eux-mêmes ; `X-KPB-App-Version` n'étiquette aucun événement côté serveur : il ne sert qu'à la répartition des builds, `GET /admin/app-builds`). Écrit ici parce que c'est
> le document qu'on ouvre pour interpréter l'entonnoir, et qu'un zéro constant
> se lit autrement comme « personne ne choisit de filière ».
>
> **`wants_premium` part en `1`/`0`, pas en booléen.**
> `FirebaseAnalytics.logEvent` assert `value is String || value is num` : le
> booléen brut faisait lever en debug, l'exception était attrapée, et c'est
> l'événement ENTIER qui disparaissait — celui-là même dont ce document dit
> qu'il décide du modèle payant.
>
> **Une « modification » réussie réémet `eef_interest_declared`.** Le ratio
> `wants_premium` calculé sur les ÉVÉNEMENTS est donc biaisé par les étudiants
> qui cochent Premium dans un second temps. Compter sur les utilisateurs
> distincts, ou lire le compteur du back-office, qui compte des lignes.

## Communauté d'entraide (C1 + C2)

Drapeau distant `features.community` (fermé par défaut). Propriétés FERMÉES :
types, compteurs, drapeaux `1`/`0`, identifiants d'écran. **Jamais** le texte
d'une publication, d'une réponse ou d'une recherche, ni un nom, un pays ou un
identifiant de membre : `AnalyticsService.communityParams` retire toute autre
clé avant l'envoi (test `community_logic_test.dart`).

| Event | Parameters | Purpose |
|-------|------------|---------|
| `community_viewed` | `source` (`home_card`, `profile`, `deep_link`…) | L'accueil de la communauté s'ouvre — quelle porte amène du monde |
| `community_feed_viewed` | `tab` (`for_you`/`recent`/`unanswered`), `post_type`, `has_hashtag` | Un fil est chargé (une fois par onglet et par jeu de filtres) |
| `community_searched` | `result_count`, `is_hashtag` | Une recherche (première page) — sans le texte tapé |
| `community_post_opened` | `source`, `post_type`, `has_verified` | Une discussion ouverte |
| `community_composer_opened` | `source`, `has_prefill` | Le compositeur s'ouvre (après la charte) ; `has_prefill` = depuis une fiche |
| `community_post_created` | `post_type`, `mention_count`, `hashtag_count`, `pending_review`, `is_edit` | Publication créée ou modifiée ; `pending_review` = mise en attente par le filtre anti-arnaque |
| `community_post_failed` | `reason` (`CommunityFailure`), `target` (`post`/`reply`) | Échec d'une écriture — sans lui, une panne se lirait comme un abandon |
| `community_reply_created` | `pending_review`, `mention_count` | Réponse publiée |
| `community_helpful_toggled` | `target`, `enabled` | « Utile » posé ou retiré |
| `community_follow_toggled` | `enabled` | Suivre / ne plus suivre une discussion |
| `community_report_sent` | `target` (`post`/`reply`/`member`), `reason` | Signalement envoyé (motif du contrat) |
| `community_block_toggled` | `enabled` | Bloquer / débloquer un membre |
| `community_charter_accepted` | — | Charte acceptée (version courante) |
| `community_entity_section_viewed` | `entity_type`, `discussion_count` | Section « Discussions (N) » vue sur une fiche |

## Sync & reliability (observability)

| Event | Parameters | Purpose |
|-------|------------|---------|
| `sync_full_complete` | `success` (0/1), `elapsed_ms`, `catalog_hive_fallback_count` ; en échec seulement : `failure_stage` (`account` = profil/dossiers/favoris, `catalog` = catalogue ni serveur ni cache), `error_kind` (`timeout`/`connection`/`rate_limited`/`unauthorized`/`http_4xx`/`http_5xx`/`other`) | Full sync outcome. Depuis octobre 2026, un échec dit où et pourquoi (valeurs fermées, jamais un message brut). Les appels du compte (profil, dossiers, favoris) réessaient désormais 3 fois les pannes passagères (délai, coupure, 5xx), comme le catalogue ; jamais un 4xx. |
| `sync_conflict_resolved` | `domain`, `resolution` | Merge / skip logic (profile, cases, saved_items) |
| `sync_catalog_hive_fallback` | `resource`, `attempts` | Catalog API exhausted retries; Hive used |

## Recommended GA4 / BigQuery checks

- **Hand-off failure rate:** Count `whatsapp_handoff` where `success = 0` / all `whatsapp_handoff` — spikes mean users can't reach the advisor (device without WhatsApp, broken link).
- **Hand-off mix:** Breakdown of `whatsapp_handoff` by `source` × `context_type` to see which screens actually convert.
- **Sync failure rate:** Count `sync_full_complete` where `success = 0` / all `sync_full_complete`.
- **Slow sync:** Distribution of `elapsed_ms` on successful runs.
- **Offline catalog pressure:** Sum `catalog_hive_fallback_count` or count `sync_catalog_hive_fallback`.

See also [`observability-dashboards.md`](observability-dashboards.md).
