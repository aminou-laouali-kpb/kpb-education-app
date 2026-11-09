# Mise à jour 2.3.1 (58) — la checklist du 07/11/2026

> **⚠️ REMPLACÉE par la 59 le 09/11/2026 : suivre `docs/mise-a-jour-59-checklist.md`.**
> La `2.3.1 (58)` a été téléversée le 08/11/2026 (App Store Connect pour TestFlight, AAB en test
> interne Play ; commit archivé `5332a128`) et n'a jamais été soumise. Décision du propriétaire du
> 09/11/2026 : la version de lancement doit contenir davantage ; la build suivante est la
> `2.3.1 (59)`, même version marketing. Le contenu ci-dessous est conservé tel qu'écrit.

> **Ce que ce fichier est.** L'ordre exact des opérations pour vérifier, archiver, recetter,
> soumettre et déployer **par étapes** la 58, avec les commandes. Il **succède** à
> `docs/mise-a-jour-57-checklist.md`. La 58 est la 57 corrigée : l'audit UX externe du 28/10/2026
> a refusé l'archive de la 57 (`ba84fedf`, téléversée le 25/10/2026, jamais soumise) et demandé
> une 58 avec ses correctifs. Ce que la 58 ajoute : #387 (les 9 correctifs app du top 10) et #389
> (quick wins A, B et C). Côté serveur, #392 et #397 sont **déjà en production**. Les textes à
> coller sont dans `docs/release-58-store-pack.md` (ce qui change) et
> `docs/release-57-store-pack.md` (tout le reste) ; la recette appareil dans
> `docs/device-qa-build58.md` ; l'historique dans `docs/release-ledger.md`.
>
> **État de départ — relevé du 07/11/2026** : **2.3.0 en vente** sur l'App Store (depuis le
> 07/10/2026) et sur Google Play ; la `2.3.1 (57)` est sur App Store Connect, **non soumise** ;
> aucune 2.3.1 n'a jamais été en vente. Backend de production `b1f6a329` (#398, #399, #400, déployé le
> 07/11/2026 à 17 h 38 UTC ; il porte #392 et #397), `push.fcm: true`. Drapeaux `community`, `assistBridge`,
> `referralOnboardingCode` et `referralLeaderboard` **refermés** le 07/11/2026 (lus sur
> `/api/config/app`). Les autres drapeaux n'ont pas été remesurés : l'étape 2 le fait.
>
> **🔒 = étape de distribution ou de production.** Déploiement du backend, AAB importé, IPA
> envoyée, soumission, élargissement d'un palier : **aucune ne se fait sans le feu vert explicite
> du propriétaire, donné pour cette étape.** Le reste (lire, comparer, lancer un préflight en
> lecture seule) se fait librement.
>
> **Ce que la mise à jour ne fait PAS** : déployer le backend avant le préflight, ouvrir
> `features.scholarshipMatch`, `features.onboardingV2`, `features.community`,
> `features.assistBridge` ou les drapeaux du parrainage, passer le mode d'ouverture hors de
> `legacy`, relever `KPB_MIN_APP_VERSION`, envoyer une notification de masse, lancer
> `roll-omnes-fall-2027`. Tout cela vient après, dans l'ordre du pack 57 §5 et §6 et de l'étape 9.

## Ce qui change par rapport à la checklist de la 57

- **Version attendue : `2.3.1 (58)`.** Même version marketing que la 57 : la 2.3.0 est en vente,
  App Store Connect refuse une version qui ne lui est pas strictement supérieure (ITMS-90062), et
  la 2.3.1 n'a jamais été soumise. Le numéro 57 est consommé (téléversé) : la 58 en est le
  successeur direct. La 57 ne repart pas.
- **Couplage backend : `tolerates-old`**, plus `requires-new`. La 58 n'appelle aucune route ni
  aucune clé `features.*` que la production ne sert pas déjà (registre, entrée
  « Préparation de la build 58 »). Le backend dont elle a besoin (FCM, #351, puis #392 et #397)
  est en production. **Aucun déploiement avant l'archive.** Seule nouveauté de contrat : la 58
  joint un `clientMessageId` aux messages de dossier (#408) ; face à la production actuelle, qui le
  refuse, elle renvoie le message une fois sans lui. Le déploiement serveur dû **après** l'envoi
  (étape 1) porte une migration additive, `20261108120000_case_message_client_id`.
- **Dépendances et manifestes : presque rien ne bouge** depuis la 57. `pubspec.yaml` ne change que
  par sa ligne `version:` (et une dépendance de test, #403) ; `ios/Podfile.lock` a été aligné par
  #383 ; le manifeste Android gagne une entrée `<queries>` pour la dictée vocale (#407) (étape 0.3).
- **Le préflight de l'IPA exportée (`--app`) est obligatoire.** Il n'a pas tourné pour la 57 :
  l'envoi était parti de l'Organizer sans export. Cette fois, on exporte, on contrôle l'IPA, et
  c'est **cette** IPA qui part (étape 4).
- **Recette TestFlight en release** aux conditions de l'audit (étape 6.1), sur la fiche
  `docs/device-qa-build58.md`.
- **Notes de revue recomptées** : l'écran « Premium » s'appelle désormais « Pass Karatou »
  (#389) ; le pack 58 §3 remplace le pack 57 §3. Le reste du pack 57 vaut pour la 58 (pack 58,
  en tête).

## 0. Ce qui doit être vrai avant d'archiver

### 0.1 Décisions à avoir prises AVANT d'archiver

| | Décision | Conséquence sur l'archive |
|---|---|---|
| **a** | **Version marketing** : `2.3.1`, inchangée depuis la 57 | Posée par la PR de préparation (§0.2) |
| **b** | **Choix faits par défaut pendant les correctifs** : nom « Pass Karatou », délai « Réponse sous 24 h » sur la carte conseiller, champ de recherche en tête de l'Accueil, téléphone de 7 à 12 chiffres | Textes **compilés** : après l'archive, ils ne changent qu'avec une 59. À VALIDER (propriétaire) |
| **c** | **#401** (« Autre indicatif ») et **#403** (verrou biométrique : un Android pouvait enfermer l'élève dehors) | **Fusionnées le 07/11/2026, dans la 58.** #403 ajoute la seule différence de dépendances et de manifeste Android depuis la 57 (§0.3) |
| **d** | **Notes de version** : garder le texte du pack 57 §2 ou ajouter la puce « corrections » du pack 58 §2 | Ne bloque pas l'archive (texte de console). À VALIDER (propriétaire) |
| **e** | **Drapeaux fermés à la revue** : `community`, `assistBridge`, `referralOnboardingCode`, `referralLeaderboard` (refermés le 07/11/2026) | Les notes de revue les disent « OFF at review time » : ils restent fermés jusqu'à l'approbation |

### 0.2 La PR de préparation de la 58 (avant de relever `RELEASE`)

> **Fait le 07/11/2026** (branche `claude/release-58-prep`, à fusionner avant de relever
> `RELEASE`) : les points 1 à 5 ci-dessous sont posés.

1. `pubspec.yaml` : `version: 2.3.1+58`.
2. `scripts/preflight-ios-archive.sh` : `EXPECTED_BUILD="58"`, `EXPECTED_VERSION="2.3.1"` ;
   `scripts/preflight-android-aab.sh` : `EXPECTED_VERSION_NAME="2.3.1"`,
   `EXPECTED_VERSION_CODE="58"` (gardés par `test/release/artifact_signing_contract_test.dart`).
3. `docs/release-ledger.md` :
   - « Version marketing EN VENTE : `2.3.0` » ne change pas (la 2.3.1 n'est pas en vente) ;
   - la ligne `57` passe sous **Consommés** : téléversée le 25/10/2026 sur App Store Connect,
     jamais soumise, remplacée par la 58 sur le verdict de l'audit ;
   - une ligne `58` sous **Courant**, à l'état « avant l'archive » (« EN COURS (archive à faire) :
     non téléversée, non soumise », marqueur `<RELEASE>`).
4. `test/release/mise_a_jour_57_checklist_test.dart` ne lit plus la version du dépôt : il garde le
   document de la 57. `test/release/mise_a_jour_58_checklist_test.dart` prend le relais.
5. Les papiers de la 57 reçoivent un bandeau « REMPLACÉE par la 58 », sans réécriture.

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
git show "$RELEASE:pubspec.yaml" | grep '^version:'        # version: 2.3.1+58
git merge-base --is-ancestor ba84fedf "$RELEASE" && echo "archive de la 57 = ancêtre de RELEASE : OK"
git log --oneline --first-parent ba84fedf.."$RELEASE"
#   attendu (relevé du 07/11/2026) : #386, #387, #390, #389, #392, #393, #395, #396, #397, #383,
#   #384, #398, #401, #399, #400, #403, #404, #405, #406, #407, #408 (revue avant la 58), puis
#   la PR de préparation de la 58 — et rien d'autre.
#   Une PR de plus : la nommer ici et arbitrer avant d'archiver.
git diff --stat ba84fedf "$RELEASE" -- pubspec.lock ios/Runner/Info.plist \
  ios/Runner/PrivacyInfo.xcprivacy android/app/src/main/AndroidManifest.xml android/app/build.gradle
#   attendu (aucune autre dépendance, aucun autre manifeste ne bouge depuis la 57) : seulement
#   pubspec.lock (local_auth_platform_interface passe en « direct dev », même version) et
#   android/app/build.gradle (androidx.appcompat 1.7.1, #403) et AndroidManifest.xml (une seule
#   entrée `<queries>` : android.speech.RecognitionService, #407). Info.plist et PrivacyInfo : rien.
git diff -U0 ba84fedf "$RELEASE" -- pubspec.yaml | grep '^[+-]' | grep -v '^+++\|^---' | grep -v '^[+-][[:space:]]*#'
#   exactement trois lignes (la troisième : dépendance de TEST de #403, absente du binaire) :
#     -version: 2.3.1+57
#     +version: 2.3.1+58
#     +  local_auth_platform_interface: ^1.1.0
git diff --stat ba84fedf "$RELEASE" -- ios/Podfile.lock
#   attendu : ios/Podfile.lock seul (#383 : OneSignal sort, Firebase Messaging entre)
git ls-tree -r --name-only "$RELEASE" | grep -c '^pubspec_overrides.yaml$'   # 0 : le fichier ne doit pas être suivi
git show "$RELEASE:pubspec.lock" | grep -c 'onesignal_flutter'                # 0
```

Si une commande affiche autre chose que l'attendu, **ne pas archiver** : arbitrer d'abord (un
`pubspec_overrides.yaml` local réécrit `pubspec.lock` : voir la checklist de la 56, étape 0).

## 1. Serveur et admin — déjà en production, rien à déployer avant l'archive 🔒

La production sert le backend de la 58 depuis le 07/11/2026 (`b1f6a329`, #398 à #400 ; #392 et #397 avant).
Le contrôle : aucun écart serveur entre la production et `RELEASE`.

```bash
git merge-base --is-ancestor b1f6a329 "$RELEASE" && echo "production = ancêtre de RELEASE : OK"
git diff --stat b1f6a329 "$RELEASE" -- backend admin docker-compose.yml
#   attendu (relevé du 08/11/2026 sur main) : backend seulement, #407 (textes du dossier au
#   « tu », messages du plus ancien au plus récent, canal WhatsApp par défaut) et #408
#   (clientMessageId : DTO, service, migration). La 58 n'en dépend pas (elle tolère l'ancien
#   serveur) ; leur déploiement devient dû APRÈS l'envoi.
```

- **Ne pas déployer avant le préflight.** `tolerates-old` exige que la production soit un
  **ancêtre** de `RELEASE`, jamais en avance : un déploiement à un commit postérieur à `RELEASE`
  fait échouer l'étape 5.
- Si l'écart n'est pas vide, le déploiement se fait **après** l'envoi de la 58 aux testeurs
  (`deploy.yml`, `ref` = `RELEASE`, `scope` = `full`), au feu vert du propriétaire, avec les
  opérations propres à chaque PR (simulation d'abord).
- Une seule migration est attendue, additive (colonne nullable + index unique) :
  `git diff --stat b1f6a329 "$RELEASE" -- backend/prisma/migrations` n'affiche que
  `20261108120000_case_message_client_id`. `deploy.yml` l'applique (`prisma migrate deploy`).
- Après ce déploiement : `backfill-cases-fr` (vps-ops, **simulation d'abord**) pour réécrire au
  « tu » les textes de dossier déjà en base (#407), au feu vert du propriétaire.

## 2. Vérifications de départ (5 min)

```bash
curl -fsS https://api.kpbeducation.cloud/api/health/version      # sha : b1f6a329a0b7 (relevé du 07/11/2026)
PROD=$(curl -fsS https://api.kpbeducation.cloud/api/health/version | jq -r .sha)
git merge-base --is-ancestor "$PROD" "$RELEASE" && echo "production ($PROD) = ancêtre de RELEASE : OK"
curl -fsS https://api.kpbeducation.cloud/api/health | jq '.push'   # {configured: true, fcm: true, oneSignal: true}
curl -fsS https://api.kpbeducation.cloud/api/config/app \
  | jq '.features | {eef, eefTeaser, eefSpace, eefHelpBubble, eefPrivateSchools, scholarshipMatch, onboardingV2, followPushPrimer, homeNextStep}'
#   attendu : false, true, true, false, false, false, false, true, true
curl -fsS https://api.kpbeducation.cloud/api/config/app \
  | jq '.features | {referralInstallReferrer, referralOnboardingCode, referralLeaderboard, community, assistBridge}'
#   attendu : false, false, false, false, false (fermés à la soumission ; refermés le 07/11/2026)
```

- **Si la production n'est pas un ancêtre de `RELEASE`** (déployée depuis une autre branche, ou
  en avance) : **ne pas continuer** ; le préflight échouera.
- **Si `push.fcm` vaut `false`** : **ne pas continuer** (la 58 ne recevrait aucune notification).
- **Si `scholarshipMatch` ou `onboardingV2` vaut `true`** (ou l'un des trois drapeaux du
  parrainage, ou `community`, ou `assistBridge`) : **ne pas continuer** ; Actions → **VPS ops** →
  `referral-leaderboard-off`, `referral-onboarding-code-off`, `referral-install-referrer-off`,
  `community-off`, `assist-bridge-shadow`, `scholarship-match-off` ou `onboarding-v2-off` (un
  retour arrière agit même `dry_run` coché) ; puis relancer la commande.
- **Si `eefSpace` vaut `false`** : la phrase « The "Études en France" space is open » des notes de
  revue est fausse ; prendre la variante du pack 57 §3, point 1, et recompter.
- Sur le Mac, avant l'étape 4 : `flutter --version` (3.44.1), `python3 --version`,
  `xcodebuild -version`. Les constats Xcode 27 des checklists précédentes (licence, cibles des
  Pods à iOS 15.0, `lipo -verify_arch`) valent toujours.

**Copie propre de `RELEASE`** — le préflight de l'AAB et l'archive iOS se font dans cette copie :

```bash
git worktree add ../kpb-release-58 "$RELEASE" && cd ../kpb-release-58
test "$(git rev-parse HEAD)" = "$RELEASE" && git status --porcelain     # rien à afficher
```

## 3. Android — l'AAB signé (≈ 15 min, sans toi) 🔒

1. Actions → **Flutter CI** → *Run workflow* → branche `main`, cocher **`release_android`**. Ne pas
   pousser de tag `v2.3.1`. Vérifier en tête de l'exécution que le commit est bien `RELEASE`.
2. Journal « Verify App Bundle signature » : comparer l'empreinte SHA-256 au **certificat de la clé
   d'importation** de Play Console (Intégrité de l'app).
3. Journal « Run strict Android store-artifact preflight » :
   `Préflight Android OK — 2.3.1 (58), com.karatou.android, SDK 36, …`.
4. Télécharger l'artefact **`app-release-android-aab`** de **cette** exécution.

   **NE PAS importer un AAB plus ancien** : ni celui de la 55 (Flutter CI, run **37322572087**), ni
   celui de la 54 (run **36945000021**), ni un AAB de la 56 ou de la 57 : Play refuserait un
   `versionCode` déjà vu, ou enverrait une build sans les correctifs de l'audit. Seul l'artefact du
   run de `RELEASE` s'importe (étape 6).
5. *Recommandé* — depuis `../kpb-release-58` :
   ```bash
   BUNDLETOOL_JAR=/chemin/bundletool-all-1.18.1.jar scripts/preflight-android-aab.sh \
     --aab app-release.aab --expected-cert-sha256 "<empreinte SHA-256 de Play Console>"
   # → « Préflight Android OK — 2.3.1 (58), … certificat Play concordant, AD_ID absent. »
   ```

## 4. iOS — l'archive (sur le Mac) 🔒

```bash
cd ../kpb-release-58
test "$(git rev-parse HEAD)" = "$RELEASE" && git status --porcelain     # rien à afficher
flutter pub get && (cd ios && pod install)
git diff --stat ios/Podfile.lock     # rien : #383 l'a aligné sur FCM
```

Si `pod install` modifie encore `ios/Podfile.lock`, ne pas le committer pendant la release (rien
ne fusionne) : noter le diff et le reporter dans une PR après l'archive.

**La clé PostHog : quatre gestes, UN BLOC À LA FOIS** (ne jamais coller deux lignes d'un coup ici).

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
grep -E '^FLUTTER_BUILD_(NAME|NUMBER)=' ios/Flutter/Generated.xcconfig   # FLUTTER_BUILD_NAME=2.3.1 / FLUTTER_BUILD_NUMBER=58
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
  ```
- **Exporter l'IPA, puis la contrôler — obligatoire pour la 58.** Pour la 57, l'envoi était parti
  de l'Organizer (*Distribute App* → envoi direct) sans export : le préflight `--app` n'a jamais
  tourné, et l'APNs de production comme le profil App Store n'ont pas été contrôlés. Cette fois :
  Organizer → *Distribute App* → *App Store Connect* → **Export**, puis :
  ```bash
  unzip -q Runner.ipa -d ipa
  scripts/preflight-ios-archive.sh --xcconfig ios/Flutter/Generated.xcconfig --app ipa/Payload/Runner.app
  # → « Préflight iOS OK — 2.3.1 (58) »
  ```
  Envoyer **cette** IPA par Transporter — seulement avec le feu vert du propriétaire. Pas d'envoi
  direct depuis l'Organizer : il saute ce contrôle.
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

Puis lancer le préflight **avec la dérogation** et le couplage **`tolerates-old`** (la production
sert un ancêtre de `RELEASE`, sans écart serveur : étape 1) :

```bash
gh workflow run release-preflight.yml --ref main \
  -f ref="$RELEASE" -f backend_coupling=tolerates-old -f require_24h_stability=false
```

- `ref` = `RELEASE` (le SHA complet, pas `main`) ;
- `backend_coupling` = **`tolerates-old`** : la production doit être un **ancêtre** de `RELEASE`.
  Le journal dit « production is N commit(s) BEHIND » et « The coupled deploy is now OWED » : avec
  un écart serveur vide (étape 1), ce déploiement ne change aucun code serveur ; il n'est dû que
  si l'étape 1 a listé des fichiers ;
- `require_24h_stability` = `false`, dérogation journalisée, conservée avec la preuve des sondes.

## 6. Recette sur appareil (TestFlight + Play Internal) 🔒

1. IPA par Transporter → TestFlight ; AAB → Play Console → **Tests internes** (feu vert du
   propriétaire pour chacun). Installer **la ligne `2.3.1 (58)`** ; Android : `versionCode` 58.
2. Dérouler **`docs/device-qa-build58.md`** en entier, sur l'artefact, **en release** (jamais un
   build de debug). Les cas « Mes 10 bourses » et onboarding V2 se jouent hors production
   (préproduction ou fenêtre décrite dans la fiche) : **ne jamais** ouvrir `scholarshipMatch` en
   production pour la recette.
3. Avant de soumettre, **refermer** toute fenêtre de recette (Actions → **VPS ops** →
   `onboarding-v2-off`, `scholarship-match-off`), puis revérifier l'étape 2 : tous les drapeaux
   fermés à la revue valent `false`.
4. Un ✗ non résolu bloque la soumission.

### 6.1 Conditions de l'audit pour la recette (28/10/2026)

L'audit n'accepte la 58 qu'après une recette **sur TestFlight, en release**, sur **un iPhone, dont
un iPhone SE**, et **un Android d'entrée de gamme en 360 dp**. Chaque point a sa ligne dans
`docs/device-qa-build58.md` :

- **vraie 3G** (pas le simulateur) : durée du bandeau au lancement, du retour de Google et des
  réponses du chat ;
- **vrai mode avion** : bandeau hors ligne global, toasts « Hors ligne » et « Connexion rétablie » ;
- **VoiceOver réel** sur les constats d'accessibilité ;
- **notifications réelles** : la demande d'autorisation, une alerte d'ouverture, et le **tap** sur
  une notification ;
- **connexion Google** (jamais jouée par l'audit) ;
- **☰ invité en 1re session**, **« Suivre » puis retour**, tunnel **« Être accompagné »** ;
- **HorsLigne-1** (la carte « Études en France » revient après un démarrage hors ligne) et
  **HorsLigne-5** (l'alerte d'ouverture est posée côté serveur, pas seulement le favori).

La recette ne vaut que signée (appareil, OS, build, profil réseau) en bas de la fiche.

## 7. Consoles

| Quoi | Où | Note |
|---|---|---|
| Data Safety (Play), App Privacy (Apple) | **Pack 57 §4** | Inchangées pour la 58 : aucune donnée, aucun SDK, aucun hôte nouveau (pack 58 §4). Si elles n'ont pas été envoyées avec la 57, les envoyer avec la 58 |
| Questionnaire d'âge, communauté | Pack 57 §4.4 ; `docs/CONSOLE_ANSWERS.md` §3 bis | Inchangés : communauté et passerelle déclarées, fermées à la revue |
| XC-06, D5 | Pack 57 §4.3 | Tranchés (18 et 19/10/2026), inchangés |

## 8. Soumettre 🔒

- **App Store** : dans la version **2.3.1**, rattacher la build **`58`** — jamais la 57. Si une
  fiche de version 2.3.1 a déjà été créée pour la 57, y remplacer la build (À VALIDER
  (propriétaire) : l'état de la fiche dans App Store Connect). « Nouveautés » = pack 58 §2 ;
  *Notes for Review* = le texte **complet** du pack 58 §3, à coller **seul** (décompte refait par
  `test/release/mise_a_jour_58_checklist_test.dart`). Cocher **« Phased release for automatic
  updates »**.
- **Google Play** : production, notes = pack 58 §2 (bloc Google Play), **déploiement par paliers à
  10 %**. L'AAB importé est celui du run de `RELEASE`.
- Avant d'appuyer : la commande de l'étape 2 (`/config/app`) → `scholarshipMatch=false`,
  `onboardingV2=false`, `eefHelpBubble=false`, `eefPrivateSchools=false`, les trois drapeaux du
  parrainage à `false`, `community=false`, `assistBridge=false`, `eefSpace` conforme au texte des
  notes de revue.
- **Le jour de l'envoi**, reporter dans `docs/release-ledger.md` le SHA de `RELEASE` et « téléversée
  le … » sur la ligne `58` — après l'étape 5, jamais pendant.

## 9. Déploiement progressif, et ce qui vient après

Détail et seuils : **pack 57 §6**, valable pour la 58 (À VALIDER (propriétaire) pour les seuils).
L'étape 9 de la checklist de la 57 s'applique en lisant « 58 » pour « 57 » ; en bref :

1. **Play 10 %** (48 h au moins) → **50 %** (72 h au moins) → **100 %**, chaque élargissement au feu
   vert du propriétaire, si les critères du pack 57 §6.2 tiennent (plantages, ANR, 5xx,
   `push.fcm=true`, synchro, retours). Sinon : suspendre, couper l'interrupteur en cause, corriger
   dans une 59.
2. **iOS** : publication progressive (phased release) sur sept jours, mêmes critères.
3. **`KPB_RECOMMENDED_APP_VERSION=2.3.1`** (la version marketing, jamais le numéro de build) quand
   Play est à 100 % et la publication iOS terminée. Aucune 57 n'étant chez les utilisateurs, la
   valeur 2.3.1 ne vise que la 58.
4. **`KPB_MIN_APP_VERSION`** reste `0.0.0` jusqu'à environ 85 % des comptes actifs en 2.3.1
   (`GET /admin/app-builds`), jamais pendant un palier.
5. **Le déploiement serveur dû**, s'il y en a un (étape 1) : après l'envoi aux testeurs, au feu
   vert du propriétaire.
6. **Drapeaux fermés à la revue** (`community`, `assistBridge`, parrainage), puis onboarding V2,
   mode d'ouverture, test « Mes 10 bourses » : dans l'ordre du pack 57 §5, après l'approbation,
   chacun par son action **VPS ops** (simulation, puis application). Dates : À VALIDER
   (propriétaire).
7. **`roll-omnes-fall-2027`** : seulement quand la 2.3.1 est installée chez la **majorité** des
   comptes actifs (`docs/runbook-rentrees-partenaires.md`).
8. Ne jamais poser `KPB_EEF_ENABLED=true`. Aucun tag `v2.3.1` poussé pendant la release.
