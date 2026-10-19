# Store readiness — privacy declarations, age rating & performance budget

> **Issue:** KPB-68 (Epic 8 — IA responsable, conformité & store-readiness).
> **Status of dependencies:** the data-minimization and account-deletion
> behaviours described here are delivered by PRs **#58** (KPB-66 — PII
> minimization + AI consent), **#59** and **#60** (KPB-67 — account deletion,
> data export, minor/guardian consent). This document assumes those have
> merged. Keep it updated whenever a data flow or third-party changes.

The **code-derived** inventory of processors and data types lives in
`[data-inventory.md](data-inventory.md)` (lot 9). This file remains the
copy-paste source for the store forms. If the two diverge, the inventory
(and the code it cites) wins.

This is the source of truth for the **App Store Privacy "nutrition labels"**,
the **Google Play Data Safety** form, the **age rating**, and the **measured
performance budget**. Copy the relevant sections into App Store Connect / the
Play Console at submission time.

---

## 1. Data collection inventory

Ce que l'app collecte, où ça vit, et — quand un tiers le voit aussi — qui le
reçoit.

**Responsable du traitement : KPB Global L.L.C-FZ**, société à responsabilité
limitée de zone franche immatriculée auprès de la Meydan Free Zone (Meydan City
Corporation, Émirat de Dubaï) sous la licence n° 2537631.01, siège Meydan
Grandstand, 6th floor, Meydan Road, Nad Al Sheba, Dubaï (EAU) ; KPB Education en
est un **service**, pas une entité. C'est l'identité que porte la politique
livrée dans l'app (`app_translations.dart:624-625`, EN `:3425-3426`) et la page
web (`web/public/confidentialite.html:17`) : les deux consoles doivent porter la
même, sinon la fiche et la politique liée se contredisent. Régime applicable :
**décret-loi fédéral EAU n° 45 de 2021**, autorité **UAE Data Office**
(`app_translations.dart:628`, EN `:3429`) — l'analyse de transferts est donc
**EAU → États-Unis**, pas UE → États-Unis.

| Data | Collected | Stored in | Notes |
|---|---|---|---|
| Name (full name) | Onboarding | Own backend (Postgres) | **Coach : jamais transmis** — `fullName` existe dans le contexte (`coach-prompt.builder.ts:4`) mais n'est interpolé dans aucune invite (`:103`, `:136`). **Outils :** `/tools/cv-summary` et `/tools/personalize-letter` acceptent encore `name` (le PDF l'imprime) sans le recopier dans l'invite (`tools.service.ts:73-74`, `:126`) ; les 4 écrans restent masqués (`app_config.dart:149`). **Orientation : la fuite était réelle**, fermée par **PR #216** (projection close `{currentLevel, targetCountryIds, fieldIds, preferredLanguage}`, garde `orientation.prompt-privacy.spec.ts`). **#216 est fusionnée ET déployée** : la projection close vit à `orientation.service.ts:166` sur main, et la prod servait `84554c04f106` — qui la contient — au relevé du 24/08/2026 (`GET /api/health/version`). La case « pas de nom chez Groq » est donc cochable. Le nom transite aussi en paramètre d'URL vers notre propre backend pour le flux coach (`app_api_client.dart:940` → `coach.controller.ts:52`, `:62`), qui ne le relaie pas. |
| Email | Onboarding / OAuth | Supabase Auth + Postgres | **Ne part plus chez OneSignal** (correctif 2 du 18/08) : `login()` ignore délibérément son paramètre `email` (`onesignal_service.dart:73-75`) et `addEmail` a disparu du dépôt (`grep -rn addEmail lib/` = 0). Garde : `test/core/services/onesignal_no_email_test.dart`. Resend (transactionnel) et Mautic (après consentement seulement, correctif 6) restent des sous-traitants nommés en politique. |
| Phone + WhatsApp | Onboarding | Postgres | Jamais écrits dans `SharedPreferences` (`local_app_repository.dart:133`). Non transmis à OneSignal (`syncOneSignalIdentity`, `app_controller.dart:1902-1918`, ne les lit pas). |
| Country of residence | Onboarding | Postgres + local | Part aussi chez OneSignal comme étiquette `target_country` lorsqu'aucun pays visé n'est renseigné (`app_controller.dart:1905-1907`, `:1914`). |
| Birth date | Onboarding (students) | Postgres + local (`local_app_repository.dart:160`) | Blocage strict sous 16 ans (`onboarding_screen.dart:223`) ; tuteur exigé sous 18 (`:218`, `:430-436`). |
| Guardian name/contact + consent | Onboarding (declared minors) | Postgres ; nom + consentement aussi en local (`local_app_repository.dart:161`) | **Contact du tuteur jamais persisté sur l'appareil** : `guardianContact` n'apparaît nulle part dans `local_app_repository.dart`. |
| Profile photo | Profile | Backend storage — **objet privé**, aucune URL publique, flux authentifié (`profiles.controller.ts:63-66`) | Réduite à 512 px avant tout accès réseau (`app_api_client.dart:161-163`), scannée avant écriture (`profiles.service.ts:270` → `assertAvatarScannerReady`). En prod sans `CLAMAV_HOST`, la route **échoue fermé** (`profile-avatar.policy.ts:70-76`) : aucune photo n'entre. Condition d'ops — pas une raison de retirer la déclaration. |
| Voice dictation | Support / case request | **Aucun octet audio chez KPB** : seul `result.recognizedWords` est lu et seul le texte devient un message | **Locale demandée ; plateforme seulement sur accord explicite** (correctif 1 du 18/08). L'unique `listen()` pose `onDevice` (`speech_input_service.dart:86-90`) ; en cas d'échec local, l'app REFUSE la session et ne réessaie avec le service de la plateforme qu'après un dialogue d'accord dans le flux (`case_tunnel_flow.dart:881-888`, dialogue `:958`, seam `:975-978`). **Garantie inégale, à ne jamais écrire absolue** : iOS = contrat dur (le greffon refuse la session si le local manque) ; Android = simple préférence `EXTRA_PREFER_OFFLINE`, dont le repli réseau est invisible depuis Dart. Gardes : `test/core/services/speech_input_on_device_test.dart` + les deux tests du tunnel de dictée. Permissions inchangées : `RECORD_AUDIO`, `NSMicrophoneUsageDescription` + `NSSpeechRecognitionUsageDescription`. |
| Academic profile (level, field, target countries, grades, budget) | Onboarding | Postgres + local | Budget envoyé à Groq **en tranche** seulement (`coach-prompt.builder.ts:28-40`). Niveau et pays visé partent aussi chez OneSignal comme étiquettes (`app_controller.dart:1919-1921`). |
| Cases: messages, timeline | In-app | Postgres + file storage | **L'app n'envoie aucun fichier en 49** (`app_config.dart:182`) : l'étape documents est remplacée par un renvoi WhatsApp (`case_tunnel_flow.dart:345-346`). Fichiers téléversés par des builds antérieures encore en stockage. |
| Saved items, orientation answers, search history | In-app | Postgres (`orientation.service.ts:200`) + local (`app_snapshot.dart:56`, `:63` ; `local_app_repository.dart:66`, `:105`) | Le **terme de recherche** part aussi à Firebase Analytics en texte libre (`analytics_service.dart:434-437`). |
| Coach (AI) messages | In-app | Postgres ; **transmis à Groq (US)** (`llm.service.ts:53`) | Texte libre — voir §2. Les routes IA sont derrière `AiConsentGuard` (`orientation.controller.ts:29`, `:37` ; `tools.controller.ts:13` ; `document-review.controller.ts:12`). |
| **Push identity** (ex-« Push token ») | Runtime, dès qu'un profil existe | OneSignal (US) | ⚠️ **Plus que le jeton** : identifiant de compte (`OneSignal.login` — `onesignal_service.dart:80` ← `app_controller.dart:1906`) et **4 étiquettes** `account_type / level / target_country / locale` (`onesignal_service.dart:85` ← `app_controller.dart:1919-1921`). **L'e-mail ne part plus** (correctif 2 du 18/08 ; garde `onesignal_no_email_test.dart`). Actif par défaut en 49 : App ID compilé non vide (`app_config.dart:58-64`, aucun `--dart-define` ne l'écrase dans les chaînes de build), `initialize()` inconditionnel (`main.dart:120`), envoi à trois points d'entrée (`main.dart:125-126` ; `app_controller.dart:557`, `:635`). **Aucun consentement** : `requestPermission()` rend `Future<void>` et jette son résultat (`onesignal_service.dart:60-67`) — un refus système n'empêche pas l'envoi ; `analyticsOptOut` ne route que vers Firebase + PostHog (`app_controller.dart:512-514` → `analytics_service.dart:96-108`). Périmètre négatif : ni e-mail (depuis le correctif 2), ni nom, ni téléphone, ni WhatsApp, ni date de naissance, ni document (`user.dart:77`, `:78`, `:123`, `:127-128` — aucun n'est lu par `syncOneSignalIdentity`). |
| Newsletter bourses : consentement + coordonnées | Profil / onboarding | Postgres ; **Mautic auto-hébergé quand configuré** | ⚠️ Ce qui partirait n'est pas « l'e-mail après opt-in » : `upsertContact` envoie e-mail, **prénom + nom**, téléphone, WhatsApp, pays, langue (`mautic.service.ts:99`, `:105-109`) — mais **plus jamais sans consentement** : depuis le correctif 6 du 18/08, `resolveNewsletterAction` décide AVANT tout appel et « jamais consenti » ne pousse rien (`newsletter-sync.service.ts:45`, `:86`). **Inerte tant que Mautic n'est pas configuré** — `isConfigured` faux → sortie immédiate (`mautic.service.ts:64-68`), variables vides par défaut. La case « partagé après opt-in » est donc vraie du code ; elle ne devient effective qu'à la configuration. |
| App interaction events | Runtime | Firebase Analytics ; **PostHog seulement si le build porte une clé** | Noms d'événements + paramètres non-PII, **sauf le terme de recherche** et **sauf `current_level`** (`eef_interest_declared`, ajouté par l'espace « Études en France »), qui est un attribut de profil académique et non un nom d'événement. Aucune case ne bascule pour autant — *App activity → App interactions* et *Usage Data → Product Interaction* sont déjà à « Yes » — mais la description ci-contre serait fausse sans cette réserve. Le miroir PostHog est sauté quand `posthogEnabled` est faux (`app_config.dart:87`). |
| Session recordings (screen replays) | Runtime | PostHog (US) — **conditionnel** | Captures de navigation, **tous les textes et images masqués** à la capture (`main.dart:71-75`) ; identité = UUID backend (`analytics_service.dart:69-73`), pas de PII. ⚠️ Tout le câblage PostHog est inerte quand `POSTHOG_API_KEY` est vide, ce qui est le **défaut compilé** (`app_config.dart:72-75`, `:87` ; `main.dart:66`) — voir « à trancher » ci-dessous. |
| Crash diagnostics | On crash | Firebase Crashlytics | Traces + clés de synchro non-PII (compteurs et horodatages : `sync_telemetry.dart:14-16`, `:29-35`, via `:96`). **Opt-out réel depuis le correctif 3 du 18/08** : « Analyse d'usage » coupe les TROIS collecteurs — `applyCrashlyticsConsent` appelle `setCrashlyticsCollectionEnabled` (`crashlytics_observability.dart:50-52`), l'état est appliqué au démarrage, et un refus purge la file des rapports non envoyés (`deleteUnsentReports`, `:59`). Au manifeste et au plist, la collecte démarre ÉTEINTE (`firebase_crashlytics_collection_enabled=false`, `AndroidManifest.xml:160` ; `Info.plist`). Garde : `test/core/services/analytics_consent_test.dart`. **Non lié à l'utilisateur** : aucun `setUserIdentifier` — les 6 usages de l'instance sont tous des écritures (`main.dart:50`, `:52`, `:179` ; `app_logger.dart:39` ; `safe_crashlytics.dart:42` ; `sync_telemetry.dart:96`). |
| Identifiant publicitaire Android (`AD_ID`) | **Retirée du binaire** (correctif 4 du 18/08) | — | La permission qu'héritait le manifeste fusionné de `firebase_analytics` est RETIRÉE par `tools:node="remove"` (`AndroidManifest.xml:48-49`) et la collecte de l'identifiant est coupée dans le SDK de mesure lui-même (`google_analytics_adid_collection_enabled=false`, `:110`). **La preuve est au binaire, plus au raisonnement** : `scripts/preflight-android-aab.sh:123` ÉCHOUE si `AD_ID` figure dans le manifeste de l'AAB signé — l'ancienne « réserve de preuve » (un APK v45 traînant sous build/) est remplacée par cette porte exécutable, à passer sur l'AAB 49 le jour J. |

**Aucun SDK publicitaire, aucune attribution, aucun courtier de données, aucun
suivi inter-applications.** Ce qui ship côté identifiant publicitaire est
`play-services-ads-identifier:18.0.0` (`sdkDependencies.txt:944`), une
bibliothèque de **lecture** tirée par la chaîne de mesure Firebase, pas une
régie : rien dans le code ne lie ces données à des données tierces à des fins
publicitaires, donc « Used for tracking » reste **Non** partout. Le masquage du
replay est réel (`main.dart:74-75`) et l'identifiant envoyé à PostHog après
connexion est un UUID (`analytics_service.dart:69-73`). L'interrupteur
**Profil → « Analyse d'usage »** (`profile_screen.dart:735-745` →
`app_controller.dart:503-508`, persisté `local_app_repository.dart:46`, `:97`)
coupe **les trois collecteurs — Firebase Analytics, PostHog et Crashlytics —
depuis le correctif 3 du 18/08** (garde `analytics_consent_test.dart`).
OneSignal reste hors interrupteur (`syncOneSignalIdentity` ne lit aucun
drapeau) : c'est la ligne « Push identity » qui le couvre.

> **Cases de formulaire dont la réponse change — avec la raison, en une ligne.**
>
> | Console → case | Réponse | Raison (adossée au code) |
> |---|---|---|
> | Play → Sécurité des données → Informations personnelles → **Adresse e-mail** | Collectée, finalité « Fonctionnalité de l'application » — **le partage OneSignal a disparu** | `addEmail` retiré (correctif 2 du 18/08) ; `login()` ignore son paramètre `email` (`onesignal_service.dart:73-75`) ; garde `onesignal_no_email_test.dart`. |
> | Play → Identifiants → **ID utilisateur** | Collecté **et partagé** | `OneSignal.login(profile.id)` — `onesignal_service.dart:80` ← `app_controller.dart:1906`. |
> | Play → Informations personnelles → **Autres informations** (ou Activité → Autres actions, selon la ventilation retenue) | Collectées **et partagées** | 4 étiquettes de ciblage `account_type / level / target_country / locale` — `app_controller.dart:1919-1921` → `onesignal_service.dart:85`. |
> | Play → App info & performance → **Journaux de plantage** | Collectés, **collecte FACULTATIVE** | Depuis le correctif 3 : `applyCrashlyticsConsent()` appelle `setCrashlyticsCollectionEnabled`, l'interrupteur « Analyse d'usage » coupe les trois collecteurs, l'état est appliqué au démarrage, et un refus purge la file des rapports non envoyés. Garde `test/core/services/analytics_consent_test.dart`. |
> | Play → Activité dans l'appli → **Interactions, historique de recherche** | Collectées, **optionnelles** | L'interrupteur coupe réellement les deux SDK — `analytics_service.dart:96-108` ← `profile_screen.dart:735-745`. |
> | Play → **Identifiants de l'appareil ou autres identifiants** | Collectés (Analyses), **désactivables** | Même interrupteur (`analytics_service.dart:98`). L'identifiant PUBLICITAIRE, lui, n'est plus en cause : permission retirée du manifeste fusionné et collecte coupée dans le SDK (`AndroidManifest.xml:48-49`, `:110`). |
> | Play → Contenu de l'appli → **« L'appli utilise-t-elle un identifiant publicitaire ? »** | **NON** | Permission retirée du manifeste fusionné (`AndroidManifest.xml:48-49`, correctif 4 du 18/08) ; vérifié sur l'AAB signé par `scripts/preflight-android-aab.sh:123`, qui échoue si elle réapparaît. Play recoupe cette réponse avec le manifeste : répondre OUI serait désormais la réponse fausse. |
> | Play → **Audio → Enregistrements vocaux** | **Non collecté** — traitement éphémère : locale demandée, service de la plateforme seulement après accord explicite, aucun octet audio chez KPB, texte seul conservé | Voie A implémentée et renforcée (correctif 1 du 18/08) : `onDevice` posé (`speech_input_service.dart:86-90`), dialogue d'accord avant tout repli (`case_tunnel_flow.dart:881-888`). |
> | Apple → Contact Info → **Email Address** | Collected, **Linked to the user**, App Functionality, **not** used to track | Compte KPB (Supabase Auth + Postgres) ; l'envoi OneSignal a disparu (correctif 2 du 18/08). |
> | Apple → Identifiers → **User ID** | Collected, **Linked** | `OneSignal.login` (`onesignal_service.dart:80`). |
> | Apple → Diagnostics → **Crash Data** | Collected, **NOT linked to the user**, not for tracking | Aucun `setUserIdentifier` sur Crashlytics ; les 6 usages sont des écritures. |
> | Apple → **Audio Data** (User Content / Sensitive selon le questionnaire) | **Not collected** — même raisonnement éphémère que la case Play Audio | `speech_input_service.dart:86-90` ; accord explicite `case_tunnel_flow.dart:881-888`. |
> | Apple → **aucune case ne change du fait d'`AD_ID`** | — | Permission Android ; l'IDFA / ATT n'est pas déclenché par elle. Le volet iOS n'a pas été audité ici : **non vérifié**, pas « rien à déclarer ». |

> **Ne pas sur-déclarer pour autant.**
> - **L'audio dicté n'arrive jamais chez KPB ni sur son backend** et aucun octet
>   audio n'est stocké (`speech_input_service.dart:37-39`). La formulation juste
>   est « audio traité par le service de reconnaissance de la plateforme, texte
>   seul conservé » — **pas** « KPB collecte des enregistrements vocaux ».
> - **Aucune case Localisation.** Le module `OneSignalLocation` est lié, d'où
>   `NSLocationWhenInUseUsageDescription` (`Info.plist:56-63`, ITMS-90683), mais
>   il n'est jamais appelé : `OneSignal.Location` n'apparaît nulle part dans
>   `lib/`. La politique le dit déjà (`app_translations.dart:638`).
> - **Les enregistrements de session ne sont pas du « User Content »** : textes
>   et images sont masqués à la capture (`main.dart:74-75`).
> - **Aucun téléversement de document actif en 49** (`app_config.dart:182`,
>   `case_tunnel_flow.dart:345-346`) : la ligne Photos/Files de §4 couvre
>   l'avatar et les fichiers d'anciennes builds, pas un envoi in-app vivant.
> - **Lecteur YouTube embarqué** — hors tableau parce qu'il ne fait entrer
>   aucune donnée chez KPB, mais il en fait sortir : `youtube_player_flutter`
>   (`pubspec.yaml:82`) rend une WebView `flutter_inappwebview` qui charge
>   `youtube-nocookie.com` et `https://www.youtube.com/iframe_api` dès la
>   construction du widget (`raw_youtube_player.dart:77`, `:254`), et les
>   vignettes `img.youtube.com` (`parcours.dart:80`, `catalog.dart:913`) sont
>   rendues dès l'accueil, y compris pour un visiteur non connecté
>   (`home_screen.dart:238-243`). Google reçoit IP + user-agent. **Aucun type de
>   données Play ne bascule pour autant** (l'IP n'est pas un type déclarable) :
>   ce qui change est la ligne destinataire de §2 et la politique publiée.

> **À trancher avant de cocher — deux réponses ne sont pas déductibles du dépôt.**
>
> 1. **PostHog.** Les deux lignes PostHog (événements, replay) ne sont vraies
>    que si le binaire 49 porte `POSTHOG_API_KEY`. Défaut compilé **vide**
>    (`app_config.dart:72-75`) et tout le câblage est sauté quand vide (`:87`,
>    `main.dart:66`) ; la CI injecte un secret qui peut lui-même être vide
>    (`.github/workflows/flutter-ci.yml:286`, `:367`) ; le préflight d'archive
>    iOS ne vérifie que la **présence du nom** de la variable
>    (`scripts/preflight-ios-archive.sh:70`), donc `POSTHOG_API_KEY=` vide passe
>    le contrôle. Vérifier la valeur du build effectivement livré : déclarer
>    replay + analytique PostHog sur un binaire sans clé serait une
>    sur-déclaration ; l'omettre sur un binaire avec clé, une sous-déclaration.
> 2. **Dictée vocale — TRANCHÉ le 18/08/2026 (voie A, renforcée).**
>    `onDevice` est posé (`speech_input_service.dart:86-90`) et le repli vers le
>    service de la plateforme exige un accord explicite dans le flux
>    (`case_tunnel_flow.dart:881-888`). La garantie reste INÉGALE — iOS contrat
>    dur, Android préférence au repli invisible — donc jamais « converted to
>    text on device » sec. **Fait le 24/08/2026** : les trois politiques (in-app
>    FR/EN et web) nomment le service de reconnaissance de la plateforme et
>    l'embed YouTube parmi les destinataires, et la garde de parité exige
>    désormais le mot « reconnaissance » pour la permission iOS
>    correspondante.
> 3. **Taille du binaire** : non mesurable ici, `flutter build apk --release`
>    refuse sans `android/key.properties` (garde volontaire). Les cases de §7
>    restent _TBD_ — ne rien y inventer.

> **Ce que la CI garde, et ce qu'elle ne garde pas.** Trois fois sur ce projet,
> le défaut était caché par l'outil censé le détecter ; ces cases-ci reposent
> donc sur une relecture humaine jusqu'à correction du harnais.
> - ~~Aucun test n'assert `SpeechListenOptions.onDevice`~~ — **corrigé le
>   18/08** : `test/core/services/speech_input_on_device_test.dart` et trois
>   autres fichiers l'exercent.
> - `test/core/privacy_disclosure_parity_test.dart` ne compare que des
>   **noms** de sous-traitants, jamais la charge déclarée — limite toujours
>   vraie. Son exemple historique est clos : les trois politiques décrivent
>   désormais la charge OneSignal réelle (identifiant de compte + 4 attributs,
>   jamais l'e-mail — la page web a été alignée le 24/08).
> - ~~Le même test rangeait `youtube.com` parmi les non-processeurs~~ —
>   **corrigé le 24/08** : `youtube.com`/`youtu.be` sont mappés processeur
>   (jeton « YouTube » exigé dans les deux politiques), et la garde a été vue
>   ROUGE sur l'état d'avant le correctif.
> - Le **manifeste fusionné** doit être vérifié dans le binaire de release avec
>   `bundletool dump manifest --bundle <aab>`, jamais seulement dans le
>   manifeste source.

> **Divergence avec `data-inventory.md` : RÉSORBÉE le 18/08/2026.** Ses lignes
> dictée (`:42`) et opt-out (`:45`) disent désormais la même chose que le code
> (locale demandée + accord explicite ; l'interrupteur coupe bien les trois
> collecteurs). Si une nouvelle divergence apparaît, c'est toujours
> `data-inventory.md` qui l'emporte (lignes 10-13) — après vérification du
> code, qui l'emporte sur les deux.

> **Où « vit » réellement la donnée.** Le projet Supabase compilé par défaut est
> `hijzqsljasbobjrjotjy` (`app_config.dart:197-199`) et l'API de production est
> `https://api.kpbeducation.cloud/api` (`app_config.dart:250`), servie par le VPS
> KPB (la politique le nomme : `app_translations.dart:654`). Leurs **régions** ne
> sont pas lisibles dans le dépôt : Supabase en `eu-west-3` (Paris) et VPS
> Hostinger en France ont été vérifiés hors dépôt (console Supabase / whois) —
> **NON PROUVÉ par le code**, à confirmer avant de remplir §2. Hébergement UE,
> responsable du traitement aux EAU, sous-traitants US nommés à part : les trois
> se cumulent, aucun n'annule l'autre.

---

## 2. Third-party processors

> **Responsable du traitement (à recopier tel quel dans les deux consoles, PR #214).**
> L'éditeur et le responsable du traitement est **KPB Global L.L.C-FZ**, société
> à responsabilité limitée de zone franche immatriculée auprès de la **Meydan
> Free Zone** (Meydan City Corporation, Émirat de Dubaï) sous la licence
> **n° 2537631.01**, siège Meydan Grandstand 6th floor, Meydan Road, Nad Al
> Sheba, Dubaï, EAU. **KPB Education est un service de cette société, pas une
> entité.** Publié dans l'app et sur le web : `app_translations.dart:624` (FR),
> `:3425` (EN), `web/public/confidentialite.html:17` ; CGU/loi applicable
> `app_translations.dart:696`, `:700`.
> — **raison** : la console et la politique liée doivent nommer la même entité,
> sinon la fiche est incohérente avec l'URL de politique qu'elle référence.
> Régime applicable : **décret-loi fédéral EAU n° 45 de 2021**, autorité **UAE
> Data Office**, for de Dubaï. L'analyse de transferts est donc **EAU → États-Unis**
> pour les sous-traitants US, alors que **l'hébergement est en UE** (voir les deux
> premières lignes du tableau).

| Processor | Region | Receives | Purpose | Linked to user | Used for tracking |
|---|---|---|---|---|---|
| **Own backend (NestJS/Postgres)** | **France** — VPS Hostinger, `api.kpbeducation.cloud` (`app_config.dart:250` ; `docs/DEPLOYMENT.md:11`) | All app data above | App functionality | Yes | No |
| **Supabase Auth** | **eu-west-3 (Paris)** — projet `hijzqsljasbobjrjotjy` (`app_config.dart:197-200`) | Email, Google OAuth identity, session tokens | Authentication | Yes | No |
| **Groq** (LLM) | **United States** (`llm.service.ts:53`) | **Deux surfaces, deux charges.** Coach : profil pseudonymisé sans nom + budget en **tranche** (`coach-prompt.builder.ts:28`, `:103-108`) + les messages libres de l'étudiant. Orientation : **projection close** `{currentLevel, targetCountryIds, fieldIds, preferredLanguage}` + les réponses au questionnaire (`orientation.service.ts:166-179`, `:190-194`, numérotation post-#216) — **plus jamais l'objet `profile` du client** | Generate AI coach replies / orientation explanations | No (pseudonymized) | No |
| **OneSignal** | US | Push token, external id = `UserProfile.id` (`onesignal_service.dart:80`), ~~l'adresse e-mail~~ (**retirée par le correctif 2** : `addEmail` supprimé, argument retiré du site d'appel `app_controller.dart`, garde `test/core/services/onesignal_no_email_test.dart`), et **4 étiquettes de profil** : `account_type`, `level`, `target_country`, `locale` (`:85` ; charge construite en `app_controller.dart:1906-1921`) | Push notifications **+ segmentation** | Yes | No |
| **Firebase Analytics** | Google (US) | App-instance id, device/OS, coarse region, interaction events ; **search terms** (`analytics_service.dart:434-436`) ; **+ identifiant publicitaire Android** — permission `AD_ID` dans le manifeste fusionné, aucun opt-out déclaré (voir note « AD_ID ») | Product analytics | Yes (app-instance) | No |
| **PostHog** | **United States** — `https://us.i.posthog.com` par défaut (`app_config.dart:79-82`) | Interaction events + screen views ; **le terme de recherche en clair**, miroité depuis Firebase (`analytics_service.dart:437`) ; backend user id (UUID) après login (`app_controller.dart:558-561`) ; **content-masked** session recordings ; device/OS. **Inerte si `POSTHOG_API_KEY` est vide** (`app_config.dart:72-87` ; garde `analytics_service.dart:45-46`) | Product analytics, session replay | Yes (UUID after login) | No |
| **Firebase Crashlytics** | Google (US) | Crash stack traces, device model, OS, app version. Aucun `setUserIdentifier` dans le dépôt | Stability/diagnostics | Pseudonymous | No |
| **Reconnaissance vocale de la plateforme — Apple / Google** | Apple, Google (US/global) | **L'audio dicté**, quand l'utilisateur touche « dicter » dans le tunnel de dossier. Le plugin ne rend à l'app que du **texte** (`speech_input_service.dart:37-39`) ; **aucun octet audio n'atteint KPB ni son backend**, et aucun identifiant KPB ne part avec l'audio | Dictée du message de demande d'accompagnement | No (aucun identifiant KPB transmis) | No |
| **Resend** | **United States** | Adresse e-mail (`to`) + objet + corps du message (`campaign-mail.service.ts:18-40`) | Transactional / campaign email | Yes | No |
| **Mautic** (self-hosted) | KPB VPS (France) | **7 champs, pas seulement l'e-mail** : e-mail, `firstname`/`lastname` découpés depuis `fullName`, `phone`, `mobile` (= numéro WhatsApp), `country` (pays de résidence), `preferred_locale` (`mautic.service.ts:99-115`) | Scholarship newsletter — **et depuis le correctif 6, SEULEMENT après consentement** : `resolveNewsletterAction` distingue « jamais consenti » (aucun appel) de « consentement retiré » (désinscription nécessaire), là où `null === false` faisait partir les données d'un utilisateur qui n'avait jamais dit oui | Yes | No |
| **CinetPay** | (provider region) | Intent id, montant, devise, description **+ `customer_email`, `customer_phone_number`, `customer_name`** (`cinetpay.adapter.ts:48-62`) | Paid accompaniment (checkout serveur, non atteignable depuis l'app 49) | Yes | No |
| **PayDunya** | (provider region) | Facture : description, montant, `intent_id` — **aucune donnée client** (`paydunya.adapter.ts:61-82`, aucune occurrence de `customer`) | Paid accompaniment (idem) | Pseudonymous (intent id) | No |
| **Embedded web — lecteur YouTube IFrame (Google)** | Google (US/global) | **Adresse IP + user-agent + identifiant de la vidéo**, à chaque ouverture du lecteur (`youtube-nocookie.com` et `https://www.youtube.com/iframe_api`) et à chaque chargement de vignette (`img.youtube.com`) | Lecture vidéo (Parcours, vidéos de bourses) et vignettes | Pseudonymous (IP) | per Google |
| **WhatsApp / Meta** — remise externe, **pas un sous-traitant de KPB** | Meta (US/global) | L'URL `wa.me` ouverte par l'app : numéro du conseiller + **texte prérempli de contexte catalogue** (référence de dossier, programme, école, pays, service — **jamais le nom ni l'e-mail** : `whatsapp_utils.dart:18-61`, `:64-81`). **Ensuite, ce que l'étudiant y envoie lui-même**, dont ses documents depuis M2 | Contact conseiller ; **canal de remise des pièces** depuis le masquage du téléversement | n/a (external) | per Meta |

> ✅ **Lot 11 — le serveur ne recopie plus le nom civil dans les invites Groq.**
> `POST /tools/cv-summary` et `POST /tools/personalize-letter` *acceptent* encore
> un champ `name` (le PDF l'imprime) mais `tools.service.ts` n'interpole plus
> `Nom : ${dto.name}`. Ces routes, plus document-review et les deux alias POST
> d'orientation, sont derrière `AiConsentGuard` (403 `ai_consent_required` /
> `guardian_consent_required` ; `orientation.controller.ts:28-29`, `:36-37`).
> **Ne pas déployer ce backend en production avant que la build 49 soit chez les
> testeurs** — la 48 renverrait 403 avec « vérifiez votre connexion ». Le masque
> client `KPB_AI_TOOLS_ENABLED=false` reste en place jusqu'à ce basculement couplé.

> ✅ **#216 — la surface orientation a été refermée, et une garde la verrouille.**
> Le lot 11 n'avait nettoyé que `/tools` : `orientation.service.ts` recopiait
> encore l'objet `profile` du client — **nom civil inclus** — dans l'invite, alors
> que l'écran de consentement affiché juste avant promet le contraire mot pour mot
> (« Ton nom civil n'est pas recopié dans l'invite »). Corrigé : la charge est
> désormais une **liste close** (`orientation.service.ts:166-179`) reprise telle
> quelle en `:190-194`, et le test `orientation.prompt-privacy.spec.ts` échoue si
> un champ ajouté au corps de la requête atteint l'invite.
> — **raison de la case « Groq — Linked to user : No (pseudonymized) »** : après
> #216 aucune des deux surfaces atteignables n'envoie d'identité ; avant #216
> cette case était fausse.
> À ne pas confondre : le **client** poste toujours `fullName` vers **notre**
> backend (`app_controller.dart:826-834`). C'est un traitement KPB, pas un
> transfert au tiers — la ligne 1 du §1 reste exacte.
> ⚠️ Numérotation post-#216 (commit `5555111`, présent sur `main`, **absent de la
> branche docs** où ce document est rédigé).

> 🎙️ **Dictée vocale — la ligne du §1 est fausse et doit être corrigée avec cette section.**
> L'unique appel à `listen()` du dépôt ne passe pas `onDevice`
> (`speech_input_service.dart:36-45`) ; le défaut du paquet est `false`
> (`speech_to_text_platform_interface-2.4.0/lib/speech_to_text_platform_interface.dart:78-83`,
> transmis au natif en `method_channel_speech_to_text.dart:109`), et `false`
> signifie explicitement « on device **et** network recognition » : côté iOS
> `requiresOnDeviceRecognition` n'est jamais mis à vrai
> (`speech_to_text-7.4.0/darwin/.../SpeechToTextPlugin.swift:557-559`), côté
> Android `EXTRA_PREFER_OFFLINE` n'est jamais posé et le recognizer réseau par
> défaut est utilisé (`SpeechToTextPlugin.kt:687-689`, `:623-637`). Paquet
> réellement embarqué : `pubspec.yaml:74` → `pubspec.lock` 7.4.0,
> `ios/Podfile.lock:272`.
> Atteignable **sans aucun drapeau** en 49 : `case_tunnel_flow.dart:53-59`
> (étape 3 = message), `:357` (`case 3:` sans condition, à comparer au `case 2:`
> documents gardé en `:345`), `:762`, `:775`, `:844` ; permissions déclarées des
> deux côtés (`ios/Runner/Info.plist:52-55` ; `android/app/src/main/AndroidManifest.xml:7`).
> **À corriger dans le même passage :** `docs/STORE_READINESS.md:35` (« Converted
> to text **on device** ») et `docs/data-inventory.md:41` (« Convertie en texte
> **localement** ») affirment un fait que le code démentirait devant un
> examinateur. En revanche la politique publiée, elle, ne promet rien de tel
> (`app_translations.dart:635`, `:3436` ; `web/public/confidentialite.html:31`
> disent seulement « le micro convertit votre voix en texte ») — l'erreur est
> **documentaire**, pas contractuelle.
> **VOIE A RETENUE par le correctif 1.** L'app demande désormais la
> reconnaissance LOCALE (`onDevice: true`) et, quand la plateforme la refuse,
> elle ne bascule pas en silence : la session échoue et l'envoi au service du
> téléphone n'a lieu qu'après un accord explicite de l'étudiant
> (`allowPlatformService`). Garde `test/core/services/speech_input_on_device_test.dart`.
> Donc : **par défaut, aucun audio ne quitte l'appareil.**
> · Play → Data Safety → **Audio → Voice or sound recordings : NON collecté par
> défaut.** Si vous préférez déclarer le cas de l'accord explicite, cochez
> « collecté, transfert FACULTATIF pour l'utilisateur ».
> · **RÉSERVE, à écrire noir sur blanc :** la garantie n'est pas égale sur les
> deux plateformes. Sur iOS le greffon refuse la session si la reconnaissance
> locale n'est pas disponible — contrat dur. Sur Android, `onDevice` n'est
> qu'une préférence (`EXTRA_PREFER_OFFLINE`) et le repli réseau est INVISIBLE
> depuis Dart. Ne pas écrire « jamais transmis » : écrire « la reconnaissance
> locale est demandée à votre téléphone ».
> État d'avant le correctif, conservé parce qu'il dit d'où venait le risque :
> l'audio quittait l'appareil vers le recognizer de la plateforme, et
> l'exemption « on device » n'était adossée à aucun code.
> · Apple → App Privacy → **Audio Data : collectée, non liée à l'utilisateur, pas
> de tracking** — raison : même transmission, mais aucun identifiant KPB ne
> l'accompagne.
> · Politique §5 (`app_translations.dart:652`, EN `:3453`) : **nommer le service de
> reconnaissance vocale d'Apple / de Google** — raison : il ne figure aujourd'hui
> sous aucun titre dans la liste des destinataires.
> **Ne pas sur-déclarer** : la formulation correcte est « audio traité par le
> service de reconnaissance de la plateforme, texte seul conservé », **pas** « KPB
> collecte des enregistrements vocaux » (`speech_input_service.dart:37-39` ne lit
> que `result.recognizedWords`, aucun octet audio n'est stocké).
> Alternative assumée : forcer `onDevice: true` rendrait vraie la phrase déjà
> écrite — mais iOS échouerait fermé (`SpeechToTextPlugin.swift:507-515`) et
> Android retomberait **silencieusement** sur le recognizer réseau sous Android 12
> ou sans modèle local (`SpeechToTextPlugin.kt:623-637`) : la phrase devrait alors
> dire « sur l'appareil quand l'appareil le permet », pas « on device » sec.

> 📣 **OneSignal — ce qu'il reçoit est désormais NOMMÉ dans les trois
> politiques** (identifiant de compte + 4 étiquettes, jamais l'e-mail — la page
> web, dernière en retard, a été alignée le 24/08). Le mécanisme, pour les
> formulaires :
> Le chemin est actif par défaut dans la 49 : App ID compilé non vide
> (`app_config.dart:58-64`), `initialize()` inconditionnel (`main.dart:120`), puis
> `syncOneSignalIdentity()` déclenché en trois points — `main.dart:125-126`
> (démarrage à froid d'un utilisateur connecté), `app_controller.dart:557`
> (chaque connexion), `:635` (fin d'onboarding). **Aucun consentement ne le
> conditionne** : `setCollectionEnabled` ne touche que Firebase et PostHog
> (`analytics_service.dart:97-108`), et un refus de l'invite système n'arrête rien
> (`onesignal_service.dart:60-67` rend `Future<void>` et jette le résultat).
> Cases qui changent :
> · Play → **Adresse e-mail : le partage OneSignal a DISPARU** (correctif 2 du
> 18/08) — `addEmail` est retiré du dépôt et `login()` ignore délibérément son
> paramètre `email` (`onesignal_service.dart:73-75`) ; garde
> `test/core/services/onesignal_no_email_test.dart`. La case reste « Collectée »
> au titre du compte KPB, sans partage.
> · Play → **Identifiants → ID utilisateur : « Collecté » ET « Partagé »** —
> raison : `OneSignal.login(profile.id)` (`:80`).
> · Play → rattacher les **4 étiquettes** (`account_type`, `level`,
> `target_country`, `locale`) à « Informations personnelles → Autres informations »
> — raison : ce sont des attributs de profil transmis à un tiers
> (`app_controller.dart:1919-1921`).
> · Apple → **Identifiers → User ID**, « Linked to the user »,
> « App Functionality » — raison : `OneSignal.login`. (Email Address reste
> collectée par le compte KPB, mais n'est plus envoyée à OneSignal.)
> · **Aucune case « Localisation »** — raison : le module OneSignalLocation est lié
> (d'où `NSLocationWhenInUseUsageDescription`, `ios/Runner/Info.plist:56-63`) mais
> jamais appelé ; aucune occurrence de `OneSignal.Location` dans `lib/`.
> · **Ne pas cocher « Used to Track You »** — raison : rien ne lie ces données à
> des données tierces à des fins publicitaires cross-app.
> Politique à réécrire en conséquence : `app_translations.dart:657` (« jeton de
> notifications ») et `:3458` — sinon la fiche Play et la politique se
> contredisent, motif de rejet « Data Safety declaration inconsistent with privacy
> policy ». Le serveur, lui, n'envoie aucune PII supplémentaire
> (`onesignal-sender.service.ts:61-68` : `include_aliases.external_id` seulement) —
> la charge prouvée est **côté client**, avec un App ID compilé : elle ne dépend
> d'aucune variable d'environnement.

> ✉️ **Mautic — « (email) after opt-in » est faux deux fois.**
> (1) La charge est de 7 champs (`mautic.service.ts:99-115`), pas l'e-mail seul.
> (2) L'envoi **précède** le test d'opt-in : `syncContact` appelle `upsertContact`
> en `:76`, **avant** le branchement `if (optIn)` en `:77` ; et
> `newsletter-sync.service.ts:48` compare `newsletterSyncedOptIn ===
> newsletterOptIn` alors que le champ est **nullable sans défaut**
> (`schema.prisma:373`, contre `newsletterOptIn @default(false)` en `:371`) — donc
> `null === false` échoue et un utilisateur **qui n'a jamais consenti** voit ses
> 7 champs partir chez Mautic, puis être mis en DNC.
> **Inerte aujourd'hui** : `isConfigured` exige 4 variables
> (`mautic.service.ts:49-53`) qui ne sont posées nulle part dans le dépôt
> (`docker-compose.yml:62-65`, `.env.example:67-70` toutes vides) et la méthode
> sort en `:63-64`. — **raison de garder la ligne au tableau** : le code est livré,
> une seule variable d'environnement l'active ; mais **ne pas** écrire « after
> opt-in » dans le formulaire tant que `:76` précède `:77`.

> 💳 **PayDunya / CinetPay — à garder, avec le motif exact.**
> La build 49 ne peut joindre aucun des deux : `PaymentsController` /
> `AdminPaymentsController` ne sont **pas** enregistrés (`app.module.ts:95-98`), la
> méthode cliente de checkout a été retirée (`app_api_client.dart:1555-1557`),
> l'app n'appelle que `POST /me/purchases/whatsapp` (`:1565`) et `GET /me/purchases`
> (`:1576`), et le CTA est WhatsApp (`service_packages_screen.dart:17-18`).
> **Mais le motif « aucun contrôleur enregistré » est incomplet** : `POST /me/purchases`
> **est** enregistré (`app.module.ts:215` ; `service-packages.controller.ts:50`,
> `:57-79`) et mène à `createIntent` avec **`'cinetpay'` en défaut**
> (`service-packages.service.ts:148-150`), après avoir construit un client
> `{email, phone, fullName}` (`:126-130`). Ce qui bloque réellement est la **garde
> d'environnement** (`payments.service.ts:87-91` ; clés exigées en
> `cinetpay.adapter.ts:28-38` et `paydunya.adapter.ts:26-43`, déclarées nulle part
> dans le dépôt) — barrière renversable par une variable, sans toucher à l'app.
> Cases :
> · **« Achats intégrés » (Apple 3.1.1 / 3.1.3, équivalent Play) : ne PAS y faire
> figurer ces deux prestataires** — raison : aucun SDK d'achat au `pubspec.yaml`,
> aucun checkout client, remise conseiller par WhatsApp ; `docs/store-listing-copy.md:437`
> répond déjà « Aucun ».
> · **« Destinataires / sous-traitants » : les GARDER** — raison : les adaptateurs
> sont livrés dans le backend déployé et la route appelante est enregistrée avec
> `'cinetpay'` en défaut ; en outre `test/core/privacy_disclosure_parity_test.dart:42-43`
> fait échouer la CI si les mentions disparaissent tant que les adaptateurs vivent
> dans `backend/src`.
> · Colonne « Receives » **dissociée** — raison : CinetPay reçoit e-mail, téléphone
> et nom (`cinetpay.adapter.ts:58-60`), PayDunya ne reçoit **aucune** donnée client
> (`paydunya.adapter.ts:61-82`). Les fusionner sur-déclarait PayDunya et
> sous-déclarait CinetPay.
> Défaut annexe (hors formulaire) : la ligne `ServicePurchase` est créée en
> `service-packages.service.ts:133` **avant** `createIntent` en `:148` — un 400
> « not configured » laisse une ligne orpheline `pending_payment`.

> ▶️ **Embedded web — la ligne se trompait de tiers dans les deux sens.**
> **Sur-déclaration** : `webview_flutter` est déclaré (`pubspec.yaml:72`) mais n'a
> **aucun** site d'appel dans `lib/` ; Kayak n'est pas embarqué, c'est un **proxy
> serveur** (`backend/src/modules/kayak/kayak.controller.ts:9-11` : « the Kayak
> secret and affiliate tracking stay server-side ») et la surface est de toute
> façon masquée (`app_config.dart:116-119`, défaut `false` ; entrée profil gardée
> en `profile_screen.dart:1264`).
> **Sous-déclaration** : la seule vue web réellement embarquée est le **lecteur
> YouTube** (`pubspec.yaml:82` → `youtube_player_flutter`, qui rend un
> `InAppWebView` : `youtube_player_flutter-9.1.3/lib/src/player/raw_youtube_player.dart:72`,
> `baseUrl` `youtube-nocookie.com` en `:77`, script `www.youtube.com/iframe_api`
> chargé dès la construction du widget en `:254` — **ouvrir l'écran suffit**, sans
> toucher « play »). Trois chaînes sans drapeau : `parcours_screen.dart:796`/`:832`,
> `parcours_feed_screen.dart:191`/`:258`, `scholarship_video_player_screen.dart:40`/`:87`
> (depuis `scholarship_detail_screen.dart:147-157`). Vignettes dérivées en
> `parcours.dart:77-82` et `catalog.dart:913`, rendues jusque sur l'accueil pour un
> **visiteur non connecté** (`home_screen.dart:238-243`, commentaire « Shown to
> guests too » ; `story_of_week_card.dart:100`) lorsque le récit ne porte pas de
> vignette propre.
> Cases :
> · Apple → **Third-Party Partners / contenu tiers embarqué : déclarer Usage Data /
> Identifiers via partenaire** — raison : le lecteur transmet IP et user-agent à
> Google à l'ouverture.
> · Apple → classification d'âge, « accès web illimité » : **la réponse reste NON**,
> mais son fondement change — raison : l'embed est **figé sur YouTube**, pas sur des
> « partner/price-comparison URLs ». **`§5` lignes 159-160 est à corriger en
> conséquence** (hors périmètre de cette section).
> · Play → **aucune case de type de données ne bascule** — raison : l'adresse IP
> n'est pas un type déclarable dans la taxonomie Play et l'embed n'ajoute aucun
> type collecté. Ne rien cocher de plus.
> · **Kayak ne doit apparaître nulle part** comme destinataire de l'app — raison :
> secret et tracking affilié restent serveur, surface masquée.

> 🟢 **WhatsApp / Meta — nommé comme remise externe, pas comme sous-traitant.**
> C'est le canal de sortie de la 49 et, depuis M2, le remplaçant du téléversement
> (`app_config.dart:182-188`, `KPB_DOCUMENT_UPLOAD_ENABLED` défaut `false`) ; la
> politique in-app le dit déjà (`app_translations.dart:636`). Le texte prérempli ne
> porte que du contexte catalogue (`whatsapp_utils.dart:18-61`) — **ni nom, ni
> e-mail**.
> — **raison de la ligne** : c'est désormais Meta qui reçoit les pièces du dossier ;
> l'omettre laisserait croire que les documents ne quittent jamais l'app.
> — **raison de ne PAS le compter comme sous-traitant** : l'app ne transmet à Meta
> qu'une URL ouverte par l'OS ; tout le reste est envoyé par l'étudiant lui-même
> dans sa propre conversation. **Ne pas** lui attribuer de finalité de traitement
> KPB, et **ne pas** cocher de type de données Play à ce titre.

> 📊 **PostHog — la ligne est exacte OU sur-déclarée, selon un fait non lisible ici.**
> Tout le câblage (setup, observateur de navigation, enveloppe de replay, chaque
> miroir) est sauté quand la clé est vide, et **le défaut compilé est vide**
> (`app_config.dart:72-75`, `:87` ; garde `analytics_service.dart:45-46`, `:55-56`).
> La CI injecte `secrets.POSTHOG_API_KEY` (`.github/workflows/flutter-ci.yml:189`,
> `:286`, `:367`) mais le dépôt ne dit pas si le secret est renseigné, et le
> préflight iOS ne vérifie que **la présence du nom** de la variable
> (`scripts/preflight-ios-archive.sh:70` : `POSTHOG_API_KEY=` vide passe le
> contrôle).
> — **raison de trancher avant de cocher** : déclarer le replay sur un binaire où
> PostHog est inerte est une **sur-déclaration**, l'omettre sur un binaire où la clé
> est posée est une **sous-déclaration**. Vérifier la valeur effective du secret
> pour le binaire 49, puis cocher.
> Une fois la clé posée : provisionner le projet « KPB Education », et activer
> **PostHog → project settings → « Record user sessions »** (le replay est dark
> côté serveur sans cela, même avec `sessionReplay: true`). Masquage activé par
> défaut — le garder pour cette app.

> 🆔 **AD_ID (Android) — RETIRÉE du binaire (correctif 4 du 18/08).**
> `firebase_analytics` faisait entrer `com.google.android.gms.permission.AD_ID`
> dans le manifeste fusionné ; elle en est désormais RETIRÉE par
> `tools:node="remove"` (`android/app/src/main/AndroidManifest.xml:48-49`), et
> la collecte de l'identifiant est coupée dans le SDK de mesure lui-même
> (`google_analytics_adid_collection_enabled=false`, `:110`). Les permissions
> sœurs `ACCESS_ADSERVICES_*` restent (Google ne documente `tools:node="remove"`
> que pour AD_ID — le commentaire du manifeste explique ce choix) ; c'est AD_ID
> seule que le questionnaire Play interroge.
> · Play → « Contenu de l'application » → **Identifiant publicitaire : NON** —
> raison : la permission n'est plus dans le manifeste fusionné, et Play recoupe
> la réponse avec le bundle : c'est OUI qui serait désormais la réponse fausse.
> · Play → Data Safety → **Identifiants de l'appareil ou autres identifiants :
> collecté, non partagé, finalité Analyses, et « les utilisateurs peuvent
> choisir » COCHÉ** — raison : il reste l'identifiant d'instance Firebase, et
> l'interrupteur de profil coupe réellement la collecte
> (`analytics_service.dart:98`). Ne pas déclarer cette donnée comme
> *obligatoire*.
> · **Aucune case Apple ne change de ce fait** — raison : la permission est
> Android seulement ; le volet IDFA/ATT n'a pas été audité ici (donc : non
> vérifié, pas « rien à déclarer »).
> **La preuve est exécutable, plus documentaire** : `scripts/preflight-android-aab.sh:123`
> ÉCHOUE si `AD_ID` figure dans le manifeste de l'AAB signé — à passer sur
> l'AAB 49 le jour J. L'ancienne « réserve de preuve » (un APK `versionCode=45`
> traînant sous `build/`) est caduque : ne plus jamais lire un artefact de
> build traînant, mesurer l'AAB du jour.

> 💥 **Crashlytics — l'interrupteur « Analyse d'usage » le coupe DÉSORMAIS
> (correctif 3 du 18/08).** `applyCrashlyticsConsent` appelle
> `setCrashlyticsCollectionEnabled` (`crashlytics_observability.dart:50-52`),
> l'état est appliqué au démarrage, un refus purge la file des rapports non
> envoyés (`deleteUnsentReports`, `:59`), et la collecte démarre ÉTEINTE au
> manifeste et au plist (`firebase_crashlytics_collection_enabled=false`,
> `AndroidManifest.xml:160` ; `Info.plist`). Garde :
> `test/core/services/analytics_consent_test.dart`.
> · Play → « Journaux de plantage » → **collecte FACULTATIVE, « les utilisateurs
> peuvent choisir de ne pas fournir ces données »** — raison : l'interrupteur
> coupe bien les trois collecteurs depuis le correctif 3.
>
> ⚠️ **Revue du build 49 — la mesure est passée ACTIVE PAR DÉFAUT.** La réponse
> Play ne change PAS pour autant, et il faut savoir pourquoi avant de remplir le
> formulaire : « facultative » au sens de Google, ce n'est pas « désactivée au
> départ », c'est « l'utilisateur peut choisir ». Un opt-OUT réel qualifie donc
> autant qu'un opt-in. Ce qui doit rester vrai — et ce que la garde
> `analytics_consent_test.dart` tient — c'est que l'interrupteur Profil →
> « Analyse d'usage » coupe VRAIMENT les trois collecteurs et que le refus
> survit au redémarrage (`app_controller.dart` : le ternaire sur
> `analyticsConsentDecided`). Le jour où l'un des deux cesse d'être vrai, la
> réponse Play devient « obligatoire », pas « facultative ».
>
> Reste exact au niveau natif : la collecte démarre éteinte au manifeste et au
> plist ; c'est `applyAnalyticsConsent()` qui l'allume après `hydrate()`. Le
> défaut produit vit dans le contrôleur, pas dans le manifeste — ne pas
> « corriger » le manifeste en croyant l'aligner.
>
> Déclaré aux utilisateurs : CGU §5 « Mesure d'audience »
> (`terms_analytics_body`, `web/public/conditions.html`) et politique §9
> (`privacy_s9_body`, `web/public/confidentialite.html`).
> · Play → « Interactions dans l'appli » / « Historique de recherche » →
> **OPTIONNELLE** — raison : `analytics_service.dart:97-108` +
> `profile_screen.dart:741`. Les deux lignes doivent donc répondre **différemment** :
> une fiche qui coche « obligatoire » partout, ou « optionnel » partout, est fausse.
> · Apple → **Diagnostics → Crash Data, « non liée à l'utilisateur », pas de
> tracking** — raison : aucun `setUserIdentifier` dans le dépôt.
> Ambiguïté rédactionnelle à lever dans la politique : `app_translations.dart:667`
> propose de « refuser l'analytique » juste après avoir nommé « Firebase / Google
> (Analytics, **Crashlytics**) » en `:658`. La copie in-app, elle, ne sur-promet pas
> (`:1520-1522` ne mentionne que l'usage et les enregistrements) ; et
> `docs/data-inventory.md:45` dit désormais juste — l'opt-out crash EXISTE
> depuis le correctif 3, l'ancien reproche est levé.

> **Action before submission (mise à jour).**
> · Régions : **répondu** — Supabase `eu-west-3` (Paris), backend VPS Hostinger en
> France, Mautic sur le même VPS. Les sous-traitants US restent nommés à part
> (Groq, PostHog, OneSignal, Resend, Firebase/Google, YouTube). L'analyse de
> transferts est **EAU → US** (responsable émirien), pas UE → US.
> · Termes de recherche : si l'équipe refuse de déclarer « User Content / Search
> History », **il faut DEUX suppressions, pas une** —
> `analytics_service.dart:436` (Firebase) **et** `:437` (miroir PostHog avec
> `search_term` brut). Le §1 note en outre une persistance locale de l'historique :
> à traiter au §1, hors de cette section.

> 🧪 **Gardes manquantes — à poser avec ces corrections (motif déjà vu trois fois
> sur ce dépôt : l'outil censé détecter cachait le défaut).**
> · `test/core/privacy_disclosure_parity_test.dart:49` classe `youtube.com` parmi
> les **non-processeurs**, et le commentaire `:46-47` y range explicitement
> « WebView » — c'est l'affirmation fausse qui a autorisé l'omission ; la garde
> saute alors l'exigence en `:199`. À déplacer vers `_processorSuffixToToken`
> (`:35-44`).
> · Le scanner ne lit que `lib` + `backend/src` : `youtube-nocookie.com`, déclaré
> **dans le paquet pub**, lui est structurellement invisible.
> · La parité ne compare que des **noms** de destinataires, jamais la **charge**
> déclarée : d'où une ligne OneSignal verte alors qu'elle omet e-mail, id
> utilisateur et 4 étiquettes.
> · Aucun test n'assert `SpeechListenOptions.onDevice` ; aucun test ne garde le
> manifeste fusionné (AD_ID) ; aucun spec n'assure que `PaymentsController` reste
> non enregistré ni qu'aucune route enregistrée n'atteigne `createIntent` (le seul
> spec existant couvre la branche WhatsApp : `service-packages.service.spec.ts:64`).

## 3. App Store — Privacy "nutrition labels"

For each type: **Linked to the user? Used for tracking? Purpose.**
Tracking is **No** everywhere — raison : aucun SDK publicitaire, d'attribution ou
de MMP n'est déclaré dans `pubspec.yaml` (ni `google_mobile_ads`, `appsflyer`,
`adjust`, `branch`, `facebook_app_events`, `applovin` ; `play_install_referrer`,
ajouté à la 57, est l'API Install Referrer de Google Play, Android seulement, lue
sur l'appareil pour préremplir un code de parrain — ni MMP ni attribution
publicitaire, voir « Referral in the app » au §5), et rien dans `lib/` ne
joint nos données à des données tierces à des fins publicitaires. La permission
Android `AD_ID` est un sujet **Play** (§4) et ne déclenche pas l'ATT d'Apple ; la
surface IDFA iOS n'a pas été réauditée dans cette passe, donc cette ligne repose
sur l'absence de tout SDK publicitaire, pas sur un audit du `Info.plist`.

Chaque ligne porte la **raison** de la réponse, pour que le prochain lecteur
sache pourquoi la case est cochée ainsi.

| Apple data type | Collected | Linked | Tracking | Purpose | Pourquoi cette réponse (code) |
|---|---|---|---|---|---|
| Contact Info — Name, Email | Yes | Yes | No | App Functionality, Account management | `app_controller.dart:1996-1999` pousse `fullName` + `email` ; les deux sont **obligatoires** à l'inscription (`onboarding_screen.dart:1106,1115,1127`, validateur `_req`). |
| Contact Info — Phone number (+ WhatsApp) | Yes | Yes | No | App Functionality | `app_controller.dart:1999-2000`. **Optionnel**, pas requis : le champ téléphone n'a aucun validateur et `_buildProfile` retombe sur la valeur existante ou `''` quand il est vide (`onboarding_screen.dart:396-398`). |
| Contact Info — **Other User Contact Info (nom + contact du tuteur)** | Yes | Yes | No | App Functionality (consentement du tuteur pour mineur déclaré) | **Ligne ajoutée** : ce sont les coordonnées d'un **tiers**. `app_controller.dart:2021-2023` transmet `guardianName` et `guardianContact` ; stockés en colonnes dédiées (`backend/prisma/schema.prisma:388-390`) ; exigés pour un mineur déclaré (`onboarding_screen.dart:483-486`). §4 le portait déjà, §3 l'omettait. |
| Sensitive Info — *none* | No | — | — | — | Aucun champ origine / religion / orientation / santé dans le modèle de profil (`lib/app/core/models/user.dart:73-112`). |
| User Content — Photos or Videos (photo de profil) | Yes | Yes | No | App Functionality | **Le seul envoi de fichier prouvé et inconditionnel** de la 49 : `profile_screen.dart:440` → `profile_avatar.dart:409` → `app_api_client.dart:171-190` (`POST /profiles/me/avatar`), sans aucun drapeau. Pas d'EXIF/GPS : `requestFullMetadata: false` (`profile_avatar.dart:387`). |
| User Content — Customer Support (messages de dossier) | Yes | Yes | No | App Functionality | Messages de dossier envoyés au backend et persistés ; l'étape « message » du tunnel est atteignable sans drapeau (`case_tunnel_flow.dart:357-362`). |
| User Content — Other (messages au coach IA → Groq, US) | Yes | Yes | No | App Functionality | Chat atteignable en 49, mais **derrière un consentement explicite** : `ai_consent.dart:58-63` n'ouvre l'écran qu'après `ensureAiConsent`. Groq ne reçoit **aucun identifiant** : ni nom (`backend/src/modules/coach/coach.service.ts:208-216`) et budget réduit à une tranche (`coach-prompt.builder.ts:25-40`, appelé `:94,:127`). |
| User Content — **Audio Data (dictée vocale)** | **No** — locale demandée, service de la plateforme seulement après accord explicite, traitement éphémère | — | — | — | **Tranché par le correctif 1 du 18/08** : l'unique `listen()` pose `onDevice` (`speech_input_service.dart:86-90`) ; échec local → l'app REFUSE et ne réessaie qu'après un dialogue d'accord (`case_tunnel_flow.dart:881-888`). Aucun identifiant KPB n'accompagne l'audio, KPB ne lit que `result.recognizedWords` et ne stocke aucun octet. Gardes : `speech_input_on_device_test.dart` + tests du tunnel. |
| User Content — Other (documents de dossier / fichiers) | **No en build 49**, sauf Success Lab — voir la note « Fichiers » | — | — | — | L'envoi de pièces de dossier est masqué à **deux** niveaux : interface (`case_tunnel_flow.dart:345` remplace l'étape par un renvoi WhatsApp ; `case_detail_screen.dart:435,486-487`) **et** point d'étranglement du contrôleur (`app_controller.dart:1317` sort avant `_uploadRemoteCaseDocument`, `:1920-1928`). Le scanner reste local : partage par la feuille de l'OS (`document_scanner_screen.dart:69-71`) et `document_upload_service.dart` n'a aucun appel réseau. |
| Identifiers — User ID | Yes | Yes | No | App Functionality, Analytics | `OneSignal.login(profile.id)` (`onesignal_service.dart:80` ← `app_controller.dart:1906`) et `Posthog().identify` (`analytics_service.dart:72`). **Transmis en plus à un tiers** — voir la note « OneSignal ». |
| Identifiers — Device ID | Yes | Yes | No | App Functionality, Analytics | Identifiant d'instance Firebase (`pubspec.yaml:83`) + identifiant d'abonnement OneSignal : `main.dart:120` initialise OneSignal **sans condition** et l'App ID compilé par défaut n'est pas vide (`app_config.dart:58-64`). |
| Usage Data — Product Interaction, Search History | Yes | Yes | No | Analytics, App Functionality | La recherche est du texte libre : `analytics_service.dart:434-437` (`logSearch` + miroir `search_term`) appelé par `app_controller/search.dart:44`. Désactivable : `profile_screen.dart:735-745` → `app_controller.dart:503-508` → `analytics_service.dart:96-108`. |
| Diagnostics — Crash Data, Performance Data | Yes | **No (non lié)** | No | App Functionality (stabilité) | **Changement** : aucun `setUserIdentifier` dans tout `lib/` → le rapport ne porte pas d'identifiant KPB (seules écritures : `main.dart:50,52`, `app_logger.dart:39`, `sync_telemetry.dart:96`). Et la collecte est **DÉSACTIVABLE depuis le correctif 3 du 18/08** : éteinte au manifeste/plist, armée par le consentement seulement (`applyCrashlyticsConsent` — `crashlytics_observability.dart:50-52` ; garde `analytics_consent_test.dart`), refus = purge de la file. |
| Health, Financial Info, Location (precise/coarse), Browsing History, Contacts | No | — | — | — | Aucun moyen de paiement collecté : `POST /referrals/withdraw` part **sans corps** (`app_api_client.dart:825`), le compte de retrait n'est qu'**affiché masqué** depuis le serveur (`ambassador_screen.dart:822-825`), aucun SDK d'achat dans `pubspec.yaml`, contrôleurs de paiement non enregistrés (`backend/src/app.module.ts:95-98`). Aucun appel de géolocalisation dans `lib/` — la chaîne iOS existe seulement parce que le module de localisation OneSignal est lié, et le dit (`ios/Runner/Info.plist:62-63`). Aucune permission contacts (`android/app/src/main/AndroidManifest.xml:1-7`). |

> "Budget" is a self-reported figure for guidance, stored as profile data
> (`app_controller.dart:2008,2015-2016`), **not** a financial account — declare
> under App Functionality, not "Financial Info". Ce qui part vers Groq n'est
> qu'une **tranche** (`coach-prompt.builder.ts:25-40`).
>
> **Session replay (PostHog) — déclaration CONDITIONNELLE.** Ne la déclarez que
> si la 49 livrée porte une `POSTHOG_API_KEY` non vide. `posthogEnabled` vaut
> `posthogApiKey.trim().isNotEmpty` avec un défaut compilé **vide**
> (`app_config.dart:72-87`) ; `main.dart:66` saute la configuration et `:176` ne
> monte `PostHogWidget` (autocapture + rejeu) que si le drapeau est vrai. La CI
> passe `--dart-define=POSTHOG_API_KEY=${{ secrets.POSTHOG_API_KEY }}`
> (`.github/workflows/flutter-ci.yml:189,286,367`) : un secret non défini donne
> une valeur **vide**, et le préflight iOS ne vérifie que la présence du NOM
> (`scripts/preflight-ios-archive.sh:70`, `grep -q 'POSTHOG_API_KEY='`), donc une
> valeur vide passe le contrôle. Le dépôt ne peut pas trancher : celui qui
> construit la 49 doit le dire. **Si la clé est posée :** déclarer sous **Usage
> Data — Product Interaction** (Apple n'a pas de type « enregistrement d'écran »),
> Linked Yes, Tracking No ; le contenu est masqué (`main.dart:78-80`,
> `maskAllTexts` + `maskAllImages`) donc ce n'est pas du "User Content" ;
> désactivable (`analytics_service.dart:102-106`).
>
> **OneSignal reçoit plus qu'un jeton de notification.** À déclarer comme
> collecté **par un tiers** : Identifiers → User ID, finalité App Functionality
> (ajouter Product Personalization si les campagnes segmentent sur les
> étiquettes). Code : `onesignal_service.dart:80` envoie `login(userId)` et
> `:85` les `addTags{account_type, level, target_country, locale}`, alimentés
> par `app_controller.dart:1906`, `:1919-1921` ; trois points d'entrée sans
> consentement — démarrage à froid (`main.dart:125-126`), connexion
> (`app_controller.dart:557`), fin d'onboarding (`:635`) — et l'interrupteur
> d'analyse ne touche pas OneSignal (`analytics_service.dart:96-108`). Ne
> **pas** cocher « Used to Track You » : rien ne joint ces données à des
> données tierces pour la publicité. **L'e-mail, lui, ne part plus** —
> `addEmail` a été retiré (correctif 2 du 18/08, garde
> `onesignal_no_email_test.dart`) : la case Email Address tombe côté tiers.
>
> **Audio — TRANCHÉ le 18/08/2026 (voie A, renforcée d'un accord explicite).**
> `onDevice` est posé (`speech_input_service.dart:86-90`) ; en cas d'échec
> local, l'app refuse la session et ne réessaie avec le service de la
> plateforme qu'après un dialogue d'accord (`case_tunnel_flow.dart:881-888`).
> La formulation publiée doit rester QUALIFIÉE — « sur l'appareil quand
> l'appareil le permet » — jamais « converted to text on device » sec :
> sur Android, `onDevice` n'est qu'une préférence et le repli réseau est
> invisible depuis Dart. Et ne jamais écrire « KPB collecte des enregistrements
> vocaux » : aucun octet audio n'atteint KPB ni son backend.
>
> **Contenu tiers embarqué — Google / YouTube.** Les lecteurs vidéo Parcours et
> bourses sont un embed YouTube dans une WebView (`pubspec.yaml:82`
> `youtube_player_flutter` → transitif `flutter_inappwebview`,
> `pubspec.lock:473-474`), et les vignettes tapent `img.youtube.com`
> (`lib/app/core/models/parcours.dart:80`, `catalog.dart:913`), y compris sur la
> carte d'accueil visible **sans connexion** (`home_screen.dart:236-243`,
> « Shown to guests too »). Google reçoit donc IP + user-agent + identifiant de
> vidéo. À déclarer au titre du contenu / des partenaires tiers (Usage Data /
> Identifiers via partenaire). ⚠️ Hors périmètre de cette section mais à corriger
> avec : §2 ligne 67 et §5 lignes 159-160 décrivent encore une WebView Kayak qui
> n'existe pas (aucun `WebViewController`/`WebViewWidget` dans `lib/`, et
> l'estimateur de vols est masqué, `app_config.dart:116-119`).
>
> **Fichiers (Success Lab) — case à trancher côté ops, pas dans le dépôt.**
> Les envois d'artefacts et de pièces de preuve existent et ne sont pas masqués
> côté client (`success_lab_repository.dart:317-386` et `:670`), mais chaque
> entrée revérifie une décision **serveur** et échoue fermé
> (`live_scholarships_screen.dart:250-263`,
> `scholarship_detail_screen.dart:159-171`). Si, au dépôt du binaire, l'accès
> Success Lab est ouvert à de vrais utilisateurs en production → déclarer
> **User Content — Other (documents)** = Yes ; sinon = No. _TBD (ops)_ — ne pas
> deviner.

---

## 4. Google Play — Data Safety form

- **Does your app collect or share user data?** Yes (collect). **Share :** les
  transferts vers des sous-traitants agissant pour notre compte (Groq, Firebase,
  Supabase, **PostHog**, Resend, Mautic, PayDunya, CinetPay) sont traités par
  Play comme de la collecte, **pas** comme du « partage » publicitaire.
  **Deux exceptions à cocher « Partagée », pour une raison tirée du code :**
  (a) **OneSignal** reçoit une identité et des attributs de profil, pas une
  simple instruction de traitement — `onesignal_service.dart:80-85` envoie
  l'identifiant de compte et 4 étiquettes de ciblage
  (`app_controller.dart:1906`, `:1919-1921`) ; **l'e-mail ne part plus**
  (correctif 2 du 18/08, garde `onesignal_no_email_test.dart`) ; par contraste
  **Groq** ne reçoit aucun identifiant (`coach.service.ts:208-216`, budget en
  tranche `coach-prompt.builder.ts:25-40`), d'où « No » pour lui ;
  (b) le **service de reconnaissance vocale de la plateforme** (Apple / Google)
  ne reçoit l'audio de la dictée que si le local échoue ET que l'utilisateur
  l'accepte explicitement (`speech_input_service.dart:86-90`,
  `case_tunnel_flow.dart:881-888`) — il doit malgré tout être nommé comme
  destinataire dans la politique, ce qui reste dû.
  **PayDunya / CinetPay restent dans la liste** : les adaptateurs sont livrés
  dans le backend déployé, la route `POST /me/purchases` **est** enregistrée
  (`backend/src/app.module.ts:215`, `service-packages.controller.ts:57-68`) avec
  `'cinetpay'` en défaut (`service-packages.service.ts:148-150`), et
  `test/core/privacy_disclosure_parity_test.dart:42-43` casse si la mention
  disparaît tant que les adaptateurs vivent dans `backend/src`. **Mautic** reste
  aussi, et l'ordre est CORRIGÉ (correctif 6 du 18/08) :
  `resolveNewsletterAction` décide avant tout appel, « jamais consenti » ne
  pousse rien (`newsletter-sync.service.ts:45`, `:86`) — la réponse « e-mail
  transféré seulement après opt-in » est vraie du code, activable sans réserve.
- **Identifiant publicitaire (section « Contenu de l'application ») : NON**,
  depuis le correctif 4 (PR « huit correctifs de conformité »). Le manifeste
  source porte `<uses-permission android:name="com.google.android.gms.permission.AD_ID"
  tools:node="remove"/>` et la méta-donnée d'opt-out de collecte du SDK de
  mesure ; garde exécutable `test/release/android_manifest_test.dart`.
  **À REVÉRIFIER SUR L'AAB DE LA 49** avant de répondre — le manifeste source
  exprime une intention, seul le fusionné prouve le résultat :
  `java -jar <bundletool>.jar dump manifest --bundle <aab> | grep -i ad_id`.
  Les deux permissions Privacy Sandbox du même AAR
  (`ACCESS_ADSERVICES_AD_ID`, `ACCESS_ADSERVICES_ATTRIBUTION`) sont laissées en
  place délibérément : Google ne documente `tools:node="remove"` que pour AD_ID.
  <br>Ce qui suit décrit l'état AVANT le correctif, conservé parce qu'il
  explique d'où venait la permission : le manifeste fusionné portait
  `com.google.android.gms.permission.AD_ID`,
  apporté par `firebase_analytics` (`pubspec.yaml:83`) via
  `com.google.android.gms:play-services-measurement-api:23.2.0` — attribution
  unique confirmée par le blame du merger
  (`build/app/intermediates/manifest_merge_blame_file/release/processReleaseMainManifest/manifest-merger-blame-release-report.txt:75`),
  et rien ne la retire (`android/app/src/main/AndroidManifest.xml:1-7` n'a ni
  `xmlns:tools`, ni `tools:node="remove"`, ni `google_analytics_adid_collection_enabled` ;
  aucun `tools:node` dans tout `android/`). Motif à cocher : mesure d'audience,
  pas de publicité ciblée. **Réserve d'honnêteté :** le manifeste fusionné et
  l'APK présents sur disque portent `android:versionCode="45"`
  (`build/app/intermediates/packaged_manifests/release/processReleaseManifestForPackage/AndroidManifest.xml:4,75-77`) —
  ils prouvent le mécanisme, pas le binaire 49. À revérifier sur l'AAB de la 49
  (`java -jar <bundletool>.jar dump manifest --bundle <aab>`) avant de répondre.
- **Session replay (PostHog) :** à déclarer sous **App activity → App
  interactions** — **seulement si** la 49 livrée porte une `POSTHOG_API_KEY` non
  vide (même démonstration qu'en §3 : `app_config.dart:72-87`, `main.dart:66,176`,
  `scripts/preflight-ios-archive.sh:70`). Contenu masqué (`main.dart:78-80`),
  désactivable en app (`analytics_service.dart:102-106`), jamais utilisé pour la
  publicité. Play n'a pas de type « enregistrement d'écran ».
- **Is all data encrypted in transit?** Yes — raison : l'hôte prod par défaut est
  `https://api.kpbeducation.cloud/api` (`app_config.dart:249`, `appEnv` par
  défaut `prod` `:8-11`), l'ATS iOS interdit les chargements arbitraires
  (`ios/Runner/Info.plist:41-45`, `NSAllowsArbitraryLoads=false`), et le
  manifeste Android ne pose aucun `usesCleartextTraffic`.
- **Can users request data deletion?** **Yes** — en app (`profile_screen.dart:160`
  et `:1386` → `app_api_client.dart:106,112`, `GET /profiles/me/export` et
  suppression de compte) et via l'URL de suppression de compte (§6).
- **Data types — collected? shared? required or user-controllable? purpose:**

| Play data type | Collected | Shared | Requis / choix de l'utilisateur | Purpose | Pourquoi cette réponse (code) |
|---|---|---|---|---|---|
| Personal info — Name | Yes | No | **Requis** | App functionality, Account management | `app_controller.dart:1997` ; validateur `_req` sur prénom/nom (`onboarding_screen.dart:1106,1115`). |
| Personal info — Email address | Yes | **No — le partage OneSignal a disparu** (correctif 2 du 18/08) | **Requis** | App functionality | `app_controller.dart:1998` ; validateur `_req` (`onboarding_screen.dart:1127`). `addEmail` retiré, `login()` ignore son paramètre `email` (`onesignal_service.dart:73-75`) ; garde `onesignal_no_email_test.dart`. |
| Personal info — Phone number | Yes | No | **Optionnel** | App functionality | **Correction** : aucun validateur sur le champ, `_buildProfile` retombe sur `''` si vide (`onboarding_screen.dart:396-398`) — l'ancienne note « Phone requis » était fausse. |
| Personal info — User IDs | Yes | **Yes (OneSignal)** | **Requis — aucun réglage ne le coupe** | App functionality, Analytics | `OneSignal.login(profile.id)` (`onesignal_service.dart:80` ← `app_controller.dart:1906`) ; l'interrupteur d'analyse ne touche que Firebase + PostHog (`analytics_service.dart:96-108`). |
| Personal info — Other info (date de naissance, nom + contact du tuteur) | Yes | No | Requis pour un mineur déclaré | App functionality (contrôle d'âge, consentement du tuteur) | `app_controller.dart:2019-2023` ; colonnes `schema.prisma:388-390` ; blocage à l'inscription `onboarding_screen.dart:460-486`. |
| Financial info | **No** | — | — | — | Aucun moyen de paiement collecté : `app_api_client.dart:825` poste `/referrals/withdraw` sans corps, compte de retrait seulement affiché masqué (`ambassador_screen.dart:822-825`), aucun SDK d'achat, contrôleurs de paiement non enregistrés (`backend/src/app.module.ts:95-98`). Le budget auto-déclaré est de l'App functionality, pas un compte financier. |
| Messages — In-app messages (dossiers) | Yes | No | Requis pour utiliser la fonction | App functionality | Étape « message » du tunnel sans garde (`case_tunnel_flow.dart:357-362`). |
| Messages — Other in-app messages (coach IA → Groq, US) | Yes | No (sous-traitant, aucun identifiant transmis) | **Optionnel — consentement explicite** | App functionality | `ai_consent.dart:58-63` ; pas de nom dans l'invite (`coach.service.ts:208-216`). |
| Photos and videos — Photos | Yes | No | **Optionnel** | App functionality | Avatar seulement, non masqué (`profile_avatar.dart:409` → `app_api_client.dart:171-190`) ; sans EXIF/GPS (`profile_avatar.dart:387`). |
| Files and docs | _TBD (ops)_ — Yes **seulement si** l'accès Success Lab est ouvert en prod ; sinon No | No | Optionnel | App functionality | **Correction** : l'ancienne ligne fusionnée « Photos / Files — uploaded documents = Yes » sur-déclarait. Les pièces de dossier sont impossibles en 49 (`case_tunnel_flow.dart:345`, `case_detail_screen.dart:435,486-487`, chokepoint `app_controller.dart:1317`) ; le seul chemin fichier restant est Success Lab (`success_lab_repository.dart:317-386`, `:670`), atteignable uniquement si le serveur répond `enabled: true`, et fermé sinon (`live_scholarships_screen.dart:250-263`, `scholarship_detail_screen.dart:159-171`). |
| Audio — Voice or sound recordings | **No** — voie A implémentée (correctif 1 du 18/08) : locale demandée, plateforme seulement après accord explicite, traitement éphémère | — | — | — | `onDevice` posé (`speech_input_service.dart:86-90`) ; dialogue d'accord avant tout repli (`case_tunnel_flow.dart:881-888`) ; permissions `android/app/src/main/AndroidManifest.xml:7` et `ios/Runner/Info.plist`. KPB ne conserve que le texte : ne déclarer NI stockage NI collecte d'enregistrements. |
| App activity — App interactions | Yes | No | **Optionnel** — l'utilisateur peut couper | Analytics, App functionality | `profile_screen.dart:735-745` → `app_controller.dart:503-508` → `analytics_service.dart:96-108` (Firebase + PostHog), rejoué au démarrage (`main.dart:110`, `app_controller.dart:512-514`). |
| App activity — Search history | Yes | No | **Optionnel** — même interrupteur | Analytics | Texte libre : `analytics_service.dart:434-437` ← `app_controller/search.dart:44`. |
| App activity — Other user-generated actions (étiquettes de ciblage OneSignal : `account_type`, `level`, `target_country`, `locale`) | Yes | **Yes (OneSignal)** | **Requis — aucun réglage ne le coupe** | App functionality (+ personnalisation si les campagnes segmentent) | `app_controller.dart:1919-1921` → `onesignal_service.dart:85` (`addTags`) ; hors périmètre de l'interrupteur d'analyse (`analytics_service.dart:96-108`). |
| App info & performance — Crash logs | Yes | No | **FACULTATIVE — « les utilisateurs peuvent choisir de ne pas fournir ces données »** | App functionality (stabilité) | **Case retournée par le correctif 3** (`applyCrashlyticsConsent`, garde `analytics_consent_test.dart`). État d'avant, conservé pour mémoire : `setCrashlyticsCollectionEnabled` n'existe nulle part dans le dépôt, et les collecteurs sont armés avant toute lecture de consentement (`main.dart:49-54`, consentement relu seulement `:110`) ; les non-fatales partent sans garde (`app_logger.dart:37-45`, `safe_crashlytics.dart:41-60`). Non éphémère : les rapports persistent en console. |
| App info & performance — Diagnostics | Yes | No | **FACULTATIVE — même interrupteur que les crash logs (correctif 3)** | App functionality (stabilité) | Clés de diagnostic de synchronisation posées sans condition (`sync_telemetry.dart:92-98`, `setCustomKey`). |
| Device or other IDs | Yes | **Yes (OneSignal)** | **Requis** — le jeton part même sans réglage d'analyse | Analytics, Push notifications | `main.dart:120` initialise OneSignal sans condition, App ID compilé non vide (`app_config.dart:58-64`) ; l'identifiant d'instance Firebase, lui, suit l'interrupteur (`analytics_service.dart:96-108`). |

> **Requis / optionnel — la note précédente était incomplète et fausse sur un
> point.** Name et Email sont *Required* (validateurs `_req`,
> `onboarding_screen.dart:1106,1115,1127`) ; **Phone est *Optional*** (aucun
> validateur, `:396-398`) ; documents/budget/tuteur restent *Optional* là où le
> parcours permet de passer, sauf le tuteur d'un mineur déclaré
> (`onboarding_screen.dart:483-486`). Les lignes analytiques
> (App interactions, Search history) ET les diagnostics (Crash logs,
> Diagnostics — depuis le correctif 3, même interrupteur) répondent
> **Optionnel**, tandis que User IDs, étiquettes OneSignal et Device IDs
> répondent **Obligatoire** : une fiche qui coche « optionnel » partout, ou
> « obligatoire » partout, est fausse.
>
> **Traitement éphémère : Non** pour toutes les lignes cochées — le backend, la
> console Crashlytics et les outils d'analyse persistent leurs données ; l'audio
> de la dictée est le seul cas indéterminable (il est traité par le service de la
> plateforme, pas par nous) : ne pas cocher « éphémère » faute de preuve.
>
> **Ce qu'il ne faut PAS cocher, pour éviter la faute symétrique.**
> (a) Aucune case **Localisation** : aucun appel de géolocalisation dans `lib/`,
> la chaîne iOS ne vient que du module OneSignal lié et le dit
> (`ios/Runner/Info.plist:62-63`), et l'avatar est lu sans métadonnées
> (`profile_avatar.dart:387`).
> (b) L'embed YouTube ne fait basculer **aucun** type Play : il envoie IP +
> user-agent à Google (`pubspec.yaml:82`, vignettes `parcours.dart:80`,
> `catalog.dart:913`, carte visible sans connexion `home_screen.dart:236-243`),
> et l'adresse IP n'est pas un type déclarable de la taxonomie Play. Il doit en
> revanche figurer dans la politique de confidentialité et côté Apple (§3).
> (c) Aucune case « achats intégrés » : pas de SDK d'achat dans `pubspec.yaml`,
> méthode de checkout retirée du client (`app_api_client.dart:1555-1557`), CTA
> WhatsApp (`service_packages_screen.dart:66-90`).

---

## 5. Age rating

The two rating questionnaires (Apple's in App Store Connect, the IARC one in the
Play Console) ask about **surfaces**, not about intentions. Every answer below
carries, on one line, the code that decides it — and where the repository cannot
decide, the row says **NON PROUVÉ** rather than guessing.

| Questionnaire item | Answer | Reason (from the code) |
|---|---|---|
| Contractual minimum age | **16** | ToS `web/public/conditions.html:29`; in-app copy `lib/app/core/translations/app_translations.dart:704-706` |
| Unrestricted web access | **No** | The only embedded browser is the YouTube IFrame player, and it cannot navigate: `IgnorePointer(ignoring: true)` around the WebView, `pointer-events: none` on its document, player vars `controls: 0`, `fs: 0`, `rel: 0` (`youtube_player_flutter` 9.1.3 — `lib/src/player/raw_youtube_player.dart:70,245,265-271`; resolved version `pubspec.lock:2093-2100`). Every outbound link leaves through `LaunchMode.externalApplication` (`lib/app/core/utils/external_link.dart:38`; all 6 `launchUrl` call sites in `lib/` are external) |
| Users interact with each other | **No** in build 49 | The three `CommunityScreen` entries sit behind `!AppConfig.mvpOnly`, default `true` (`home_screen.dart:388,405`, `home_screen.dart:1831`, `profile_screen.dart:1281-1287`; `app_config.dart:93-96`); the shell ships 5 tabs and no Community (`app_shell.dart:63-70`); the two public forum routes 404 under `MvpGuard` (`community.controller.ts:25-35`, `mvp.guard.ts:17-22`, deployed default `docker-compose.yml:48`) |
| User-generated content | **Yes — staff-facing, never public** | Three writes ship; see the note below |
| In-app content report / user block | **AI report: Yes. User block: Not applicable in build 49** | Every reportable coach reply exposes `coach_report_ai_output`; every generated orientation explanation exposes `orientation_report_ai_output_*`. Both open the native reason/note sheet and await an authenticated `POST /cases` receipt (`ai_content_report_sheet.dart`, `ai_content_report_service.dart`). The case is marked `TRUST_AND_SAFETY_REPORT`, bounded below the server's 2,000-character limit, and visible through the guarded staff case queue (`cases.controller.ts`, `admin-cases.controller.ts`). Blocking another user is not offered or claimed because no user-to-user surface ships (previous row). |
| Generative AI, free text in and out | **Yes — two surfaces** | Coach chat, pill mounted on 4 of the 5 tabs (`app_shell.dart:141`, `coach_fab.dart:15-38`), and the orientation test (`orientation_screen.dart:288` → `POST /orientation/submit` → `orientation.service.ts:126,152` → `llm.service.ts:53`, `api.groq.com`) |
| App shares the user's location | **No** | No location plugin in `pubspec.yaml`; no `OneSignal.Location` call anywhere in `lib/`; `ios/Runner/Info.plist:56-63` declares the string only because `onesignal_flutter` links `OSFlutterLocation.m` |
| Gambling / wagering | **No** | Exhaustive absence over `lib/`: `casino|wager|gambl` → 0 hits, `lottery|loterie` → 0 hits |
| In-app purchases (IARC asks) | **No** | No purchase SDK in `pubspec.yaml`; the client checkout method was removed (`app_api_client.dart:1555-1557`); paid packages route to WhatsApp (`service_packages_screen.dart:17-18`). **PayDunya / CinetPay belong in §2 (processors), never in this box** |
| Editorial "mature content" | **NON PROUVÉ** | Parcours stories and scholarships are typed in the back office (`parcours.controller.ts:49-50`, behind `AdminAuthGuard`), so the answer rests on editorial review, not on the binary |

> **The declared-date bypass is closed server-side; the provision-before-age
> product gap remains.** The ToS and onboarding both say 16. The backend now
> applies the same calendar-age policy twice: `UpdateProfileDto` rejects an
> under-16/future `birthDate`, and `ProfilesService.updateMe` repeats the check
> for direct callers that bypass the global validation pipe
> (`profile-age.policy.ts`, `update-profile.dto.ts`, `profiles.service.ts`). An
> attacker can no longer PATCH a younger date past the mobile form. The first
> valid Supabase token still provisions a shell `UserProfile` before onboarding,
> however, and that row has a null birth date (`supabase-auth.service.ts`). Fully
> preventing account creation below 16 therefore needs a product/auth change:
> collect and validate DOB before Supabase signup, or introduce a server-side
> provisional-account state/guard with an explicit allowlist for onboarding.
> That decision is broader than a DTO fix and must be settled before claiming
> that the 16 floor gates the whole app rather than declared profile completion.

> **Guardian consent is self-declared, and its server effect is a fail-closed
> 403.** The
> app collects a name, a contact and a checkbox (`onboarding_screen.dart:482-498`)
> and pushes a `guardianConsentedAt` timestamp
> (`app_controller.dart:2024-2025`). Server-side it is read only by
> `AiConsentService.consentBlockCode`, which now returns
> `age_verification_required` when the profile read fails, the row is absent or
> `birthDate` is null. The HTTP guard and streaming coach stop before any Groq
> call; a known 16/17-year-old still receives `guardian_consent_required` until
> the existing guardian timestamp is present. The stronger record the schema offers,
> `GuardianAuthorization` (verified authorization + evidence), has **zero
> writers** anywhere in `backend/src`: the only statements against it are deletes
> (`profiles.service.ts:726-728`) and reads. So "under-18s require guardian
> consent (#60)" remains true of self-attestation, not of a verified
> authorization. Making verified evidence mandatory is a separate product/legal
> decision because build 49 has no issuance or review flow for that record.
>
> A second, **lower** AI floor exists in the repository — 13, from
> `KPB_AI_DIAGNOSTIC_MIN_AGE` (`competition-readiness/diagnostics/ai-consent.service.ts:227-232`,
> `common/feature-access.service.ts:117-120`) — but it governs a surface that is
> **off** in build 49: the client fails closed on `/success-lab/access`
> (`live_scholarships_screen.dart:250-262,265-269`) and the server needs
> `KPB_COMPETITION_READINESS_ENABLED` + `KPB_SUCCESS_LAB_ENABLED` +
> `KPB_AI_DIAGNOSTIC_ENABLED` with the kill switch off, all shipped the other way
> (`docker-compose.yml:90-93`). **Do not write 13 on any questionnaire**; do not
> claim it can never come back either.

> **The UGC that actually ships — three writes, none of them public.**
>
> | Write | Who else can read it | Proof |
> |---|---|---|
> | Case messages + timeline | The assigned KPB staff, through the back office (`admin/cases`, `AdminAuthGuard` + Counselor/Commercial/Admin/SuperAdmin roles); and **one linked parent, read-only, per case, only if the student flips the switch** (default `false`) | `admin-cases.controller.ts:27-34,41-44`; `parent-links.controller.ts:47-70` (GET only) + `:71-80`; `schema.prisma:566`; toggle surfaced at `case_detail_screen.dart:560` |
> | Counsellor review — rating, free text **and the student's civil name** (`reviewerName: profile.fullName`) | Nobody, in build 49: rows are created `isPublished: false` (`counsellors.service.ts:245-247`) and an admin can flip that (`counsellors.controller.ts:94`), but the public carousel *additionally* requires an active `public_testimonial` consent receipt that **no code path writes** (`impact.service.ts:252-259,292-309`), and `/impact/reviews` is feature-disabled by default (`impact.service.ts:312-319`; `docker-compose.yml:90,123`) | client write `case_detail_screen.dart:300-306` |
> | Coach chat | Nobody — reads are scoped to the author's id | `coach.controller.ts:42-44` |
>
> No public feed, no profile-to-profile visibility, no comments. The only content
> a stranger sees is editorial (`content/parcours`, catalog).

> **✅ The launch-visible content-report blocker is closed in the repository.**
> Community/forum remains disabled on both sides of the API boundary, so there
> is no other user to block and no public UGC to report in build 49. The two
> surfaces that do produce generative output are covered at the content itself:
> assistant bubbles in `ai_chat_screen.dart` and recommendation explanations in
> `orientation_screen.dart` open `ai_content_report_sheet.dart`. Submission is
> not a WhatsApp hand-off and does not optimistically claim success: the sheet
> closes only after `AiContentReportService` receives both the durable case id
> and reference code from authenticated `POST /cases`. Failure stays in-app and
> offers retry. Staff can read and process the report in `admin/cases`, guarded
> by `AdminAuthGuard` and the Counselor/Commercial/Admin/SuperAdmin roles.
>
> This closes the **app-path** requirement, not the operations evidence. Before
> public submission, create one report from each surface on an internal-track
> build and retain the two resulting case references plus a back-office capture
> showing that staff can triage them. The anti-fraud WhatsApp button remains a
> separate fraud tip line and must not be cited as the content-report control.

> **The web-access bullet was wrong in both directions, and the fix is in §2.**
> `webview_flutter` is declared (`pubspec.yaml:72`) with **zero call sites** in
> `lib/`; the Kayak / price-comparison screen is masked
> (`app_config.dart:116-119`, entry point `profile_screen.dart:1264-1270`) and
> even unmasked it opens links in the system browser
> (`flight_estimator_screen.dart:149-176`). The surface that *does* ship is the
> YouTube IFrame player, reachable **without an account**: the home « Récit de la
> semaine » card is mounted with no guest guard (`home_screen.dart:236-242`,
> comment *"Shown to guests too"*) and opens the player
> (`story_of_week_card.dart:55-63` → `parcours_feed_screen.dart:191-194,258`);
> Parcours is also reachable from `home_screen.dart:2462` and
> `profile_screen.dart:1245-1249`. The rating answer stays **No** (the player
> cannot navigate — see the table), but §2's "Embedded web (WebView)" row must
> name Google/YouTube (`youtube-nocookie.com`, `www.youtube.com/iframe_api`,
> `img.youtube.com`) instead of a price comparator.

**Recommended:** enter the answers above and let each questionnaire compute the
band. Do **not** carry the old "Apple 12+ / Google Teen" pair forward: it was
derived from a community module that does not ship and without the two
generative-AI surfaces. The repository now provides the AI-report path and does
not claim user blocking where no user-to-user interaction exists. The remaining
questionnaire caveat is that the 16 floor lives only in a client form; the
report path still needs the internal-track/back-office operational evidence
described above.

### Community (C1 + C2) — ⚠️ TO APPLY ON THE DAY THE FLAG OPENS

The table above stays true **while `KPB_COMMUNITY_ENABLED=false`** (default,
`docker-compose.yml`): every student route `/community/*` answers 404
`{ disabled: true }` before authentication (`community.feature.ts`), and the app
hides the community. On the day the remote flag `features.community` is turned
on — in the same submission as the build that shows it, never before — the
answers change:

| Questionnaire item | Answer at the flip | Reason (server, contract `docs/community-api-contract.md`) |
|---|---|---|
| Users interact with each other | **Yes** — public posts and replies between students; **no private messages**, no user mentions | `community-student.controller.ts`; §1 of the contract |
| User-generated content | **Yes — public, moderated** | pre-publication filter (phone/WhatsApp/e-mail, money requests, mobile money, links outside an allowlist, FR/EN insults) → "pending review", visible to the author only (`community-content-filter.ts`); staff queue `GET /admin/community/queue` (target: 24 h) |
| In-app content report / user block | **Yes / Yes** | report a post, a reply or a member (`POST /community/reports`); block a member, hidden both ways (`POST /community/members/:id/block`); provisional hide at 3 distinct reporters |
| Community guidelines | **Yes** — 4 rules, accepted (timestamped, versioned) before the first post | `POST /community/charter/accept`, `CommunityCharterAcceptance` |
| Sanctions / audit | read-only N days, ban; every staff action in `AdminAuditEvent` + `ForumModerationAction` | `community-moderation.service.ts` |
| Minors (16–17) | minimal public profile (first name + initial, country, badges); never e-mail, phone, age or location | `community-presenter.ts` (`memberAuthor`) |

Apple Guideline 1.2 (filter, report, block, contact, timely moderation) and Google
Play's UGC policy are covered server-side; the app agent wires the report/block
entry points. Data safety / privacy labels at the flip: add **Other user-generated
content** (posts, replies, reports) — collected, **not shared**, linked to the
account, App functionality; deleted with the account, included in the export (§6).
ToS and privacy policy (web + in-app): "Community" sections **drafted on 18/10/2026**
(charter in four rules, prohibited content, moderation, sanctions, reporting, no private
messages; 30-day retention of deleted content, hard deletion with the account) — to be reviewed
by the owner **before** opening.
*À VALIDER (owner): announced moderation delay, contact address shown in the app.*

---

### Referral in the app (build 57 / 2.3.1) — what changes in the forms

Owner decision of 17/10/2026: the app side of the referral programme ships in build 57
(`docs/runbook-campagne-ambassadeurs.md` §8), behind three **closed** remote flags
(`features.referralInstallReferrer`, `referralOnboardingCode`, `referralLeaderboard`).

- **Installation identifier** — a random UUID v4 stored on the device (never the IMEI, never the
  advertising ID), sent as `X-KPB-Device-Id` on `POST /referrals/redeem` **only**, flags or not;
  the server keeps an HMAC only (180 days, `docs/data-inventory.md` §6). Play: "Device or other
  IDs", collected, not shared, purpose **Fraud prevention, security, and compliance** (added).
  Apple: Identifiers — Device ID (already declared), App Functionality.
- **Play Install Referrer** (Android only, `play_install_referrer` 0.5.0 wrapping Google's
  `com.android.installreferrer:installreferrer:2.2`) — read **once per installation** when the
  flag is open; the referrer URL, click/install timestamps and install version are processed
  **on the device**; only `ref` is kept locally to prefill a field, sent only when the student
  confirms. Not an MMP, no ad attribution, no joining with third-party data: **Tracking stays No**
  (§3). The library adds the normal install-time permission
  `com.google.android.finsky.permission.BIND_GET_INSTALL_REFERRER_SERVICE` to the merged manifest
  (no user prompt).
- **Ambassador contest screen** — reads `GET /referrals/campaigns/current`; shows no amount; footer
  names the organiser (KPB Global L.L.C-FZ) and says Apple and Google are neither organisers nor
  partners (Apple 5.3.2). No user-to-user interaction, no UGC: age rating unchanged.

Full lines to paste: `docs/release-57-store-pack.md` §4, `docs/CONSOLE_ANSWERS.md` §0septies.
Privacy policy (web + in-app): the installation identifier (fraud prevention), the invite-link
reading (prefill only, nothing sent without confirmation), the HMAC fingerprints (180 days, owner
decision of 18/10/2026) and the contest are now named — text **drafted on 18/10/2026, to be
reviewed by the owner before the archive** (the in-app text is compiled).

### Owner decisions of 18/10/2026 — what they change for the stores

- **Nationality** ("My 10 scholarships", flag still closed): legal basis **explicit consent**,
  optional, kept while the account exists, erasable; the app now shows a consent checkbox on the
  test summary and sends nothing without it. Play/Apple rows unchanged (`docs/release-57-store-pack.md`
  §4); "Sensitive Info: No" still to confirm with counsel — *À VALIDER (owner)*.
- **XC-06 (Marketing purpose) — SETTLED 19/10/2026**: promotional push stays opt-out, so the owner **declares the Marketing purpose** (Play Data Safety; Apple App Privacy « Developer's Advertising or Marketing »). History: the owner first chose "no Marketing purpose" **provided** no
  promotional message goes out without opt-in. *Fixes 57 (19/10/2026)*: admin campaigns now carry
  a purpose (`promotional` by default); a promotional **e-mail** only goes to accounts that ticked
  "KPB news and offers" (off by default; declared minors also need guardian consent) and carries a
  one-click unsubscribe link + `List-Unsubscribe`; a promotional **push** honours the
  `kpb_promotions` opt-out. Still not guaranteed by code: push is **opt-out**, not opt-in; the
  purpose is a human choice in the admin; the sales team still receives contact details for
  every filed case. The forms must **not** claim "no Marketing" until the owner decides on
  these. *À VALIDER (owner).*
- **Nationality withdrawal** (fixes 57): an "Erase my nationality" button in "My 10
  scholarships" (`DELETE /profiles/me/nationality`) erases it and the test results computed
  with it; e-mail to privacy@kpbeducation.com still works.
- **D5 (FCFA prices)**: settled — indicative prices ("~" prefix), paid outside the stores via a
  counsellor on WhatsApp; consistent with the Notes for Review.
- **GDPR export**: now includes in-app notifications (`notifications` key).

## 6. Account deletion & data export (store requirement)

Both are **delivered** (KPB-67). Three gaps below must not be papered over by the
form wording.

- **In-app:** Profile → **« Mes données »** / "My data" → **« Exporter mes
  données »** / **« Supprimer mon compte »** (`app_translations.dart:2341,2342,2346`
  / EN `:5066,5067,5071`; card `profile_screen.dart:1367-1396`, mounted
  `:159-163`). *The label is « Mes données » — there is no "/ RGPD" string in the
  app; §4 already quotes it correctly.* Deletion is **immediate and hard**:
  Supabase Auth hard deletion is confirmed first, then one Prisma transaction
  runs an explicit table list plus schema cascades, ending in
  `userProfile.delete`; object erasure follows for case documents, artifact
  versions, outcome evidence, guardian evidence and the avatar. No soft-delete,
  no grace period. It is **not** a blanket "purge of Postgres": what is not named
  and not reached by a cascade survives (see the table below).
- **Account deletion URL — already shipped; only the console entry remains.**
  `web/public/suppression-compte.html` gives the in-app steps (`:16-24`) and a
  fallback address (`:26-31`), is served by the `web` nginx container behind the
  `kpbeducation.cloud` Traefik router (`docker-compose.yml:249-266`), is linked
  from the three other legal pages (`index.html:21`, `confidentialite.html:100`,
  `conditions.html:73`) and is probed **by title every 15 minutes**
  (`.github/workflows/uptime.yml:143-146`, cron `:20-21`). Whether the container
  is actually up on the VPS is not provable from the repository.

| Console field | Answer | Reason (from the code) |
|---|---|---|
| Play → *Can users request that their data be deleted?* | **Yes — in-app and via a web URL** | `profile_screen.dart:271-301` → `app_controller.dart:678-700` → `DELETE /profiles/me` (`profiles.controller.ts:116-120`) |
| Play / Apple → **Account deletion URL** | `https://kpbeducation.cloud/suppression-compte.html` | page + router + uptime probe cited above |
| Data export offered | **Yes — in-app, JSON shared from the app** | `GET /profiles/me/export` (`profiles.controller.ts:110-113` → `profiles.service.ts:823-1237`), handed to the OS share sheet as text (`profile_screen.dart:251-269`) |
| Deletion is immediate (no retention window declared) | **Yes** | Supabase `should_soft_delete: false`, then the local purge transaction; the web page's "sous 30 jours" is an outer bound, not the implementation |

> **The surviving-login configuration gap is closed in the repository.**
> Production bootstrap validates `SUPABASE_URL` and the server-only
> `SUPABASE_SERVICE_ROLE_KEY`; Compose uses required interpolation, the release
> workflow renders the production configuration before build/backup/migration,
> and CI proves the gate. At request time `deleteSupabaseAuthUser` sends an
> explicit hard delete (`should_soft_delete: false`) **before any local write**.
> A missing link/key, timeout or non-success provider response raises 503, so the
> mobile's success path cannot run while the Auth identity survives; 404 is an
> idempotent success because the identity is already absent.
>
> **Unavoidable JWT window:** Supabase hard deletion removes `auth.users`,
> cascades sessions and invalidates refresh tokens, but an access JWT already
> issued remains cryptographically valid until its `exp`. Because this backend
> validates JWTs locally, that token can still reach authenticated code during
> the remaining window (and profile provisioning can recreate a temporary local
> shell). Keep the Supabase JWT lifetime short, clear the device session after
> deletion, and validate `session_id` against `auth.sessions` for particularly
> sensitive operations if immediate revocation is required. Do not represent
> Auth deletion as retroactive revocation of already-issued JWTs.

> **What survives `DELETE /profiles/me` today.** Three families — none of them a
> cascade the schema will fix on its own.
>
> | Surviving data | Why the purge misses it | Store consequence |
> |---|---|---|
> | `CounsellorReview`: the student's **civil name** (`reviewerName`, sent as `profile.fullName` — `case_detail_screen.dart:305`) + free-text body | No relation to `UserProfile` (`schema.prisma:1380-1394`: only `counsellorId`; `reviewerUserId` is a bare string), so no cascade reaches it and the transaction never names it | The page's "Ce qui est supprimé" list (`suppression-compte.html:33-39`) is not true of this row. Either delete it in the transaction or stop storing the civil name |
> | Ambassador ledger — `Ambassador` (display name, city, **full payout account**), `AmbassadorReferral` (referee name), `Commission`, `Withdrawal` | `userProfileId` / `refereeProfileId` are plain strings with no `@relation` (`schema.prisma:1848-1935`) and none of the four appears in the transaction | Bites only ops-created ambassadors in build 49 — no caller of `activateAmbassador` exists in `lib/` (`app_api_client.dart:811-816` is unused) — but the rows hold payout data |
> | The **Mautic contact**: email, first/last name, phone, mobile (WhatsApp), country, language (`mautic.service.ts:99-113`) | **No deletion request is ever sent to a processor.** `deleteMe` never calls `NewsletterSyncService`, the newsletter module has no delete path, and reconciliation is profile-driven — a deleted profile simply stops being seen (`newsletter-sync.service.ts:28-48,71-90`) | Inert while Mautic is unconfigured (`docker-compose.yml:62-65` ship empty; `mautic.service.ts:49-53`), a hard erasure gap the day it is configured. Note also that `syncContact` upserts the contact **before** branching on the opt-in (`mautic.service.ts:63-95`) |
>
> The only processor signal the client does send is `OneSignal.logout()`
> (`app_controller.dart:682`), which unlinks the **device**, not the contact.

> **`EefInterest` EST exporté** depuis que la déclaration d'intérêt « Études en
> France » a été branchée dans `exportMe` (niveaux, `wantsPremium`,
> `consentVersion`, `consentedAt`). La suppression l'était déjà par la cascade.
> Elle a figuré un temps dans la liste ci-dessous des enregistrements absents :
> documenter une omission n'est pas la réparer quand le champ manquant est la
> preuve de consentement.
>
> **Export scope — the honest wording for the forms.** `GET /profiles/me/export`
> returns 15 top-level keys (`profiles.service.ts:1213-1228`) and is **not
> exhaustive of the caller's own records**. Absent although the same user owns
> them, and although the purge explicitly deletes them: `PaymentIntent` (`:565`),
> `Referral` (`:577-580`), `CreditTransaction` (`:581`), `DeviceToken` (`:729`),
> `PartnerLead` (`:730`), `StudentCredential` (`:731`) — plus the cascade-owned
> `Match`, `ScholarshipAlertSubscription` and `UserNotification`
> (`schema.prisma:1063-1077,1193-1206,1211-1240`) — and `CounsellorReview`, which
> is neither exported nor deleted. And it is **not a file**: the client hands the
> pretty-printed JSON to the OS share sheet as `text`
> (`profile_screen.dart:254-262`). Declare "export available in-app (JSON, shared
> from the app)", not "downloadable archive".
>
> The export's analytics slice, like the purge's, is env-conditional on
> `KPB_ANALYTICS_ACTOR_SECRET` (`profiles.service.ts:584-591`, `:1186-1193`,
> `:1249-1254`; empty by default, `docker-compose.yml:114`) — but this narrows
> nothing in build 49: the single `AnalyticsEvent` writer always sets
> `actorKey: null` (`domain-event-analytics-projector.service.ts:47-56`). The
> actor key that is really written lives on `AiUsageAttempt`
> (`ai-budget.service.ts:258,378-382`), and the purge nulls it
> (`profiles.service.ts:705-712`). Do not declare an analytics-erasure gap that
> the code does not have; do re-read this the day the Success Lab analytics chain
> is switched on.

> **Harness note** (the recurring defect on this repo: the tool meant to catch it
> hid it). The only test that proves erasure end-to-end is
> `backend/src/modules/profiles/profiles.postgres.spec.ts` — it does run in CI
> (`.github/workflows/backend-ci.yml:112`) — and it seeds **no `CounsellorReview`
> and no ambassador row**, so it cannot fail on either gap above. Extending the
> purge without extending that spec would leave exactly the blind spot that
> produced this section's earlier wording. Same for the export: assert the set of
> top-level keys, not just that it serializes.

---

## 7. Performance budget (measured)

The airtime/low-end-device moat must be **measured, not asserted**. Reference
device: an entry-level Android with **~2 GB RAM** (e.g. a device matching the
target market). Fill in and keep these in the PR description for the award.

### How to measure

```bash
# APK size (per-ABI, release)
flutter build apk --release --split-per-abi
ls -lh build/app/outputs/flutter-apk/*.apk        # arm64-v8a is the headline number
# (or App Bundle delivered size)
flutter build appbundle --release

# Cold start (app fully closed → first frame), on the reference device:
adb shell am force-stop com.karatou.android   # applicationId (android/app/build.gradle)
adb shell am start-activity -W -n com.karatou.android/.MainActivity | grep -E 'TotalTime|WaitTime'
# average of 5 cold starts

# Bytes/session — capture a representative session (open app, browse, 1 coach turn):
#   Settings → Apps → KPB → Data usage   (before/after), or
adb shell dumpsys netstats detail | grep -A3 com.karatou.android   # uid totals
```

### Results (to fill in on the reference device)

| Metric | Target | Measured | Device / build |
|---|---|---|---|
| APK size (arm64, release) | ≤ 25 MB | _TBD_ | |
| App Bundle delivered size | ≤ 20 MB | _TBD_ | |
| Cold start (TotalTime, avg of 5) | ≤ 2.5 s | _TBD_ | |
| Bytes / typical session | ≤ 500 KB | _TBD_ | |

### Quick wins already applied / recommended
- ✅ Removed the unused `google_fonts` dependency (this PR).
- ☐ Defer non-critical startup work (OneSignal init, quick-actions) off the
  first frame (e.g. `addPostFrameCallback` / after first paint).
- ☐ Audit catalog image sizes; the data-saver mode (already present) should be
  the default on metered connections.

---

## 8. CI — coverage floor on critical modules (AC3)

Sync/merge/outbox correctness must not regress silently. Calibrate the floors
to **current** coverage first (`npx jest --coverage` / `flutter test
--coverage`), then set the floor at-or-just-below it so CI ratchets.

**Backend (`backend/jest.config` or `package.json` jest block):**

```jsonc
"coverageThreshold": {
  "global": { "statements": 60, "branches": 50, "functions": 60, "lines": 60 }
  // tighten after measuring; never set above current coverage (breaks CI).
}
```

**Flutter (CI step) — floor the sync/merge/outbox modules:**

```bash
flutter test --coverage
# Fail if the critical modules drop below the floor (uses lcov):
lcov --extract coverage/lcov.info \
  '*/services/sync_*' '*/services/*merge*' '*/services/case_message_outbox.dart' \
  -o coverage/critical.info
lcov --summary coverage/critical.info   # parse the % and fail under the floor
```

Wire both into the existing `Analyze & test` workflow.

---

_Last updated: 2026-08-18 (revue contradictoire des déclarations contre la build 49 ;
sections 1 à 6 réécrites). Owner: keep
in sync with any new SDK, data flow, or third-party processor._
