# Fiches boutique — texte prêt à coller (build 49)

> **⚠️ Ce fichier date de la build 49. Pour la 55 (`2.3.0`), lire d'abord
> [`release-55-store-pack.md`](release-55-store-pack.md)** — notes de version,
> addendum « Notes for Review » (activation à distance de l'espace, non-affiliation),
> phrases de la fiche Google Play (source officielle + « ne représente aucune
> entité gouvernementale »). **Le §3 ci-dessous est PÉRIMÉ sur un point :** CV,
> lettres de motivation, simulateur d'entretien et relecture IA sont **actifs depuis
> la 52** (`aiToolsEnabled` vaut `true` par défaut ; surfaces d'IA générative : 6 —
> `CONSOLE_ANSWERS.md` §0ter). Les autres interdits du §3 restent vrais. Les
> citations `fichier:ligne` de ce fichier ne sont pas revérifiées pour la 55.

> **Périmètre.** Textes des fiches Google Play (`com.karatou.android`) et App Store
> (`Karatou.karatou`, id `1128659292`) pour l'app **déjà publiée** qui se renomme
> **KPB Education**. Cible : lycéens, étudiants et parents d'Afrique de l'Ouest et
> du Centre francophone.
>
> **Règle appliquée à chaque phrase de ce fichier.** Toute fonctionnalité vantée
> ci-dessous est prouvée atteignable dans la build 49 (`pubspec.yaml:22` —
> `version: 2.1.0+49`) par une citation `fichier:ligne`. Ce qui est masqué par un
> drapeau compilé est listé §3 et **interdit** dans les fiches. Ce que le dépôt ne
> peut pas prouver est marqué INCONNU (§10) et **ne doit pas** être écrit.
>
> **Ne pas coller les sections 1 à 4 ni 8 à 10** : seules les sections 5 (FR), 6
> (EN) et 7 (revue Apple / champs Play) sont du texte de fiche.

---

## 1. Contrainte de langue — à lire avant de traduire quoi que ce soit

**La build 49 ne livre que le français.** Le sélecteur FR|EN existe encore dans le
code mais n'est plus monté, et toute préférence persistée est ramenée à `fr`.

- `lib/app/core/i18n/app_locale.dart:8` — `const kShippedLocale = 'fr';`
- `lib/app/core/i18n/app_locale.dart:13` — `const kLanguageSwitchVisible = false;`
- `lib/app/core/i18n/app_locale.dart:16` — `String canonicalAppLocale(String? raw) => kShippedLocale;`
- Sites de masquage : `lib/app/features/profile/profile_screen.dart:772` et
  `lib/app/features/onboarding/onboarding_screen.dart:1079` (`if (kLanguageSwitchVisible)`)

**Conséquence obligatoire :** la fiche anglaise (§6) est une fiche de *vitrine*,
pas la promesse d'une interface anglaise. Elle contient donc la phrase
« The app interface is in French. » Ne pas la retirer.
Le français doit rester la **langue par défaut** de la fiche dans les deux
consoles (`lib/main.dart:238` — `fallbackLocale: const Locale('fr')`).

---

## 2. Ce que la build 49 livre réellement (base de preuve des fiches)

| Élément de fiche | Preuve |
|---|---|
| Nom affiché « KPB Education » | `android/app/src/main/AndroidManifest.xml:9` (`android:label="KPB Education"`) ; `ios/Runner/Info.plist:9-10` (`CFBundleDisplayName` / `KPB Education`) |
| 5 onglets : Accueil, Bourses, Universités, Dossiers, Profil | `lib/app/features/shell/app_shell.dart:63-70` (pages) et `:192-229` (libellés `nav_home`, `nav_universities`, `nav_scholarships`, `nav_cases`, `nav_profile`) |
| 10 destinations au catalogue | `lib/app/core/utils/country_utils.dart:47-58` (`kMvpCountryIds`) ; noms FR : `lib/app/core/data/mock_catalog/countries_data.dart:47,101,116,212,267,321,377,432,487,542` |
| Filtres programmes : pays, domaine, niveau, budget annuel | `lib/app/core/services/program_filter_service.dart:10-22` (`countryId`, `budgetMaxEur`, `levelKey`, `fieldId`) ; application `lib/app/features/universities/universities_screen.dart:165-167` |
| Comparaison de deux établissements | `lib/app/features/universities/universities_screen.dart:151-158` (`InstitutionCompareScreen`), aucun `AppConfig.` dans le fichier |
| Date de dernière vérification sur les fiches pays / programmes | `lib/app/core/ui/components/verified_badge.dart:52` (`'verified_on'`) ; usages `lib/app/features/explore/country_detail_screen.dart:151` et `lib/app/features/explore/program_detail_screen.dart:169` |
| Bourses : financement, niveau, date limite, compte à rebours | `lib/app/features/scholarships/live_scholarships_screen.dart:121-149` (`_DeadlineBadge`), `:653-665` ; libellés `lib/app/core/translations/app_translations.dart:1080-1086,1108-1111` |
| Bourses : filtre par type de financement (3 chips) | `lib/app/features/scholarships/live_scholarships_screen.dart:359-376` |
| Bourses : lien vers le site / formulaire officiel | `lib/app/core/translations/app_translations.dart:1087,1105-1107` |
| Bourses : « Suivre » une bourse (favori + alerte d'ouverture + rappels, + push) | `lib/app/features/scholarships/widgets/follow_scholarship_button.dart` (`FollowScholarshipButton`) ; demande d'autorisation au premier suivi `lib/app/features/scholarships/widgets/follow_push_primer.dart` |
| Bourses : compte requis (mur invité) | `lib/app/features/scholarships/live_scholarships_screen.dart:416` (`KpbGuestGate`) ; copie `lib/app/core/translations/app_translations.dart:47-50` |
| Exploration sans compte | `lib/app/features/auth/auth_welcome_screen.dart:249` (`'auth_explore_guest'`) ; libellé `lib/app/core/translations/app_translations.dart:2025` |
| Dossiers : statuts + fil de messages avec le conseiller | `lib/app/features/cases/cases_screen.dart:569-625` (`_statusPill`) ; `lib/app/features/cases/case_detail_screen.dart:656-682` (champ + `addCaseMessage`) |
| Dictée vocale à l'étape « message » | `lib/app/features/cases/case_tunnel_flow.dart:763,844` ; `:357-358` (étape non gardée) |
| Scanner de documents 100 % local (PDF) | `lib/app/features/tools/document_scanner_screen.dart:50,56-72` (aucun `AppApiClient`) ; entrée `lib/app/features/shell/kpb_tools_drawer.dart:188-195` |
| Calculateur de budget (local, sans collecte) | `lib/app/features/budget/budget_calculator_screen.dart:44-46` ; entrées `lib/app/features/shell/kpb_tools_drawer.dart:204-208`, `lib/app/features/profile/profile_screen.dart:1257-1261` |
| Simulateur d'éligibilité + export PDF | `lib/app/features/eligibility/eligibility_simulator_screen.dart:27,65` ; `lib/app/features/eligibility/eligibility_pdf.dart:157` ; entrée `lib/app/features/profile/profile_screen.dart:1244` |
| Parcours : témoignages vidéo **et** interviews écrites | `lib/app/core/models/parcours.dart:3-5` (`enum ParcoursKind { video, text }`) ; entrées `lib/app/features/home/home_screen.dart:2462`, `lib/app/features/profile/profile_screen.dart:1249` |
| Favoris + calendrier d'échéances | `lib/app/features/profile/profile_screen.dart:1254` (`SavedScreen`) ; `lib/app/features/saved/saved_screen.dart:71` (`DeadlineCalendarScreen`) |
| KPB Intelligence (assistant IA), consentement explicite | `lib/app/features/shell/app_shell.dart:141` + `lib/app/features/ai_advisor/coach_fab.dart:36` (aucune garde de drapeau) ; `lib/app/features/ai_advisor/ai_consent.dart:20-36` ; nom public `lib/app/core/translations/app_translations.dart:841` |
| KPB Intelligence : quota hebdomadaire gratuit | `lib/app/features/premium/premium_screen.dart:49-51` (« default 5 ») ; libellés `lib/app/core/translations/app_translations.dart:837,845` |
| Test d'orientation | `lib/app/features/orientation/orientation_screen.dart:288` ; entrées `lib/app/features/home/home_screen.dart:1092,1178`, `lib/app/features/profile/profile_screen.dart:1239` |
| Espace parent, en lecture seule, visibilité choisie par l'étudiant | `lib/app/features/profile/profile_screen.dart:1291-1296` ; `lib/app/features/parent/parent_case_view_screen.dart:33` (« read-only — parent can't post ») ; interrupteur `lib/app/features/cases/case_detail_screen.dart:560` |
| Hors ligne : catalogue en cache + bandeaux d'honnêteté | `lib/app/features/shell/app_shell.dart:105-112` (bandeaux échantillon / données datées) ; `lib/app/core/services/catalog_cache_service.dart:26` |
| Verrou biométrique de l'app | `lib/app/features/profile/profile_screen.dart:764-770` ; `lib/app/core/services/security_service.dart:123` (`authenticate`) |
| Âge minimum 16 ans + accord du tuteur < 18 ans | `lib/app/features/onboarding/onboarding_screen.dart:459-497` ; libellés `lib/app/core/translations/app_translations.dart:704-706` |
| Export des données + suppression du compte depuis l'app | `lib/app/features/profile/profile_screen.dart:159-163` (`_DataRightsCard`) ; `lib/app/core/repositories/app_api_client.dart:112-114` (`DELETE /profiles/me`) ; serveur `backend/src/modules/profiles/profiles.controller.ts:105-117` |
| Refus de l'analyse d'usage | `lib/app/core/services/analytics_service.dart:88-101` ; libellé `lib/app/core/translations/app_translations.dart:1520-1521` |
| Aucun achat intégré : contact conseiller par WhatsApp | `lib/app/features/services/service_packages_screen.dart:13-18,67` ; `lib/app/features/premium/premium_screen.dart:12-22` (« there is NO Premium product, price, subscription or payment ») ; `backend/src/app.module.ts:95-98` ; `lib/app/core/repositories/app_api_client.dart:1555-1557` ; aucune dépendance d'achat : `grep -n "in_app_purchase\|purchases_flutter" pubspec.yaml` → aucun résultat |
| Avertissement anti-fraude + conseiller vérifié | `lib/app/core/ui/components/anti_fraud_notice.dart:53-59` ; libellés `lib/app/core/translations/app_translations.dart:2069-2081` |

---

## 3. Interdits durs — fonctionnalités masquées en build 49

Aucune ligne des fiches ne doit y faire allusion, même indirectement.

| Interdit | Drapeau / preuve |
|---|---|
| Générateur de CV, lettres de motivation, simulateur d'entretien, relecture IA | `lib/app/core/config/app_config.dart:149-154` (`aiToolsEnabled` défaut `false`) ; masquages `lib/app/features/shell/kpb_tools_drawer.dart:162,197`, `lib/app/features/tools/student_tools_screen.dart:34`, `lib/app/features/cases/case_detail_screen.dart:444,495`, `lib/app/features/ai_advisor/ai_chat_screen.dart:676` |
| Téléversement de pièces jointes dans un dossier | `lib/app/core/config/app_config.dart:182-187` (défaut `false`) ; `lib/app/features/cases/case_tunnel_flow.dart:345` ; `lib/app/core/controllers/app_controller.dart:1317` |
| Simulateur de vols | `lib/app/core/config/app_config.dart:116-119` (défaut `false`) ; `lib/app/features/shell/kpb_tools_drawer.dart:211-217`, `lib/app/features/profile/profile_screen.dart:1264-1270` |
| Communauté / forum / articles | `lib/app/core/config/app_config.dart:93-96` (`mvpOnly` défaut `true`) ; `lib/app/features/home/home_screen.dart:388`, `lib/app/features/profile/profile_screen.dart:1281-1286` ; côté serveur `backend/src/common/guards/mvp.guard.ts:18-21` |
| Annuaire alumni, mentors, salon virtuel, Academy | `lib/app/features/profile/profile_screen.dart:1303-1325` (`if (!AppConfig.mvpOnly)`) ; serveur `backend/src/modules/alumni/alumni.controller.ts:33-34`, `backend/src/modules/salon/salon.controller.ts:29-30` |
| Programme ambassadeur rémunéré (FCFA, classement, retraits Wave) | `lib/app/core/config/app_config.dart:105-108` (défaut `false`) ; `lib/app/features/referral/ambassador_screen.dart:166` |
| Estimateur de logement | Techniquement atteignable (`lib/app/features/shell/kpb_tools_drawer.dart:218-223`) mais la tuile Profil est masquée (`lib/app/features/profile/profile_screen.dart:1272-1278`). **Incohérent ⇒ ne pas vanter** (décision §9-D4) |
| Success Lab / relecture d'étude / preuve de résultat | Décidé par le serveur, pas par le binaire : `lib/app/features/scholarships/live_scholarships_screen.dart:250-263` (fail-closed) ; gabarits à `false` `backend/.env.example:83-87,105` ⇒ INCONNU en prod ⇒ ne pas vanter |
| « Premium », abonnement, tarif d'abonnement | `lib/app/features/premium/premium_screen.dart:12-28` : écran « bientôt / via un conseiller », sans prix ni paiement. Depuis la 52, la liste d'attente est une inscription GRATUITE et réversible — aucun montant, aucun droit ouvert, aucune donnée de paiement (`backend/src/modules/premium/`), et `test/features/premium/premium_waitlist_consent_version_test.dart` balaie toutes les clés `premium_pitch_*` / `premium_waitlist_*` à la recherche d'un montant ou d'un verbe d'achat |

**Interdits de langage** (contraintes de la demande, non négociables) :
aucune promesse d'admission, de visa ou de bourse ; aucun superlatif
invérifiable (« n° 1 », « le meilleur », « garanti », « le plus complet ») ;
aucun nombre non prouvé par le code (nombre de bourses, d'universités, de
témoignages, de questions du test d'orientation — voir §10).

---

## 4. Champ « Éditeur » (à saisir à l'identique dans les deux consoles)

```
KPB Global L.L.C-FZ
```

Mentions complètes lorsque la console demande l'adresse ou l'immatriculation :

```
KPB Global L.L.C-FZ — société à responsabilité limitée de zone franche
immatriculée auprès de la Meydan Free Zone (Meydan City Corporation,
Émirat de Dubaï), licence n° 2537631.01.
Siège : Meydan Grandstand, 6th floor, Meydan Road, Nad Al Sheba,
Dubaï, Émirats arabes unis.
KPB Education est un service de KPB Global L.L.C-FZ, et non une entité distincte.
Contact : contact@kpbeducation.com — Confidentialité : privacy@kpbeducation.com
```

Preuves : `lib/app/core/translations/app_translations.dart:624,696,700` ;
`web/public/conditions.html:17,79,85,87-88` ; `docs/security-compliance.md:65`
(siège et licence) ; `lib/app/features/legal/legal_pages.dart:142`.

---

## 5. FRANÇAIS — texte à coller

### 5.1 Google Play

<!-- FIELD: play_fr_title | max=30 -->
**Titre — 30 caractères max — proposition : 23**

```
KPB Education : bourses
```

Variante si le propriétaire préfère le nom nu (13) : `KPB Education`.

<!-- FIELD: play_fr_short | max=80 -->
**Description courte — 80 caractères max — proposition : 76**

```
Bourses, universités et suivi de dossier avec un conseiller KPB. En français.
```

<!-- FIELD: play_fr_long | max=4000 -->
**Description longue — 4000 caractères max — proposition : 3452**

```
KPB Education accompagne les lycéens, les étudiants et leurs parents d'Afrique de l'Ouest et du Centre dans la préparation d'un projet d'études à l'étranger. Tout est en français, pensé pour nos connexions et nos budgets.

BOURSES D'ÉTUDES
Parcours les bourses fiche par fiche : type de financement (entièrement ou partiellement financée), niveau concerné, date limite avec un compte à rebours, avantages, critères d'éligibilité et étapes de candidature. Chaque fiche renvoie au site officiel et, quand il existe, au formulaire officiel du bailleur. Active une alerte sur une bourse pour être prévenu avant la clôture. Un compte gratuit est nécessaire pour voir la liste : les bourses sont sélectionnées selon ton niveau, tes pays visés et ton domaine.

UNIVERSITÉS ET PROGRAMMES
Explore des établissements et des formations dans dix destinations : Allemagne, Canada, Chine, Émirats arabes unis, Espagne, États-Unis, France, Maroc, Royaume-Uni, Turquie. Filtre par pays, domaine, niveau d'études et budget annuel. Compare deux établissements côte à côte. Les fiches pays et programmes affichent la date de leur dernière vérification, pour que tu saches à quand remonte l'information.

TES DOSSIERS, SUIVIS PAR UN CONSEILLER
Crée une demande en quelques étapes : consultation, candidature ou accompagnement. Tu peux dicter ton message à la voix au lieu de le taper. Chaque dossier affiche son statut d'avancement et le fil de discussion avec le conseiller KPB qui le suit.

OUTILS PRATIQUES
Scanner de documents : photographie tes pièces et assemble-les en un seul PDF. Tout se passe sur ton téléphone.
Calculateur de budget : estime le coût de la vie selon la destination et le niveau de vie choisi.
Simulateur d'éligibilité : réponds à quelques questions et exporte un récapitulatif en PDF à partager.

PARCOURS
Regarde des témoignages vidéo et lis des interviews écrites d'étudiants passés par les mêmes démarches avant toi.

KPB INTELLIGENCE
Un assistant conversationnel pour tes questions sur les écoles, les filières et le budget. Il ne s'active qu'après ton accord explicite, il inclut un nombre de messages gratuits par semaine, et ses réponses sont indicatives : elles ne remplacent ni un conseiller KPB, ni les informations officielles de l'établissement.

ESPACE PARENT
Un parent peut créer son propre compte. Il ne voit que les dossiers que l'étudiant a choisi de partager, en lecture seule.

PENSÉE POUR NOS CONNEXIONS
Le catalogue reste consultable hors ligne depuis sa dernière synchronisation, et l'application indique clairement quand une donnée est ancienne ou provisoire. L'accès à l'app peut être verrouillé par empreinte ou reconnaissance du visage.

TES DONNÉES, TES DROITS
Le compte est réservé aux 16 ans et plus. En dessous de 18 ans, le nom, le contact et l'accord d'un parent ou tuteur sont demandés. Depuis l'application tu peux exporter tes données, supprimer ton compte et refuser l'analyse d'usage.

AUCUN PAIEMENT DANS L'APPLICATION
KPB Education ne vend rien dans l'app et ne demande aucun numéro de carte bancaire. Les accompagnements payants de KPB sont présentés avec leur tarif en FCFA, puis organisés directement avec un conseiller sur WhatsApp. L'application affiche aussi comment reconnaître un conseiller KPB officiel et comment signaler une tentative de fraude.

CE QUE L'APPLICATION NE FAIT PAS
Elle ne garantit aucune admission, aucune bourse et aucun visa. Elle ne dépose aucune candidature à ta place. Les dates, montants et critères affichés doivent toujours être revérifiés sur le site officiel de l'établissement ou du bailleur avant de postuler.

Éditeur : KPB Global L.L.C-FZ (Meydan Free Zone, Dubaï, Émirats arabes unis — licence n° 2537631.01). KPB Education est un service de cette société.
Contact : contact@kpbeducation.com
```

### 5.2 App Store

<!-- FIELD: ios_fr_name | max=30 -->
**Nom — 30 caractères max — proposition : 13**

```
KPB Education
```

<!-- FIELD: ios_fr_subtitle | max=30 -->
**Sous-titre — 30 caractères max — proposition : 29**

```
Bourses, écoles et conseiller
```

<!-- FIELD: ios_fr_promo | max=170 -->
**Texte promotionnel — 170 caractères max — proposition : 166**

```
Bourses avec dates limites et alertes, universités dans dix pays, dossiers suivis par un conseiller KPB sur WhatsApp. En français. Aucun paiement dans l'application.
```

<!-- FIELD: ios_fr_desc | max=4000 -->
**Description — 4000 caractères max — proposition : 3452**

```
Identique à la description longue Google Play (§5.1). Coller le même texte :
les deux fiches partagent la limite de 4000 caractères et la même liste de
fonctionnalités prouvées, il n'y a aucune raison de les faire diverger.
```

<!-- FIELD: ios_fr_keywords | max=100 -->
**Mots-clés — 100 caractères max — proposition : 99**

```
bourse,etudes,etranger,universite,candidature,orientation,dossier,visa,ecole,master,licence,afrique
```

Règles appliquées : séparateur virgule sans espace, aucun mot déjà présent dans
le nom ou le sous-titre, pas d'accents (la recherche App Store les normalise),
pas de marque tierce.

---

## 6. ANGLAIS — texte à coller

> Fiche de vitrine. **L'interface de la build 49 est en français** (§1) : chaque
> version anglaise le dit explicitement. Ne pas promettre une UI anglaise.

### 6.1 Google Play

<!-- FIELD: play_en_title | max=30 -->
**Title — 30 characters max — proposal: 26**

```
KPB Education: scholarships
```

<!-- FIELD: play_en_short | max=80 -->
**Short description — 80 characters max — proposal: 78**

```
Scholarships, universities and advisor-tracked applications. French interface.
```

<!-- FIELD: play_en_long | max=4000 -->
**Full description — 4000 characters max — proposal: 3305**

```
KPB Education helps secondary-school students, university students and their parents in French-speaking West and Central Africa prepare a study-abroad project, step by step.

PLEASE NOTE: the app interface is in French only in this version.

SCHOLARSHIPS
Browse scholarships one entry at a time: funding type (fully or partially funded), eligible study level, closing date with a countdown, benefits, eligibility criteria and application steps. Every entry links to the official website and, where one exists, to the funder's official form. Turn on an alert for a scholarship to be notified before it closes. A free account is required to see the list, because scholarships are selected against your study level, your target countries and your field.

UNIVERSITIES AND PROGRAMMES
Explore institutions and programmes across ten destinations: Canada, China, France, Germany, Morocco, Spain, Turkey, United Arab Emirates, United Kingdom, United States. Filter by country, field, study level and yearly budget. Compare two institutions side by side. Country and programme entries show the date they were last verified, so you know how recent the information is.

YOUR CASES, FOLLOWED BY AN ADVISOR
Open a request in a few steps: consultation, application or guidance. You can dictate your message instead of typing it. Each case shows its progress status and the message thread with the KPB advisor handling it.

PRACTICAL TOOLS
Document scanner: photograph your papers and assemble them into a single PDF. Everything stays on your phone.
Budget calculator: estimate living costs by destination and lifestyle.
Eligibility simulator: answer a few questions and export a PDF summary you can share.

JOURNEYS
Watch video testimonials and read written interviews from students who went through the same process before you.

KPB INTELLIGENCE
A conversational assistant for your questions about schools, fields of study and budget. It only starts after your explicit consent, it includes a number of free messages per week, and its answers are indicative: they replace neither a KPB advisor nor the institution's official information.

PARENT SPACE
A parent can create their own account. They only see the cases the student chose to share, and they see them read-only.

BUILT FOR OUR CONNECTIONS
The catalogue stays readable offline from its last sync, and the app states clearly when data is old or provisional. App access can be locked with a fingerprint or face recognition.

YOUR DATA, YOUR RIGHTS
Accounts are for ages 16 and over. Under 18, a parent or guardian's name, contact and consent are required. From inside the app you can export your data, delete your account and opt out of usage analytics.

NO PAYMENT INSIDE THE APP
KPB Education sells nothing in the app and never asks for card details. Paid KPB guidance packages are shown with their price in FCFA, then arranged directly with an advisor on WhatsApp. The app also explains how to recognise an official KPB advisor and how to report a fraud attempt.

WHAT THIS APP DOES NOT DO
It guarantees no admission, no scholarship and no visa. It submits no application on your behalf. Dates, amounts and criteria shown must always be re-checked on the institution's or funder's official website before you apply.

Publisher: KPB Global L.L.C-FZ (Meydan Free Zone, Dubai, United Arab Emirates — licence no. 2537631.01). KPB Education is a service of that company.
Contact: contact@kpbeducation.com
```

### 6.2 App Store

<!-- FIELD: ios_en_name | max=30 -->
**Name — 30 characters max — proposal: 13**

```
KPB Education
```

<!-- FIELD: ios_en_subtitle | max=30 -->
**Subtitle — 30 characters max — proposal: 30**

```
Scholarships, schools, advisor
```

<!-- FIELD: ios_en_promo | max=170 -->
**Promotional text — 170 characters max — proposal: 164**

```
Scholarship deadlines and alerts, universities across ten countries, cases followed by a KPB advisor on WhatsApp. French interface. No payment inside the app.
```

<!-- FIELD: ios_en_desc | max=4000 -->
**Description — 4000 characters max — proposal: 3305**

```
Identical to the Google Play full description (§6.1). Paste the same text.
```

<!-- FIELD: ios_en_keywords | max=100 -->
**Keywords — 100 characters max — proposal: 96**

```
scholarship,study abroad,university,application,orientation,student,visa,africa,master,funding
```

---

## 7. Notes pour la revue Apple + champs de console

### 7.1 Compte de démonstration — OUI, il en faut un

**Pourquoi.** L'onglet Bourses et la création de dossier sont derrière un mur
invité :
`lib/app/features/scholarships/live_scholarships_screen.dart:416`,
`lib/app/features/cases/case_create_screen.dart:106`,
`lib/app/features/cases/case_tunnel_flow.dart:251,260`.
Le reste de l'app (Accueil, Universités, outils, Parcours) est explorable sans
compte : `lib/app/features/auth/auth_welcome_screen.dart:249`.

**Difficulté à signaler.** Il n'y a **pas de mot de passe** : la connexion se
fait par Google OAuth ou par code à usage unique envoyé par e-mail.
`lib/app/core/services/auth_service.dart:58-64` (`signInWithOtp`) et
`:105-107` (`signInWithOAuth(OAuthProvider.google)`).
Le champ « mot de passe » d'App Store Connect n'a donc pas de valeur utile
⇒ **décision D1 (§9)** : fournir une boîte de réception accessible au relecteur,
ou un compte Google de test dont on donne les identifiants.

Texte à coller dans « Notes for Review », une fois D1 tranchée :

```
SIGN-IN
This app has no password. Sign-in is either Google OAuth or a one-time code
sent by email. Demo account: <ADRESSE> — the one-time code can be read at
<MÉTHODE FOURNIE PAR L'ÉDITEUR>. Most of the app (Home, Universities, tools,
Journeys) is usable without any account via "Explorer sans compte" on the
welcome screen; a signed-in account is only needed for the Scholarships tab
and to open a case.

LANGUAGE
The app interface is French only in this version. The English store listing
is a storefront translation, not a claim about the UI language.

NO IN-APP PURCHASE
There is no in-app purchase, no subscription and no checkout anywhere in the
app or the backend, and no card details are ever requested. Paid KPB guidance
packages are real-world, human services (a KPB counsellor reviews a CV,
letters and an application file). Their FCFA price is displayed for
information, and the call to action opens WhatsApp to reach a counsellor;
payment is arranged outside the app. The "Premium" screen is a
"coming soon / arrange with an advisor" screen: it shows no price, no
subscription and no billing state. From build 52 it also carries a free
waiting-list button: tapping it records the student's interest so the team can
size demand before building the service. It takes no payment details, states no
price, creates no entitlement and can be undone from the same screen; the stored
row holds only the account id, the timestamp, and which consent notice was shown
and in which language.

AI FEATURES
Six features call a third-party LLM (OpenRouter and Groq, United States): the
conversational assistant "KPB Intelligence", the orientation questionnaire,
and the four writing tools — CV summary, motivation letter, interview practice
and document review. All six are behind an explicit, timestamped in-app AI
consent dialog enforced server-side on every route, and a declared minor
additionally requires a guardian's recorded consent. The assistant has a
weekly free message quota. Answers are presented as indicative and the UI
states they do not replace a counsellor or the institution's official
information. Text the student pastes into the writing tools is sent to the
model to produce the requested draft. The app never appends the student's
name or profile identity to a prompt; pasted text is forwarded as written, so
a pasted CV or letter may itself contain the student's name. Prompts are not
used for provider training (OpenRouter routing is pinned to zero-data-retention
with data collection denied).

USER-GENERATED CONTENT
There is no public feed, no forum and no user-to-user messaging. A student
writes only to the KPB advisor assigned to their own case. A parent account
can read a case only if the student explicitly turns on sharing for that
case, and a parent cannot post.

AGE
Accounts require 16+. Under 18, a guardian's name, contact and consent are
required before the profile can be completed.
```

Preuves de ce bloc : IAP → `lib/app/features/services/service_packages_screen.dart:13-18,67`,
`lib/app/features/premium/premium_screen.dart:12-22`, `backend/src/app.module.ts:95-98`,
`lib/app/core/repositories/app_api_client.dart:1555-1557`, absence de dépendance d'achat
dans `pubspec.yaml`. IA → `lib/app/features/ai_advisor/coach_fab.dart:36`,
`lib/app/features/ai_advisor/ai_consent.dart:20-36`,
`lib/app/features/orientation/orientation_screen.dart:288`,
`backend/src/modules/orientation/orientation.controller.ts:29,37` (`AiConsentGuard`),
`backend/src/modules/ai/llm.service.ts:53-54` (destinataire `api.groq.com`),
`lib/app/core/config/app_config.dart:149-154` (outils IA masqués).
UGC → `lib/app/features/community/forum_category_screen.dart:11-16`,
`backend/src/modules/community/community.controller.ts:23-40`,
`lib/app/features/parent/parent_case_view_screen.dart:33`,
`lib/app/features/cases/case_detail_screen.dart:560`.
Âge → `lib/app/features/onboarding/onboarding_screen.dart:459-497`.

### 7.2 Âge / classification

- Plancher contractuel **16 ans**, contrôlé à l'inscription :
  `lib/app/features/onboarding/onboarding_screen.dart:471-481` ;
  libellés `lib/app/core/translations/app_translations.dart:704-706`
  (« Âge minimum : 16 ans », « Les CGU exigent 16 ans révolus »).
- **La tranche exacte à cocher dans chaque console n'est pas prouvable par le
  dépôt** ⇒ INCONNU (§10), décision **D2**.
- À déclarer sans hésitation dans les questionnaires : présence d'un assistant
  IA génératif, contenu utilisateur non public, liens sortants vers des sites
  tiers (site officiel du bailleur, WhatsApp), aucune publicité, aucun contenu
  sensible. Aucun SDK publicitaire n'est embarqué (`docs/STORE_READINESS.md:56`).

### 7.3 Achats intégrés

**Aucun.** Preuves ci-dessus (§7.1). À cocher « pas d'achat intégré » dans les
deux consoles. Le tarif FCFA affiché reste un tarif de **service humain réel**
réglé hors application : `lib/app/features/services/service_packages_screen.dart:13-18`.

### 7.4 URL et contacts à saisir

| Champ | Valeur | Preuve |
|---|---|---|
| Politique de confidentialité | `https://kpbeducation.cloud/confidentialite.html` | `web/public/confidentialite.html` ; `docs/DEPLOYMENT.md:210` |
| Conditions d'utilisation | `https://kpbeducation.cloud/conditions.html` | `web/public/conditions.html` ; `docs/DEPLOYMENT.md:210` |
| Suppression de compte (exigée par Play) | `https://kpbeducation.cloud/suppression-compte.html` | `web/public/suppression-compte.html:26-38` ; `docs/DEPLOYMENT.md:210-211` |
| Site vitrine | `https://kpbeducation.cloud` | `web/public/conditions.html:88` |
| Support | `contact@kpbeducation.com` | `web/public/conditions.html:87` |
| Confidentialité / droits | `privacy@kpbeducation.com` | `web/public/confidentialite.html:105` |

⚠️ Le dépôt ne prouve pas que ces pages sont **servies** en production
(le service `web` du docker-compose doit être levé). Vérifier les trois URL
avant de les coller — voir §10.

### 7.5 Formulaires de confidentialité

Ce fichier ne remplace pas les formulaires. La source de vérité pour
App Privacy et Play Data Safety reste `docs/data-inventory.md` (dérivé du code)
et `docs/STORE_READINESS.md`. Points que la fiche marketing ne doit surtout pas
contredire : analyse d'usage **active par défaut** avec opt-out
(`lib/app/core/repositories/app_snapshot.dart:50-53`), OneSignal reçoit
l'identifiant de profil et quatre étiquettes de ciblage mais **aucun e-mail**
(`lib/app/core/services/onesignal_service.dart`),
Crashlytics n'est pas coupé par le refus d'analytique
(`lib/app/core/services/analytics_service.dart:96-108`).

---

## 8. Cohérence à corriger AVANT publication (copie interne fausse)

Ces textes sont **dans l'app** et contredisent les fiches ci-dessus. Une
capture d'écran de la fiche boutique montrant ces écrans serait une
sur-déclaration.

| Copie interne | Problème | Preuve |
|---|---|---|
| Écran d'accueil de connexion : « Probabilité d'admission chiffrée par université » | Promesse de résultat, exactement ce que les fiches s'interdisent | `lib/app/core/translations/app_translations.dart:2018-2019` ; écran `lib/app/features/auth/auth_welcome_screen.dart:138` |
| Même écran : « lettre, entretien, budget » | Vante deux outils **masqués** en build 49 (lettre de motivation, simulateur d'entretien) | `lib/app/core/translations/app_translations.dart:2020-2021` contre `lib/app/core/config/app_config.dart:149-154` |
| Même écran : « Réponds à 12 questions » | Le nombre vient du serveur ; le repli embarqué en contient 5 | `lib/app/core/translations/app_translations.dart:2016-2017` ; `lib/app/features/orientation/orientation_screen.dart:58` (`_ctrl.orientationQuestions`) ; repli : 5 `OrientationQuestion(` dans `lib/app/core/data/mock_catalog/orientation_data.dart` |
| Écran de consentement IA : « Ton nom civil n'est pas recopié dans l'invite » | Vrai pour le coach, **faux pour le test d'orientation** : le profil entier, `fullName` inclus, est sérialisé dans le message envoyé au LLM | `lib/app/core/translations/app_translations.dart:2333` contre `lib/app/core/controllers/app_controller.dart:826-831` et `backend/src/modules/orientation/orientation.service.ts:163-168` |
| Doc de release : tableau des drapeaux | Ne décrit que 2 des 5 masquages ⇒ sous-déclare l'état de la 49 | `docs/phase8-release-operations.md:16-31` |

---

## 9. Décisions qui appartiennent au propriétaire

- **D1 — Compte de démonstration Apple.** L'authentification est sans mot de
  passe (`lib/app/core/services/auth_service.dart:58-64,105-107`). Choisir :
  (a) une adresse de test dont la boîte est consultable par le relecteur, (b) un
  compte Google de test, ou (c) demander une exemption en arguant du mode invité.
  Sans ce choix, le bloc « Notes for Review » du §7.1 reste incomplet.
- **D2 — Tranche d'âge à cocher.** Le code prouve 16 ans révolus
  (`onboarding_screen.dart:471-481`), pas la case à cocher dans chaque console.
  À trancher, en cohérence avec la présence d'un assistant IA génératif.
- **D3 — Titre Play.** « KPB Education : bourses » (23) capte la requête la plus
  probable ; « KPB Education » (13) est plus propre pour une app renommée qui
  garde ses anciens installés. Un seul choix, et il doit tenir dans le temps.
- **D4 — Estimateur de logement.** Atteignable par le tiroir d'outils
  (`kpb_tools_drawer.dart:218-223`) alors que sa tuile Profil est masquée
  (`profile_screen.dart:1272-1278`). Soit on le masque aussi dans le tiroir,
  soit on l'assume et on l'ajoute aux fiches. En l'état il n'y figure pas.
- **D5 — Prix FCFA affichés.** Les paquets de services montrent un tarif
  (`service_packages_screen.dart:164,199`) puis renvoient vers WhatsApp
  (`:67`). C'est un service humain réel, donc défendable hors achat intégré,
  mais c'est le point que la revue Apple regardera. Valider la formulation du
  §7.1 avec le conseil, ou retirer l'affichage du prix de l'app.
- **D6 — Copie interne fausse (§8).** Publier la fiche sans corriger l'écran de
  connexion et l'écran de consentement IA, c'est laisser dans l'app les
  promesses que la fiche refuse d'écrire. Corriger avant, ou l'assumer par écrit.
- **D7 — Renommage de la fiche iOS.** Le nom livré est déjà « KPB Education »
  (`ios/Runner/Info.plist:9-10`) alors que le bundle reste `Karatou.karatou`
  (id 1128659292). Prévoir la note de version qui explique le changement de nom
  aux installés — ce fichier ne la contient pas.
- **D8 — Captures d'écran.** Non traitées ici. Elles ne doivent montrer aucun
  écran de la liste §3 (aucun outil IA, aucun forum, aucune surface ambassadeur,
  aucun téléversement de pièce jointe) et aucun écran affichant les textes du §8.

---

## 10. INCONNUS — ne pas écrire dans les fiches

- **Nombre de bourses, d'universités, de programmes et de témoignages
  réellement publiés.** Le catalogue vient du backend, le dépôt n'en contient
  qu'un repli (`lib/app/core/data/mock_catalog/`). Aucun chiffre ne peut donc
  être promis. INCONNU.
- **Nombre de questions du test d'orientation.** Serveur
  (`lib/app/features/orientation/orientation_screen.dart:58`) ; le repli
  embarqué en a 5, l'app annonce 12. INCONNU.
- **Contenu effectif par destination.** Les 10 pays sont l'*allowlist* du verrou
  MVP (`lib/app/core/utils/country_utils.dart:47-58`), pas la preuve qu'un
  établissement est publié pour chacun. Le mot « dix destinations » n'est donc
  exact que si la production contient bien des fiches pour les dix — à vérifier
  côté données avant publication.
- **Disponibilité de Success Lab en production** (`GET /success-lab/access`,
  fail-closed) : décision serveur, pas binaire. INCONNU ⇒ absent des fiches.
- **PostHog actif dans la 49** (`POSTHOG_API_KEY` injectée ou vide,
  `lib/app/core/config/app_config.dart:72-75,87`). Sans conséquence sur la copie
  marketing, mais décisif pour les formulaires de confidentialité. INCONNU.
- **Pages légales réellement servies** en production
  (`/confidentialite.html`, `/conditions.html`, `/suppression-compte.html`) :
  non vérifiable depuis le dépôt. INCONNU — à tester avant de coller les URL.
- **`--dart-define` de l'archive iOS 49.** Livrée par Xcode Organizer ;
  `ios/Flutter/Generated.xcconfig` est gitignoré (`ios/.gitignore:21`). Tout ce
  fichier suppose les défauts compilés d'`app_config.dart`. Si l'archive a
  inversé un drapeau, la liste §3 change. INCONNU sans le journal de build.
- **Traduction des fiches dans d'autres langues** (arabe, portugais) : hors
  périmètre, non traité.
