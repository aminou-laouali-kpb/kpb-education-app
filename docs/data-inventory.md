# Inventaire des données — dérivé du code

Source de vérité pour les destinataires que l’utilisateur accepte à
l’inscription. Chaque ligne cite le fichier qui **prouve** le flux. Les docs
existants ne font pas autorité : si ce fichier et le code divergent, c’est le
code qui gagne, et ce fichier doit être mis à jour.

Dernière lecture du dépôt : 2026-08-24 (après l'alignement des trois
politiques : YouTube et le service de reconnaissance vocale nommés).

## 1. Destinataires tiers (10 + paiements)

| Destinataire | Hôte / preuve | Région | Ce qui part | Finalité |
|---|---|---|---|---|
| **Groq** | `https://api.groq.com/openai/v1/chat/completions` — `backend/src/modules/ai/llm.service.ts` | États-Unis | Texte libre du coach ; faits de profil (niveau, pays, tranche de budget, domaine). Le nom civil n'est plus recopié dans l'invite — mais le lot 11 n'avait couvert que `/tools` : l'orientation sérialisait l'objet `profile` ENTIER, `fullName` compris, jusqu'au correctif du 18/08 (`orientation.service.ts` envoie une projection close ; garde `orientation.prompt-privacy.spec.ts`). Les quatre outils IA restent masqués (`KPB_AI_TOOLS_ENABLED=false`) jusqu'au déploiement couplé avec la build 49. | Réponses IA |
| **Firebase Cloud Messaging (Google)** | `https://fcm.googleapis.com/v1/projects/<id>/messages:send` — `backend/src/modules/notifications/fcm-sender.service.ts` ; SDK `lib/app/core/services/push_service.dart` | États-Unis | Jeton d'appareil seul (le rattachement jeton → compte vit dans notre table `DeviceToken`). Titre, corps et charge `data` (route, `campaignId`, `notificationKey`) de chaque notification. | Notifications |
| **OneSignal** (repli, anciennes versions) | `https://onesignal.com/api/v1/notifications` — `backend/src/modules/notifications/onesignal-sender.service.ts` | États-Unis | Pour les builds antérieures à FCM seulement : jeton push, `external id` = `UserProfile.id`, 4 étiquettes de ciblage envoyées par ces builds. L'app courante n'embarque plus le SDK. À retirer avec le repli de `PushSenderService`. | Notifications (transition) |
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
| Photo de profil | Profil | Stockage backend, scan antivirus, pas d’URL publique | Caméra / photothèque |
| Documents de dossier | WhatsApp (pas l’app) | — | `KPB_DOCUMENT_UPLOAD_ENABLED=false` (M2) : l’app n’envoie aucun fichier. Les pièces (passeport, relevés…) passent par WhatsApp vers le conseiller. Fichiers d’anciennes builds encore en stockage. |
| Messages de dossier | In-app | Postgres | |
| Textes soumis au coach | In-app | Postgres + Groq (US) | Texte libre |
| Dictée vocale | Demande d’accompagnement | Reconnaissance **locale demandée** (correctif 1 du 18/08) ; à défaut, l'app refuse la session et ne l'envoie au service du téléphone qu'après accord explicite | **Garantie inégale** : contrat dur sur iOS (le greffon refuse si le local manque) ; sur Android `onDevice` n'est qu'une préférence et le repli réseau est invisible depuis Dart. Ne pas écrire « jamais transmis ». `NSMicrophoneUsageDescription` + `RECORD_AUDIO` |
| Profil académique, budget | Onboarding | Postgres + local | Budget → Groq en **tranche** seulement |
| Jeton push | Runtime | Backend KPB (`DeviceToken`), FCM | |
| Dernière version / build de l'app, date de dernière requête | En-têtes `X-KPB-App-Version` / `X-KPB-App-Build` (build 54+) des requêtes authentifiées — `backend/src/modules/app-builds/app-build.interceptor.ts` | Postgres (`UserProfile.lastAppVersion`, `lastAppBuild`, `lastAppSeenAt`) | Au plus une écriture par 6 h ; lue seulement en agrégat (`GET /admin/app-builds`) ; incluse dans l'export, supprimée avec le compte |
| Analytique / replay / crash | Runtime | Firebase + PostHog + Crashlytics | Opt-out : Profil → « Analyse d’usage » — coupe bien **les trois** depuis le correctif 3 du 18/08 (avant, Crashlytics continuait quoi qu'on choisisse), état appliqué au démarrage, et un refus purge la file des rapports non envoyés |

## 3. Permissions (ce que l’OS affiche)

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
