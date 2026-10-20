# Inventaire des données — dérivé du code

Source de vérité pour les destinataires que l’utilisateur accepte à
l’inscription. Chaque ligne cite le fichier qui **prouve** le flux. Les docs
existants ne font pas autorité : si ce fichier et le code divergent, c’est le
code qui gagne, et ce fichier doit être mis à jour.

Dernière lecture du dépôt : 2026-10-18 (finalisation de la build 57 : décisions du
propriétaire du 18/10/2026 reportées — conservations validées, nationalité sur consentement
explicite avec une case au récapitulatif du test, notifications in-app ajoutées à l'export,
politique et CGU rédigées pour la communauté, les bots, le parrainage et la compétition, à
relire par le propriétaire ; §5 à §7 ter). Lecture précédente : 2026-10-17 (parrainage côté app de la build 57 / 2.3.1 :
Play Install Referrer, identifiant d'installation, étape « code de ton parrain », écran
« Compétition ambassadeurs », derrière trois drapeaux fermés ; §6 bis). Lecture précédente :
2026-10-17 (communauté C1 + C2, serveur, derrière un drapeau fermé ; §7). Lecture précédente : 2026-10-17 (compétition ambassadeurs, serveur + admin + page
web, sans nouvelle build ; §6). Lecture précédente : 2026-10-16 (chantier L, préparation de
la build 57 : test « Mes 10 bourses », « Suivre » et notifications, caches hors ligne ; §5).
Lecture précédente : 2026-08-24 (alignement des trois politiques : YouTube et le
service de reconnaissance vocale nommés).

## 1. Destinataires tiers (10 + paiements)

| Destinataire | Hôte / preuve | Région | Ce qui part | Finalité |
|---|---|---|---|---|
| **Groq** | `https://api.groq.com/openai/v1/chat/completions` — `backend/src/modules/ai/llm.service.ts` | États-Unis | Texte libre du coach ; faits de profil (niveau, pays, tranche de budget, domaine). Le nom civil n'est plus recopié dans l'invite — mais le lot 11 n'avait couvert que `/tools` : l'orientation sérialisait l'objet `profile` ENTIER, `fullName` compris, jusqu'au correctif du 18/08 (`orientation.service.ts` envoie une projection close ; garde `orientation.prompt-privacy.spec.ts`). Les quatre outils IA restent masqués (`KPB_AI_TOOLS_ENABLED=false`) jusqu'au déploiement couplé avec la build 49. | Réponses IA |
| **Firebase Cloud Messaging (Google)** | `https://fcm.googleapis.com/v1/projects/<id>/messages:send` — `backend/src/modules/notifications/fcm-sender.service.ts` ; SDK `lib/app/core/services/push_service.dart` | États-Unis | Jeton d'appareil seul (le rattachement jeton → compte vit dans notre table `DeviceToken`). Titre, corps et charge `data` (route, `campaignId`, `notificationKey`) de chaque notification. | Notifications |
| **OneSignal** (repli, anciennes versions) | `https://onesignal.com/api/v1/notifications` — `backend/src/modules/notifications/onesignal-sender.service.ts` | États-Unis | Pour les builds antérieures à FCM seulement : jeton push, `external id` = `UserProfile.id`, 4 étiquettes de ciblage envoyées par ces builds. L'app courante n'embarque plus le SDK. À retirer avec le repli de `PushSenderService`. **Suppression du compte** (audit 57, F09) : quand `ONESIGNAL_APP_ID` / `ONESIGNAL_REST_API_KEY` sont posées, `deleteMe` demande à OneSignal d'effacer l'utilisateur (`DELETE https://api.onesignal.com/apps/<app>/users/by/external_id/<id>` : alias, étiquettes, abonnements), hors transaction et au mieux — un échec est journalisé sans l'identifiant et ne bloque pas la suppression (`OneSignalSenderService.deleteUser`). | Notifications (transition) |
| **Firebase** (Analytics + Crashlytics) | `https://karatoupostbac-178213.firebaseio.com` — `lib/firebase_options.dart` ; init `lib/main.dart` | Google | Événements d’usage, termes de recherche, piles de crash, modèle / OS / version | Analytique, stabilité |
| **YouTube** (Google) | lecteur intégré `youtube_player_flutter` → WebView `flutter_inappwebview` sur youtube-nocookie.com ; vignettes `img.youtube.com` (`parcours.dart:80`, `catalog.dart:913`), rendues dès l'accueil, connexion ou pas | Google | Adresse IP, user-agent, identifiant de vidéo — dès l'affichage | Lecture des vidéos témoignages et bourses |
| **Service de reconnaissance vocale de la plateforme** (Apple / Google) | `speech_input_service.dart:86-90` (reconnaissance locale demandée) ; repli sur accord explicite (`case_tunnel_flow.dart:881-888`) | Éditeur de l'OS | L'audio de la dictée, seulement si le local manque ET après accord — sur Android le système peut aussi replier de lui-même ; KPB ne reçoit que le texte | Dictée vocale |
| **PostHog** | `https://us.i.posthog.com` — `lib/app/core/config/app_config.dart` | États-Unis | Événements, vues d’écran, UUID après login, replays **textes + images masqués** | Analytique, session replay |
| **Supabase** (auth) | `https://hijzqsljasbobjrjotjy.supabase.co` — `lib/app/core/config/app_config.dart` | **`eu-west-3` (Paris)** — projet `hijzqsljasbobjrjotjy`, relevé le 18/08 | E-mail, identité Google OAuth, jetons de session | Authentification |
| **Resend** | `https://api.resend.com/emails` — `backend/src/modules/notifications/campaign-mail.service.ts` | États-Unis | Adresse e-mail + contenu des campagnes | E-mails transactionnels / campagnes |
| **Mautic** | `$MAUTIC_BASE_URL` — `backend/src/modules/newsletter/mautic.service.ts` (pas d’hôte en dur : instance auto-hébergée) | VPS KPB | E-mail, prénom, nom, téléphone, WhatsApp, pays, locale — **seulement après consentement** depuis le correctif 6 (`resolveNewsletterAction` : « jamais consenti » n'appelle plus rien) | Newsletter bourses |
| **Backend KPB** (NestJS / Postgres) | `https://api.kpbeducation.cloud/api` — `lib/app/core/config/app_config.dart` | VPS Hostinger | Toutes les données d’app ci-dessous | Fonctionnement |

Paiements (hors liste historique des 8, mais présents dans le code) :

| Destinataire | Preuve | Ce qui part |
|---|---|---|
| **PayDunya** | `https://app.paydunya.com` — `backend/src/modules/payments/paydunya.adapter.ts` | Intentions de paiement |
| **CinetPay** | `https://api-checkout.cinetpay.com` — `backend/src/modules/payments/cinetpay.adapter.ts` | Intentions de paiement |

## 2. Données collectées (côté app)

| Donnée | Où elle naît | Où elle vit | Note |
|---|---|---|---|
| Nom, e-mail, téléphone, WhatsApp | Onboarding | Postgres ; e-mail aussi Supabase Auth | Le nom n’est **pas** envoyé à Groq — coach et outils depuis le lot 11, **orientation seulement depuis le 18/08** (elle envoyait tout le profil). Les outils IA restent masqués jusqu’au déploiement couplé 49 |
| Date de naissance | Onboarding (étudiants) | Postgres + snapshot local | Plancher 16 ans (lot 9) ; tuteur si &lt; 18 |
| Nom / contact / consentement du tuteur | Onboarding (mineurs déclarés) | Postgres | Contact tuteur non persisté sur l’appareil |
| Réponses du test « Mes 10 bourses » (nationalité(s), résidence, date de naissance, accord du tuteur pour un mineur, diplôme, niveau visé, domaines, tranche de moyenne, niveaux de langue, scores de test, tranche d'expérience) | Assistant du test (drapeau `features.scholarshipMatch`, fermé ; son ouverture reste une action d'exploitation). La nationalité n'est envoyée qu'après la case de consentement explicite du récapitulatif (`match-nationality-consent`, ajoutée le 18/10/2026 ; jamais envoyée au serveur ni gardée dans le brouillon) | Postgres, colonnes de `UserProfile` (`nationalityCode`, `secondNationalityCode`, `highestDiploma`, `scholarshipTargetLevel`, `gradeBandOn20`, `englishLevel`, `frenchLevel`, `languageTests`, `workExperienceBand`, `scholarshipProfileConfirmedAt`, plus `birthDate` et les champs tuteur existants), écrites par `POST /scholarships/match/runs` seulement, jamais par le PATCH du profil (`backend/src/modules/scholarship-match/match-answers.ts`) ; sur l'appareil : brouillon Hive `kpb.scholarship_match.v1` (sans le nom ni le contact du tuteur), par compte, effacé à la fin du test (`scholarship_match_flow_screen.dart`, `clearDraft`) et à la déconnexion, et le dernier run (sans les réponses) | Jamais dans l'analytique ni dans le push (liste fermée des propriétés `scholarship_match_*`). **Écritures de compatibilité** : l'anglais et la moyenne recopient `languageLevel` / `gradeRange`, la résidence `countryOfResidence` (`legacyCompatibilityWrites`) — ces champs anciens suivent ensuite leurs propres flux (la résidence figure dans l'e-mail commercial d'un dossier). Transmission, conservation, export : §5 |
| Passages du moteur (`ScholarshipMatchRun`) | Chaque `POST /scholarships/match/runs` | Postgres ; **5 derniers par élève** (`prune`), cascade à la suppression du compte | `inputsSummary` **minimisé** : niveau visé, nombre de domaines, booléens, jamais la nationalité, la date de naissance ni la moyenne (`match-presenter.ts`, `RunInputsSummary`) ; `items` = bourses retenues et raisons rendues ; empreinte SHA-256 du profil normalisé (`profileHash`) |
| Opt-in « nouvelles bourses compatibles » | Résultats du test | Postgres (`UserProfile.scholarshipMatchAlertsOptInAt`) | Horodatage seul. **Aucun envoi n'est implémenté à ce jour** (aucune tâche planifiée ne lit la colonne, relevé du 16/10/2026) |
| Bourses suivies (« Suivre ») et alertes d'ouverture | Bouton « Suivre », cloche, « Mes suivis » (chantiers C et G) | Postgres : favori `SavedItem` + `ScholarshipAlertSubscription` (`pushEnabled`, `inAppEnabled`, `mutedAt`, `impliedFollow`), cascade à la suppression du compte ; sur l'appareil : cache Hive `kpb.followed.cache` par compte, vidé à la déconnexion (`followed_scholarships_store.dart`) | Interrupteurs serveur ouverts par défaut (`features.follow*`, `followedScholarships`…). Désinscription globale par la clé `followed_scholarship_updates` de `disabledNotificationTypes` |
| Notifications in-app et file d'envoi | Annonce d'ouverture, rappels de date limite (`backend/src/modules/scholarships-index/opening/`) | Postgres `UserNotification` (titre, corps FR/EN, route, état d'envoi `push*`), cascade à la suppression du compte ; aucune purge par âge | **Incluse dans l'export** `GET /profiles/me/export` depuis le 18/10/2026 (clé `notifications`, sans les détails d'exploitation de la boîte d'envoi ; §5) |
| Ouverture d'une notification | Tap sur un push (`POST /me/push-opens`, `backend/src/modules/notifications/push-opens.controller.ts`) | Postgres `NotificationDelivery.openedAt` ; un rappel tapé passe en lu (`UserNotification.readAt`) | Mesure de l'utilité des campagnes (`opened` / `openRate` dans l'admin) |
| Bourses gardées pour le hors-ligne | Liste et fiches consultées (chantier I) | Appareil seulement : Hive `kpb.scholarships.cache` (première page par jeu de filtres, 60 fiches au plus) | Données publiques du catalogue ; vidé à la déconnexion et à la perte de session, jamais relu après un 401 / 403 |
| Photo de profil | Profil | Stockage backend, scan antivirus, pas d’URL publique | Caméra / photothèque |
| Documents de dossier | WhatsApp (pas l’app) | — | `KPB_DOCUMENT_UPLOAD_ENABLED=false` (M2) : l’app n’envoie aucun fichier. Les pièces (passeport, relevés…) passent par WhatsApp vers le conseiller. Fichiers d’anciennes builds encore en stockage. |
| Messages de dossier | In-app | Postgres | |
| Textes soumis au coach | In-app | Postgres + Groq (US) | Texte libre |
| Dictée vocale | Demande d’accompagnement | Reconnaissance **locale demandée** (correctif 1 du 18/08) ; à défaut, l'app refuse la session et ne l'envoie au service du téléphone qu'après accord explicite | **Garantie inégale** : contrat dur sur iOS (le greffon refuse si le local manque) ; sur Android `onDevice` n'est qu'une préférence et le repli réseau est invisible depuis Dart. Ne pas écrire « jamais transmis ». `NSMicrophoneUsageDescription` + `RECORD_AUDIO` |
| Profil académique, budget | Onboarding | Postgres + local | Budget → Groq en **tranche** seulement |
| Jeton push | Runtime | Backend KPB (`DeviceToken`), FCM | |
| **Identifiant d'installation** (build 57 / 2.3.1) | UUID v4 **aléatoire** créé par l'app au premier rattachement demandé (`lib/app/core/services/referral_attribution.dart`, `installId`) — jamais l'IMEI, jamais l'identifiant publicitaire | Appareil : `SharedPreferences` `kpb_relaunch_v1.install_id_v1` ; serveur : **HMAC seulement** (`ReferralAttributionSignal.clientDeviceHash`, §6) | Envoyé dans l'en-tête `X-KPB-Device-Id` de `POST /referrals/redeem` **et d'aucune autre requête** (`test/core/repositories/referral_api_test.dart`). Indépendant des drapeaux. Nouveau à chaque réinstallation (`android:allowBackup="false"`). Détail : §6 bis |
| Code du parrain en attente (build 57) | Play Install Referrer (Android, drapeau `features.referralInstallReferrer`) ou code saisi à l'onboarding sans réseau | Appareil seulement : `SharedPreferences` `kpb_relaunch_v1.referral_pending_code_v1` (code + origine) | Ne part au serveur que quand l'élève appuie sur « Valider le code » ; effacé au rattachement réussi. Détail : §6 bis |
| Dernière version / build de l'app, date de dernière requête | En-têtes `X-KPB-App-Version` / `X-KPB-App-Build` (build 54+) des requêtes authentifiées — `backend/src/modules/app-builds/app-build.interceptor.ts` | Postgres (`UserProfile.lastAppVersion`, `lastAppBuild`, `lastAppSeenAt`) | Au plus une écriture par 6 h ; lue seulement en agrégat (`GET /admin/app-builds`) ; incluse dans l'export, supprimée avec le compte |
| Analytique / replay / crash | Runtime | Firebase + PostHog + Crashlytics | Opt-out : Profil → « Analyse d’usage » — coupe bien **les trois** depuis le correctif 3 du 18/08 (avant, Crashlytics continuait quoi qu'on choisisse), état appliqué au démarrage, et un refus purge la file des rapports non envoyés. **Conservation** (chantier juridique 57) : les statistiques agrégées et anonymisées sans limite ; les événements Firebase Analytics et PostHog (PostHog identifié par l'id du compte, un UUID : `analytics_service.dart`, `identifyUser`) et les enregistrements de session PostHog pendant la durée de rétention de l'outil. **Enregistrements de session PostHog : 30 jours** (réglage `session_recording_retention_period = 30d` du projet PostHog « KPB Education App », lu le 19/10/2026). **À VALIDER (propriétaire) : durée de rétention des événements PostHog** (dépend du forfait) **et Firebase Analytics** — elle n'est documentée ni configurée nulle part dans le dépôt ; la politique dit « pendant la durée de rétention de l'outil, puis supprimés », sans chiffre |

## 3. Permissions (ce que l’OS affiche)

Aucune permission **demandée à l'utilisateur** n'est nouvelle avec la build 57 :
`POST_NOTIFICATIONS` (Android 13+) et l'autorisation iOS des notifications
existaient déjà. Le SDK OneSignal est retiré, Firebase Cloud Messaging le remplace
(#351) ; deux `meta-data` FCM (icône, canal `kpb_default`) s'ajoutent au manifeste
Android, aucune permission.

**Parrainage (build 57 / 2.3.1)** : la bibliothèque Google
`com.android.installreferrer:installreferrer:2.2` (tirée par le paquet
`play_install_referrer` 0.5.0) ajoute au manifeste **fusionné** Android la
permission d'installation `com.google.android.finsky.permission.BIND_GET_INSTALL_REFERRER_SERVICE`
(lue dans le manifeste de l'AAR le 17/10/2026). Elle n'est pas dans
`android/app/src/main/AndroidManifest.xml`, n'est **jamais affichée** à
l'utilisateur (permission normale, pas d'invite) et ne sert qu'à se lier au
service Install Referrer du Play Store. Rien côté iOS (le paquet n'a pas de
partie iOS).

### Android (`android/app/src/main/AndroidManifest.xml`)

- `INTERNET`, `ACCESS_NETWORK_STATE` — API, Firebase
- `POST_NOTIFICATIONS` — notifications FCM (Android 13+)
- `USE_BIOMETRIC` — verrouillage local
- `RECORD_AUDIO` — dictée

### iOS (`ios/Runner/Info.plist`)

- `NSCameraUsageDescription` — pièce jointe de dossier **et** photo de profil
- `NSPhotoLibraryUsageDescription` — même usages
- `NSMicrophoneUsageDescription` / `NSSpeechRecognitionUsageDescription` — dictée
- `NSFaceIDUsageDescription` — verrouillage
- `NSLocationWhenInUseUsageDescription` — déclarée à l'origine pour le SDK OneSignal (retiré), gardée par précaution tant qu'une archive n'a pas prouvé qu'aucune bibliothèque ne référence CoreLocation ; **jamais demandée ni utilisée**

## 4. Ce que ce fichier n’est pas

- ~~L’identité juridique de l’entité~~ — **résolue le 16/08/2026.** Le
  responsable du traitement est **KPB Global L.L.C-FZ**, société de zone
  franche (Meydan Free Zone, Meydan City Corporation, Émirat de Dubaï),
  licence n° 2537631.01, siège Meydan Grandstand, 6th floor, Meydan Road,
  Nad Al Sheba, Dubaï, Émirats arabes unis. **KPB Education en est un
  service, pas une personne morale distincte.** Régime applicable :
  décret-loi fédéral n° 45 de 2021 (EAU) ; autorité de recours : UAE Data
  Office. Licence à renouveler avant le **21/09/2027**.
  Garde exécutable : `test/core/legal_identity_test.dart`.
- ~~La région du projet Supabase et du VPS~~ — **relevées le 18/08/2026.**
  Supabase : `eu-west-3` (Paris), les deux projets du compte. VPS backend :
  bloc Hostinger FR (`whois` : netname `HOSTINGER-HOSTING`, `country: FR`) — à
  confirmer dans le panneau Hostinger, mais l'hébergement des données est donc
  en **UE**, les sous-traitants américains étant nommés séparément.

## 5. Build 57 — transmission, conservation, export des nouvelles données (relevé du 16/10/2026)

Lu dans `backend/prisma/schema.prisma`, `backend/src/modules/scholarship-match/`,
`backend/src/modules/cases/` et `backend/src/modules/profiles/profiles.service.ts`.

| Question | Réponse tirée du code | Preuve |
|---|---|---|
| Les réponses du test partent-elles **chez une école** ou un organisme de bourse ? | **Non.** Aucun code n'écrit vers un établissement. Un dossier ouvert depuis une bourse porte seulement `Case.scholarshipId` (clé étrangère `SET NULL`) ; la vue staff du dossier montre le nom et les liens officiels de la bourse, **pas** les réponses du test | `cases.service.ts` (`mapDbCase`, `CASE_SCHOLARSHIP_SELECT`) |
| Partent-elles dans l'**e-mail commercial** d'un dossier ? | **Non** pour la nationalité, la date de naissance, les notes et les langues. L'e-mail porte nom, e-mail, téléphone, WhatsApp, pays de résidence, langue, niveaux actuel et visé (`targetLevel`, distinct de `scholarshipTargetLevel`), contact du tuteur | `case-lead-mail.service.ts` (`CaseLeadUser`, `leadBody`) |
| L'**admin** les voit-il ? | Pas par une route : aucune route admin ne sert `nationalityCode` ni les autres réponses. « Tester un profil » (`POST /admin/scholarships/match-preview`) prend un profil **saisi par l'équipe**, rien n'est lu ni écrit sur un élève | `admin-catalog/scholarship-eligibility-admin.service.ts` |
| Analytique, push, IA ? | Non : propriétés `scholarship_match_*` en liste fermée ; aucune réponse dans une charge de push ; aucune dans une invite IA | `docs/analytics-event-contract.md` ; `scholarship-match.service.ts` |
| **Export** (`GET /profiles/me/export`) | Les colonnes du profil (réponses comprises, sans la clé de stockage de la photo), les `ScholarshipMatchRun`, les `ScholarshipAlertSubscription`, les favoris `SavedItem` et, depuis le 18/10/2026, les notifications in-app `UserNotification` (clé `notifications` : type, bourse, cycle, titres et textes FR/EN, route, données, dates de création, de lecture et d'envoi, état d'envoi ; sans `dedupeKey`, verrous, identifiant du worker, lot ni dernière erreur) et, depuis l'audit 57 (20/10/2026), les livraisons des campagnes de l'équipe `NotificationDelivery` (clé `campaignNotifications` : nom de la campagne et titre FR/EN vu par l'élève, canal, état, dates d'envoi, de livraison et d'ouverture ; sans `recipientName` ni identifiants). La politique décrit l'export (section 8) | `profiles.service.ts` (`exportMe`) ; `profiles.postgres.spec.ts`, `profiles-residues.postgres.spec.ts` |
| **Suppression du compte** | Cascade sur `ScholarshipMatchRun`, `ScholarshipAlertSubscription`, `UserNotification` ; les colonnes du profil partent avec la ligne. `NotificationDelivery` (référence plate `recipientId`, sans cascade) : les livraisons liées à un dossier de l'élève sont supprimées ; les autres (diffusions) sont **anonymisées** dans la même transaction — `recipientId` = `compte-supprime`, `recipientName` = « Compte supprimé » — parce que les statistiques de campagne comptent ces lignes (audit 57, F05) | `schema.prisma` (`onDelete: Cascade`) ; `profiles.service.ts` (`deleteMe`) ; `profiles-residues.postgres.spec.ts` |
| **Durée de conservation** | Réponses : tant que le compte est actif (modifiables en refaisant le test). Nationalité : conservée tant que le compte existe, effaçable à tout moment (décision du propriétaire, 18/10/2026) — **aucune action « effacer » dans l'app** : le retrait passe par une demande à privacy@kpbeducation.com (texte de la politique et de la case), et la suppression du compte l'efface ; runs : 5 derniers ; notifications et suivis : tant que le compte est actif, aucune purge par âge ; brouillon local : fin du test ou déconnexion ; caches hors ligne : déconnexion | ci-dessus |
| **Mineurs de 16 et 17 ans** | Le test exige l'accord du représentant légal (`readiness` : `guardianConsent` requis sous 18 ans) ; plancher de 16 ans (`MINIMUM_ACCOUNT_AGE`, `parseBirthDate` refuse en dessous) ; le niveau « lycée » n'est proposé qu'en dessous d'un âge plafond (`SECONDARY_MAX_AGE`) | `match-inputs.ts`, `match-answers.ts`, `profiles/profile-age.policy.ts` |

**Décisions du propriétaire du 18/10/2026** (le drapeau `features.scholarshipMatch` reste
**fermé** : son ouverture est une action d'exploitation, défaut inchangé) :

- **Nationalité — base légale : consentement explicite**, saisie facultative ; conservée tant
  que le compte existe, effaçable à tout moment, supprimée avec le compte. L'app recueille le
  consentement par une case au récapitulatif du test (`scholarship_match_nationality_consent`,
  test `scholarship_match_flow_controller_test.dart` et `…_flow_screen_test.dart`) ; sans elle,
  rien ne part. La politique (in-app et web, section « Votre nationalité », rédigée le
  18/10/2026, à relire) le dit.
- Écart corrigé côté serveur : les notifications in-app sont dans l'export (ligne « Export »).

**Ce que ce relevé ne tranche toujours pas** :

- À VALIDER (propriétaire) : le classement de la nationalité hors des catégories « sensibles »
  des consoles (Apple : *Sensitive Info* = origine raciale ou ethnique, opinions, religion,
  santé…), avec le juridique (`docs/release-57-store-pack.md` §4).
- À VALIDER (propriétaire) : le texte de la politique sur les mineurs de 16 et 17 ans
  (« accord déclaré d'un représentant légal ») face au droit des pays visés (Sénégal,
  Côte d'Ivoire, Niger…).
- **Codé (correctifs 57, 19/10/2026)** : bouton « Effacer ma nationalité » dans l'espace
  « Mes 10 bourses » (`scholarship_match_results_screen.dart`, avec confirmation) →
  `DELETE /profiles/me/nationality` : `nationalityCode` et `secondNationalityCode` à NULL **et**
  suppression des `ScholarshipMatchRun` de l'élève (calculés avec elle), dans une transaction ;
  côté appareil, le dernier run, l'état et le brouillon du test sont effacés
  (`ScholarshipMatchStore.eraseNationality`). Le retrait par écrit à privacy@kpbeducation.com
  reste possible. Les autres réponses du test (diplôme, notes, langues…) restent sur le profil et
  se modifient en refaisant le test. `NotificationDelivery` est dans l'export depuis l'audit 57
  (ligne « Export »).

## 5 bis. Nouvelles et offres de KPB — campagnes de l'admin (correctifs 57, 19/10/2026)

À relire par le propriétaire (XC-06, `docs/CONSOLE_ANSWERS.md` §0quater).

| Donnée / règle | Où | Preuve |
|---|---|---|
| Finalité d'une campagne : `informational` / `promotional`, **défaut `promotional`** (y compris les campagnes antérieures) | `NotificationCampaign.purpose` (migration `20261026120000_campaign_purpose_promotions_consent`) ; choisie dans l'admin | `campaign-purpose.ts`, `admin/app/notifications/page.tsx` |
| Consentement « Nouvelles et offres de KPB » par e-mail : **non par défaut**, distinct de la newsletter bourses | `UserProfile.promotionsEmailOptIn` + preuve horodatée `promotionsEmailConsentedAt` (posée au seul passage à oui) ; interrupteur Profil → Préférences (app 2.3.1, visible si le serveur annonce le champ) | `profiles.service.ts`, `profiles-fix57.spec.ts`, `campaign-consent.postgres.spec.ts` |
| E-mail promotionnel | Part seulement si consentement ; mineur déclaré (< 18 ans, date connue) : accord du représentant légal (`guardianConsentedAt`) en plus ; pied + `List-Unsubscribe` avec lien signé `GET/POST /public/promotions/unsubscribe` (aucune donnée du compte affichée) ; sans secret, rien ne part | `campaign-executor.service.ts`, `promotions-unsubscribe*.ts` |
| Consentement « Nouvelles et offres de KPB » par notification (chantier juridique 57, App Store 4.5.4) : **non par défaut pour tous, comptes existants compris**, distinct de l'e-mail | `UserProfile.promotionsPushOptIn` + preuve horodatée `promotionsPushConsentedAt` (posée au seul passage à oui ; migration `20261027120000_promotions_push_opt_in`) ; interrupteur Notifications → « Nouvelles et offres de KPB par notification » (visible si le serveur annonce le champ ; l'activer retire aussi la coupure `kpb_promotions`) | `profiles-promotions.spec.ts`, `campaign-consent.postgres.spec.ts`, `notification_center_test.dart` |
| Push promotionnel | **Opt-in** : seulement si `promotionsPushOptIn = true` **et** `kpb_promotions` absent de `disabledNotificationTypes` ; mineur déclaré : accord du représentant légal (`guardianConsentedAt`) en plus. Une build sans le champ ne peut pas consentir : plus de push promotionnel | `campaign-purpose.spec.ts`, `campaign-executor.service.spec.ts`, `campaign-consent.postgres.spec.ts` |
| Campagne `informational` | Aucun filtre de plus qu'avant | idem |
| Ce qui part chez Resend | Adresse e-mail + contenu de la campagne + lien de désinscription (identifiant de compte et jeton HMAC dans l'URL) | §1, ligne Resend |
| Aperçu de l'admin | Nombre réel par canal après filtres (`byChannel`, `reachable`) | `notifications.service.ts` |

Non garanti par le code : la **classification** (choix humain). Le push promotionnel est un opt-in
explicite depuis le chantier juridique 57 (deux interrupteurs distincts, e-mail et notification,
plutôt qu'un consentement unique : réutiliser le consentement e-mail pour le push aurait fait
passer pour consentants des comptes qui n'avaient accepté que l'e-mail). Le consentement et sa date figurent dans `GET /profiles/me/export` (la
ligne `UserProfile` y est exportée entière, hors clé de stockage de la photo).

## 6. Compétition ambassadeurs (relevé du 17/10/2026)

Lu dans `backend/prisma/schema.prisma` (migration `20261022120000_referral_campaigns`),
`backend/src/modules/referrals/` et `web/public/classement/`. **Aucune collecte nouvelle dans
l'app installée** : tout vient de données déjà présentes (profil, rattachement par code, jeton
push) ou de la saisie de l'équipe.

| Donnée | Où elle naît | Où elle vit | Qui la voit | Conservation |
|---|---|---|---|---|
| Nom public « Prénom I. », ville, pays d'un ambassadeur participant | Calculé du nom du compte à l'inscription par l'équipe, modifiable par elle | Postgres `ReferralCampaignParticipant` | **Public** (`/classement/`, `GET /public/campaigns/:slug/leaderboard`) avec le nombre de filleuls qualifiés et le rang — seulement si le participant est classable | Tant que le compte existe ; cascade à la suppression du compte (via `Ambassador`) |
| Âge (majeur / mineur / inconnu) et **autorisation parentale** (statut, date de vérification, admin qui l'a vérifiée, note libre) | Date de naissance du profil ; saisie de l'équipe à la réception du formulaire signé | `ReferralCampaignParticipant` | Équipe (Admin, SuperAdmin, Commercial en lecture) | Idem. **Le formulaire signé lui-même n'est pas stocké par l'app** (reçu hors app, WhatsApp) : À VALIDER (propriétaire) où et combien de temps il est gardé |
| Activation ambassadeur (`approvedAt`, admin) et espace « cash » (`cashProgramEnabled`) | Action de l'équipe | `Ambassador` | Équipe | Avec la ligne `Ambassador` |
| Statut de chaque filleul dans une campagne (rattachement, création du compte, complétion du profil, qualification, signaux, décision et motif de l'équipe) | Calcul du serveur (`ReferralCampaignService.recompute`) ; décision de l'équipe | `ReferralCampaignReferral` (référence plate au filleul) | Équipe (nom et e-mail du filleul affichés dans l'admin et l'export CSV) ; **jamais public** ; l'ambassadeur voit dans l'app le seul nombre d'amis inscrits (écran Parrainage, existant) | Tant que la campagne existe ; purgé nommément à la suppression du compte du filleul ; cascade avec le participant |
| Instant de complétion du profil (`UserProfile.profileCompletedAt`) | Serveur, au `PATCH /profiles/me` qui complète le profil | `UserProfile` | Serveur (date de qualification) | Avec le profil ; incluse dans l'export (colonne du profil) |
| **Empreintes anti-fraude** : HMAC de l'adresse IP, de sa plage (/24, /48), des jetons push du filleul, de l'identifiant d'installation (build 57+, en-tête `X-KPB-Device-Id`), horodatage, type de code | `POST /referrals/redeem` | `ReferralAttributionSignal` — **aucune IP ni aucun jeton en clair** (clé `KPB_REFERRAL_SIGNAL_SECRET`, à défaut `KPB_JWT_SECRET`) | Serveur seulement (le calcul des signaux) ; l'équipe ne voit que le signal (« même téléphone », « rafale… ») | **180 jours** (`REFERRAL_SIGNAL_RETENTION_DAYS`, purge quotidienne) — durée **validée par le propriétaire le 18/10/2026** ; purgées à la suppression du compte (filleul ou parrain) |
| Ligne de l'espace ambassadeur (`AmbassadorReferral.refereeName` = « Prénom I. » du filleul) | `POST /referrals/redeem` quand le parrain est ambassadeur | `AmbassadorReferral` | L'ambassadeur ayant l'espace « cash » (aucun pour la compétition) | Purgée à la suppression du compte du filleul (existant) |
| Prix et versements (rang, nom public figé, montant, bénéficiaire ambassadeur/parent, moyen, référence Wave, date, admin, note) | Validation du podium et saisie de l'équipe | `ReferralCampaignPrizeAward` | Équipe | Prix **versé** : **gardé après suppression du compte** (trace comptable, `participantId` → NULL, nom public figé) — À VALIDER (propriétaire) : durée légale de conservation comptable. Prix **non versé** : à la suppression du compte, `participantId` → NULL, nom public → « Compte supprimé », note et référence effacées ; l'équipe le déclare forfait sans lauréat (`POST …/prizes/:rank/forfeit` sans `participantId`) et il passe au suivant (audit 57, F17) |
| Prix perdus (rang du prix, nom public figé, montant, **motif libre** de l'équipe, date, admin, remplaçant) | « Déclarer le prix forfait et réattribuer » | `ReferralCampaignPrizeForfeit` | Équipe | Tant que la campagne existe ; à la suppression du compte : `participantId` → NULL, nom public → « Compte supprimé », motif → « Motif effacé (compte supprimé) » (audit 57, F17) |
| Journal des actions de l'équipe | Chaque écriture admin | `AdminAuditEvent` (`purposeCode = referral_campaign`, motif dans `reasonCode`) | Équipe | Comme le reste de l'audit (aucune purge). À la suppression du compte (audit 57, F08) : pour les lignes `Ambassador` et `ReferralCampaignParticipant` du compte, `changes` (id du compte, nom public, ville, statut de mineur, note d'autorisation parentale) et `reasonCode` sont effacés ; pour ses forfaits et ses lignes de filleul, le motif libre (`reasonCode`) est effacé. L'action, l'auteur et la date restent |

- **Export** (`GET /profiles/me/export`) : `referralCampaigns.asAmbassador` (participations),
  `asReferee` (statut de filleul, signaux, décision et motif) et `attributionSignals` (empreintes
  hachées) s'ajoutent ; depuis l'audit 57 (F07, F17), `referralCampaigns.prizes` (rang, montant,
  bénéficiaire, état et référence du versement) et `prizeForfeits` (rang, montant, motif, date),
  et une clé `referral` : code, solde de crédits, rattachement comme filleul (**date seule**, ni
  nom ni identifiant du parrain), filleuls comme parrain (nombre et dates seuls), mouvements de
  crédits (sans l'identifiant du filleul ; code de bon d'avis pour une dépense), espace
  ambassadeur (code, ville, campus, statut KYC, totaux, compte de versement **masqué**, statuts
  et dates des filleuls sans leur nom, commissions, retraits avec destination masquée).
- **Suppression du compte** : participations (cascade), lignes de filleul et empreintes (purge
  nommée) ; seul le prix versé garde son nom public, sans lien vers le compte ; prix non versés,
  forfaits et journal d'audit anonymisés (lignes ci-dessus).
- **Page publique** : statique, sans traceur ; elle appelle l'API sans cookie (CSP
  `connect-src 'self' https://api.kpbeducation.cloud`).
- Mention de la compétition (nom public, autorisation parentale, empreintes anti-fraude,
  organisateur) **rédigée le 18/10/2026** dans `confidentialite.html` et la politique in-app
  (section « Parrainage et compétition des ambassadeurs »), à relire par le propriétaire.
- À VALIDER (propriétaire) : base légale du traitement anti-fraude (intérêt légitime — la
  politique dit la finalité, pas la base) ; lieu et durée de conservation du formulaire
  d'autorisation parentale signé ; durée légale de conservation comptable des prix versés.

## 6 bis. Parrainage côté app — build 57 / 2.3.1 (relevé du 17/10/2026)

Lu dans `lib/app/core/services/referral_attribution.dart`,
`lib/app/features/onboarding/onboarding_referral_step.dart`,
`lib/app/features/referral/` et `lib/app/core/repositories/app_api_client/engagement.dart`.
Trois drapeaux distants **fermés** et indépendants (`features.referralInstallReferrer`,
`referralOnboardingCode`, `referralLeaderboard`, `docs/api-contracts.md`) ; l'identifiant
d'installation, lui, accompagne tout `POST /referrals/redeem`, drapeaux ou non.

| Donnée | Où elle naît | Où elle vit | Ce qui part, et quand | Conservation |
|---|---|---|---|---|
| **Chaîne du Play Install Referrer** (URL de référence du lien Play, horodatages du clic et du début d'installation, version installée, paramètre Instant) | Lue par le SDK `play_install_referrer` 0.5.0 (bibliothèque Google `installreferrer` 2.2) auprès du Play Store de l'appareil — Android seulement, **une fois par installation**, drapeau `referralInstallReferrer` ouvert | **Mémoire vive seulement** : l'app n'en garde que `ref`, et seulement s'il a la forme exacte d'un code réel (`ReferralCodeFormat`) | **Rien.** Ni la chaîne, ni les horodatages ne quittent l'appareil ; aucun appel réseau dans la capture | Non conservée ; un drapeau local `…referral_install_referrer_checked_v1` (booléen) empêche toute seconde lecture |
| Code du parrain en attente (`ref` du lien, ou code saisi à l'onboarding non validé faute de réseau / limite horaire) | Ci-dessus, ou saisie de l'élève | `SharedPreferences` `kpb_relaunch_v1.referral_pending_code_v1` (code + origine `install_referrer` / `typed`) | **Seulement quand l'élève appuie sur « Valider le code »** (étape d'onboarding ou écran Parrainage) : le code part dans `POST /referrals/redeem`, comme une saisie manuelle — jamais de rattachement silencieux | Effacé au rattachement réussi (ou déjà fait) et au refus définitif de CE code ; sinon jusqu'à la désinstallation |
| Identifiant d'installation | UUID v4 aléatoire (`uuid`), créé au premier rattachement demandé | `SharedPreferences` `kpb_relaunch_v1.install_id_v1` | En-tête `X-KPB-Device-Id` de `POST /referrals/redeem` **seulement** ; le serveur n'en garde qu'une empreinte HMAC (§6, « empreintes anti-fraude ») | Sur l'appareil : jusqu'à la désinstallation (pas de sauvegarde Android, `allowBackup="false"`) ; serveur : 180 jours (§6) |
| Position dans la compétition (rang, qualifiés / à vérifier / en attente, nom public, ville, code ambassadeur) | `GET /referrals/campaigns/current` (élève connecté, drapeau `referralLeaderboard`) | **Affichée, jamais stockée** sur l'appareil | Rien de plus : lecture | — |
| Règlement de la campagne | `GET /public/campaigns/:slug/leaderboard` (sans authentification) : l'app n'en lit que `rulesUrl` (https) | Mémoire vive | — | — |
| Mesure d'audience | `referral_code_prompt_viewed`, `referral_code_submitted`, `referral_code_skipped`, `referral_competition_viewed` (`docs/analytics-event-contract.md`) | Firebase Analytics, PostHog (opt-out existant) | Identifiants **fermés** seulement (`surface`, `prefill`, `result`, `campaign_phase`) : **jamais le code**, ni rang, ni compteur, ni nom | Comme le reste de l'analytique |

- **Suppression du compte / déconnexion** : le code en attente et l'identifiant d'installation ne
  sont pas liés au compte et restent sur l'appareil (le code prérempli reste à confirmer par
  l'utilisateur suivant ; l'identifiant n'a de sens que par son empreinte serveur, purgée avec le
  compte, §6).
- **Data safety / App Privacy** : `docs/release-57-store-pack.md` §4 (lignes « identifiant
  d'installation » et « SDK Install Referrer »).
- Mention de l'identifiant d'installation (UUID aléatoire, prévention de la fraude) et de la
  lecture du lien d'invitation (Install Referrer : préremplissage, rien de transmis sans
  confirmation) **rédigée le 18/10/2026** dans `confidentialite.html` et la politique in-app —
  à relire par le propriétaire **avant l'archive** (texte in-app compilé), l'identifiant partant
  avec tout rattachement par code dès la 2.3.1.

## 7. Communauté d'entraide C1 + C2 (relevé du 17/10/2026)

Lu dans `backend/prisma/schema.prisma` (migration `20261023120000_community`),
`backend/src/modules/community/` et `backend/src/modules/profiles/profiles.service.ts`. Contrat :
`docs/community-api-contract.md`. **Tout est derrière `KPB_COMMUNITY_ENABLED` (fermé)** : tant
qu'il l'est, aucune de ces données ne naît.

| Donnée | Où elle naît | Où elle vit | Qui la voit | Conservation |
|---|---|---|---|---|
| Fiche membre (identifiant public, version et date d'acceptation de la charte) | Premier appel `/community/*` ; `POST /community/charter/accept` | `CommunityMember`, historique `CommunityCharterAcceptance` | Le membre ; l'équipe | Avec le compte (cascade) |
| Publications et réponses (type, titre, texte libre, mentions d'entités du catalogue, hashtags, statut de modération, drapeaux du filtre) | Écran communauté | `CommunityPost`, `CommunityReply`, `CommunityMention`, `CommunityPostHashtag` | **Public pour les élèves connectés** quand visibles (nom affiché « Prénom I. », pays de résidence déclaré, badges) ; l'auteur seul quand masquées ; l'équipe toujours | Avec le compte (cascade) ; un contenu supprimé par l'auteur ou l'équipe est gardé **30 jours** pour la modération puis purgé (`CommunityPurgeCronService`) |
| « Utile », suivis de discussion, blocages | Boutons | `CommunityReaction`, `CommunityFollow`, `CommunityBlock` | Compteurs publics (« utile ») ; le reste : le membre seul | Avec le compte (cascade, blocages dans les deux sens) |
| Signalements (motif, détail libre ≤ 500 car.) | `POST /community/reports` | `CommunityReport` | L'équipe ; **jamais** le membre signalé | Ceux **visant** le compte supprimé partent ; ceux **rédigés** restent sans auteur (`SET NULL`), datés (`reporterDeletedAt`, migration `20261027130000_community_report_orphan_retention`) et **purgés 12 mois après la suppression du compte** (`CommunityPurgeCronService`, quotidienne ; un orphelin d'avant la colonne part 12 mois après sa création) |
| Sanctions (motif, durée, admin) | Équipe | `CommunitySanction` | Le membre (motif dans sa notification et `GET /community/me`) ; l'équipe | Avec le compte (cascade) |
| Journal de modération | Chaque décision de l'équipe | `ForumModerationAction` (+ `AdminAuditEvent`, `purposeCode = community_moderation`) | L'équipe | Gardé ; le lien vers le membre (`memberId`) est mis à NULL à la suppression du compte |
| Notifications `community_*` | Réponses, réponse vérifiée, modération | `UserNotification` + push (chemin commun) | Le destinataire | Avec le compte (cascade) ; désinscription : clé `community` de `disabledNotificationTypes` (push seulement) |
| Identité réelle d'un membre (nom complet, e-mail) dans l'admin | Profil existant | — | **Admin et SuperAdmin seulement** ; Moderator/ContentManager/Counselor voient le nom public et les drapeaux « mineur » / « compte < 7 jours » | — |

- **Suppression du compte** : **suppression définitive, pas d'anonymisation** (choix motivé au §12
  du contrat : récits personnels d'un public jeune). Les réponses d'autres membres sous les
  publications du compte supprimé partent avec elles ; les compteurs d'autrui sont recalculés.
- **Export** (`GET /profiles/me/export`) : clé `community` (fiche, acceptations de charte,
  publications et réponses en texte complet tous états, « utile », suivis, blocages, signalements
  rédigés, sanctions). Les signalements **visant** l'élève ne lui sont pas rendus.
- **Mineurs** : aucun message privé, aucune mention d'utilisateur, aucune géolocalisation ; profil
  public minimal ; filtre anti-coordonnées avant publication.
- **Aucun nouveau destinataire tiers** : rien ne part vers un service externe (le filtre est local ;
  pas d'IA dans C1 + C2).
- Durée de conservation des contenus supprimés : **30 jours, validée par le propriétaire le
  18/10/2026**. Mention de la communauté **rédigée le 18/10/2026** dans `confidentialite.html`,
  `conditions.html` et les textes in-app (politique et CGU), à relire par le propriétaire avant
  l'ouverture ; la charte en quatre règles du serveur y est reprise sans changement (aucune
  contradiction relevée avec la politique).
- Durée de conservation des signalements rédigés après la suppression du compte : **12 mois,
  décidée le 19/10/2026** (chantier juridique 57) — purge quotidienne, testée
  (`community-purge-cron.service.spec.ts`, `community.postgres.spec.ts`) ; politique et page de
  suppression mises à jour (à relire par le propriétaire).
- À VALIDER (propriétaire) : base légale (exécution du service) et âge minimal pour publier
  (16 ans, celui du compte).

### 7 bis. Bot « Vérif » (C3, relevé du 17/10/2026)

Migration `20261024120000_community_verif_bot`, `backend/src/modules/community/community-verif-bot*.ts`,
runbook `docs/runbook-bot-verif.md`. Réglage `KPB_COMMUNITY_VERIF_BOT_MODE` (défaut `review` ;
passage en `auto` possible après 50 réponses validées sans correction, décision du propriétaire du
18/10/2026). Mention dans la politique (« Réponses et suggestions automatiques ») rédigée le
18/10/2026, à relire.

| Donnée | Où elle naît | Où elle vit | Qui la voit | Conservation |
|---|---|---|---|---|
| Brouillon du bot (statut, motifs repérés, langue, entités du catalogue citées, **faits du catalogue** sérialisés avec leurs sources, texte proposé, confiance, admin qui a traité, motif de rejet) | Tâche de la minute, sur une question visible d'un membre | `CommunityBotDraft` (un au plus par publication) | L'équipe (rôle R) | Avec la publication (cascade : purge à 30 jours d'un contenu supprimé, suppression du compte de l'auteur) |
| Réponse « Assistant KPB » publiée | Clic « Publier » d'un admin, ou mode `auto` | `CommunityReply` (`authorKind = kpb_assistant`, `botDraftId`, `botSourceVerifiedAt`) | Comme toute réponse visible | Comme toute réponse |

- **Aucune donnée personnelle copiée** : le brouillon ne recopie ni le texte de la question, ni
  l'auteur, ni son profil ; il ne contient que des faits du catalogue publié. `processedByAdminId`
  / `processedByName` désignent l'admin (pas l'élève).
- **LLM (option, fermée par défaut — `KPB_COMMUNITY_VERIF_BOT_LLM`)** : seul le texte déterministe
  bâti sur les faits du catalogue part vers le fournisseur existant (`llm.service.ts`,
  OpenRouter en rétention nulle, repli Groq) — **jamais** la question de l'élève ni rien de son
  compte. Destinataire déjà inventorié (coach IA).
- **Export RGPD** : rien de neuf pour l'élève (le brouillon n'est pas une donnée le concernant ;
  la réponse publiée est un contenu de l'équipe, comme une réponse « Équipe KPB »).


### 7 ter. Bot « Passerelle » (C3 bis, relevé du 17/10/2026)

Migration `20261025120000_assist_bridge`, `backend/src/modules/assist-bridge/`, contrat §15,
runbook `docs/runbook-bot-passerelle.md`. Réglages `KPB_ASSIST_BRIDGE_MODE` (défaut `shadow` :
rien n'est envoyé) et `KPB_ASSIST_BRIDGE_COACH` (défaut `false`).

| Donnée | Où elle naît | Où elle vit | Qui la voit | Conservation |
|---|---|---|---|---|
| Événement passerelle : besoin repéré (`needId`), règle et version du catalogue, **type et id** de la source (publication, réponse, message au coach), statut et motif, dates d'envoi et de clic (`opened_feature`, `opened_whatsapp`, `dismissed`) — **aucun texte** | Détection à l'écriture d'un texte de l'élève (publication / réponse visible ; message au coach si la source est ouverte) ; clics de la feuille de l'app (`POST /me/assist-bridge/events/:id`) | `AssistBridgeEvent` (un au plus par texte) | L'équipe (rôle R), **sans identité d'élève** ; un extrait de 120 caractères seulement pour un contenu **public** de la communauté, relu à la volée ; rien pour le coach | **12 mois** puis purge quotidienne (validés par le propriétaire le 18/10/2026) ; supprimé avec le compte (cascade) |
| Notification `assist_bridge` (titre, texte, route, besoin, id de l'événement) | Tâche de la minute, mode `on` | `UserNotification` + push (chemin commun) | L'élève seul | Avec le compte (cascade) ; désinscription : clé `assist_bridge` (coupe tout, pas même la ligne du fil) |

- **Source coach — donnée privée, FERMÉE par défaut.** Ouverte, le texte du message ne sert qu'à
  la détection en mémoire : **il n'est jamais recopié** (seuls le besoin, la règle et l'id du message
  sont écrits). À activer **après mise à jour de la politique de confidentialité** (finalité nouvelle
  pour un message privé : proposer une fonction de l'app) — À VALIDER (propriétaire).
- **Aucun nouveau destinataire tiers** : détection locale par expressions régulières, aucun LLM ;
  le push suit le chemin existant (FCM / OneSignal, déjà inventoriés). Le lien WhatsApp est ouvert
  par l'app vers la ligne KPB de sa configuration ; le serveur n'envoie aucun numéro.
- **Export RGPD** (`GET /profiles/me/export`) : clé `assistBridgeEvents` (sans `userId`).
- **Mineurs** : rien de public ; la suggestion est privée et ne cite pas le texte de l'élève.
- **Validés par le propriétaire le 18/10/2026** : conservation 12 mois ; textes FR/EN des
  besoins ; seuils (72 h, 30 jours, 14 jours, 48 h, 4 mots) ; ligne WhatsApp `+33768674292`
  comme ligne d'assistance ; `shadow` au moins 2 semaines, passage à `on` sous 10 % de faux
  positifs. Mention dans `confidentialite.html` et la politique in-app **rédigée le
  18/10/2026** (analyse automatique des publications, aucun texte stocké, 12 mois, réglage
  « Suggestions de l'équipe KPB »), à relire par le propriétaire.
- Source coach : **reste FERMÉE** ; la politique ne la mentionne pas (décision du 18/10/2026).
  Son ouverture demanderait d'abord une mise à jour de la politique — À VALIDER (propriétaire).
