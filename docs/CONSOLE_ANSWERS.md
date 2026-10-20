# Réponses consoles

> **Vérifié contre l'artefact `2.2.0 (53)`** — archive iOS téléversée le
> 04/09/2026 à 10h21, AAB Android du run CI 33781909005. Vérification précédente :
> `2.1.0 (49)`, le 25/08/2026.
>
> **⚠️ Build 54 (`2.3.0 (54)`) : réponses RELUES sur le dépôt, PAS encore vérifiées
> sur l'artefact.** Les réponses ci-dessous valent pour la 53 ; la section **0quater**
> liste ce que la 54 change (Wikimedia, finalités commerciales, langue du
> consentement, déclaration « applications gouvernementales »). Les contrôles qui
> dépendent de l'ARTEFACT — clé PostHog (`strings App.framework/App | grep -c
> '^phc_'` = 1), `AD_ID` absent du manifeste fusionné — se refont sur l'archive 54
> avant de changer cet en-tête (LIV-09). Ne pas le passer à « 54 » sans l'avoir fait.
>
> **Le numéro de build n'est PAS dans le titre**, et c'est délibéré. Ce fichier
> s'appelait « — build 49 » et servait encore de référence quatre numéros plus
> tard, alors que trois de ses six points ouverts s'étaient résolus entre-temps.
> Un titre figé sur une build fait vieillir le document en silence ; un en-tête
> « vérifié contre » se voit périmé du premier coup d'œil. Même correction que
> `mobile-store-submission-contract.md`.
>
> **À quoi sert cette fiche.** `docs/STORE_READINESS.md` est l'analyse ; celle-ci
> est la **feuille à cocher**, dans l'ordre où chaque console pose ses questions.
> Chaque réponse porte, en une ligne, la **preuve vérifiée dans le code**. Quand
> une case n'est pas déductible du dépôt, elle est marquée **⚠️ À TRANCHER** et
> regroupée en tête — ne rien y deviner.
>
> **Certaines réponses dépendent de l'ARTEFACT, pas du dépôt** — « la clé PostHog
> est-elle dans le binaire ? » en est l'exemple type. Elles se revérifient à
> chaque build, et l'en-tête ci-dessus dit contre laquelle.
>
> **Entité (les deux consoles, à l'identique) :** l'éditeur et responsable du
> traitement est **KPB Global L.L.C-FZ**, zone franche Meydan (Dubaï, EAU),
> licence **2537631.01**, siège Meydan Grandstand 6th floor, Meydan Road, Nad Al
> Sheba, Dubaï. **KPB Education est un service de cette société, pas une entité.**
> Régime : décret-loi fédéral EAU n° 45/2021, autorité UAE Data Office. Transferts
> analysés **EAU → US** (sous-traitants US), hébergement **UE** (voir §Régions).
> C'est l'entité que porte la politique liée à la fiche — les deux doivent
> coïncider, sinon rejet « declaration inconsistent with privacy policy ».

---

## 0. ⚠️ À TRANCHER AVANT DE SOUMETTRE (3 points)

Trois des six points de la vérification du 25/08 se sont **résolus** ; ils sont
consignés en §0bis avec leur preuve, parce qu'un point retiré sans trace se
rouvre tout seul à la revue suivante.

| # | Point | Décision requise | Comment trancher |
|---|---|---|---|
| 4 | **SDK d'attribution embarqué (iOS)** | Répondre juste si un formulaire demande « SDK tiers d'attribution/pub présent ? » | `GoogleAdsOnDeviceConversion 3.4.2` **est** dans le binaire (transitif via `firebase_analytics`, `ios/Podfile.lock:124`). **Aucun suivi** (ATT absent, `NSPrivacyTracking=false`) — mais le SDK est *présent*. Ne pas cocher « Used to Track », mais le lister si la liste des SDK est demandée. |
| 5 | **Régions d'hébergement** | Confirmé hors dépôt — recopier tel quel | Supabase **eu-west-3 (Paris)**, VPS **France** (Hostinger), Mautic même VPS. Non prouvable par le code (`STORE_READINESS.md` §1). |
| 6 | **Fichiers Success Lab (Apple : User Content → Documents)** | Yes **seulement si un utilisateur réel peut effectivement téléverser** ; sinon No | **NE PAS se fier à `/config/app` → `features.successLab`** : ce drapeau est grossier et ne dit rien du déploiement progressif, du pays du compte, ni des drapeaux enfants `KPB_APPLICATION_ARTIFACTS_ENABLED` / `KPB_STUDY_REVIEW_ENABLED`. Il peut donc valoir `true` alors que **personne** n'atteint le formulaire d'envoi — et déclarer une collecte de documents inexistante est une déclaration fausse. La décision qui fait foi est **par utilisateur** : `GET /success-lab/access` (`workspaces.controller.ts`), et les deux capacités imbriquées **`applicationArtifacts.enabled`** et **`counsellorStudy.enabled`**. Interroger avec un compte représentatif du public visé. |

---

## 0bis. Points RÉSOLUS depuis le 25/08 (ne pas les rouvrir sans preuve contraire)

| # | Point | Résolution, vérifiée sur l'artefact `2.2.0 (53)` |
|---|---|---|
| 1 | Clé PostHog conditionnelle au build | **RÉSOLU — et la réponse s'INVERSE.** La 49 et la 50 partaient sans clé ; la 53 la porte. Vérifié : `strings App.framework/App \| grep -c '^phc_'` → **1** (la 50 rendait 0). Le préflight iOS refuse désormais une clé vide, courte ou sans préfixe `phc_`, et le job AAB applique les mêmes trois règles **avant** de construire. → **PostHog DOIT être déclaré** : analytique produit + enregistrement de session masqué. |
| 2 | AD_ID sur l'AAB réel | **RÉSOLU.** Manifeste **fusionné** du bundle livré : permission absente. Vérifié en dépaquetant `base/manifest/AndroidManifest.xml` de l'AAB téléversé, et par `preflight-android-aab.sh` qui échoue si elle revient. ⚠️ **La déclaration Play, elle, disait encore le contraire** — la corriger réactive les erreurs bloquantes que quelqu'un avait désactivées. |
| 3 | Suppression de compte incomplète | **RÉSOLU.** `deleteMe` fait désormais 499 lignes et 38 `deleteMany`, et traite nommément `counsellorReview`, le registre ambassadeur, le référral et le contact Mautic. Les tables récentes (`EefInterest`, `PremiumWaitlistEntry`) suivent en `onDelete: Cascade` sur `userProfile.delete`. → « **≤ 30 jours** » redevient une réponse exacte. |

---

## 0ter. NOUVEAU depuis la 49 — à ne pas oublier dans les formulaires

| Changement | Effet sur les déclarations |
|---|---|
| **Les quatre outils IA ne sont plus masqués** | `AppConfig.aiToolsEnabled` porte `defaultValue: true`, et les `DART_DEFINES` de l'archive 2.2.0 (53) ne le contredisent pas : CV, lettre de motivation, simulateur d'entretien et relecture de document sont **actifs** dans la build soumise. Les surfaces d'IA générative passent de **2 à 6** (§3). C'est un changement de nature pour la revue Apple — l'app soumise n'est pas l'app masquée de la 49. |
| **Mesure d'audience passée d'opt-in à ACTIVE PAR DÉFAUT** (revue du build 49, point 6) | La réponse Play « Requis / l'utilisateur peut choisir » **reste « peut choisir »** : le refus explicite existe, fonctionne et est conservé (`app_controller.dart`, verrouillé par `analytics_consent_test.dart`). Mais la collecte démarre **sans geste préalable**, et c'est annoncé dans les CGU (clause « Mesure d'audience »). Ne pas décrire un opt-in. |
| **Liste d'attente Karatou Premium** (en ligne depuis le 03/09) | Nouvelle collecte : identifiant de compte, horodatage, version **et langue** du texte de consentement. Se rattache à « Activité dans l'application → Autres actions » + l'ID utilisateur déjà déclaré. **Aucune donnée financière** : inscription gratuite, sans prix ni moyen de paiement (`premium_screen.dart`, garde exécutable dans `premium_waitlist_consent_version_test.dart`). |
| **Déclaration d'intérêt « Études en France »** (vitrine allumée le 30/08) | Même rattachement. Stocke niveau, filières, horodatage et version de consentement. Écriture réservée aux comptes étudiants. |
| **30 bourses servies au lieu de 10** | Aucun effet sur les déclarations : données de catalogue publiques, aucune donnée personnelle. |

---

## 0quater. NOUVEAU avec la 54 — à reporter dans les formulaires À LA SOUMISSION

| # | Point | Ce qu'il faut faire | Qui tranche |
|---|---|---|---|
| **LIV-09** | **Wikimedia Commons** est un destinataire | La politique publiée le nomme (IP + user-agent dès qu'un logo s'affiche). Ajouté au tableau §5. Reporter la **même réponse que pour YouTube** dans Data Safety (Play) et App Privacy (Apple). | Dev (fait ici) · Ops (consoles) |
| **XC-06** | **Finalités commerciales** des coordonnées | La politique publiée dit que (a) les déclarations d'intérêt sont lues par l'équipe commerciale pour rappeler l'étudiant et (b) dès qu'un dossier est déposé, nom, e-mail, téléphone, WhatsApp et contact du tuteur partent par e-mail aux commerciaux. Or les tableaux §1.2 et §2 ne déclarent que « Fonctionnalité / Compte ». **⚠️ À TRANCHER avec le juridique** — recommandation : ajouter la finalité **Marketing** (Play : « Advertising or marketing » ; Apple : « Developer's Advertising or Marketing ») sur Nom, E-mail, Téléphone et listes d'intérêt, pour que les consoles ne contredisent pas la politique. Le sens de l'erreur est choisi : sur-déclarer coûte une ligne, sous-déclarer coûte une soumission (« declaration inconsistent with privacy policy »). | **Juridique** |
| **XC-06** | **Suivi du 18/10/2026 — décision NON reportée** | Le propriétaire a décidé le 18/10/2026 de **ne pas déclarer de finalité « Marketing »** pour les coordonnées, **sous réserve** qu'aucun envoi promotionnel ne parte sans opt-in explicite. Vérification du code : la newsletter (Mautic) n'est alimentée qu'après consentement (`newsletter-sync.service.ts`, `resolveNewsletterAction`) ; le récapitulatif hebdomadaire est fermé par défaut et respecte la désinscription `weekly_digest` ; **mais les campagnes de l'admin** (`campaign-executor.service.ts`) envoient un modèle **libre** en push et par e-mail (Resend) à des audiences larges (`all_users`, `all_students`, pays, niveau…) **sans aucun filtre de consentement ni de désinscription** — le code permet donc un envoi promotionnel sans opt-in. En outre, la politique dit que l'équipe commerciale reçoit les coordonnées à chaque dossier déposé et rappelle les déclarants d'intérêt (ces derniers sur consentement). **Ne pas déclarer « pas de Marketing » en l'état** : soit ajouter la finalité (recommandation d'origine), soit réserver par écrit (ou par le code) les campagnes admin aux messages de service et/ou à un opt-in, puis trancher. **À VALIDER (propriétaire).** | **Propriétaire** |
| **XC-06** | **Suivi du 19/10/2026 — correctifs 57 (ce que le code garantit désormais)** | Les campagnes de l'admin portent une **finalité** (`NotificationCampaign.purpose`) : `informational` (service) ou `promotional`, **`promotional` par défaut** (texte libre, et toutes les campagnes antérieures). Pour une campagne promotionnelle, le code garantit, à l'aperçu comme à l'envoi (`campaign-purpose.ts`, tests unitaires et Postgres) : **e-mail** seulement aux comptes qui ont coché « Nouvelles et offres de KPB » (`promotionsEmailOptIn`, **non par défaut**, consentement horodaté, distinct de la newsletter bourses) — et, pour un mineur déclaré, avec en plus l'accord de son représentant légal —, avec un **lien de désinscription en un clic** et `List-Unsubscribe` dans chaque e-mail (sans secret de signature, l'e-mail ne part pas) ; **push** jamais vers un compte qui a coupé « Nouvelles et offres de KPB » (`kpb_promotions`). La politique (in-app et `confidentialite.html`) le dit (ajout marqué « à relire par le propriétaire »). **Ce qui n'est PAS garanti par le code, donc XC-06 reste ouvert** : (1) le **push promotionnel est en opt-out** (autorisation des notifications du téléphone + interrupteur dédié), pas en opt-in explicite — si la réserve du 18/10 vise aussi le push, elle n'est tenue que par un consentement à ajouter (même mécanique que l'e-mail) ; (2) la **classification** d'une campagne reste un choix humain dans l'admin (une offre marquée « information de service » échapperait aux filtres) ; (3) l'**équipe commerciale** reçoit toujours les coordonnées à chaque dossier déposé et rappelle les déclarants d'intérêt (sur consentement) — question juridique inchangée. **À VALIDER (propriétaire)** : accepter le push en opt-out ou demander l'opt-in ; puis trancher la case Marketing avec (3). | **Propriétaire** |
| **XC-06** | **Décision du 19/10/2026 — TRANCHÉ** | Le propriétaire garde le **push promotionnel en opt-out** (désactivable dans les réglages de notification, clé `kpb_promotions`) et **déclare donc la finalité « Marketing »** : Play Data Safety (adresse e-mail, identifiants de l'appareil/notification : « Marketing » coché en plus des finalités existantes) et Apple App Privacy (« Third-Party Advertising » NON, « Developer's Advertising or Marketing » OUI). L'e-mail promotionnel reste réservé par le code aux comptes consentants. |
| **XC-06** | **Suivi du 19/10/2026 (chantier juridique 57) — push promotionnel désormais en OPT-IN (App Store 4.5.4)** | Apple (4.5.4) exige pour le push promotionnel un consentement **explicite, préalable, recueilli dans l'app et retirable dans l'app**. Le code l'impose désormais (`campaign-purpose.ts`, tests unitaires et Postgres) : un push d'une campagne `promotional` ne part qu'aux comptes qui ont **activé** « Nouvelles et offres de KPB par notification » (`UserProfile.promotionsPushOptIn`, **non par défaut pour tous, comptes existants compris**, preuve horodatée `promotionsPushConsentedAt`) **et** n'ont pas coupé `kpb_promotions` ; mineur déclaré : accord du représentant légal en plus (même règle que l'e-mail). Une build qui ne connaît pas le champ ne peut pas l'activer, donc ne reçoit plus de push promotionnel. Choix d'interface : **deux interrupteurs distincts** (e-mail dans Profil, notification dans les réglages des notifications), plutôt qu'un consentement unique — l'e-mail avait déjà son consentement horodaté, et le réutiliser pour le push aurait fait passer pour consentants au push des comptes qui n'avaient accepté que l'e-mail. Les messages de service (`informational`) ne changent pas. **Formulaires** : la finalité **« Marketing » reste déclarée** (Play Data Safety ; Apple « Developer's Advertising or Marketing ») — c'est honnête (e-mail et push promotionnels existent) et ça ne coûte rien ; préciser **opt-in** partout où un champ libre le permet. Restent hors du code : la classification humaine d'une campagne, et les coordonnées envoyées à l'équipe commerciale. | Dev (fait) · Ops (consoles) |
| **XC-06** | « Langue du consentement » | Corrigé §1.2 : `EefInterest` n'a pas de colonne de langue. Soit retirer l'affirmation (fait), soit ajouter `consentLocale` avec une `eef-consent-v2` — **non fait**, voir `docs/eef-consent-v1.md`. | Juridique + Dev |
| **XC-04** | **Applications gouvernementales** (Play → App content → « Government apps ») | L'app communique des informations d'État (date d'ouverture de la campagne ; la 56 n'affiche **plus** de suspension d'un pays — retirée par #324 et #326). Répondre : **l'app n'est pas une application gouvernementale et ne représente aucune entité gouvernementale**. La description de la fiche doit porter la **mention de non-affiliation** et la **source officielle** : texte prêt, **pour la 56**, dans `docs/release-56-store-pack.md` §4 (FR et EN, sans « suspensions » : la 56 n'en affiche plus ; `docs/release-54-store-pack.md` §4 et `docs/release-55-store-pack.md` §4 les citent encore et ne se collent plus). Côté Apple, vérifier la guideline 5.2.1 (usage du nom « Campus France » — cité en corps de texte seulement, jamais en enseigne : `eef_naming_test`). | Contenu KPB + Ops |
| **MISS-04** | **Classification d'âge** | L'App Store affiche **4+** alors que les CGU fixent **16 ans** et que l'app a **6 surfaces d'IA générative à texte libre**. Remplir le questionnaire App Store Connect **et** IARC avec les réponses du §3, **garder la preuve des réponses** (exigée par le §5 du contrat de soumission), consigner la décision D2 (`store-listing-copy.md` §9). | Ops + propriétaire |
| **XC-03** | L'espace réel pendant la revue | Décision et texte pour « Notes for Review » : `docs/release-54-store-pack.md` §3. | Propriétaire |

## 0quinquies. Build 56 — rien ne change dans les formulaires, sous six conditions

La 56 ajoute la bulle verte WhatsApp, la visite guidée et la feuille « écoles privées », tous
dormants derrière `eefSpace` et, pour deux d'entre eux, un interrupteur serveur
(`docs/release-56-store-pack.md`). **Data Safety et App Privacy restent ceux de la 55**, tant que
les six faits suivants restent vrais sur le SHA final — l'un tombe, « inchangé » tombe :
(1) les ajouts de la 56 (bulle, feuille) n'envoient qu'un lien `wa.me` sans donnée personnelle : l'écran et le sujet choisi, rien du profil ; (2) identifiants analytiques fermés
(`docs/analytics-event-contract.md`) ; (3) aucun nouvel hôte ; (4) aucune transmission aux
écoles, aucun formulaire ; (5) état de la visite local à l'appareil ; (6) aucune dépendance ni
manifeste modifié. Preuves et commandes : pack §5 et §6. Restent à trancher **avant la
soumission**, inchangés par la 56 : **XC-06** (finalité Marketing) et **D5** (prix FCFA affichés).
*Suivi du 18/10/2026* : **D5 tranché** — les prix FCFA restent affichés **à titre indicatif**
(préfixe « ~ », `CurrencyUtils.formatXof(approximate: true)`) et sont **payés hors store**
(bouton WhatsApp vers un conseiller), ce que disent déjà les notes de revue (« their FCFA price is
shown for information… payment is arranged outside the app ») ; **XC-06 tranché le 19/10/2026 : finalité « Marketing » déclarée** (§0quater,
lignes « Suivi du 18/10/2026 » et « Suivi du 19/10/2026 » : l'e-mail promotionnel est désormais
réservé aux consentants par le code ; le push promotionnel, d'abord laissé en opt-out, est **en opt-in
depuis le chantier juridique 57** — App Store 4.5.4, ligne « Suivi du 19/10/2026 (chantier juridique 57) »).

## 0sexies. Migration push OneSignal → FCM — ce qui change à la build qui la porte

À partir de la build qui embarque `firebase_messaging` à la place de `onesignal_flutter`
(`lib/app/core/services/push_service.dart`), **l'app n'envoie plus rien à OneSignal** :

| Ligne | Avant (OneSignal) | Avec FCM | Preuve |
|---|---|---|---|
| Infos perso — **ID utilisateur** | Partagé (OneSignal) | **Non partagé** : l'ID ne part que vers notre backend (`POST /device-tokens`) et PostHog (`identify`, collecte) | `PushService.login` → `registerDeviceToken(token, platform)` |
| Activité — **Autres actions** (4 étiquettes) | Partagé (OneSignal) | **Ligne à retirer** : plus aucune étiquette ne part ; le ciblage se calcule côté serveur | `syncPushIdentity()` sans `tags` (`translations_build49_truth_test`) |
| **Identifiants d'appareil** | Partagé (OneSignal) | Collecté (jeton FCM, Firebase = sous-traitant) — **non partagé** | `FirebaseMessaging.getToken()` |
| Sous-traitants §5 | OneSignal : ID + 4 étiquettes | Firebase Cloud Messaging : jeton d'appareil seul | `fcm-sender.service.ts` |

**Mais OneSignal ne disparaît pas des formulaires tout de suite.** Les builds antérieures
restent installées et le backend leur envoie encore leurs notifications par OneSignal
(`PushSenderService`, repli quand l'élève n'a pas de jeton FCM) ; leurs abonnements portent
toujours l'ID et les 4 étiquettes. Tant que ce repli tourne (variables `ONESIGNAL_*` posées sur
le serveur), garder les lignes « Partagé (OneSignal) » ci-dessous et la ligne OneSignal du §5 ;
la politique de confidentialité le dit déjà (« uniquement pour les versions antérieures »).
**Le jour où le repli est retiré** : appliquer le tableau ci-dessus, retirer la puce OneSignal
des deux politiques (le test `translations_build49_truth_test` le réclame), et demander la
suppression des données de l'application KPB Education chez OneSignal.

Localisation iOS : `NSLocationWhenInUseUsageDescription` reste déclarée par précaution
(`Info.plist`) jusqu'à preuve, sur l'archive, qu'aucune bibliothèque ne référence plus
CoreLocation. Réponse inchangée : **ne pas cocher Localisation**.

## 0septies. Build 57 (2.3.1) — parrainage côté app : ce qui change dans les formulaires

Décision du propriétaire du 17/10/2026 : les parties app du parrainage entrent dans la 57
(`docs/runbook-campagne-ambassadeurs.md` §8), derrière trois drapeaux **fermés**
(`features.referralInstallReferrer`, `referralOnboardingCode`, `referralLeaderboard`). Détail et
preuves : `docs/release-57-store-pack.md` §4 et `docs/data-inventory.md` §6 bis.

| Ligne | Réponse avec la 57 | Preuve |
|---|---|---|
| Play — **Identifiants d'appareil ou autres** | Garder « Collecté, non partagé » et **ajouter la finalité « Prévention de la fraude, sécurité et conformité »** : un **identifiant d'installation** (UUID v4 aléatoire, ni IMEI ni identifiant publicitaire) part en `X-KPB-Device-Id` avec chaque `POST /referrals/redeem`, **drapeaux ou non** ; le serveur n'en garde qu'une empreinte HMAC (180 jours) | `lib/app/core/services/referral_attribution.dart` (`installId`) ; `test/core/repositories/referral_api_test.dart` (en-tête sur cette route seulement) |
| Play — **Play Install Referrer** (SDK Android `play_install_referrer` 0.5.0 → Google `installreferrer` 2.2) | **Non collecté** : URL de référence, horodatages et version d'installation sont lus et traités **sur l'appareil** ; seul `ref` est gardé localement pour préremplir un champ ; le code ne part qu'au rattachement **confirmé** par l'élève (le rattachement par code est déjà couvert par « Autres actions », KPB-69) | `referral_attribution.dart` (`captureInstallReferrerOnce`, aucun appel réseau) |
| Apple — **Identifiers / Device ID** | Inchangé (déjà déclaré, lié, non utilisé pour le suivi) ; finalité **App Functionality** couvre la prévention de la fraude. Aucun SDK nouveau sur iOS | `ios/Runner/PrivacyInfo.xcprivacy` (`NSPrivacyCollectedDataTypeDeviceID`) |
| Apple — **Tracking** | **Non**, inchangé : l'Install Referrer est Android seulement, sert à préremplir un code de parrain, ne joint rien à des données tierces | — |
| Classification d'âge | L'écran « Compétition ambassadeurs » n'y change rien (ni interaction entre utilisateurs ni contenu généré ; un concours avec prix, Apple 5.3, se signale aux notes de revue, pack 57 §3). **La communauté, elle, la change dès la 57** : voir §3 bis (décision du propriétaire du 20/10/2026) | — |

**Politique (18/10/2026)** : la politique in-app (FR/EN) et `web/public/confidentialite.html`
nomment désormais l'identifiant d'installation (finalité prévention de la fraude), la lecture du
lien d'invitation (préremplissage, rien de transmis sans confirmation), les empreintes HMAC
(180 jours) et la compétition (section « Parrainage et compétition des ambassadeurs »). Texte
rédigé le 18/10/2026, **à relire par le propriétaire avant l'archive** (le texte in-app est
compilé) — sans quoi « declaration inconsistent with privacy policy ».

---

## 1. Google Play — Data Safety

### 1.1 Portée
- **L'app collecte-t-elle / partage-t-elle des données ?** **Oui (collecte).**
- **Partage (« shared ») :** les transferts vers sous-traitants (OpenRouter, Firebase,
  Supabase, PostHog, Resend, Mautic, PayDunya, CinetPay) = **collecte**, PAS
  « partage ». **Deux exceptions à cocher « Partagée » :**
  - **OneSignal** — reçoit l'**ID utilisateur** (UUID de profil) + **4 étiquettes**
    de ciblage. Vérifié : `onesignal_service.dart:80` (`OneSignal.login`), `:85`
    (`addTags`) ; étiquettes = `account_type, level, target_country, locale`
    (`app_controller.dart:1918`). **L'e-mail ne part PAS** (`onesignal_service.dart:73`).
  - **Service de reconnaissance vocale (Apple/Google)** — reçoit l'audio *seulement*
    si le local échoue **et** que l'utilisateur accepte (voir §Audio). À nommer en
    politique quoi qu'il arrive.
- **Toutes les données chiffrées en transit ?** **Oui** — API prod `https://`
  (`app_config.dart:250`), ATS iOS `NSAllowsArbitraryLoads=false`, aucun
  `usesCleartextTraffic` Android.
- **Suppression possible ?** **Oui — en app + URL** (voir §4).
- **Identifiant publicitaire utilisé ?** **NON.** Vérifié : AD_ID retiré du
  manifeste (`tools:node="remove"`), `google_analytics_adid_collection_enabled=false`,
  `QUERY_ALL_PACKAGES` absent. **Reconfirmé sur l'AAB signé de la 53** : permission
  absente du manifeste fusionné. Si la Play Console affiche un avertissement
  d'incohérence, c'est la **déclaration** qu'il faut corriger, pas l'app.

### 1.2 Types de données (collecté / partagé / requis-ou-optionnel / finalité)

| Type Play | Collecté | Partagé | Requis / Choix | Finalité | Preuve |
|---|---|---|---|---|---|
| Infos perso — **Nom** | Oui | Non | **Requis** | Fonctionnalité, Compte | `app_controller.dart:1997`, validateur `_req` |
| Infos perso — **E-mail** | Oui | **Non** | **Requis** | Fonctionnalité | e-mail retiré d'OneSignal (`onesignal_service.dart:73`) |
| Infos perso — **Téléphone** | Oui | Non | **Optionnel** | Fonctionnalité | aucun validateur (`onboarding_screen.dart:396-398`) |
| Infos perso — **ID utilisateur** | Oui | **Oui (OneSignal)** | **Requis — non coupable** | Fonctionnalité, Analyses | `OneSignal.login(profile.id)` ; hors interrupteur analyse |
| Infos perso — **Autres** (date de naissance, nom+contact tuteur) | Oui | Non | Requis si mineur déclaré | Contrôle d'âge, consentement tuteur | `schema.prisma:388-390` |
| Infos financières | **Non** | — | — | — | aucun moyen de paiement, aucun SDK d'achat |
| Messages — **In-app (dossiers)** | Oui | Non | Requis pour la fonction | Fonctionnalité | tunnel `case_tunnel_flow.dart:357` |
| Messages — **Autres (surfaces IA → OpenRouter)** | Oui | Non (aucun ID transmis) | **Optionnel — consentement explicite** | Fonctionnalité | `AiConsentGuard` ; pas de nom dans l'invite |
| Photos | Oui | Non | **Optionnel** | Fonctionnalité | avatar seul, sans EXIF |
| Fichiers & docs | ⚠️ **Point 6** | Non | Optionnel | Fonctionnalité | dépend de `applicationArtifacts.enabled` / `counsellorStudy.enabled` sur `GET /success-lab/access`, pas du drapeau public |
| **Audio — enregistrements vocaux** | **Non** | — | — | — | on-device + accord explicite ; aucun octet chez KPB |
| Activité — **Interactions** | Oui | Non | **Peut choisir** — active par défaut, refus honoré | Analyses | opt-out réel (`analytics_service.dart:144`) ; défaut changé en 50, annoncé aux CGU |
| Activité — **Historique de recherche** | Oui | Non | **Peut choisir** — même interrupteur | Analyses | terme en clair vers Firebase **et PostHog** (`:559`) |
| Activité — **Autres actions** (4 étiquettes OneSignal) | Oui | **Oui (OneSignal)** | **Requis — non coupable** | Fonctionnalité (+ perso.) | `addTags` (`onesignal_service.dart:85`) |
| Perf — **Journaux de plantage** | Oui | Non | **Peut choisir** — active par défaut | Stabilité | opt-out réel + purge (`crashlytics_observability.dart:52,59`) ; dSYM envoyés depuis la 52, donc plantages symbolisés |
| Perf — **Diagnostics** | Oui | Non | **Peut choisir** — même interrupteur | Stabilité | idem |
| Activité — **Autres actions** (listes d'intérêt : Premium, Études en France) | Oui | Non | **Peut choisir** — geste explicite | Fonctionnalité | `PremiumWaitlistEntry` : id de compte, horodatage serveur, version **et langue** du consentement. `EefInterest` : id de compte, horodatage serveur, version du consentement — **pas de langue** (la table n'a pas de colonne de langue ; seule `PremiumWaitlistEntry` en a une, XC-06). Aucune donnée financière. |
| **Identifiants d'appareil** | Oui | **Oui (OneSignal)** | **Requis** | Analyses, Push | OneSignal init inconditionnel ; ID Firebase suit l'interrupteur |

> **Requis vs « l'utilisateur peut choisir » — ne pas uniformiser.** Nom/E-mail =
> *Requis* ; Téléphone = *Optionnel* ; lignes analytiques + diagnostics = *peut
> choisir* ; ID utilisateur / étiquettes OneSignal / ID appareil = *Requis*. Une
> fiche « tout optionnel » ou « tout requis » est fausse.
>
> **Attention au sens de « peut choisir » pour l'analytique.** Depuis la 50, la
> mesure démarre **sans geste préalable** et l'utilisateur peut la couper ensuite.
> La case Play reste « l'utilisateur peut choisir » — le refus existe, fonctionne
> et est conservé — mais ne décrivez nulle part un opt-in : ce serait faux, et le
> texte des CGU (clause « Mesure d'audience ») dit l'inverse.
>
> **Traitement éphémère : Non** partout (backend + consoles tierces persistent).
>
> **NE PAS cocher :** Localisation (aucun appel géo ; chaîne iOS gardée par précaution,
> jamais demandée — voir §0sexies) · Achats intégrés (CTA WhatsApp, aucun SDK) · aucun type
> supplémentaire pour l'embed YouTube (l'IP n'est pas un type déclarable Play).

---

## 2. Apple — App Privacy (« nutrition labels »)

- **Suivi (Tracking) : Non** partout. Vérifié : aucun `NSUserTrackingUsageDescription`,
  pas d'ATT, `PrivacyInfo.xcprivacy` `NSPrivacyTracking=false`. ⚠️ **Point 4** :
  `GoogleAdsOnDeviceConversion` est bundlé (transitif) mais non utilisé pour du
  suivi — ne change pas la réponse « Tracking : Non », mais à mentionner si la
  liste des SDK est demandée.

| Type Apple | Collecté | Lié | Suivi | Finalité | Preuve |
|---|---|---|---|---|---|
| Contact — **Nom, E-mail** | Oui | Oui | Non | Fonctionnalité, Compte | requis à l'inscription |
| Contact — **Téléphone (+ WhatsApp)** | Oui | Oui | Non | Fonctionnalité | optionnel |
| Contact — **Autres (nom+contact tuteur)** | Oui | Oui | Non | Fonctionnalité (mineur) | coordonnées d'un tiers, `schema.prisma:388-390` |
| Sensibles | **Non** | — | — | — | aucun champ sensible au modèle |
| Contenu — **Photos** (avatar) | Oui | Oui | Non | Fonctionnalité | sans EXIF/GPS |
| Contenu — **Support (messages dossier)** | Oui | Oui | Non | Fonctionnalité | tunnel |
| Contenu — **Autres (surfaces IA → OpenRouter)** | Oui | Oui | Non | Fonctionnalité | derrière consentement ; aucun ID transmis |
| Contenu — **Audio** | **Non** | — | — | — | on-device + accord explicite (voir §Audio) |
| Contenu — **Autres (docs dossier)** | ⚠️ **Point 6** | — | — | — | Yes seulement si `GET /success-lab/access` rend `applicationArtifacts.enabled` **ou** `counsellorStudy.enabled` vrai pour un compte réel |
| Identifiants — **ID utilisateur** | Oui | Oui | Non | Fonctionnalité, Analyses | OneSignal + PostHog `identify` — PostHog **actif** depuis la 52 |
| Identifiants — **ID appareil** | Oui | Oui | Non | Fonctionnalité, Analyses | ID instance Firebase + abonnement OneSignal |
| Usage — **Interaction, Historique recherche** | Oui | Oui | Non | Analyses, Fonctionnalité | désactivable |
| Diagnostics — **Crash, Performance** | Oui | **Non (non lié)** | Non | Stabilité | aucun `setUserIdentifier` ; désactivable |
| Santé, Finances, Localisation, Navigation, Contacts | **Non** | — | — | — | absence exhaustive vérifiée |

> **Session replay (PostHog) — À DÉCLARER, ce n'est plus conditionnel.** L'archive
> `2.2.0 (53)` **porte la clé** : `strings App.framework/App | grep -c '^phc_'` → 1,
> là où la 50 rendait 0. Déclarer sous *Usage Data → Product Interaction*, **Lié
> Oui, Suivi Non**. Le contenu est masqué à la capture (`main.dart`,
> `maskAllTexts` + `maskAllImages`) → **pas** « User Content ». Désactivable par
> le même interrupteur que le reste de la mesure d'audience.
>
> Le préflight iOS refuse maintenant une clé vide, trop courte ou sans préfixe
> `phc_`, et le job AAB applique les trois mêmes règles avant de construire : une
> build ne peut plus repartir muette en silence comme la 50.
>
> **Contenu tiers embarqué (YouTube/Google) :** le lecteur transmet IP + user-agent
> à Google à l'ouverture → déclarer au titre des partenaires tiers (Usage Data /
> Identifiers via partenaire). Le budget auto-déclaré = App Functionality, **pas**
> « Financial Info ».

---

## 3. Classification d'âge (Apple ASC + IARC Play)

| Item | Réponse | Preuve |
|---|---|---|
| Âge contractuel minimum | **16** | CGU `conditions.html:29` ; in-app `app_translations.dart:704` |
| Accès web illimité | **Non** | lecteur YouTube non navigable (`IgnorePointer`, `controls:0`) ; liens sortants en `externalApplication` |
| Interaction entre utilisateurs | **Oui dès la 57** (communauté, §3 bis). Jusqu'à la 56 : Non (vérifié sur la 53) | 53 à 56 : Community derrière `!mvpOnly` défaut true ; forum 404 sous `MvpGuard`. 57 : §3 bis |
| Contenu généré par l'utilisateur | **Oui — public et modéré dès la 57** (§3 bis) ; s'y ajoutent 3 écritures visibles du staff seulement | §3 bis ; 3 écritures, aucune publique |
| Signalement de contenu / blocage | **Oui / Oui dès la 57** (§3 bis) ; signalement IA : Oui | `ai_content_report_sheet.dart` → `POST /cases` ; §3 bis |
| IA générative, texte libre | **Oui — 6 surfaces** | coach, test d'orientation, CV, lettre de motivation, simulateur d'entretien, relecture de document → OpenRouter |
| Localisation | **Non** | aucun plugin géo |
| Jeux d'argent | **Non** | absence exhaustive |
| Achats intégrés (IARC) | **Non** | CTA WhatsApp, aucun SDK. PayDunya/CinetPay = §processeurs, jamais ici |
| Contenu « mature » éditorial | **NON PROUVÉ** | dépend de la revue éditoriale, pas du binaire |

> **Recommandé :** saisir ces réponses et laisser chaque questionnaire calculer la
> tranche. **Ne pas** reporter l'ancien couple « Apple 12+ / Google Teen » (dérivé
> d'un ancien module communautaire et sans les 6 surfaces d'IA) : avec la 57, ce sont
> les lignes du §3 bis qui décrivent la communauté.

### 3 bis. Communauté (C1 + C2) — DÉCLARÉE DÈS LA SOUMISSION DE LA 57 (décision du propriétaire du 20/10/2026)

La communauté est **dans le binaire de la 57**, derrière le drapeau distant `features.community`
(`KPB_COMMUNITY_ENABLED`, `false` par défaut, `docker-compose.yml`) **sans verrou de compilation** :
c'est donc la 57 « qui l'affiche » — ouvrir le drapeau suffit, sans nouvelle build. Tant qu'il est
fermé, les routes élève `/community/*` répondent 404 et l'app montre « La communauté arrive
bientôt » : le relecteur ne la voit pas (« OFF at review time », pack 57 §3). Décision du
propriétaire du 20/10/2026 : **la déclarer à Apple et à Google dès la soumission de la 57**
(notes de revue, classification d'âge, formulaires de confidentialité) — **avec la 57, pas « le
jour de la bascule »**. Saisir ces lignes à la place des lignes correspondantes du §3 :

| Item | Réponse (dès la 57) | Preuve (serveur, `docs/community-api-contract.md`) |
|---|---|---|
| Interaction entre utilisateurs | **Oui** — publications et réponses publiques entre élèves, **sans message privé** ni mention d'utilisateur | `community-student.controller.ts` ; aucun DM (§1 du contrat) |
| Contenu généré par l'utilisateur | **Oui — public, modéré** : filtre avant publication (coordonnées, WhatsApp, demandes d'argent, mobile money, liens hors liste blanche, insultes FR/EN) → « en attente de revue » ; file de modération de l'équipe (délai cible 24 h) | `community-content-filter.ts`, `GET /admin/community/queue` |
| Signalement de contenu / blocage | **Oui / Oui** — signaler une publication, une réponse ou un membre ; bloquer un membre (ses contenus disparaissent, dans les deux sens) ; masquage provisoire à 3 signalements | `POST /community/reports`, `POST /community/members/:id/block` |
| Charte / règles | **Oui** — 4 règles, acceptées (horodatées, versionnées) avant la 1re publication | `POST /community/charter/accept`, `CommunityCharterAcceptance` |
| Sanctions | lecture seule N jours, bannissement, journal d'audit | `POST /admin/community/members/:id/sanctions` |
| Mineurs (16-17 ans) | profils publics minimaux (prénom + initiale, pays, badges) ; ni e-mail, ni téléphone, ni âge, ni localisation | `community-presenter.ts` (`memberAuthor`) |
| Apple « User Generated Content » (Guideline 1.2) | filtre + signalement + blocage + contact + modération : **tous présents côté serveur** ; contact = équipe KPB (WhatsApp / e-mail existants) | — |
| Play « Contenu généré par les utilisateurs » / IARC « les utilisateurs peuvent interagir » | **Oui**, modéré | idem |

Sécurité des données (Play) / étiquettes (Apple) **dès la 57** : ajouter **Autre contenu généré
par l'utilisateur** (publications, réponses, signalements) — collecté, **non partagé**, lié au
compte, facultatif, finalités Fonctionnalité de l'app et Prévention de la fraude, sécurité et
conformité (filtre anti-arnaque, modération) ; supprimé avec le compte, inclus dans l'export (§4) ;
« Autres actions » : charte acceptée, « utile », discussions suivies, membres bloqués. Apple :
*User Content → Other User Content* (lié, pas de suivi, App Functionality). Questionnaire d'âge
Apple (capacités) : contenu généré par les utilisateurs **Oui** ; messagerie et discussion **Non**
(aucun message privé) — À VALIDER (propriétaire) avec l'intitulé exact de la grille du jour.
Lignes prêtes : `docs/release-57-store-pack.md` §4.4. CGU et politique
(`web/public/conditions.html`, `confidentialite.html`, textes in-app) : sections « Communauté
d'entraide » **validées par le propriétaire le 19/10/2026**. *À VALIDER (propriétaire) : délai de
modération annoncé, adresse de contact affichée.*

### 3 ter. Bot « Passerelle » (C3 bis) — rien à changer tant que la source coach reste fermée

Déclaré aux notes de revue de la 57 (`features.assistBridge`, OFF à la revue : « a settings switch
for private KPB-team suggestions »), comme la communauté (§3 bis).

La passerelle (`docs/runbook-bot-passerelle.md`) ne collecte **aucune donnée nouvelle** : elle lit
les publications et réponses que l'élève vient d'écrire (déjà déclarées au §3 bis) et lui envoie
une notification privée par le chemin push existant ; aucun texte n'est recopié, aucun destinataire
tiers ne s'ajoute, aucune interaction entre utilisateurs n'est créée. **Aucune réponse de console ne
change** en `shadow` (défaut) ni en `on` avec la seule source communauté.

**Le jour où `KPB_ASSIST_BRIDGE_COACH=true`** (et pas avant), dans la même mise à jour que la
politique de confidentialité : Play *Sécurité des données* → « Messages — Autres messages in-app
(coach IA) » : ajouter la finalité **Personnalisation** (suggestion d'une fonction de l'app à partir
du message) ; Apple → « Other User Content » : ajouter **App Functionality / Product
Personalization** selon la grille du moment. *À VALIDER (propriétaire).*

---

## 4. Suppression de compte & export (exigence store)

| Champ console | Réponse | Preuve |
|---|---|---|
| Play → *Suppression des données possible ?* | **Oui — en app + URL web** | `DELETE /profiles/me` (`profiles.controller.ts:117`) |
| Play / Apple → **URL de suppression de compte** | `https://kpbeducation.cloud/suppression-compte.html` | page + routeur Traefik + sonde uptime |
| Export proposé | **Oui — en app, JSON partagé depuis l'app** (pas une archive téléchargeable) ; il comprend les notifications in-app depuis le 18/10/2026 (clé `notifications`) | `GET /profiles/me/export` (`profiles.controller.ts:110`) |
| Suppression immédiate | **Oui dans le code** (hard-delete Supabase puis purge locale) | `profiles.controller.ts:115` |

> ✅ **Point 3 — RÉSOLU.** Il était encore ouvert le 25/08 : `CounsellorReview`
> (nom civil), le registre ambassadeur et le contact Mautic survivaient
> indéfiniment, et « ≤ 30 jours » était donc faux pour ces utilisateurs.
>
> `deleteMe` fait aujourd'hui **499 lignes et 38 `deleteMany`**, et traite
> nommément `counsellorReview`, l'ambassadeur, le référral et Mautic — ce dernier
> sans jamais faire de lookup quand le contact n'a jamais été synchronisé, la
> requête elle-même divulguant l'adresse au sous-traitant (revue P1 #246). Les
> tables plus récentes (`EefInterest`, `PremiumWaitlistEntry`) tombent en
> `onDelete: Cascade` sur `userProfile.delete({ where: { id } })`.
>
> → **« ≤ 30 jours » est désormais une réponse exacte**, et « immédiat » l'est pour
> le compte et les données actives. Vérifié sur le code servi en production
> (`90264244a0e0`).
>
> **Fenêtre JWT inévitable :** un access-token déjà émis reste valide jusqu'à son
> `exp` après suppression Supabase — ne pas présenter la suppression comme une
> révocation rétroactive des JWT. C'est la **seule** réserve qui subsiste.
>
> (Les « survivances de purge » que cette fiche listait ici — `CounsellorReview`,
> registre ambassadeur, contact Mautic — sont **traitées** depuis, voir le point
> ci-dessus. `STORE_READINESS.md` §6 décrit encore l'ancien état ; ne pas s'y
> fier pour cette question.)

---

## 5. Régions & sous-traitants (recopier au formulaire « destinataires »)

Hébergement **UE** ; responsable **EAU** ; sous-traitants **US** nommés à part — les
trois se cumulent.

| Sous-traitant | Région | Reçoit | Finalité | Partagé (Play) |
|---|---|---|---|---|
| Backend NestJS/Postgres | **France** (VPS) | toutes les données app | Fonctionnalité | collecte |
| Supabase Auth | **eu-west-3 (Paris)** | e-mail, OAuth Google, jetons | Authentification | collecte |
| OpenRouter (LLM) | **US** | profil pseudonymisé (sans nom), budget en tranche, messages | Réponses IA | collecte |
| **OneSignal** | US | **ID utilisateur + 4 étiquettes** (pas d'e-mail) | Push + segmentation | **PARTAGÉ** |
| Firebase Analytics | US | ID instance, événements, **terme de recherche** | Analyses | collecte |
| PostHog | **US** | événements, replay masqué, UUID | Analyses, replay | collecte — **actif si l'archive porte la clé** (point 1) |
| Firebase Crashlytics | US | traces, modèle, OS (aucun `setUserIdentifier`) | Stabilité | collecte |
| **Reconnaissance vocale Apple/Google** | US/global | audio dicté (si repli accepté) ; texte seul rendu | Dictée | **destinataire** — ⚠️ nommer en politique |
| Resend | **US** | e-mail + objet + corps | E-mail transactionnel | collecte |
| Mautic (auto-hébergé) | France (VPS) | 7 champs, **après opt-in seulement** | Newsletter bourses | collecte |
| CinetPay | (région prestataire) | e-mail, téléphone, nom | Accompagnement payant (**toujours inatteignable** : aucun tunnel d'achat dans l'app) | collecte |
| PayDunya | (région prestataire) | facture seule, **aucune donnée client** | idem | collecte |
| **YouTube IFrame (Google)** | US/global | **IP + user-agent + id vidéo** | Lecture vidéo / vignettes | pseudonyme (IP) |
| **Wikimedia Commons (Wikimedia Foundation)** | US | **IP + user-agent** (+ URL de l'image) | Affichage des logos d'établissement (`Image.network`, dès l'ouverture d'une fiche ou d'une liste qui en porte) | pseudonyme (IP) — **même réponse que YouTube** dans les deux consoles (LIV-09) |
| **WhatsApp / Meta** | US/global | URL `wa.me` dont le texte est composé par l'app et **ne contient aucune donnée personnelle** : l'écran, la formation (**intitulé, université, ville**), les filtres posés ou l'outil pour les aides de la 55 (données publiques du catalogue) ; depuis la 56, aussi le **sujet choisi** dans la bulle verte et la feuille « écoles privées » (là, le message ne nomme que l'écran et le sujet) ; **jamais de nom, d'e-mail, de téléphone ni de pays** — + ce que l'étudiant écrit lui-même. **Aucun SDK Meta** : l'app n'ouvre qu'un lien | Remise externe | n/a (externe) — **pas un sous-traitant** |

> **OpenRouter est un *routeur*, pas un modèle.** Il redistribue chaque invite
> vers des clouds de modèles tiers ; en production le modèle demandé est
> `deepseek/deepseek-v4-flash`. Le routage est épinglé sur des points de
> terminaison **sans rétention** (`zdr: true`, plus `data_collection: 'deny'` et
> `require_parameters: true` — `llm.service.ts:routingPolicy`). Si le formulaire
> demande de nommer les destinataires en clair, écrire « OpenRouter (routeur) et
> les fournisseurs de modèles vers lesquels il achemine, épinglés sans
> rétention » : nommer OpenRouter seul laisserait croire à un destinataire
> unique.
>
> Groq reste un chemin de **repli** dans le code (variables `GROQ_*` héritées) ;
> il n'est pas le destinataire actif. Vérifier avant chaque soumission avec
> `vps-ops` → `show-state`, section « Fournisseur LLM » : elle lit le conteneur
> en cours, pas ce document.

---

_Établi le 2026-08-25. Base : `docs/STORE_READINESS.md` (18/08) + revérification
indépendante des fichiers primaires (7 questions, 0 contradiction) + `test/release/`
verte (46 tests). Tenir à jour à chaque nouveau SDK / flux / sous-traitant._
