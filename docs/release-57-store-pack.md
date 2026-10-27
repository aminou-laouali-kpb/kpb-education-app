# Build 57 — pack de soumission : ce que la 57 embarque, notes de revue recomptées, déclarations de confidentialité, drapeaux et déploiement par étapes

> **À quoi sert ce fichier.** La 57 est une **release unique** qui embarque les chantiers B, C,
> D, F, G, H, I et K (PR #353 à #361), plus la bascule des notifications vers Firebase Cloud
> Messaging (#351), les correctifs #349 et #350, les PR #362 à #374 (chantier L, catalogue,
> compétition, communauté et bots, parrainage, finalisation, correctifs et corrections juridiques)
> et la PR de correctifs de l'audit 57. Ce fichier rassemble ce qu'il faut *coller*
> dans les consoles — notes de version, « Notes for Review » **recomptées**, réponses **Data
> Safety** (Play) et **App Privacy** (Apple) — le **tableau de tous les drapeaux** de
> `/config/app` avec leur valeur au lancement, et le **plan de déploiement par étapes**
> (serveur, puis admin, puis app ; Play 10 % → 50 % → 100 % ; publication progressive iOS). L'ordre
> exact des opérations, avec les commandes, est dans `docs/mise-a-jour-57-checklist.md` ; la
> recette appareil dans `docs/device-qa-build57.md` ; l'inventaire des données dans
> `docs/data-inventory.md`.
>
> **État mesuré le 16/10/2026** (lecture seule, depuis l'extérieur) :
> - **App Store** (fiche FR, `itunes.apple.com/lookup?id=1128659292`) : version **2.3.0**, mise en
>   ligne le **07/10/2026** ; **Google Play** (fiche publique) : **2.3.0**. La 2.3.0 est donc en
>   vente sur les deux boutiques. Le registre (`docs/release-ledger.md`) dit encore « Version
>   marketing EN VENTE : 2.2.0 » et la ligne `56` « non téléversée » : il n'a pas été mis à jour
>   après l'envoi. À VALIDER (propriétaire) : que la build en vente est bien la **56** (les
>   boutiques n'affichent pas le numéro de build), sa date de téléversement et le SHA archivé.
> - **Backend de production** : `28ac82dab0c2` (`/api/health/version`, démarré le 12/10/2026),
>   c'est-à-dire **avant** #351 et les chantiers B à K. `/api/health` rend `push.configured`
>   sans les clés `fcm` / `oneSignal` de #351 : **le chemin FCM n'est pas en production**.
> - **`/api/config/app` → `features`** : `eefTeaser=true`, `eef=false`, **`eefSpace=true`**,
>   `eefHelpBubble=false`, `eefPrivateSchools=false`, les cinq clés Success Lab à `false` ;
>   **aucune** des clés des chantiers G, K, D, I (absentes = repli de l'app). `minVersion=0.0.0`,
>   `recommendedVersion=null`.
>
> **Règle qui gouverne tout le reste** (`docs/store-listing-copy.md`, « Règle appliquée à chaque
> phrase ») : *toute fonctionnalité vantée doit être atteignable le jour de l'approbation.* Le
> test « Mes 10 bourses » (`features.scholarshipMatch`) et l'onboarding V2
> (`features.onboardingV2`) partent **fermés** : ni les notes de version ni la fiche ne les citent.
> Même règle pour les parties app du **parrainage** (révision du 17/10/2026,
> `docs/runbook-campagne-ambassadeurs.md` §8) : `features.referralInstallReferrer`,
> `features.referralOnboardingCode` et `features.referralLeaderboard` partent fermés.
>
> **Rien de ce qui suit ne s'envoie sans le feu vert explicite du propriétaire.** Ce fichier
> prépare des textes et des valeurs ; il ne soumet rien, ne déploie rien, n'allume aucun drapeau.
>
> **Mise à jour du 18/10/2026 (finalisation)** : version **`2.3.1+57` posée** (`pubspec.yaml`,
> préflights, registre) ; décisions du propriétaire du 18/10/2026 reportées (§4, §5, §7) ;
> politique de confidentialité et CGU **rédigées** pour la communauté, les bots, le parrainage, la
> compétition et la nationalité — **validées par le propriétaire le 19/10/2026** (après les
> corrections juridiques #372 ; enregistrements de session PostHog : 30 jours, #374) ; export RGPD
> complété des notifications in-app ; compilation Android avec `play_install_referrer` vérifiée par
> la CI (§8).

---

## 1. Ce que la 57 embarque — et ce qu'on en voit le jour de l'approbation

| Chantier | Contenu | Visible à l'approbation ? |
|---|---|---|
| #349, #350 | L'étape 1 de l'onboarding dit pourquoi elle refuse ; la synchro du compte réessaie trois fois les pannes passagères, un échec dit sa cause (`failure_stage`, `error_kind`) | Oui |
| #351 | Notifications par **Firebase Cloud Messaging** en direct ; le SDK OneSignal est **retiré** de l'app (le serveur garde OneSignal en repli pour les builds 53 et 56) ; suivi des ouvertures (`POST /me/push-opens`) | Oui, **si le backend de #351 est déployé** (§6) |
| B (#353) | Honnêteté des scores côté serveur, sécurité des seeds, en-têtes de version lus (`GET /admin/app-builds`) | Serveur seulement |
| C (#356) | « Suivre » côté serveur et admin : annonce d'ouverture programmée et annulable, file d'envoi, rappels de date limite | Mode `legacy` à l'approbation (§6.3) |
| F + G (#357) | Fondations UI (`KpbToast`, `KpbAsyncView`, `KpbMotion`, `KpbHaptics`, `KpbFontSize`) ; bouton **« Suivre »**, écran **« Mes suivis »**, liste de notifications, feuille d'explication avant la demande d'autorisation des notifications (au premier « Suivre », jamais à l'onboarding) | Oui (interrupteurs **ouverts** par défaut) |
| D (#358) | Moteur d'éligibilité et API « Mes 10 bourses », catalogue 1.5.0, admin (éligibilité structurée, couverture, « Tester un profil ») | **Non** : `features.scholarshipMatch` fermé |
| H (#359) | Test « Mes 10 bourses » dans l'app ; **libellés honnêtes** (plus aucun palier de compatibilité calculé côté client pour une bourse, plus de « chances ») ; héros invité « Trouve tes bourses » | Libellés : oui. Test : **non** (drapeau fermé) |
| I (#360) | Liste des bourses lisible (statut, filtres, tri), **cache hors ligne** des bourses, fiche ; onboarding V2 ; code OTP collé et validé au 6e chiffre | Liste, hors ligne, OTP : oui. Onboarding V2 : **non** |
| K (#361) | Accueil « **Ta prochaine étape** » : une action, sept blocs, chacun avec un interrupteur serveur ouvert par défaut, chacun replié quand son appel échoue | Oui |
| Parrainage côté app (17/10/2026) | **Play Install Referrer** (Android, une fois par installation, code prérempli jamais validé sans l'élève) ; **identifiant d'installation** (UUID v4 aléatoire) en `X-KPB-Device-Id` sur `POST /referrals/redeem` seulement ; étape facultative « code de ton parrain » en fin d'onboarding ; écran « **Compétition ambassadeurs** » (phase, compte à rebours, rang, compteurs, code, classement public, règlement) ; messages clairs sur chaque erreur de code (écran Parrainage compris) | Messages d'erreur et identifiant : oui. Referrer, étape, compétition : **non** (trois drapeaux fermés, §5) |
| Communauté C1 + C2 (#365), bots « Vérif » (#366) et « Passerelle » (#367) | Questions-réponses entre élèves, modérées : filtre avant publication (coordonnées, WhatsApp, demandes d'argent, mobile money, liens hors liste blanche, insultes → « en attente de revue »), signalement, blocage, charte en quatre règles acceptée avant la 1re publication, file de modération de l'équipe, sanctions ; aucun message privé. Bot « Vérif » : réponses préparées depuis les données vérifiées, validées par un admin (mode `auto` seulement après 50 réponses validées sans correction). « Passerelle » : suggestions privées de l'équipe, interrupteur dans les préférences des notifications | **Non** : `features.community` et `features.assistBridge` fermés ; **déclarées dès la 57** (§3, §4.4) |

**Ce que la 57 change dans le binaire** (à re-prouver sur le SHA final, checklist étape 0) :
`pubspec.yaml` gagne `firebase_messaging` et perd `onesignal_flutter` (#351), puis gagne
**`play_install_referrer` 0.5.0** (parrainage, Android seulement : bibliothèque Google
`com.android.installreferrer:installreferrer:2.2`) ; `pubspec.lock` suit ;
`android/app/src/main/AndroidManifest.xml` gagne deux `meta-data` FCM (icône, canal `kpb_default`),
**aucune permission** dans le fichier source — le manifeste **fusionné** gagne la permission
d'installation `com.google.android.finsky.permission.BIND_GET_INSTALL_REFERRER_SERVICE`, déclarée
par l'AAR `installreferrer` 2.2 (lue le 17/10/2026), jamais affichée à l'utilisateur ;
`ios/Runner/Info.plist` ne change que par le commentaire et le texte de
`NSLocationWhenInUseUsageDescription` (gardée par précaution, jamais demandée). **`ios/Podfile.lock`
n'a pas été régénéré par #351** : il cite encore `onesignal_flutter` et ne cite pas
`firebase_messaging` ; le `pod install` de l'archive le réécrira (checklist étape 4).

**Ce que la 57 ne contient PAS** : les écoles partenaires (chantiers E et J, non faits) ; de
messages privés entre élèves ; un envoi hebdomadaire « nouvelles bourses compatibles » (l'opt-in est enregistré, aucun
envoi n'est codé) ; une permission **demandée à l'utilisateur** ; un hôte nouveau (l'écran de la
compétition ouvre `kpbeducation.cloud/classement/`, domaine déjà servi, et le `rulesUrl` servi par
le backend).

### 1.1 Couplage backend : `requires-new` pour les notifications

La 57 **tolère** un backend ancien écran par écran (chaque appel neuf se masque sur un 404 ;
clé `features` absente = repli de l'app) — **sauf pour les notifications** : elle n'embarque plus
le SDK OneSignal et n'enregistre qu'un jeton FCM (`POST /device-tokens`). Le backend de production
(`28ac82d`) n'envoie que par OneSignal : **un utilisateur de la 57 ne recevrait aucune
notification** tant que le backend de #351 n'est pas déployé **et** que
`FCM_SERVICE_ACCOUNT_JSON` n'est pas posé. D'où l'ordre imposé : **serveur, puis admin, puis app**
(§6.1), et un préflight en `backend_coupling=requires-new` (la production sert `RELEASE`).

### 1.2 Version marketing : 2.3.1

La 2.3.0 est en vente (mesure ci-dessus). App Store Connect refuse toute build dont la version
marketing n'est pas **strictement supérieure** à la dernière approuvée (**ITMS-90062**) : la 57 ne
peut pas rester en 2.3.0. Le propriétaire a retenu **2.3.1** le 16/10/2026 (strictement supérieure à 2.3.0, donc
acceptée ; le test « Mes 10 bourses » part fermé). La version `2.3.1+57` est posée depuis le
18/10/2026 (PR de préparation, checklist §0.2).

Le choix compte aussi pour le bandeau de mise à jour : `isVersionBelow` **ignore le numéro de
build** — `_parseVersion` coupe tout ce qui suit `+` (`lib/app/core/utils/version_utils.dart`), et
`AppVersionGate` comme `UpdateRecommendedBanner` comparent `PackageInfo.version`, la version
marketing, jamais `buildNumber` (`lib/app/core/services/app_version_gate.dart`,
`lib/app/core/ui/components/update_recommended_banner.dart`). Une 57 en 2.3.0 serait
indiscernable de la 56 pour `KPB_RECOMMENDED_APP_VERSION` et `KPB_MIN_APP_VERSION`.

---

## 2. Notes de version

**App Store — FR**
```
Nouveautés :
• Suivre une bourse : un bouton « Suivre » sur chaque bourse pour être prévenu de son ouverture et avant sa date limite. Retrouve tes bourses dans « Mes suivis ».
• Notifications : une liste de tes notifications dans l'app, et un envoi plus fiable.
• Bourses : une liste plus lisible (statut, date de clôture, filtres et tri) ; les bourses déjà consultées restent lisibles sans connexion.
• Accueil : une seule carte « Ta prochaine étape » te dit quoi faire maintenant.
• Connexion : le code reçu par e-mail se colle plus facilement et se valide dès le 6e chiffre.
• Stabilité : la synchronisation de ton compte résiste mieux aux coupures de réseau.
```

**App Store — EN**
```
What's new:
• Follow a scholarship: a "Follow" button on every scholarship to be notified when it opens and before its deadline. Find them in "My follows".
• Notifications: a list of your notifications in the app, and more reliable delivery.
• Scholarships: a clearer list (status, closing date, filters and sorting); scholarships you already viewed stay readable offline.
• Home: a single "Your next step" card tells you what to do now.
• Sign-in: the code received by email is easier to paste and is checked as soon as the 6th digit is typed.
• Stability: account sync copes better with network drops.
```

**Google Play — FR (500 caractères au plus)**
```
• Suivre une bourse : sois prévenu de son ouverture et avant sa date limite, retrouve-la dans « Mes suivis ».
• Une liste de tes notifications dans l'app, et un envoi plus fiable.
• Liste des bourses plus lisible (statut, filtres, tri), lisible hors connexion.
• Accueil : une carte « Ta prochaine étape ».
• Code de connexion plus simple à coller.
• Synchronisation plus robuste quand le réseau coupe.
```

Les captures d'écran de la fiche ne montrent ni le test « Mes 10 bourses » ni l'onboarding V2, ni
l'étape « code de ton parrain » ni l'écran « Compétition ambassadeurs » (drapeaux fermés).

---

## 3. « Notes for Review » Apple — le texte COMPLET (guideline 2.3.1)

Le champ est limité à **4 000 caractères** (à vérifier à la saisie dans App Store Connect). Le
texte ci-dessous **remplace** celui du pack 56 §3 : à coller **seul**, en anglais. Paragraphes
continus (chaque retour à la ligne compte pour un caractère).

<!-- notes-for-review: chars=3935 bytes=3938 reserve=160 -->

```
SIGN-IN
This app has no password: sign-in is Google OAuth or a one-time code sent by email. Demo account: <ADDRESS> — the code can be read at <METHOD>. Most of the app (Home, Universities, tools, Journeys) works without an account via "Explorer sans compte" on the welcome screen; an account is needed for the Scholarships tab, to follow a scholarship and to open a case.

LANGUAGE
The interface is French only in this version. The English store listing is a storefront translation.

NO IN-APP PURCHASE
There is no in-app purchase, subscription or checkout in the app or the backend, and no card details are requested. Paid KPB guidance packages are human services; their FCFA price is shown for information, the button opens WhatsApp to reach a counsellor, and payment is arranged outside the app. "Premium" is a "coming soon" screen with no price; its free waiting-list button records only the account id, a timestamp and the consent notice shown.

AI FEATURES
Six features call a third-party LLM (OpenRouter and Groq, United States): the assistant "KPB Intelligence", the orientation questionnaire and four writing tools. All six sit behind an explicit, timestamped in-app AI consent enforced server-side; a declared minor also needs a guardian's recorded consent. Answers are presented as indicative. The app never adds the student's name to a prompt. Prompts are not used for provider training.

USER-GENERATED CONTENT
None reachable at review time: a student writes only to the KPB advisor of their own case, which a parent reads only if the student shares it. The community below is declared in the age rating and privacy answers.

AGE
Accounts require 16+. Under 18, a guardian's name, contact and consent are required before the profile can be completed.

NEW IN THIS VERSION
"Follow" on a scholarship saves it and sends a notification when it opens and before its deadline. Notification permission is never asked at launch: only after a short explanation, at the first "Follow". A "My follows" screen and an in-app notification list are added; viewed scholarships stay readable offline; Home shows one "next step" card. Push notifications now use Firebase Cloud Messaging; the OneSignal SDK is removed.

REMOTELY ACTIVATED FEATURES (guideline 2.3.1)
Switched from our server (api.kpbeducation.cloud/api/config/app). The "Études en France" space is open (flag eefSpace). OFF at review time: features.scholarshipMatch, a scholarship eligibility test (nationality, date of birth, diploma, grades, languages) that shows up to 10 scholarships, never a percentage; features.onboardingV2, a shorter sign-up flow; features.eefHelpBubble and features.eefPrivateSchools, WhatsApp help inside the space; features.referralOnboardingCode and features.referralLeaderboard, an optional referral-code step after sign-up and a referral contest screen for ambassadors registered by our team (organiser KPB Global L.L.C-FZ, official rules linked, Apple is not a sponsor, no prize amount shown in the app); features.community, a student Q&A (posts and replies seen by signed-in students; pre-publication filter holding contact details, money requests and links for staff review; report; block; rules accepted before posting; staff moderation; no private messages); features.assistBridge, a settings switch for private KPB-team suggestions. None adds a permission, SDK or host on iOS. Test answers are not sent to schools, analytics or notifications. Also remote: a dismissible "update available" banner (recommendedVersion).

NOT AFFILIATED WITH ANY GOVERNMENT. KPB Education is a private guidance service, not affiliated with Campus France or any French administration, and does not process applications. The demo account is a test account: its declarations are excluded from our advisors' call lists.
```

**Décompte (script, 20/10/2026, communauté et passerelle déclarées — audit 57, F02).** Marqueurs
`<ADDRESS>` et `<METHOD>` remplacés par la place qu'on leur réserve — **40** et **120** caractères
— : **3 935 caractères** (3 938 octets en UTF-8), soit **65 caractères sous la limite**. Sans les
marqueurs : 3 775 caractères. Le test `test/release/store_pack_57_test.dart` refait ce calcul à
chaque exécution et exige au moins 50 caractères de marge : une adresse ou une méthode de compte de
démonstration plus longue que sa réserve se paie ailleurs dans le texte.

**À contrôler avant de coller**, sur le SHA final et le jour même :

1. **« The "Études en France" space is open (flag eefSpace) »** : mesuré `true` le 16/10/2026. La
   relire avec `curl … | jq .features.eefSpace` le jour de la soumission ; si elle vaut `false`,
   remplacer la phrase par « The "Études en France" space is OFF at review time (flag eefSpace) »
   et recompter. À VALIDER (propriétaire) : que l'espace reste ouvert pendant la revue.
2. **« OFF at review time » pour `scholarshipMatch`, `onboardingV2`, `eefHelpBubble`,
   `eefPrivateSchools`, `referralOnboardingCode`, `referralLeaderboard`, `community`,
   `assistBridge`** : les huit valent `false` (ou sont absentes) au moment de soumettre (checklist
   étape 8), ainsi que `referralInstallReferrer` (Android seulement, non cité aux notes Apple). Le
   relecteur ne voit ni le test, ni le nouvel onboarding, ni l'étape du code, ni l'écran de la
   compétition, ni la communauté (lien profond : écran « La communauté arrive bientôt », routes
   `/community/*` en 404), ni l'interrupteur « Suggestions de l'équipe KPB ». La communauté et la
   passerelle sont **déclarées dès la 57** (décision du propriétaire du 20/10/2026) : notes
   ci-dessus, classification d'âge et formulaires de confidentialité (§4.4) — leur ouverture plus
   tard ne demande donc pas de nouvelle soumission. Si la
   compétition doit être **ouverte** pendant la revue, la phrase change (« ON at review time » est
   interdit par le test : reformuler et recompter) et le `rulesUrl` de la campagne doit être posé —
   Apple 5.3.2 exige le règlement dans l'app et « Apple n'est pas sponsor ». À VALIDER
   (propriétaire).
3. **« Notification permission is never asked at launch »** : la demande est faite au premier
   « Suivre », derrière une feuille d'explication (`features.followPushPrimer`, ouvert), ou depuis
   l'écran des notifications ; l'onboarding ne la fait plus (`onboarding_screen.dart`, `_submit`).
   Si `followPushPrimer` est coupé, la demande reste au premier « Suivre », sans la feuille : la
   phrase reste vraie.
4. **« Test answers are not sent to schools, analytics or notifications »** : `docs/data-inventory.md`
   §5. Ne pas allonger la phrase en promesse sur l'admin : l'équipe n'a aucune route qui sert ces
   réponses, mais une base de production reste lisible par ses administrateurs.
5. **Compte de démonstration** : un compte **étudiant**, exclu des listes d'appel ; la décision D1
   (lecture du code à usage unique, `docs/store-listing-copy.md` §9) donne `<METHOD>`.

---

## 4. Déclarations de confidentialité de la 57 — Play Data Safety et Apple App Privacy

Mêmes réponses que `docs/CONSOLE_ANSWERS.md` (§1, §2), **sauf les lignes ci-dessous**, tirées de
`docs/data-inventory.md` (§2 et §5). Le sens de l'erreur est choisi comme pour XC-06 :
sur-déclarer coûte une ligne, sous-déclarer coûte une soumission (« declaration inconsistent with
privacy policy »). La politique in-app et `web/public/confidentialite.html` décrivent le test,
les suivis et les notifications (mise à jour du 16/10/2026) et, depuis le 18/10/2026 (textes
validés par le propriétaire le 19/10/2026), la nationalité sur consentement explicite, la communauté, les bots,
le parrainage (identifiant d'installation, lien d'invitation) et la compétition.

**Quand reporter ?** Les lignes du test « Mes 10 bourses » portent sur une fonction **dans le
binaire mais fermée**. Recommandation : les déclarer **dès la soumission de la 57** (le code et la
politique les décrivent) ; au plus tard **avant** d'ouvrir `features.scholarshipMatch`. Les deux
formulaires se modifient sans nouvelle build. À VALIDER (propriétaire).

### 4.1 Google Play — Data Safety (ce qui change)

| Type Play | Collecté | Partagé | Requis / Choix | Finalité | Preuve |
|---|---|---|---|---|---|
| Infos perso — **Autres** : **Nationalité(s)**, date de naissance, accord du tuteur, plus haut diplôme, niveau visé, tranche de moyenne, niveaux de langue, scores de test, tranche d'expérience | Oui | **Non** (aucune école, aucun organisme, pas l'e-mail commercial) | **Optionnel** (test facultatif ; la nationalité n'est envoyée qu'après la case de consentement explicite du récapitulatif, décision du propriétaire du 18/10/2026 ; la date de naissance reste requise par le contrôle d'âge) | Fonctionnalité (vérifier les conditions des bourses) | `UserProfile.nationalityCode`… (`schema.prisma`) ; `match-answers.ts` ; data-inventory §5 |
| Infos perso — **Origine ethnique** | **Non** | — | — | — | La nationalité n'est pas une origine ethnique ; À VALIDER (propriétaire) avec le juridique |
| Activité — **Autres actions** : bourses suivies, réglages d'alerte, ouverture d'une notification | Oui | Non | Requis pour la fonction « Suivre » | Fonctionnalité, Analyses (taux d'ouverture des campagnes) | `ScholarshipAlertSubscription`, `NotificationDelivery.openedAt` |
| Infos et performances — **Autres données de performance** : version et build de l'app | Oui (depuis la 54, lue côté serveur depuis B) | Non | Requis (en-têtes de chaque requête) | Fonctionnalité (savoir quelles versions restent en service) | `UserProfile.lastAppVersion`, `lastAppBuild` |
| **Identifiants d'appareil** | Oui (jeton FCM) | **Oui (OneSignal) tant que le repli tourne** pour les builds 53 et 56 | Requis | Push | `docs/CONSOLE_ANSWERS.md` §0sexies : garder « Partagé (OneSignal) » tant que `ONESIGNAL_*` est posé |
| Infos perso — **ID utilisateur** | Oui | **Oui (OneSignal)** pour les builds 53 et 56 seulement ; la 57 ne l'envoie qu'à notre backend et à PostHog | Requis | Fonctionnalité, Analyses | idem |
| Activité — **Autres actions** (4 étiquettes OneSignal) | Oui (builds 53 et 56) | Oui (OneSignal) | Requis | Fonctionnalité | La 57 n'en envoie plus ; la ligne tombe au retrait du repli |
| **Identifiants d'appareil ou autres** : **identifiant d'installation** (UUID v4 aléatoire, ni IMEI ni identifiant publicitaire) | Oui (2.3.1) — envoyé sur `POST /referrals/redeem` seulement, gardé côté serveur en **empreinte HMAC** (un hachage reste une collecte pour Play) | Non | Requis **quand** l'élève valide un code de parrain (pas de rattachement sans lui) | **Prévention de la fraude, sécurité et conformité** (ajout à la ligne « Identifiants d'appareil » existante) | `referral_attribution.dart` (`installId`), `referrals.controller.ts` ; data-inventory §6 bis ; conservation 180 jours (§6) |
| **Play Install Referrer** (SDK `play_install_referrer` 0.5.0 → bibliothèque Google `installreferrer` 2.2) | **Non collecté** : la chaîne de référence et ses horodatages sont lus et traités **sur l'appareil** ; seul `ref` est gardé en local pour préremplir un champ | Non | — | — | Le code ne part que quand l'élève appuie sur « Valider le code », comme une saisie manuelle (rattachement par code : déjà déclaré depuis KPB-69, « Autres actions ») ; drapeau `referralInstallReferrer` fermé : aucune lecture. À VALIDER (propriétaire) : réponse finale avec la grille Play du jour |

Inchangé : chiffrement en transit (Oui), suppression (Oui, en app + URL), identifiant publicitaire
(Non), Localisation (Non), Achats (Non), traitement éphémère (Non).

### 4.2 Apple — App Privacy (ce qui change)

| Type Apple | Collecté | Lié | Suivi | Finalité | Note |
|---|---|---|---|---|---|
| **Other Data Types — Other Data** : nationalité(s), date de naissance, diplôme, niveau visé, tranche de moyenne, niveaux et scores de langue, expérience | Oui | Oui | Non | App Functionality | Réponses du test « Mes 10 bourses » ; `PrivacyInfo.xcprivacy` déclare déjà `OtherDataTypes` (App Functionality) |
| **Sensitive Info** | **Non** | — | — | — | Apple y range l'origine raciale ou ethnique, les opinions, la religion, la santé… : pas la nationalité. À VALIDER (propriétaire) avec le juridique |
| **Usage Data — Product Interaction** : suivis, ouverture des notifications | Oui | Oui | Non | **App Functionality** (ajout) + Analytics | « Suivre » et « Mes suivis » sont une fonction, pas seulement de la mesure |
| **Identifiers — User ID, Device ID** | Oui | Oui | Non | App Functionality, Analytics | Jeton FCM (la 57) ; abonnement OneSignal des builds 53 et 56 tant que le repli tourne |
| **Diagnostics** | Oui | Non | Non | App Functionality | Inchangé (Crashlytics) ; la version de l'app vue par le serveur se rattache à « Other Diagnostic Data » |
| **Identifiers — Device ID** (précision 2.3.1) | Oui | Oui | Non | **App Functionality** (prévention de la fraude) | Identifiant d'installation aléatoire envoyé avec un code de parrain (`X-KPB-Device-Id`) ; `PrivacyInfo.xcprivacy` déclare déjà `NSPrivacyCollectedDataTypeDeviceID`. Pas de Play Install Referrer sur iOS |

**Push promotionnel (guideline 4.5.4)** : opt-in explicite recueilli dans l'app (réglages des
notifications → « Nouvelles et offres de KPB par notification », désactivé par défaut), retirable au
même endroit ; le serveur n'envoie aucun push d'une campagne promotionnelle sans ce oui
(chantier juridique 57, `campaign-purpose.ts`).

**Tracking : Non** partout, inchangé (`NSPrivacyTracking=false`, aucune ATT). La liste des SDK perd
OneSignal et gagne Firebase Messaging (même éditeur que Firebase Analytics, déjà déclaré).

**Déclaration des SDK (2.3.1)** : côté **Android**, la liste gagne le **Play Install Referrer**
(`play_install_referrer` 0.5.0, éditeur vérifié chunkytofustudios.com, autour de la bibliothèque
Google `com.android.installreferrer:installreferrer:2.2`) : il lit auprès du Play Store de
l'appareil l'URL de référence du lien Play, les horodatages du clic et du début d'installation, la
version installée et le paramètre Instant ; **rien n'est transmis** par l'app à partir de ces
données, sauf le code de parrain au moment du rattachement **confirmé** par l'élève. Côté **iOS** :
aucun SDK nouveau.

### 4.3 Points qui restent ouverts

- **XC-06** (finalité Marketing des coordonnées) : **tranché le 19/10/2026 — finalité « Marketing » DÉCLARÉE** (Play Data Safety et Apple App Privacy, coordonnées et identifiants de notification). **Chantier juridique 57 (19/10/2026, App Store 4.5.4)** : le push promotionnel passe en **opt-in** — il ne part qu'aux comptes qui ont activé « Nouvelles et offres de KPB par notification » (`promotionsPushOptIn`, non par défaut, comptes existants compris, preuve horodatée ; mineur : accord du représentant légal en plus) et n'ont pas coupé `kpb_promotions` ; une build qui ne connaît pas le champ n'en reçoit plus. Deux interrupteurs distincts (e-mail, notification), aucun coché d'avance. La finalité « Marketing » **reste déclarée** (honnête, sans coût) ; préciser « opt-in » (`docs/CONSOLE_ANSWERS.md` §0quater, ligne « chantier juridique 57 »). **Plus rien à valider sur XC-06.** Historique (dépassé par ce qui précède) : réduit par les correctifs 57
  (19/10/2026). Décision du propriétaire du 18/10/2026 : pas de finalité « Marketing », **sous
  réserve** qu'aucun envoi promotionnel ne parte sans opt-in. Depuis les correctifs 57, une campagne
  de l'admin porte une finalité (`promotional` par défaut) : l'**e-mail** promotionnel ne part
  qu'aux comptes qui ont coché « Nouvelles et offres de KPB » (non par défaut ; mineur : accord du
  représentant légal en plus), avec un lien de désinscription en un clic ; le **push**
  promotionnel respecte l'interrupteur « Nouvelles et offres de KPB » (`kpb_promotions`) — c'est un
  **opt-out**, pas un opt-in. Restent donc non garantis par le code : le push en opt-out, la
  classification humaine des campagnes, et les coordonnées envoyées à l'équipe commerciale. La
  décision n'est **pas** reportée dans les formulaires (`docs/CONSOLE_ANSWERS.md` §0quater,
  « Suivi du 18/10/2026 » et « Suivi du 19/10/2026 »). Ce point a été tranché le 19/10/2026
  (opt-in e-mail et push, finalité déclarée), ci-dessus.
- **D5** (prix FCFA) : **tranché le 18/10/2026** — affichés à titre indicatif, payés hors store
  (`docs/store-listing-copy.md` §9 ; notes de revue §3 cohérentes).
- **Nationalité** : base légale **consentement explicite**, saisie facultative, conservée tant que
  le compte existe, effaçable (décision du propriétaire, 18/10/2026) ; case de consentement ajoutée
  au récapitulatif du test ; politique rédigée (« Votre nationalité »). `features.scholarshipMatch`
  reste **fermé** (défaut inchangé : son ouverture est une action d'exploitation, §5 étape 4).
  Restent À VALIDER (propriétaire) : la réponse « Sensitive Info / origine ethnique : Non » avec le
  juridique (§4.1, §4.2) et le texte sur les mineurs de 16 et 17 ans (`docs/data-inventory.md` §5).
  **Correctifs 57** : bouton « Effacer ma nationalité » dans l'espace « Mes 10 bourses »
  (`DELETE /profiles/me/nationality` : nationalité(s) et résultats du test effacés, cache local
  vidé) ; privacy@kpbeducation.com reste possible ; politique mise à jour (validée le 19/10/2026).
- **Export** : corrigé le 18/10/2026 — les notifications in-app (`UserNotification`) figurent dans
  `GET /profiles/me/export` (clé `notifications`) ; la politique le dit (section 8).
  La PR de correctifs de l'audit 57 y ajoute les livraisons des campagnes admin
  (`NotificationDelivery`), le parrainage et les prix.
- **Parrainage (2.3.1)** : mention de l'identifiant d'installation, de la lecture du lien
  d'invitation (Install Referrer) et de la compétition (nom public, autorisation parentale,
  empreintes anti-fraude 180 jours, organisateur) **rédigée le 18/10/2026** dans la politique in-app
  et `confidentialite.html`, **validée par le propriétaire le 19/10/2026** ; finalité
  « prévention de la fraude » à ajouter à la ligne Play « Identifiants d'appareil » (§4.1) ; pied
  de l'écran « Compétition » présent et testé ; `rulesUrl` à poser sur la campagne avant d'ouvrir
  `features.referralLeaderboard` (data-inventory §6 et §6 bis) : le règlement est publié à
  `https://kpbeducation.cloud/reglement-ambassadeurs-2026-11.html`
  (`web/public/reglement-ambassadeurs-2026-11.html`), et le serveur refuse de lancer la campagne
  sans `rulesUrl` en https ; le champ « Règlement (texte) » reste interne.

### 4.4 Communauté et passerelle — déclarées dès la soumission de la 57 (décision du 20/10/2026)

La communauté (C1 + C2, #365) et le bot « Passerelle » (#367) sont **dans le binaire de la 57**,
derrière `features.community` et `features.assistBridge` (fermés), sans aucun verrou de
compilation : ouvrir le drapeau suffit à les montrer. Décision du propriétaire du 20/10/2026 : les
**déclarer à Apple et à Google dès la 57** (notes de revue §3, classification d'âge, formulaires de
confidentialité), plutôt que de lier leur ouverture à une soumission future. Lignes à saisir (détail
et preuves : `docs/CONSOLE_ANSWERS.md` §3 bis, `docs/STORE_READINESS.md` §5) :

| Formulaire | Ligne | Réponse |
|---|---|---|
| Play — Sécurité des données | Activité dans l'app — **Autre contenu généré par l'utilisateur** : publications, réponses, signalements (motif) | Collecté ; **non partagé** ; **facultatif** (la communauté l'est) ; Fonctionnalité de l'app, et Prévention de la fraude, sécurité et conformité (filtre anti-arnaque, modération) ; supprimé avec le compte, inclus dans l'export |
| Play — Sécurité des données | Activité dans l'app — **Autres actions** : charte acceptée, « utile », discussions suivies, membres bloqués | Collecté ; non partagé ; facultatif ; Fonctionnalité de l'app |
| Apple — App Privacy | **User Content — Other User Content** | Collecté ; lié ; pas de suivi ; App Functionality |
| Apple — classification d'âge | Capacités : **contenu généré par les utilisateurs** | **Oui** — public entre élèves connectés, modéré (filtre, signalement, blocage, charte, file de l'équipe) |
| Apple — classification d'âge | Capacités : **messagerie et discussion** | **Non** : aucun message privé entre élèves ; À VALIDER (propriétaire) avec l'intitulé exact de la grille du jour |
| Google Play — questionnaire IARC | **Interaction entre utilisateurs / partage de contenu** | **Oui** (publications et réponses publiques entre élèves, modérées) ; partage de la localisation : Non ; achats : Non |
| Les deux | Passerelle (`assistBridge`) | Rien de plus : elle lit ce que l'élève vient de publier (déjà déclaré) et lui envoie une notification privée par le chemin existant (`docs/CONSOLE_ANSWERS.md` §3 ter) |

Le relecteur ne voit ni l'une ni l'autre (OFF à la revue) ; leur ouverture, après l'approbation,
n'appelle plus de nouvelle soumission ni de changement de formulaire. La politique in-app et
`confidentialite.html` (section « Communauté d'entraide ») et les CGU (charte en quatre règles, « pas
de messages privés ») les décrivent déjà.

---

## 5. Drapeaux `features.*` de `/config/app` — défaut, valeur au lancement, ordre d'ouverture

Source : `backend/src/modules/config/app-config.controller.ts`. **Fermé** = `enabled()` (seule la
valeur `true` ouvre ; variable absente = fermé). **Ouvert** = `notDisabled()` (seule `false` ferme ;
variable absente = ouvert) : ce sont des **interrupteurs d'urgence** de fonctions livrées. Une clé
absente de la réponse (backend plus ancien) vaut le repli de l'app — fermé pour les premiers,
ouvert pour les seconds (`RemoteFeatureFlags`). « Prod. 16/10 » = mesure du 16/10/2026 (backend
`28ac82d`) ; « absente » = la clé n'est pas encore servie.

| Clé | Variable | Défaut | Prod. 16/10 | Au lancement de la 57 | Ordre d'ouverture et condition |
|---|---|---|---|---|---|
| `competitionReadiness` | `KPB_COMPETITION_READINESS_ENABLED` | fermé | `false` | `false` | Hors de la 57 : ne pas toucher |
| `successLab` | `KPB_SUCCESS_LAB_ENABLED` (et `competitionReadiness`) | fermé | `false` | `false` | Hors de la 57 |
| `aiDiagnostic` | `KPB_AI_DIAGNOSTIC_ENABLED` (et `successLab`, et `KPB_AI_DIAGNOSTIC_KILL_SWITCH` à `false`) | fermé | `false` | `false` | Hors de la 57 |
| `outcomeEvidence` | `KPB_OUTCOME_EVIDENCE_ENABLED` (et `successLab`) | fermé | `false` | `false` | Hors de la 57 |
| `publicImpactStats` | `KPB_IMPACT_PUBLIC_STATS_ENABLED` (et `competitionReadiness`) | fermé | `false` | `false` | Hors de la 57 ; fermé, le bloc « preuve d'impact » de l'accueil se replie (404) |
| `eefTeaser` | `KPB_EEF_TEASER_ENABLED` (et `eef` faux) | fermé | `true` | `true` | Inchangé : la vitrine des builds 49 à 53 |
| `eef` | `KPB_EEF_ENABLED` | fermé | `false` | `false` | **Jamais** `true` : il retire la vitrine aux builds 49 à 53 |
| `eefSpace` | `KPB_EEF_SPACE_ENABLED` (ou `eef`) | fermé | `true` | `true` (état mesuré) | Déjà ouvert ; À VALIDER (propriétaire) : le garder ouvert pendant la revue (§3, point 1) |
| `eefHelpBubble` | `KPB_EEF_HELP_BUBBLE_ENABLED` | fermé | `false` | `false` | Après la décision d du pack 56 (qui répond au WhatsApp) : `eef-bubble-on` |
| `eefPrivateSchools` | `KPB_EEF_PRIVATE_SCHOOLS_ENABLED` | fermé | `false` | `false` | Après les décisions b et c du pack 56 : `eef-private-schools-on` |
| `followPushPrimer` | `KPB_FOLLOW_PUSH_PRIMER_ENABLED` | ouvert | absente | ouvert (`true`) | Interrupteur d'urgence : `false` seulement sur incident |
| `followOpeningAlert` | `KPB_FOLLOW_OPENING_ALERT_ENABLED` | ouvert | absente | ouvert (`true`) | Indispensable tant que le mode d'ouverture est `legacy` ou `outbox_alerts` (§6.3) |
| `openingAlertToggle` | `KPB_OPENING_ALERT_TOGGLE_ENABLED` | ouvert | absente | ouvert (`true`) | Interrupteur d'urgence |
| `followedScholarships` | `KPB_FOLLOWED_SCHOLARSHIPS_ENABLED` | ouvert | absente | ouvert (`true`) | Interrupteur d'urgence |
| `notificationsUnreadCount` | `KPB_NOTIFICATIONS_UNREAD_COUNT_ENABLED` | ouvert | absente | ouvert (`true`) | Interrupteur d'urgence |
| `followedScholarshipOptOut` | `KPB_FOLLOWED_SCHOLARSHIP_OPT_OUT_ENABLED` | ouvert | absente | ouvert (`true`) | Interrupteur d'urgence |
| `homeFollowedEntry` | `KPB_HOME_FOLLOWED_ENTRY_ENABLED` | ouvert | absente | ouvert (`true`) | Interrupteur d'urgence |
| `homeNextStep` | `KPB_HOME_NEXT_STEP_ENABLED` | ouvert | absente | ouvert (`true`) | Interrupteur d'urgence |
| `homeScholarships` | `KPB_HOME_SCHOLARSHIPS_ENABLED` | ouvert | absente | ouvert (`true`) | Interrupteur d'urgence |
| `homeDeadlines` | `KPB_HOME_DEADLINES_ENABLED` | ouvert | absente | ouvert (`true`) | Interrupteur d'urgence |
| `homePartners` | `KPB_HOME_PARTNERS_ENABLED` | ouvert | absente | ouvert (`true`) | Interrupteur d'urgence |
| `homeIntelligence` | `KPB_HOME_INTELLIGENCE_ENABLED` | ouvert | absente | ouvert (`true`) | Interrupteur d'urgence |
| `homeParcours` | `KPB_HOME_PARCOURS_ENABLED` | ouvert | absente | ouvert (`true`) | Interrupteur d'urgence |
| `homeCounselor` | `KPB_HOME_COUNSELOR_ENABLED` | ouvert | absente | ouvert (`true`) | Interrupteur d'urgence |
| `onboardingV2` | `KPB_ONBOARDING_V2_ENABLED` | fermé | absente | `false` | **Étape 2** de l'ordre ci-dessous : quand la 57 est à 100 % sur les deux boutiques et stable |
| `scholarshipMatch` | `KPB_SCHOLARSHIP_MATCH_ENABLED` | fermé | absente | `false` | **Étape 4**, la dernière : nationalité tranchée (consentement explicite, 18/10/2026 ; case dans l'app), puis la porte des 90 % de couverture, la recette en préproduction et la relecture des textes |
| `community` | `KPB_COMMUNITY_ENABLED` | fermé | absente | `false` | Communauté (C1 + C2) : **dans la 57 et déclarée dès sa soumission** (décision du propriétaire du 20/10/2026 : notes de revue §3, classification d'âge et formulaires, §4.4, `docs/CONSOLE_ANSWERS.md` §3 bis, `docs/STORE_READINESS.md`) ; OFF à la revue (« OFF at review time ») ; son ouverture est une décision d'exploitation du propriétaire, après l'approbation, sans nouvelle soumission ; À VALIDER (propriétaire) : la date |
| `assistBridge` | `KPB_ASSIST_BRIDGE_MODE` (vrai seulement à `on`) | fermé | absente | `false` (mode `shadow`) | Bot « Passerelle » (C3 bis), déclaré aux notes de revue de la 57 ; la clé n'affiche que l'interrupteur « Suggestions de l'équipe KPB ». Passage à `on` après au moins 2 semaines de `shadow` et moins de 10 % de faux positifs (critères validés le 18/10/2026, `docs/runbook-bot-passerelle.md`) ; source coach fermée ; ne pas toucher avant l'ouverture de la communauté |
| `referralInstallReferrer` | `KPB_REFERRAL_INSTALL_REFERRER_ENABLED` | fermé | absente | `false` | Parrainage : après la Data safety Play reportée (§4.1) et la politique à jour ; dernière des trois (`docs/runbook-campagne-ambassadeurs.md` §8) |
| `referralOnboardingCode` | `KPB_REFERRAL_ONBOARDING_CODE_ENABLED` | fermé | absente | `false` | Parrainage : avec ou juste après `referralLeaderboard`, avant le 1er novembre 2026 si la 57 est à 100 % |
| `referralLeaderboard` | `KPB_REFERRAL_LEADERBOARD_ENABLED` | fermé | absente | `false` | Parrainage : avant le 1er novembre 2026 (début de la compétition), `rulesUrl` posé sur la campagne (`https://kpbeducation.cloud/reglement-ambassadeurs-2026-11.html`, publié) ; À VALIDER (propriétaire) |

**Ordre d'ouverture après la 57** (chaque étape séparée de la précédente par au moins quelques
jours, pour ne pas mêler les signaux ; chacune se referme seule, sans build) :

1. **Lancement** : backend et admin déployés avec toutes les clés ci-dessus à leur défaut (les
   interrupteurs d'urgence ouverts, `onboardingV2` et `scholarshipMatch` fermés) et
   `KPB_SCHOLARSHIP_OPENING_MODE=legacy`. La 57 part ainsi.
2. **`KPB_ONBOARDING_V2_ENABLED=true`**, quand la 57 est à 100 % sur Play, la publication
   progressive iOS terminée, et les critères du §6.2 tenus. Seule la 57 lit la clé. Action
   `onboarding-v2-on` (tableau ci-dessous).
3. **Mode d'ouverture** `outbox_alerts` puis `outbox_followers` (§6.3).
4. **`KPB_SCHOLARSHIP_MATCH_ENABLED=true`**, seulement quand : la collecte de la nationalité est
   tranchée (consentement explicite, décision du propriétaire du 18/10/2026 ; case de consentement
   dans l'app) et les textes de la politique validés (19/10/2026) ; `GET /admin/scholarships/eligibility-coverage` en
   production montre au moins 90 % de bourses publiques structurées et fraîches ; la recette
   « Mes 10 bourses » de `docs/device-qa-build57.md` est jouée en préproduction ; les déclarations
   du §4 sont reportées. Procédure : registre, entrée du 15/10/2026 « chantier D ». Action
   `scholarship-match-on` (tableau ci-dessous) ; elle rappelle le consentement à la nationalité
   (décision c) et prévient, sans bloquer, si l'onboarding V2 (étape 2) n'est pas encore ouvert.

**Fenêtre de recette TestFlight, puis revue Apple.** Pendant la revue, `onboardingV2` et
`scholarshipMatch` valent **`false`** (checklist 57 §6 et §8). Une fenêtre de recette sur
TestFlight peut les ouvrir (`onboarding-v2-on`, `scholarship-match-on` : seule la 57 lit ces clés,
absente des boutiques), mais elle se **referme avant la soumission** par `onboarding-v2-off` et
`scholarship-match-off`, qui agissent même `dry_run` coché ; l'étape 2 de la checklist
(`/config/app`) le prouve ensuite. Les deux ouvertures l'affichent en avertissement, sans bloquer.

Les interrupteurs `eefHelpBubble` et `eefPrivateSchools` suivent leur propre calendrier (pack 56
§7), comme les trois drapeaux du parrainage (compétition du 1er au 10 novembre 2026, ordre
conseillé dans `docs/runbook-campagne-ambassadeurs.md` §8, à valider par le propriétaire).

Le port 22 du VPS n'étant pas joignable depuis un poste de travail, les drapeaux du parrainage, de
la communauté, des deux bots, de « Mes 10 bourses » et de l'onboarding V2 s'ouvrent et se referment par des **actions fermées du workflow
« VPS ops »** (`vps-ops.yml`), jamais en éditant le `.env` en SSH. Chacune n'écrit qu'**une** clé, à
une valeur écrite dans `.github/scripts/vps-ops.sh`, sauvegarde le `.env`, recrée `api` à
l'identique, vérifie la valeur lue par le conteneur puis la clé `features.*` servie par
`/config/app`. Les ouvertures simulent par défaut (`dry_run` coché) ; les retours arrière agissent
tout de suite. La trace est l'exécution du workflow (qui, quand, journal).

| Action `vps-ops` | Clé écrite | `/config/app` après |
|---|---|---|
| `referral-leaderboard-on` / `-off` | `KPB_REFERRAL_LEADERBOARD_ENABLED=true` / `false` | `referralLeaderboard` |
| `referral-onboarding-code-on` / `-off` | `KPB_REFERRAL_ONBOARDING_CODE_ENABLED=true` / `false` | `referralOnboardingCode` |
| `referral-install-referrer-on` / `-off` | `KPB_REFERRAL_INSTALL_REFERRER_ENABLED=true` / `false` | `referralInstallReferrer` |
| `community-on` / `-off` | `KPB_COMMUNITY_ENABLED=true` / `false` | `community` |
| `assist-bridge-on` / `-shadow` / `-off` | `KPB_ASSIST_BRIDGE_MODE=on` / `shadow` / `off` | `assistBridge` (vrai seulement à `on`) |
| `verif-bot-auto` / `-review` / `-off` | `KPB_COMMUNITY_VERIF_BOT_MODE=auto` / `review` / `off` | aucune clé servie : la preuve est la valeur lue par le conteneur |
| `onboarding-v2-on` / `onboarding-v2-off` | `KPB_ONBOARDING_V2_ENABLED=true` / `false` | `onboardingV2` |
| `scholarship-match-on` / `scholarship-match-off` | `KPB_SCHOLARSHIP_MATCH_ENABLED=true` / `false` | `scholarshipMatch` (la même clé ouvre ou coupe `/scholarships/match/*`) |

Aucune action `vps-ops` n'écrit en revanche les autres clés des chantiers G et K : elles se posent
dans le `.env` de production, puis le conteneur `api` est recréé. À VALIDER (propriétaire) : qui
écrit ce `.env`, et la trace qu'on en garde.

---

## 6. Déploiement par étapes

### 6.1 Ordre : serveur, puis admin, puis app

1. **Serveur** — workflow « Deploy backend (VPS) » (`deploy.yml`, `scope=full`) au SHA `RELEASE`,
   **avant** le préflight de release. **Seize migrations** additives entre `28ac82d` et `RELEASE`
   (quinze jusqu'à `8c215b5`, plus celle de la PR de correctifs de l'audit 57), nommées une à une à
   l'étape 1 de la checklist : `20261013120000_notification_delivery_opened_at`,
   `20261013121500_profile_last_app_build`, `20261015120000_scholarship_follow_fanout`,
   `20261015120100_scholarship_follow_indexes`,
   `20261015120200_scholarship_follow_notification_backfill`, `20261020120000_scholarship_match_v1`,
   `20261021120000_program_recognition`, `20261022120000_referral_campaigns`,
   `20261023120000_community`, `20261024120000_community_verif_bot`,
   `20261025120000_assist_bridge`, `20261026120000_campaign_purpose_promotions_consent`,
   `20261026130000_referral_prize_forfeit`, `20261027120000_promotions_push_opt_in`,
   `20261027130000_community_report_orphan_retention` et
   `20261028120000_profile_completion_without_consent`. Préalables de `docs/api-contracts.md`
   (« Migrations `20261015120000…120200_scholarship_follow_*` — exploitation ») : `db-info.yml`, la
   requête sur `ScholarshipCycle.academicYear` qui doit être vide, les index en `CONCURRENTLY`
   au-delà d'environ un million de lignes, **gel des activations admin** pendant le déploiement.
   `FCM_SERVICE_ACCOUNT_JSON` posé (sinon la 57 ne reçoit rien, §1.1). Puis `catalog:reconcile
   --dry-run` et `--apply` (catalogue 1.5.0), puis les opérations catalogue de la 57
   (`dedupe-omnes`, `import-omnes-spring`, `import-igensia`, `import-north-america` ; checklist,
   étape 1, point 5). `roll-omnes-fall-2027` attend que la 57 soit majoritaire (checklist, étape 9 :
   les builds 2.3.0 afficheraient les dates reconduites sans « à confirmer »).
2. **Admin** — dans le même passage du workflow (il remplace `api` et `admin` ensemble) ou, à la
   main, après la santé de l'`api`. Le nouvel admin envoie `notify` à l'activation d'un cycle, qu'un
   backend plus ancien refuse : jamais l'admin avant le serveur.
3. **App** — préflight `requires-new`, AAB, archive, soumission (checklist étapes 3 à 8).

Retour arrière : chaque fonction de la 57 a son interrupteur (§5) ; le backend se ramène au tag
précédent sans toucher au schéma (migrations additives) — mais un backend sans #351 coupe les
notifications de la 57.

### 6.2 Google Play 10 % → 50 % → 100 %, publication progressive iOS

**Play** (production par paliers ; un palier ne s'élargit qu'au feu vert du propriétaire) :

| Palier | Durée minimale | Passer au suivant si… |
|---|---|---|
| **10 %** | 48 h et au moins quelques centaines de sessions de la 57 | tous les critères ci-dessous |
| **50 %** | 72 h | tous les critères ci-dessous |
| **100 %** | — | — |

Critères de passage (seuils proposés, À VALIDER (propriétaire)) :

- **Plantages** : utilisateurs sans plantage de la 57 (Crashlytics) au moins égal à celui de la 56 sur
  la même fenêtre, et taux de plantage perçu (Android vitals) **sous 1,09 %**, le seuil de
  « mauvais comportement » de Google Play ;
- **ANR** : taux d'ANR perçu (Android vitals) **sous 0,47 %**, seuil Google Play, et pas au-dessus
  de la 56 ;
- **Erreurs serveur** : pas de hausse des réponses 5xx de l'API sur la fenêtre (journaux du VPS) ;
  `/api/health` rend `push.fcm=true` ; pas d'accumulation de `UserNotification.pushStatus` en échec
  (`pushLastError`) ; échecs de `sync_full_complete` (PostHog) pas au-dessus des **9,6 %** mesurés
  sur la 2.3.0 Android avant #350 ;
- **Retours** : aucun signalement bloquant (connexion impossible, notification jamais reçue, accueil
  vide) sur la fiche Play, l'App Store et la ligne WhatsApp.

Un critère tombe → **suspendre le déploiement** dans Play Console, couper l'interrupteur de la
fonction en cause (§5), corriger dans une 58.

**iOS** — cocher **« Phased release for automatic updates »** dans la fiche de version : 1 %, 2 %,
5 %, 10 %, 20 %, 50 %, 100 % sur sept jours (mises à jour **automatiques** seulement ; un
utilisateur peut toujours mettre à jour à la main depuis l'App Store). Mêmes critères ; pause
possible (30 jours au total au plus) depuis App Store Connect.

### 6.3 Mode d'ouverture : `legacy` → `outbox_alerts` → `outbox_followers`

`KPB_SCHOLARSHIP_OPENING_MODE` est lu à chaque appel (bascule sans redémarrage d'image) ;
`backend/src/modules/scholarships-index/opening/scholarship-opening.contract.ts`.

1. **`legacy`** (défaut) au déploiement et au lancement de la 57 : envoi immédiat aux seules alertes
   « M'avertir » non mises en sourdine. La 57 pose l'alerte avec le favori
   (`followOpeningAlert` ouvert), donc un « Suivre » est prévenu.
2. **`outbox_alerts`** : **après** le déploiement de l'admin, à un moment où personne n'active de
   cycle ; une première activation surveillée (aperçu « N seront prévenus », délai annulable de
   `KPB_OPENING_HOLD_SECONDS`, envoi par le worker, rien entre 21 h et 8 h locales).
   `KPB_PUSH_OUTBOX_ENABLED=false` est l'arrêt d'urgence du worker.
3. **`outbox_followers`** : favoris ∪ alertes. Avant : `npm run follow:mirror-alerts` (simulation
   par défaut) puis `npm run follow:mirror-alerts -- --apply`, une fois le mode posé. À VALIDER
   (propriétaire) : ce mode prévient **tous les favoris**, y compris ceux posés avec les builds 53
   et 56 sans la promesse « Suivre = prévenu » ; le décider quand la 57 est majoritaire.

### 6.4 `KPB_RECOMMENDED_APP_VERSION` et `KPB_MIN_APP_VERSION`

- **`KPB_RECOMMENDED_APP_VERSION=2.3.1`** — la **version marketing** de la 57, jamais `2.3.1+57`
  ni `57` : le serveur n'accepte qu'un `x.y.z` (`recommendedVersion()`), et l'app ignore le numéro
  de build (`lib/app/core/utils/version_utils.dart`, §1.2). À poser quand la 57 est **à 100 % sur
  Play et au 7e jour de la publication iOS** : pendant un palier Play, un utilisateur hors du
  pourcentage ne trouverait pas la mise à jour derrière le lien. Effet : un bandeau fermable chez
  les 2.3.0 (54 et suivantes) ; **aucun** chez les 2.2.0 (53), qui ne lisent pas la clé. Mécanique :
  une PR change `RECOMMENDED_APP_VERSION` dans `.github/scripts/vps-ops.sh`, puis l'action
  `recommended-version-set` (simulation, puis application).
- **`KPB_MIN_APP_VERSION`** — reste `0.0.0`. Le relever (à `2.3.1`) bloque toute version inférieure
  derrière un écran qu'on ne ferme pas, **53 comprise** (elle lit `minVersion`). Seulement quand
  **environ 85 %** des comptes actifs sont en 2.3.1 ou plus, mesuré sur `GET /admin/app-builds`
  (« part des comptes actifs sur cette build ou une plus récente » ; un compte vu sans en-tête est
  compté plus ancien). La mesure ne commence qu'au déploiement du backend de B : le déployer tôt
  donne une base. Jamais pendant un palier Play.

### 6.5 « Notre politique évolue » — notification au déploiement (chantier juridique 57)

La politique (§10) promet d'informer l'élève dans l'app **avant** qu'une modification importante
s'applique. Le code n'a **aucun mécanisme de réacceptation** : pas de version de politique
acceptée, et l'horodatage `consentedAt` de l'inscription n'est jamais redemandé (vérifié :
`onboarding_screen.dart`, `profiles.service.ts`). Aucun écran n'est ajouté. À faire **au
déploiement du serveur de la 57** (avant l'ouverture des paliers) : une campagne de l'admin en
finalité **`informational`** (message de service, donc envoyée à tous, sans le filtre
promotionnel), audience `all_users`, canal **push**, titre « Notre politique évolue », dont le
texte invite à relire la politique : nouveaux choix « Nouvelles et offres de KPB » (e-mail,
notification), base légale, durées de conservation.

**Texte validé par le propriétaire (19/10/2026)** — calendrier : **envoi le 24 octobre 2026**,
application de la politique le **31 octobre 2026** (7 jours de préavis, avant la compétition du
1er novembre).

**Où mène le tap (correctif de l'audit 57, F11).** Une campagne ne porte **ni bouton ni URL
externe** : le modèle n'a que titre, texte et canaux, et le serveur n'accepte qu'une **route
interne** de l'app (`route`, `^\/[A-Za-z0-9\-_/]*$`). Dans le formulaire de campagne de l'admin,
champ **« Route dans l'app »** → **« Politique de confidentialité — `/legal/privacy` »** : la
campagne pose `route = /legal/privacy`, l'aperçu et la liste des campagnes l'affichent (« Au tap :
Politique de confidentialité (/legal/privacy) »). Au tap :
- **2.3.1 (57)** : l'app ouvre la politique de confidentialité (route `/legal/privacy`, ajoutée
  par la PR de correctifs de l'audit) ;
- **2.3.0 (54 à 56) et plus anciennes** : la route leur est inconnue, l'app ouvre l'**accueil** ;
  la politique reste à deux gestes (Profil → Informations légales).
Le push n'a **pas de bouton d'action** : le tap ouvre la route. Les libellés d'action
(`notif_cta_*`) sont ceux de l'app, dans sa liste de notifications, que les campagnes de l'admin
n'alimentent pas : le push d'une campagne **n'écrit rien** dans le centre de notifications
(`PushSenderService`), et le canal `in_app` n'a aucune voie d'envoi (ses livraisons sont marquées
en échec, `campaign-executor.service.ts`). Le texte du push est donc **tout** ce que l'élève
reçoit.

| | FR | EN |
|---|---|---|
| Titre du push | Notre politique de confidentialité évolue | Our privacy policy is changing |
| Texte du push | Communauté, parrainage, nouvelles options de confidentialité : découvre ce qui change et tes choix. | Community, referrals, new privacy options: see what's changing and your choices. |
| Route au tap | `/legal/privacy` (2.3.1) ; accueil sur les 2.3.0 | `/legal/privacy` (2.3.1); Home on 2.3.0 |

Le « message dans l'app » ci-dessous, validé le 19/10/2026, **ne part pas avec la campagne** (pas
de canal in-app) : c'est le résumé de ce qui change, que la politique publiée détaille (§10 et
sections ajoutées). À VALIDER (propriétaire) : le garder comme texte de référence, ou le publier
ailleurs (page web, e-mail de service).

Message dans l'app (FR) :

> Avec la nouvelle version de KPB Education, on ajoute :
> - la communauté d'entraide : tes publications sont visibles des autres élèves sous la forme « Prénom I. », jamais avec ton e-mail ni ton téléphone ;
> - les suggestions de l'équipe KPB : si tu cherches de l'aide dans la communauté, on peut te proposer en privé la bonne fonction de l'app (tu peux les couper dans tes réglages) ;
> - le parrainage et la compétition des ambassadeurs, avec des protections contre la fraude ;
> - ta nationalité, utilisée seulement avec ton accord pour le test « Mes 10 bourses », et effaçable à tout moment ;
> - les nouvelles et offres de KPB, envoyées par e-mail ou par notification seulement si tu les acceptes.
>
> Ces changements s'appliquent à partir du 31 octobre 2026.

Message dans l'app (EN) :

> With the new version of KPB Education, we're adding:
> - the help community: your posts are visible to other students as "First name I.", never with your email or phone number;
> - suggestions from the KPB team: if you ask for help in the community, we may privately point you to the right app feature (you can turn them off in your settings);
> - referrals and the ambassador competition, with fraud protection;
> - your nationality, used only with your consent for the "My 10 scholarships" test, and erasable at any time;
> - KPB news and offers, sent by email or notification only if you accept them.
>
> These changes apply from October 31, 2026.

Si la 57 n'est pas déployée côté serveur le 24 octobre, décaler les deux dates en gardant 7 jours
de préavis.

---

## 7. Décisions du propriétaire

| | Décision | Recommandation | Où |
|---|---|---|---|
| **a** | Version marketing de la 57 | **2.3.1** (2.3.0 est en vente : ITMS-90062) | §1.2 ; checklist §0.2 |
| **b** | État réel de la 56 à consigner au registre | Date de téléversement, SHA archivé, « en vente depuis le 07/10/2026 » (App Store) — À VALIDER (propriétaire) | `docs/release-ledger.md` |
| **c** | Collecte de la nationalité | **Tranché le 18/10/2026** : consentement explicite, facultative, conservée tant que le compte existe, effaçable ; case ajoutée au test ; `scholarshipMatch` reste fermé (défaut inchangé) | §4.3 ; `docs/data-inventory.md` §5 |
| **d** | Moment de déclarer le test dans les consoles | Dès la soumission de la 57 | §4 |
| **e** | Espace « Études en France » ouvert pendant la revue | Le garder tel que mesuré (ouvert), le dire dans les notes | §3, point 1 |
| **f** | Seuils et durées des paliers Play | Ceux du §6.2 | §6.2 |
| **g** | `outbox_followers` pour les favoris des anciennes builds | Quand la 57 est majoritaire | §6.3 |
| **h** | XC-06 (finalité Marketing), D5 (prix FCFA) | **D5 tranché le 18/10/2026** (indicatif, payé hors store). **XC-06 tranché le 19/10/2026** : finalité « Marketing » déclarée ; l'e-mail promotionnel reste réservé par le code aux consentants (lien de désinscription) ; **push promotionnel en opt-in depuis le chantier juridique 57** (App Store 4.5.4), la finalité reste déclarée | §4.3 ; `docs/CONSOLE_ANSWERS.md` §0quater |
| **l** | Corrections juridiques (19/10/2026) | **Validées** : push promotionnel en opt-in ; base légale complétée (exécution du service, consentements listés, intérêt légitime pour l'analytique avec droit d'opposition et pour l'anti-fraude du parrainage, obligation légale pour la trace des prix versés) ; transferts sans « acceptation de la politique » ; signalements orphelins 12 mois (purge quotidienne) ; durées analytiques distinguées ; information des changements par notification (§6.5) ; mineurs absents du classement public sans autorisation vérifiée. Textes **validés par le propriétaire le 19/10/2026** ; enregistrements de session PostHog : **30 jours** (lu dans le projet le 19/10/2026) ; durée de rétention des **événements** PostHog / Firebase Analytics **À VALIDER (propriétaire)** | `docs/data-inventory.md` §5 bis, §8 ; §6.5 |
| **i** | Parrainage côté app dans la 57 (décidé le 17/10/2026) | Livré fermé ; politique **rédigée le 18/10/2026, validée le 19/10/2026** et Data safety à reporter (identifiant d'installation) ; pied de l'écran « Compétition » retenu et testé ; ordre d'ouverture des trois drapeaux — À VALIDER (propriétaire) | §1, §4, §5 ; `docs/runbook-campagne-ambassadeurs.md` §8 |
| **j** | Règlement de la compétition (18/10/2026) | **Tranché** : Wave sous 7 jours ; prix perdu après 15 jours et passé au suivant ; résultats le 17 novembre 2026 ; droit des Émirats arabes unis (Dubaï), réclamations à contact@kpbeducation.com ; proches de l'équipe exclus ; pièce d'identité au versement ; fiscalité à la charge du lauréat ; empreintes 180 jours. **Correctifs 57** : « Déclarer le prix forfait et réattribuer » (onglet Prix de l'admin) réattribue un prix non versé au suivant classé, même après un premier versement ; un prix versé ne bouge jamais (`docs/runbook-campagne-ambassadeurs.md` §7) | `docs/reglement-competition-ambassadeurs-novembre-2026.md` |
| **m** | Communauté et passerelle dans la 57 (20/10/2026) | **Tranché** : déclarées à Apple et à Google **dès la soumission de la 57** (fonctions modérées, OFF au moment de la revue) : notes de revue, classification d'âge (contenu généré par les utilisateurs, interaction entre utilisateurs), Data safety / App Privacy (« Autre contenu généré par l'utilisateur ») ; ouverture ensuite sans nouvelle soumission | §3, §4.4, §5 ; `docs/CONSOLE_ANSWERS.md` §3 bis |
| **k** | Conservations et bots (18/10/2026) | **Tranché** : empreintes 180 jours, événements « Passerelle » 12 mois, contenus supprimés de la communauté 30 jours ; textes et seuils « Passerelle » validés, `shadow` ≥ 2 semaines, < 10 % de faux positifs ; « Vérif » en `auto` après 50 réponses validées sans correction | `docs/data-inventory.md` §6, §7, §7 bis, §7 ter ; runbooks des bots |

---

## 8. Ce que ce pack ne tranche pas, et ce qu'il n'a pas pu vérifier

| Question | Qui | Où |
|---|---|---|
| La build en vente est-elle la 56 ? (les boutiques n'affichent que « 2.3.0 ») | Propriétaire | App Store Connect, Play Console |
| `FCM_SERVICE_ACCOUNT_JSON` est-il déjà dans le `.env` de production ? | Propriétaire | `/api/health` → `push.fcm` après le déploiement |
| Les cas de `docs/device-qa-build57.md` | **Jamais joués sur appareil** : écrits d'après le code | Recette sur TestFlight / Play Internal |
| Le moyen d'envoyer une notification à un seul compte de test | Propriétaire | `docs/device-qa-build57.md`, §Push |
| L'anglais n'est pas atteignable sur la build soumise (`kShippedLocale = 'fr'`, `lib/app/core/i18n/app_locale.dart`) | Constat | Les textes EN de la politique sont gardés par la parité, pas par un appareil |
| Le greffon natif `play_install_referrer` compile-t-il avec l'AGP 8.9.2 / Kotlin 2.2.0 du projet ? (le greffon déclare AGP 8.13.0 et Kotlin 2.2.10 dans son `buildscript`) | **Vérifié** : la CI de la PR #368 a construit l'APK debug (« Build Android APK (debug validation) » vert, 18/10/2026) | L'**AAB signé** reste à produire au moment de la release (checklist, étape 3) |
| Les textes juridiques rédigés le 18/10/2026 (politique in-app et web, CGU, page de suppression) | **Validés par le propriétaire le 19/10/2026** (relecture des 19 passages, après les corrections juridiques #372) ; durée des enregistrements PostHog (30 jours) ajoutée le même jour | Sections listées au registre, entrée « Finalisation de la build 57 » |
| La lecture réelle du referrer (installation depuis le lien `invite.html`) | Recette appareil (Play, test interne avec un lien `referrer=`) | `docs/device-qa-build57.md`, section « Parrainage » |
