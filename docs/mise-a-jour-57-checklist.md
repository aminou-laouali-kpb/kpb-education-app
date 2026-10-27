# Mise à jour 2.3.1 (57) — la checklist du 16/10/2026

> **Ce que ce fichier est.** L'ordre exact des opérations pour préparer, déployer, archiver,
> vérifier, soumettre et déployer **par étapes** la 57, avec les commandes. Il **succède** à
> `docs/mise-a-jour-56-checklist.md`. La 57 est une release unique : chantiers B, C, D, F, G, H, I,
> K (PR #353 à #361), bascule des notifications vers FCM (#351), correctifs #349 et #350, puis
> #362 à #374 (chantier L, catalogue, compétition, communauté et bots, parrainage, finalisation,
> correctifs et corrections juridiques) et la **PR de correctifs de l'audit 57**. Les textes
> à coller, les déclarations de confidentialité, le tableau des drapeaux et le plan de déploiement
> sont dans `docs/release-57-store-pack.md` ; la recette appareil dans `docs/device-qa-build57.md` ;
> les données dans `docs/data-inventory.md`.
>
> **État de départ — mesuré le 16/10/2026** (lecture seule) : **2.3.0 en vente** sur l'App Store
> (mise en ligne le 07/10/2026) et sur Google Play ; backend de production `28ac82dab0c2`, **sans**
> #351 ni les chantiers B à K (`/api/health` sans `push.fcm`) ; `features` : `eefTeaser=true`,
> `eef=false`, `eefSpace=true`, `eefHelpBubble=false`, `eefPrivateSchools=false`, aucune clé des
> chantiers G, K, D, I ; `minVersion=0.0.0`, `recommendedVersion=null`. Le registre n'a pas suivi
> l'envoi de la 56 (§0.2).
>
> **🔒 = étape de distribution ou de production.** Déploiement du backend, AAB importé, IPA
> envoyée, soumission, élargissement d'un palier : **aucune ne se fait sans le feu vert explicite
> du propriétaire, donné pour cette étape.** Le reste (lire, comparer, lancer un préflight en
> lecture seule) se fait librement.
>
> **Ce que la mise à jour ne fait PAS** : ouvrir `features.scholarshipMatch` ou
> `features.onboardingV2`, passer le mode d'ouverture hors de `legacy`, allumer la bulle ou les
> écoles privées, relever `KPB_MIN_APP_VERSION`, envoyer une notification de masse (hors la
> notification de service « Notre politique évolue », pack §6.5), lancer `roll-omnes-fall-2027`,
> ouvrir `features.community`. Tout cela vient après, dans l'ordre du pack §5 et §6 et de l'étape 9.

## Ce qui change par rapport à la checklist de la 56

- **Version attendue : `2.3.1 (57)`** — la 2.3.0 est en vente, une 57 en 2.3.0 serait refusée
  (ITMS-90062) et indiscernable de la 56 pour le bandeau de mise à jour (pack §1.2).
- **Couplage backend : `requires-new`**, plus `tolerates-old`. La 57 n'embarque plus le SDK
  OneSignal : sans le backend de #351 et `FCM_SERVICE_ACCOUNT_JSON`, elle ne reçoit aucune
  notification. Le backend se déploie **avant** l'app, au SHA `RELEASE` (étape 1), puis
  l'admin, puis l'app.
- **Seize migrations** à passer (étape 1) : les quinze ajoutées depuis la production (`28ac82d`)
  jusqu'à `8c215b5`, plus `20261028120000_profile_completion_without_consent` (PR de correctifs de
  l'audit 57), avec les préalables de `docs/api-contracts.md`.
- **Dépendances et manifestes changent** (#351, #362, #368) : `firebase_messaging` remplace
  `onesignal_flutter` ; `play_install_referrer` entre ; le bloc `assets` est réduit (chantier L1) ;
  deux `meta-data` FCM dans le manifeste Android. Le contrôle « rien ne doit bouger » devient
  « exactement ceci doit bouger » (étape 0.3).
- **Opérations catalogue** (IGENSIA, OMNES 2027, Amérique du Nord) : à lancer en production après
  le déploiement (étape 1, point 5) ; la reconduction OMNES 2027 attend que la 57 soit majoritaire
  (étape 9).
- **Déploiement par paliers** : Play 10 % → 50 % → 100 %, publication progressive iOS (étape 8),
  puis `KPB_RECOMMENDED_APP_VERSION` et, bien plus tard, `KPB_MIN_APP_VERSION` (étape 9).
- La recette est `docs/device-qa-build57.md` (petit appareil, texte agrandi, lecteurs d'écran,
  notifications app tuée, anciennes builds, hors ligne).

## 0. Ce qui doit être vrai avant d'archiver

### 0.1 Décisions à avoir prises AVANT d'archiver

| | Décision | Conséquence sur l'archive |
|---|---|---|
| **a** | **Version marketing** : `2.3.1` — décidée par le propriétaire le 16/10/2026 | Elle est compilée : à poser dans la PR de préparation (§0.2) |
| **b** | **Textes de la politique de confidentialité** (in-app, compilés) sur le test, la nationalité, les mineurs de 16 et 17 ans, la conservation | **Validés par le propriétaire le 19/10/2026** (#374) ; enregistrements de session PostHog : 30 jours. Après l'archive, le texte in-app ne change qu'avec une 58 ; la page web, elle, se republie seule (`deploy.yml`, `scope=web`) |
| **c** | **Collecte de la nationalité** — tranchée le 18/10/2026 (consentement explicite, facultative, effaçable) | Ne bloque pas l'archive : `features.scholarshipMatch` part fermé. Son ouverture suit le pack §5, étape 4 |
| **d** | **`FCM_SERVICE_ACCOUNT_JSON`** présent dans le `.env` de production | Bloque le lancement : sans lui, la 57 ne reçoit aucune notification |

### 0.2 La PR de préparation de la 57 (avant de relever `RELEASE`)

> **Fait le 18/10/2026** (branche de finalisation de la 57, à fusionner avant de relever
> `RELEASE`) : les points 1 à 5 ci-dessous sont posés — `version: 2.3.1+57`, préflights épinglés à
> 2.3.1 (57), registre (2.3.0 en vente, 56 consommée, 57 courante « avant l'archive »), test de la 56
> restreint à son document, bandeaux « REMPLACÉE par la 57 ». Restent À VALIDER (propriétaire) les
> trois faits de la 56 (build en vente, date de téléversement, SHA archivé).

Ce dépôt **ne pose pas** la version : elle se pose le jour où l'on prépare l'archive, dans **une**
PR, fusionnée avant de relever `RELEASE` :

1. `pubspec.yaml` : `version: 2.3.1+57`.
2. `scripts/preflight-ios-archive.sh` : `EXPECTED_BUILD="57"`, `EXPECTED_VERSION="2.3.1"` ;
   `scripts/preflight-android-aab.sh` : `EXPECTED_VERSION_NAME="2.3.1"`,
   `EXPECTED_VERSION_CODE="57"` (gardés par `test/release/artifact_signing_contract_test.dart`).
3. `docs/release-ledger.md` :
   - « Version marketing EN VENTE : `2.3.0` (depuis le 07/10/2026) » (le test
     `test/release/build_number_test.dart` exige alors une version de `pubspec.yaml` strictement
     supérieure : d'où 2.3.1) ;
   - la ligne `56` passe sous **Consommés**, avec ce qui s'est réellement passé — date de
     téléversement, SHA archivé, mise en vente (À VALIDER (propriétaire) : ces trois faits ne sont
     pas dans le dépôt) ;
   - une ligne `57` sous **Courant**, à l'état « avant l'archive » (« EN COURS (archive à faire) :
     non téléversée, non soumise », marqueur `<RELEASE>`).
4. `test/release/mise_a_jour_56_checklist_test.dart` épingle `shipping.build == '56'` : le retirer
   ou le restreindre aux documents de la 56 ; `test/release/mise_a_jour_57_checklist_test.dart`
   prend le relais.
5. Les papiers de la 56 reçoivent un bandeau « REMPLACÉE par la 57 », sans réécriture.

### 0.3 L'état à constater

Dans la suite, **`RELEASE`** = le SHA complet (40 caractères) de `main` après la fusion de la PR
de préparation. **Ordre imposé : commit, PR, CI verte, fusion, puis relever `RELEASE`** ; ensuite
**plus rien ne se fusionne sur `main`** jusqu'à la fin de l'étape 5 (le workflow Flutter CI partage
son groupe de concurrence avec `main`, et le préflight vérifie les CI du SHA exact).

```bash
git fetch origin
git rev-parse origin/main        # relever ce SHA complet (40 caractères)
```

```bash
export RELEASE=<SHA>             # coller ici le SHA relevé ci-dessus : jamais un SHA écrit de mémoire
test "$(git rev-parse origin/main)" = "$RELEASE" && echo "RELEASE = tête de main : OK"
```

```bash
git show "$RELEASE:pubspec.yaml" | grep '^version:'        # version: 2.3.1+57
git merge-base --is-ancestor 28ac82d "$RELEASE" && echo "production = ancêtre de RELEASE : OK"
git log --oneline 28ac82d.."$RELEASE" -- backend admin docker-compose.yml
#   attendu (relevé du 20/10/2026 sur 8c215b5) : #351, #353, #356, #357, #358, #360, #361, #363, #364,
#   #365, #366, #367, #368, #369, #370, #371, #372 — plus la PR de correctifs de l'audit 57
git log --oneline --first-parent c9a5ef6.."$RELEASE"
#   attendu : toutes les PR depuis la 56 — #349, #350, #351, #353, #356 à #374 (#352, #354 et #355
#   ne sont pas sur main), puis la PR de correctifs de l'audit 57, et rien d'autre
# Dépendances et manifestes depuis la 56 : #351 (FCM à la place de OneSignal), #362 (bloc assets du
# chantier L1), #368 (play_install_referrer), #369 (version) — `git log c9a5ef6.."$RELEASE" -- pubspec.yaml pubspec.lock`.
# c9a5ef6 = la préparation de la 56 (#327) ; le remplacer par le SHA archivé de la 56 dès qu'il est
# reporté au registre (§0.2) — #328, fusionnée après, ne touche aucun de ces fichiers.
git diff --stat c9a5ef6 "$RELEASE" -- pubspec.lock ios/Runner/Info.plist \
  ios/Runner/PrivacyInfo.xcprivacy android/app/src/main/AndroidManifest.xml android/app/build.gradle
#   attendu : AndroidManifest.xml, Info.plist, pubspec.lock — rien d'autre (PrivacyInfo et build.gradle inchangés)
git diff -U0 c9a5ef6 "$RELEASE" -- pubspec.yaml | grep '^[+-]' | grep -v '^+++\|^---' | grep -v '^[+-][[:space:]]*#'
#   exactement treize lignes (relevé du 20/10/2026 sur 8c215b5 ; les commentaires, même indentés, sont
#   filtrés — sans ce filtre, 35 lignes) :
#     -version: 2.3.0+56
#     +version: 2.3.1+57
#     +  firebase_messaging: ^16.2.0
#     -  onesignal_flutter: ^5.0.0
#     +  play_install_referrer: ^0.5.0
#     -    - assets/
#     -    - assets/svgs/
#     -    - assets/images/
#     -    - assets/services/
#     -    - assets/icon/
#     -    - assets/images/bg_imgs/
#     -    - assets/images/on_boarding_img/
#     -    - assets/gifs/
#   La PR de correctifs de l'audit 57 ne touche pas pubspec.yaml : le compte reste 13. Si une PR
#   fusionnée avant RELEASE le modifie, recompter et arbitrer avant d'archiver.
git ls-tree -r --name-only "$RELEASE" | grep -c '^pubspec_overrides.yaml$'   # 0 : le fichier ne doit pas être suivi
git show "$RELEASE:pubspec.lock" | grep -c 'onesignal_flutter'                # 0
```

Si une commande affiche autre chose que l'attendu, **ne pas archiver** : arbitrer d'abord (un
`pubspec_overrides.yaml` local réécrit `pubspec.lock` : voir la checklist de la 56, étape 0).

## 1. Serveur, puis admin — le déploiement couplé (≈ 45 min) 🔒

**Avant l'app, toujours.** Le préflight de l'étape 5 tourne en `requires-new` : la production doit
servir `RELEASE`.

1. **Préalables** (`docs/api-contracts.md`, « Migrations `20261015120000…120200_scholarship_follow_*`
   — exploitation ») : lancer `db-info.yml` ; au-delà d'environ un million de lignes dans
   `SavedItem` ou `UserNotification`, construire les trois index en `CONCURRENTLY` avant ; la
   requête sur `ScholarshipCycle.academicYear` doit être vide ; **geler les activations de cycles
   dans l'admin** pendant le déploiement.
2. **`.env` de production** : `FCM_SERVICE_ACCOUNT_JSON` posé (décision d) ;
   `KPB_SCHOLARSHIP_MATCH_ENABLED` et `KPB_ONBOARDING_V2_ENABLED` **absents ou `false`** (sinon,
   sans SSH : Actions → **VPS ops** → `scholarship-match-off` / `onboarding-v2-off`) ;
   `KPB_REFERRAL_INSTALL_REFERRER_ENABLED`, `KPB_REFERRAL_ONBOARDING_CODE_ENABLED` et
   `KPB_REFERRAL_LEADERBOARD_ENABLED` (parrainage) **absents ou `false`** ;
   `KPB_COMMUNITY_ENABLED` **absent ou `false`** et `KPB_ASSIST_BRIDGE_MODE` **absent ou `shadow`**
   (communauté et passerelle, déclarées « OFF at review time ») ;
   `KPB_SCHOLARSHIP_OPENING_MODE` **absent ou `legacy`** ; aucune clé `KPB_FOLLOW_*` /
   `KPB_HOME_*` à `false`.
3. Actions → **Deploy backend (VPS)** (`deploy.yml`) → `ref` = `RELEASE`, `scope` = `full`. Le
   workflow sauvegarde la base, passe les **seize migrations** additives (`prisma migrate deploy`,
   dans cet ordre) :
   - `20261013120000_notification_delivery_opened_at`, `20261013121500_profile_last_app_build` ;
   - `20261015120000_scholarship_follow_fanout`, `20261015120100_scholarship_follow_indexes`,
     `20261015120200_scholarship_follow_notification_backfill` (préalables du point 1) ;
   - `20261020120000_scholarship_match_v1` ;
   - `20261021120000_program_recognition` (prérequis des imports catalogue du point 5) ;
   - `20261022120000_referral_campaigns` (tables de la compétition ; rattrapages idempotents :
     code ambassadeur normalisé — laissé vide en cas de doublon, l'index unique tolère plusieurs
     vides —, `cashProgramEnabled`, `profileCompletedAt` des profils déjà complets) ;
   - `20261023120000_community`, `20261024120000_community_verif_bot` (`ALTER TYPE … ADD VALUE`),
     `20261025120000_assist_bridge` ;
   - `20261026120000_campaign_purpose_promotions_consent`, `20261026130000_referral_prize_forfeit`,
     `20261027120000_promotions_push_opt_in`, `20261027130000_community_report_orphan_retention` ;
   - `20261028120000_profile_completion_without_consent` (PR de correctifs de l'audit 57 :
     rattrapage de `profileCompletedAt` sans `consentedAt`, que rien n'écrit).
   Aucune n'utilise `CONCURRENTLY` ni ne détruit de colonne. Comparer le journal du workflow à cette
   liste : une migration de plus ou de moins arrête la release. Le workflow remplace ensuite
   **`api` puis `admin`**, vérifie la santé et revient à l'image précédente si elle échoue. Il publie
   aussi `web/public`, donc la politique de confidentialité mise à jour et le règlement de la
   compétition (`reglement-ambassadeurs-2026-11.html`).
4. Catalogue 1.5.0 : `catalog:reconcile --dry-run`, relire, puis `--apply` (registre, entrée du
   15/10/2026 « chantier D », point 4).
5. **Catalogue de la 57 en production** (Actions → **VPS ops** ; pour chacune : simulation
   `dry_run` coché, lecture du rapport, application `dry_run` décoché — le job enchaîne
   `npm run verify:catalog`, qui doit finir sur `OK` —, puis nouvelle simulation → `TOTAL : 0
   écriture(s)`), dans cet ordre :
   1. `dedupe-omnes`, puis `import-omnes-spring` (`docs/runbook-rentrees-partenaires.md`,
      « Procédure » : comptes attendus) ;
   2. `import-igensia` (même runbook) ;
   3. `import-north-america` (`docs/runbook-catalogue-amerique-du-nord.md` : d'abord la marge de
      `verify:catalog` sous la limite de 1 000 formations des builds installées) ;
   4. **pas** `roll-omnes-fall-2027` à ce stade : les builds 2.3.0 (≤ 56) affichent les dates
      reconduites **sans** « à confirmer » ; il attend que la 57 soit majoritaire (étape 9).

## 2. Vérifications de départ (5 min)

```bash
curl -fsS https://api.kpbeducation.cloud/api/health/version      # sha : les 12 premiers caractères de RELEASE
test "$(curl -fsS https://api.kpbeducation.cloud/api/health/version | jq -r .sha)" = "${RELEASE:0:12}" && echo "production = RELEASE : OK"
curl -fsS https://api.kpbeducation.cloud/api/health | jq '.push'   # {configured: true, fcm: true, oneSignal: true}
curl -fsS https://api.kpbeducation.cloud/api/config/app \
  | jq '.features | {eef, eefTeaser, eefSpace, eefHelpBubble, eefPrivateSchools, scholarshipMatch, onboardingV2, followPushPrimer, homeNextStep}'
#   attendu : false, true, true, false, false, false, false, true, true
curl -fsS https://api.kpbeducation.cloud/api/config/app \
  | jq '.features | {referralInstallReferrer, referralOnboardingCode, referralLeaderboard, community, assistBridge}'
#   attendu : false, false, false, false, false (parrainage, communauté et passerelle : fermés à la soumission)
curl -s -o /dev/null -w '%{http_code}\n' https://api.kpbeducation.cloud/api/scholarships/match/state   # 404 (drapeau fermé, avant toute authentification)
```

- **Si `push.fcm` vaut `false`** : `FCM_SERVICE_ACCOUNT_JSON` manque ou est illisible — **ne pas
  continuer** (la 57 ne recevrait aucune notification). `push.oneSignal` doit rester `true` : c'est
  le repli des builds 53 et 56.
- **Si `scholarshipMatch` ou `onboardingV2` vaut `true`** (ou l'un des trois drapeaux du
  parrainage, ou `community`, ou `assistBridge`) : **ne pas continuer** ; pour une clé de la 57,
  Actions → **VPS ops** → `referral-leaderboard-off`, `referral-onboarding-code-off`,
  `referral-install-referrer-off`, `community-off`, `assist-bridge-shadow`, `scholarship-match-off`
  ou `onboarding-v2-off` (un retour arrière agit même `dry_run` coché) ; puis relancer la commande.
- **Si `eefSpace` vaut `false`** : la phrase « The "Études en France" space is open » des notes de
  revue est fausse ; prendre la variante du pack §3, point 1, et recompter.
- Sur le Mac, avant l'étape 4 : `flutter --version` (3.44.1), `python3 --version`,
  `xcodebuild -version`. Les constats Xcode 27 de la checklist de la 56 (licence à accepter par
  `sudo xcodebuild -license accept`, cibles des Pods relevées à iOS 15.0, `lipo -verify_arch`
  qui empêche le simulateur) valent toujours.

**Copie propre de `RELEASE`** — le préflight de l'AAB et l'archive iOS se font dans cette copie :

```bash
git worktree add ../kpb-release-57 "$RELEASE" && cd ../kpb-release-57
test "$(git rev-parse HEAD)" = "$RELEASE" && git status --porcelain     # rien à afficher
```

## 3. Android — l'AAB signé (≈ 15 min, sans toi) 🔒

1. Actions → **Flutter CI** → *Run workflow* → branche `main`, cocher **`release_android`**. Ne pas
   pousser de tag `v2.3.1`. Vérifier en tête de l'exécution que le commit est bien `RELEASE`.
2. Journal « Verify App Bundle signature » : comparer l'empreinte SHA-256 au **certificat de la clé
   d'importation** de Play Console (Intégrité de l'app).
3. Journal « Run strict Android store-artifact preflight » :
   `Préflight Android OK — 2.3.1 (57), com.karatou.android, SDK 36, …`.
4. Télécharger l'artefact **`app-release-android-aab`** de **cette** exécution.

   **NE PAS importer un AAB plus ancien** : ni celui de la 55 (Flutter CI, run **37322572087**), ni
   celui de la 54 (run **36945000021**), ni un AAB de la 56 : Play les refuserait ou enverrait une
   build sans FCM ni « Suivre ». Seul l'artefact du run de `RELEASE` s'importe (étape 6).
5. *Recommandé* — depuis `../kpb-release-57` :
   ```bash
   BUNDLETOOL_JAR=/chemin/bundletool-all-1.18.1.jar scripts/preflight-android-aab.sh \
     --aab app-release.aab --expected-cert-sha256 "<empreinte SHA-256 de Play Console>"
   # → « Préflight Android OK — 2.3.1 (57), … certificat Play concordant, AD_ID absent. »
   ```

## 4. iOS — l'archive (sur le Mac) 🔒

```bash
cd ../kpb-release-57
test "$(git rev-parse HEAD)" = "$RELEASE" && git status --porcelain     # rien à afficher
flutter pub get && (cd ios && pod install)
git diff --stat ios/Podfile.lock     # #351 n'a pas régénéré ce fichier : OneSignal en sort, Firebase/Messaging y entre
```

Le `pod install` **modifie** `ios/Podfile.lock` (constat du 16/10/2026 : il cite encore
`onesignal_flutter` et pas `firebase_messaging`). C'est attendu ; ne pas le committer pendant la
release (rien ne fusionne), le reporter dans une PR après l'archive.

**La clé PostHog : quatre gestes, UN BLOC À LA FOIS** (correction du 04/10/2026 : ne jamais coller
deux lignes d'un coup ici).

*1. La saisie — seule dans sa commande.* Coller **la clé et rien d'autre**, puis Entrée une fois.

```bash
read -rs POSTHOG_API_KEY && export POSTHOG_API_KEY      # la vraie clé phc_ du projet (jamais dans le dépôt, jamais collée dans un chat)
```

*2. Le contrôle AVANT la construction — la longueur, jamais la clé.* La comparer à celle de
PostHog (*Project settings*).

```bash
printf '%s' "$POSTHOG_API_KEY" | grep -Eq '^phc_[A-Za-z0-9]{30,60}$' \
  && echo "forme OK (${#POSTHOG_API_KEY} caractères)" \
  || echo "FORME INVALIDE (${#POSTHOG_API_KEY} caractères) : refaire la saisie, ne pas construire"
```

*3. La construction — sans la saisie, sans autre ligne.*

```bash
flutter build ios --release \
  --dart-define=KPB_APP_ENV=prod \
  --dart-define=KPB_WHATSAPP_NUMBER=+33768674292 \
  --dart-define=POSTHOG_API_KEY="$POSTHOG_API_KEY"
grep -E '^FLUTTER_BUILD_(NAME|NUMBER)=' ios/Flutter/Generated.xcconfig   # FLUTTER_BUILD_NAME=2.3.1 / FLUTTER_BUILD_NUMBER=57
```

*4. Le contrôle APRÈS la construction.*

```bash
scripts/preflight-ios-archive.sh --xcconfig ios/Flutter/Generated.xcconfig --posthog-only
# → « POSTHOG_API_KEY : N caractères, une seule clé phc_ au format attendu — OK »
# → « Replis compilés EEF : aucun define KPB_EEF_*_ENABLED à true — OK »
```

- Aucun autre `flutter build` ni `flutter run` ensuite. Aucun define pour le test « Mes 10
  bourses » ni pour l'onboarding V2 : leurs drapeaux sont **serveur**.
- Xcode avec un PATH propre :
  `env PATH="/usr/bin:/bin:/usr/sbin:/sbin" /Applications/Xcode.app/Contents/MacOS/Xcode ios/Runner.xcworkspace`
  → *Any iOS Device* → **Product → Archive** (« Successfully submitted symbols » au journal).
- Contrôler l'archive :
  ```bash
  A="<chemin>.xcarchive/Products/Applications/Runner.app"
  scripts/preflight-ios-archive.sh --xcconfig ios/Flutter/Generated.xcconfig --archive-plist "$A/Info.plist"
  strings "$A/Frameworks/App.framework/App" | grep -c '^phc_'     # doit afficher 1
  ls "$A/Frameworks" | grep -ci onesignal                          # 0 : le SDK OneSignal est retiré
  nm -u "$A"/Frameworks/*.framework/* 2>/dev/null | grep -c CLLocationManager   # si 0 : NSLocationWhenInUseUsageDescription pourra être retirée dans une 58
  ```
- Organizer → *Distribute App* → *App Store Connect* → *Export*, puis :
  ```bash
  unzip -q Runner.ipa -d ipa
  scripts/preflight-ios-archive.sh --xcconfig ios/Flutter/Generated.xcconfig --app ipa/Payload/Runner.app
  # → « Préflight iOS OK — 2.3.1 (57) »
  ```
  Envoyer **cette** IPA par Transporter — seulement avec le feu vert du propriétaire.
- Rejets connus : **90474**, **90101** (contrôlés par le préflight) ; **ITMS-90062** ne se produit pas
  si la version est 2.3.1 (> 2.3.0 en vente).

## 5. Préflight de release (≈ 5 min, lecture seule)

La porte « 24 heures de stabilité » ne passe pas sur ce dépôt (sondes planifiées trop rares :
checklist de la 56, étape 4). Prouver d'abord que les sondes des 24 dernières heures sont en succès :

```bash
gh run list --workflow uptime.yml --event schedule --limit 30 --json createdAt,conclusion,status \
  --jq '[.[] | select(.status == "completed" and .createdAt > (now - 86400 | todate))]
        | {sondes: length, hors_succes: ([.[] | select(.conclusion != "success")] | length)}
        | if .sondes < 3 or .hors_succes > 0
          then error("preuve insuffisante : sondes=\(.sondes), hors_succes=\(.hors_succes)")
          else . end'
# attendu : {sondes: ≈ 5, hors_succes: 0} et aucune erreur. « sondes = 0 » n'est PAS une preuve.
```

Puis lancer le préflight **avec la dérogation** et le couplage **`requires-new`** (la production sert
`RELEASE` depuis l'étape 1) :

```bash
gh workflow run release-preflight.yml --ref main \
  -f ref="$RELEASE" -f backend_coupling=requires-new -f require_24h_stability=false
```

- `ref` = `RELEASE` (le SHA complet, pas `main`) ;
- `backend_coupling` = **`requires-new`** : il exige que la production serve les 12 premiers
  caractères de `RELEASE`. S'il échoue, la production n'est pas au bon SHA : revenir à l'étape 1 —
  **ne jamais** retomber sur `tolerates-old` pour le faire passer (la 57 n'aurait pas de push) ;
- `require_24h_stability` = `false`, dérogation journalisée, conservée avec la preuve des sondes.

## 6. Recette sur appareil (TestFlight + Play Internal) 🔒

1. IPA par Transporter → TestFlight ; AAB → Play Console → **Tests internes** (feu vert du
   propriétaire pour chacun). Installer **la ligne `2.3.1 (57)`** ; Android : `versionCode` 57.
2. Dérouler **`docs/device-qa-build57.md`** en entier, sur l'artefact. Les cas « Mes 10 bourses » et
   onboarding V2 se jouent hors production (préproduction ou fenêtre décrite dans la fiche) : **ne
   jamais** ouvrir `scholarshipMatch` en production pour la recette. Une fenêtre de recette
   TestFlight s'ouvre sans SSH par Actions → **VPS ops** → `onboarding-v2-on` (et, sur décision du
   propriétaire, `scholarship-match-on`), `dry_run` coché puis décoché.
3. Avant de soumettre, **refermer** toute fenêtre de recette : Actions → **VPS ops** →
   `onboarding-v2-off` et `scholarship-match-off` (ils agissent même `dry_run` coché ; la revue
   Apple se fait drapeaux fermés). Puis revérifier l'étape 2 (drapeaux) : `scholarshipMatch` et
   `onboardingV2` à `false`, `eefHelpBubble` et `eefPrivateSchools` à `false`, `referralInstallReferrer`,
   `referralOnboardingCode` et `referralLeaderboard` à `false`, `community` et `assistBridge` à
   `false` (déclarés « OFF at review time »).
4. Un ✗ non résolu bloque la soumission.

## 7. Consoles

| Quoi | Où | Note |
|---|---|---|
| Data Safety (Play), App Privacy (Apple) | **Pack 57 §4** | Lignes nouvelles : test « Mes 10 bourses » (Autres infos / Other Data), suivis et ouverture des notifications ; OneSignal reste « Partagé » tant que le repli tourne (`docs/CONSOLE_ANSWERS.md` §0sexies) |
| Liste des SDK (si demandée) | Pack 57 §4.2 | OneSignal retiré, Firebase Messaging ajouté |
| Questionnaire d'âge (Apple, IARC), Data Safety / App Privacy de la communauté | **Pack 57 §4.4** ; `docs/CONSOLE_ANSWERS.md` §3 bis | **Changent dès la 57** (décision du propriétaire du 20/10/2026) : communauté déclarée — contenu généré par les utilisateurs et interaction entre utilisateurs **Oui** (modérés), « Autre contenu généré par l'utilisateur » ; messagerie privée Non |
| *Government apps*, non-affiliation | `docs/CONSOLE_ANSWERS.md` §0quater ; pack 56 §4 | Inchangés |
| XC-06, D5 | `docs/CONSOLE_ANSWERS.md` §0quater (ligne « chantier juridique 57 ») ; pack 57 §4.3 | D5 tranché le 18/10/2026. **XC-06 tranché le 19/10/2026** : finalité « Marketing » **déclarée** (Play Data Safety, Apple App Privacy) ; e-mail **et** push promotionnels en **opt-in** (`campaign-purpose.ts` : `promotionsEmailOptIn`, `promotionsPushOptIn`, aucun par défaut) ; écrire « opt-in » dans tout champ libre |

## 8. Soumettre 🔒

- **App Store** : créer la version **2.3.1**, y rattacher la build `57`. « Nouveautés » = pack 57 §2 ;
  *Notes for Review* = le texte **complet** du pack 57 §3, à coller **seul** (décompte refait par
  `test/release/store_pack_57_test.dart` ; si l'adresse ou la méthode du compte de démonstration
  dépasse sa réserve de 40 ou 120 caractères, recompter). Cocher **« Phased release for automatic
  updates »**.
- **Google Play** : production, notes = pack 57 §2 (bloc Google Play), **déploiement par paliers à
  10 %**. L'AAB importé est celui du run de `RELEASE`.
- Avant d'appuyer : la commande de l'étape 2 (`/config/app`) → `scholarshipMatch=false`,
  `onboardingV2=false` (sinon `scholarship-match-off` / `onboarding-v2-off` dans **VPS ops**), `eefHelpBubble=false`, `eefPrivateSchools=false`, les trois drapeaux du
  parrainage à `false`, `community=false`, `assistBridge=false`, `eefSpace` conforme au texte des
  notes de revue.
- **Le jour de l'envoi**, reporter dans `docs/release-ledger.md` le SHA de `RELEASE` et « téléversée
  le … » sur la ligne `57` — après l'étape 5, jamais pendant.

## 9. Déploiement progressif, et ce qui vient après

Détail et seuils : **pack 57 §6** (À VALIDER (propriétaire) pour les seuils).

1. **Play 10 %** (48 h au moins) → **50 %** (72 h au moins) → **100 %**, chaque élargissement au feu
   vert du propriétaire, si : utilisateurs sans plantage de la 57 au moins égal à la 56, taux de
   plantage perçu sous 1,09 % et taux d'ANR perçu sous 0,47 % (Android vitals) ; pas de hausse
   des 5xx de l'API ; `push.fcm=true` et pas d'échecs d'envoi qui s'accumulent ; échecs de
   synchro pas au-dessus de 9,6 % ; aucun retour bloquant. Sinon : suspendre, couper
   l'interrupteur en cause (pack §5), corriger dans une 58.
2. **iOS** : publication progressive (phased release) sur sept jours, mêmes critères, pause possible.
3. **`KPB_RECOMMENDED_APP_VERSION=2.3.1`** — la **version marketing**, jamais le numéro de build :
   `isVersionBelow` l'ignore (`lib/app/core/utils/version_utils.dart`, `_parseVersion` coupe au
   `+`), et `AppVersionGate` compare `PackageInfo.version`
   (`lib/app/core/services/app_version_gate.dart`). Quand Play est à 100 % et la publication iOS
   terminée : PR sur `RECOMMENDED_APP_VERSION` dans `.github/scripts/vps-ops.sh`, puis
   `recommended-version-set` (simulation, puis application). Sans effet sur la 53.
4. **`KPB_ONBOARDING_V2_ENABLED=true`** quand la 57 est à 100 % et stable (pack §5, étape 2) :
   Actions → **VPS ops** → `onboarding-v2-on` (simulation, puis `dry_run` décoché) ; retour arrière
   `onboarding-v2-off`.
5. **Mode d'ouverture** — dans cet ordre, jamais en sautant une marche :
   - `KPB_SCHOLARSHIP_OPENING_MODE=legacy` au lancement (défaut) ;
   - `outbox_alerts` après le déploiement de l'admin et une première activation surveillée ;
   - `npm run follow:mirror-alerts` (simulation), relire les comptes, poser `outbox_followers`, puis
     `npm run follow:mirror-alerts -- --apply` ; décider avant si les favoris des builds 53 et 56
     doivent être prévenus (pack §6.3).
   `KPB_PUSH_OUTBOX_ENABLED=false` arrête le worker en urgence.
6. **`KPB_SCHOLARSHIP_MATCH_ENABLED=true`** en dernier, après la validation juridique de la
   nationalité, la porte des 90 % de couverture et la recette en préproduction (pack §5, étape 4) :
   Actions → **VPS ops** → `scholarship-match-on` (simulation, puis `dry_run` décoché) ; retour
   arrière `scholarship-match-off`.
7. **`KPB_MIN_APP_VERSION`** reste `0.0.0`. Le passer à `2.3.1` seulement au-delà d'**environ 85 %**
   des comptes actifs en 2.3.1 ou plus (`GET /admin/app-builds`), jamais pendant un palier Play :
   il enferme sinon les 53 et 56 derrière un écran sans sortie.
8. Ne jamais poser `KPB_EEF_ENABLED=true`. Aucun tag `v2.3.1` poussé pendant la release.
9. **Parrainage** (compétition du 1er au 10 novembre 2026) : les trois `KPB_REFERRAL_*_ENABLED`
   s'ouvrent selon `docs/runbook-campagne-ambassadeurs.md` §8, **après** la politique de
   confidentialité et la Data safety à jour (pack §4.3) et le `rulesUrl` posé sur la campagne
   (`https://kpbeducation.cloud/reglement-ambassadeurs-2026-11.html` ; le lancement est refusé sans
   lui). À VALIDER (propriétaire) : l'ordre et les dates. Pas d'édition du `.env` en SSH (port 22
   injoignable) : Actions → **VPS ops**, chaque action d'abord `dry_run` coché, puis décoché, dans
   cet ordre et avant le 1er novembre :
   1. `referral-leaderboard-on` (`KPB_REFERRAL_LEADERBOARD_ENABLED=true`) ;
   2. `referral-onboarding-code-on` (`KPB_REFERRAL_ONBOARDING_CODE_ENABLED=true`) ;
   3. `referral-install-referrer-on` (`KPB_REFERRAL_INSTALL_REFERRER_ENABLED=true`).
   Le job prouve la clé `features.*` servie par `/config/app` ; retour arrière par l'action `-off`
   correspondante. Plus tard, mêmes règles : `community-on` (communauté), `assist-bridge-on`
   (après au moins 2 semaines de `shadow`, `docs/runbook-bot-passerelle.md` §2), `verif-bot-auto`
   (après 50 réponses validées sans correction, `docs/runbook-bot-verif.md` §2).
10. **Recalcul de la compétition avant le 1er novembre** : la migration
    `20261028120000_profile_completion_without_consent` (PR de correctifs de l'audit 57) est
    **déployée avant le 1er novembre** (étape 1), puis console admin → **Compétition
    ambassadeurs** → la campagne → **Recalculer maintenant**, c'est-à-dire
    `POST /api/admin/referral-campaigns/<id>/recompute` (route `POST /admin/referral-campaigns/:id/recompute`,
    idempotente ; le calcul automatique tourne aussi toutes les 5 minutes). Contrôle : un filleul
    de test au profil complet passe « qualifié » (`docs/runbook-campagne-ambassadeurs.md` §1 et
    §5).
11. **`roll-omnes-fall-2027`** (reconduction des rentrées OMNES d'automne 2026 en 2027) : seulement
    quand la 57 est installée chez la **majorité** des comptes actifs (`GET /admin/app-builds`,
    « part des comptes actifs sur cette build ou une plus récente » au-dessus de 50 % pour la 57).
    Avant, les builds 2.3.0 (≤ 56) afficheraient « Rentrée 01/10/2027 » et le tarif 2026-2027 comme
    confirmés (`docs/runbook-rentrees-partenaires.md`, « Quand lancer la reconduction »).
    Procédure : simulation, application, nouvelle simulation, comme au point 5 de l'étape 1.
