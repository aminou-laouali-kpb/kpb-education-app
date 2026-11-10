# Mise à jour 2.3.1 (59) — la checklist du 09/11/2026

> **Ce que ce fichier est.** L'ordre exact des opérations pour vérifier, archiver, recetter,
> soumettre et déployer **par étapes** la 59, avec les commandes. Il **succède** à
> `docs/mise-a-jour-58-checklist.md`. La 58 (`5332a128`, téléversée le 08/11/2026 sur App Store
> Connect et en test interne Play, jamais soumise) ne part pas en revue : décision du propriétaire
> du 09/11/2026, « je veux qu'il y ait tout déjà ». Ce que la 59 ajoute : l'espace parent sans
> prix (onglet « Accompagnement », « Demander le tarif »), « Premium » → « Pass Karatou », la
> carte invité « Découvre les bourses pour lesquelles tu es éligible » (derrière
> `scholarshipMatch`), « Déjà un compte ? » à l'entrée, la messagerie du dossier dans les deux
> sens (derrière le nouveau drapeau `caseMessaging`, fermé par défaut) et la compétition des
> ambassadeurs corrigée. Les textes à coller sont dans `docs/release-59-store-pack.md` (ce qui
> change) et `docs/release-57-store-pack.md` (tout le reste) ; la recette appareil dans
> `docs/device-qa-build59.md` ; l'historique dans `docs/release-ledger.md`.
>
> **État de départ — relevé du 09/11/2026** : **2.3.0 en vente** sur l'App Store (depuis le
> 07/10/2026) et sur Google Play ; la `2.3.1 (58)` est sur App Store Connect et en test interne
> Play, **non soumise** ; aucune 2.3.1 n'a jamais été en vente. Backend de production `5332a128`
> (le commit archivé de la 58, déployé après son envoi le 08/11/2026). Les drapeaux n'ont pas été
> remesurés depuis le 07/11/2026 : l'étape 2 le fait.
>
> **🔒 = étape de distribution ou de production.** Déploiement du backend, AAB importé, IPA
> envoyée, soumission, élargissement d'un palier, ouverture d'un drapeau :
> **aucune ne se fait sans le feu vert explicite du propriétaire, donné pour cette étape.** Le reste (lire, comparer,
> lancer un préflight en lecture seule) se fait librement.
>
> **Ce que la mise à jour ne fait PAS** : déployer le backend avant le préflight, ouvrir
> `features.caseMessaging` en dehors d'une fenêtre de recette refermée avant la soumission, ouvrir
> `features.scholarshipMatch`, `features.onboardingV2`, `features.community`,
> `features.assistBridge` ou les drapeaux du parrainage, passer le mode d'ouverture hors de
> `legacy`, relever `KPB_MIN_APP_VERSION`, envoyer une notification de masse, lancer
> `roll-omnes-fall-2027`. Tout cela vient après, dans l'ordre du pack 57 §5 et §6 et de l'étape 9.

## Ce qui change par rapport à la checklist de la 58

- **Version attendue : `2.3.1 (59)`.** Même version marketing que la 58 : la 2.3.0 est en vente,
  App Store Connect refuse une version qui ne lui est pas strictement supérieure (ITMS-90062), et
  la 2.3.1 n'a jamais été soumise. Le numéro 58 est consommé (téléversé chez Apple et chez
  Google) : la 59 en est le successeur direct. La 58 ne repart pas.
- **Couplage backend : `tolerates-old`**, comme la 58. La 59 fonctionne contre la production
  actuelle (`5332a128`) **et** contre le serveur de la 59 : chaque nouveauté serveur qu'elle lit
  a un repli quand elle manque (registre, entrée « Préparation de la build 59 ») :
  - `features.caseMessaging` **absente** (serveur de la 58) vaut `false` : le dossier renvoie vers
    WhatsApp exactement comme la 58 ; ouverte, la saisie utilise `POST /cases/:id/messages`, déjà
    servie par la production ;
  - `me.ineligible` absent vaut 0 (pas de ligne « Ne comptent pas ») ; `competition.phase` absent
    laisse le non-participant comme avant ; sans `code` dans un 403, les refus de code se lisent au
    message anglais du serveur ; sans `campaign.rulesUrl`, le lien du règlement vient du classement
    public, sinon de sa page ;
  - la carte invité suit `features.scholarshipMatch`, déjà servie (fermée).
- **Un déploiement serveur est dû après l'envoi aux testeurs** (étape 1) : le serveur de la 59
  (routes `/admin/cases/:id/messages`, notification de réponse, alerte e-mail, clé
  `caseMessaging`, compétition) et une migration additive,
  `20261109120000_case_message_case_created_idx`. La 59 n'en dépend pas à la revue
  (`caseMessaging` y vaut `false`) ; la recette de la messagerie, si.
- **Durcissement du 10/11/2026 (audit avant l'archive).** Dix
  corrections entrent dans la 59 parce qu'elles exigeaient une build : un dossier trop long
  n'est plus refusé ; le numéro WhatsApp peut être servi par le serveur
  (`support.whatsappNumber`) ; la dernière réponse de `/config/app` est gardée sur le téléphone
  et relue au retour au premier plan ; la garde de mise à jour se rejoue à chaque réponse fraîche
  du serveur ; un avis peut être affiché en haut de l'accueil (`notice`) ; la recherche
  ignore les accents ; la sonde « hors ligne » vise l'API de KPB ; les liens `kpb://` et les
  raccourcis de l'icône respectent l'écran d'entrée ; les parcours se rafraîchissent ; l'écran
  d'erreur de démarrage a une issue. Toutes gardent le couplage `tolerates-old` : les deux clés
  nouvelles, absentes du serveur de la 58, valent « rien à faire ».
- **Dépendances et manifestes : rien ne bouge** depuis la 58. `pubspec.yaml` ne change que par sa
  ligne `version:` (étape 0.3).
- **Le préflight de l'IPA exportée (`--app`) reste obligatoire**, comme pour la 58.
- **Recette en deux temps** (étape 6) : d'abord contre la production telle qu'elle est (preuve du
  `tolerates-old`), puis, après le déploiement, la messagerie de bout en bout, sur la fiche
  `docs/device-qa-build59.md`.
- **Notes de revue recomptées** : plus aucun prix affiché (onglet parent « Accompagnement ») et
  `features.caseMessaging` déclarée parmi les fonctions activables à distance ; le pack 59 §3
  remplace les packs 57 §3 et 58 §3.

## 0. Ce qui doit être vrai avant d'archiver

### 0.1 Décisions à avoir prises AVANT d'archiver

| | Décision | Conséquence sur l'archive |
|---|---|---|
| **a** | **Version marketing** : `2.3.1`, inchangée depuis la 57 | Posée par la PR de préparation (§0.2) |
| **b** | **Textes compilés de la 59** : « Accompagnement », « Demander le tarif », « Les tarifs se demandent à votre conseiller KPB, sur WhatsApp », la carte invité (« Découvre les bourses pour lesquelles tu es éligible », « Créer mon compte et voir mes bourses »), « Déjà un compte ? Utilise le même Google ou le même e-mail » | Textes **compilés** : après l'archive, ils ne changent qu'avec une 60. À VALIDER (propriétaire) |
| **c** | **Messagerie du dossier** : qui répond depuis l'administration, et dans quel délai | Ne bloque pas l'archive (drapeau serveur, fermé à la revue) ; bloque son **ouverture** (étape 9). À VALIDER (propriétaire) |
| **d** | **Notes de version** : la puce « Parents » du pack 59 §2, ou le texte du pack 57 §2 / 58 §2 tel quel | Ne bloque pas l'archive (texte de console). À VALIDER (propriétaire) |
| **e** | **Drapeaux fermés à la revue** : `scholarshipMatch`, `onboardingV2`, `eefHelpBubble`, `eefPrivateSchools`, les trois drapeaux du parrainage, `community`, `assistBridge`, **`caseMessaging`** | Les notes de revue les disent « OFF at review time » : ils restent fermés jusqu'à l'approbation. **La compétition reste fermée pendant la revue** ; l'ouvrir oblige à réécrire et recompter les notes (pack 59 §3) |

### 0.2 La PR de préparation de la 59 (avant de relever `RELEASE`)

> **Fait le 09/11/2026** (branche `claude/59-papers`, sur `claude/build-59`, à fusionner avant de
> relever `RELEASE`) : les points 1 à 6 ci-dessous sont posés.

1. `pubspec.yaml` : `version: 2.3.1+59`.
2. `scripts/preflight-ios-archive.sh` : `EXPECTED_BUILD="59"`, `EXPECTED_VERSION="2.3.1"` ;
   `scripts/preflight-android-aab.sh` : `EXPECTED_VERSION_NAME="2.3.1"`,
   `EXPECTED_VERSION_CODE="59"` (gardés par `test/release/artifact_signing_contract_test.dart`).
   Version marketing EN VENTE : `2.3.0` (registre, inchangée).
3. `docs/release-ledger.md` :
   - « Version marketing EN VENTE : `2.3.0` » ne change pas (la 2.3.1 n'est pas en vente) ;
   - la ligne `58` passe sous **Consommés** : téléversée le 08/11/2026, commit archivé `5332a128`,
     jamais soumise, remplacée par la 59 sur décision du propriétaire du 09/11/2026 ;
   - une ligne `59` sous **Courant**, à l'état « avant l'archive » (« EN COURS (archive à faire) :
     non téléversée, non soumise », marqueur `<RELEASE>`).
4. `test/release/mise_a_jour_58_checklist_test.dart` ne lit plus la version ni l'état courant du
   dépôt : il garde le document de la 58. `test/release/mise_a_jour_59_checklist_test.dart` prend
   le relais.
5. Les papiers de la 58 reçoivent un bandeau « REMPLACÉE par la 59 », sans réécriture.
6. Actions **VPS ops** `case-messaging-on` / `case-messaging-off` (même forme que
   `scholarship-match-on` / `-off`), et la clé `caseMessaging` au tableau des drapeaux du pack 57
   §5.

### 0.3 L'état à constater

Dans la suite, **`RELEASE`** = le SHA complet (40 caractères) de `main` après la fusion de la PR
de la 59 et de la PR de préparation. **Ordre imposé : commit, PR, CI verte, fusion, puis relever
`RELEASE`** ; ensuite **plus rien ne se fusionne sur `main`** jusqu'à la fin de l'étape 5 (le
workflow Flutter CI partage son groupe de concurrence avec `main`, et le préflight vérifie les CI
du SHA exact).

```bash
git fetch origin
git rev-parse origin/main        # relever ce SHA complet (40 caractères)
```

```bash
export RELEASE=<SHA>             # coller ici le SHA relevé ci-dessus : jamais un SHA écrit de mémoire
test "$(git rev-parse origin/main)" = "$RELEASE" && echo "RELEASE = tête de main : OK"
```

```bash
git show "$RELEASE:pubspec.yaml" | grep '^version:'        # version: 2.3.1+59
git merge-base --is-ancestor 5332a128 "$RELEASE" && echo "archive de la 58 = ancêtre de RELEASE : OK"
git log --oneline --first-parent 5332a128.."$RELEASE"
#   attendu (relevé du 09/11/2026) : #409 (registre de la 58), puis la ou les PR de la 59
#   (branche claude/build-59 : 7b6804ad, 39fcd758, ce0138d7, 595a1813, c263f322, 0c19e934) et la
#   PR de préparation de la 59, puis la PR de durcissement du 10/11/2026 (branche
#   claude/build-59-durcissement, audit avant l'archive) — et rien d'autre.
#   Une PR de plus : la nommer ici et arbitrer avant d'archiver.
git diff --stat 5332a128 "$RELEASE" -- pubspec.lock ios/Runner/Info.plist \
  ios/Runner/PrivacyInfo.xcprivacy android/app/src/main/AndroidManifest.xml android/app/build.gradle \
  ios/Podfile.lock
#   attendu : RIEN (aucune dépendance, aucun manifeste ne bouge depuis la 58).
git diff -U0 5332a128 "$RELEASE" -- pubspec.yaml | grep '^[+-]' | grep -v '^+++\|^---' | grep -v '^[+-][[:space:]]*#'
#   exactement deux lignes :
#     -version: 2.3.1+58
#     +version: 2.3.1+59
git ls-tree -r --name-only "$RELEASE" | grep -c '^pubspec_overrides.yaml$'   # 0 : le fichier ne doit pas être suivi
git show "$RELEASE:pubspec.lock" | grep -c 'onesignal_flutter'                # 0
```

Si une commande affiche autre chose que l'attendu, **ne pas archiver** : arbitrer d'abord (un
`pubspec_overrides.yaml` local réécrit `pubspec.lock` : voir la checklist de la 56, étape 0).

## 1. Serveur et admin — un déploiement dû APRÈS l'envoi aux testeurs 🔒

La production sert le backend de la 58 (`5332a128`, déployé le 08/11/2026 après son envoi). Le
contrôle : la production est un **ancêtre** de `RELEASE`, et l'écart serveur est celui de la 59,
rien d'autre.

```bash
git merge-base --is-ancestor 5332a128 "$RELEASE" && echo "production = ancêtre de RELEASE : OK"
git diff --stat 5332a128 "$RELEASE" -- backend admin docker-compose.yml
#   attendu (relevé du 09/11/2026 sur claude/build-59) : backend/src/modules/cases (routes admin
#   des messages, notification de réponse, alerte e-mail), backend/src/modules/config (clé
#   caseMessaging), backend/src/modules/referrals (statut ineligible, codes d'erreur, phase de la
#   compétition), backend/prisma (un index), admin/app/cases et admin/lib (fil du dossier),
#   docker-compose.yml (relais de KPB_CASE_MESSAGING_ENABLED). La 59 n'en dépend pas à la revue.
#   Durcissement du 10/11/2026 : backend/src/modules/config (support.whatsappNumber, notice),
#   backend/src/modules/cases/dto (un texte trop long est coupé, plus refusé),
#   backend/src/common/throttler-options.ts (300 lectures et 60 écritures par minute et par IP),
#   backend/src/modules/coach et ai (un message n'est plus décompté quand le modèle ne répond
#   pas), backend/src/modules/kayak (plafond gardé à 60), docker-compose.yml (relais de
#   KPB_APP_WHATSAPP_NUMBER, KPB_APP_NOTICE_FR, _EN, _URL).
git diff --stat 5332a128 "$RELEASE" -- backend/prisma/migrations
#   attendu : une seule migration, 20261109120000_case_message_case_created_idx.
```

- **Ne pas déployer avant le préflight.** `tolerates-old` exige que la production soit un
  **ancêtre** de `RELEASE`, jamais en avance : un déploiement à un commit postérieur à `RELEASE`
  fait échouer l'étape 5.
- **Quand** : après l'envoi de la 59 aux testeurs (étape 6.1, temps A joué), **avant** le temps B
  de la recette (la messagerie de bout en bout l'exige), au feu vert du propriétaire :
  `deploy.yml`, `ref` = `RELEASE`, `scope` = `full`. Le serveur de la 59 ne casse ni la 58 des
  testeurs ni la 2.3.0 en vente : une clé de plus dans `features`, un index, des routes admin.
- Une seule migration est attendue, additive (un index, `CREATE INDEX IF NOT EXISTS`, sans verrou
  long sur une table de quelques milliers de lignes) : `20261109120000_case_message_case_created_idx`.
  `deploy.yml` l'applique (`prisma migrate deploy`).
- **Aucune opération serveur obligatoire après ce déploiement.** `KPB_CASE_MESSAGING_ENABLED` et
  `KPB_SCHOLARSHIP_MATCH_ENABLED` restent à `false` (défaut de `docker-compose.yml`). Leur ouverture
  est une décision d'exploitation (étape 9), jamais une étape du déploiement.
- Contrôle après le déploiement :
  `curl -fsS https://api.kpbeducation.cloud/api/config/app | jq '.features.caseMessaging'` →
  `false` (et non plus `null`).
- Les deux leviers du durcissement sont servis à leur valeur neutre après le déploiement :
  `jq '.support.whatsappNumber, .notice'` → `null`, `null`. Le numéro WhatsApp servi se pose par
  l'action **VPS ops** `app-whatsapp-set` (constante `APP_WHATSAPP_NUMBER` de
  `.github/scripts/vps-ops.sh`, relue en PR). `KPB_APP_NOTICE_*` n'a **pas encore** d'action
  d'exploitation : en poser une demande une PR (comme `KPB_MIN_APP_VERSION`, jamais écrite par
  une action).

## 2. Vérifications de départ (5 min)

```bash
curl -fsS https://api.kpbeducation.cloud/api/health/version      # sha : 5332a128… (relevé attendu au 09/11/2026)
PROD=$(curl -fsS https://api.kpbeducation.cloud/api/health/version | jq -r .sha)
git merge-base --is-ancestor "$PROD" "$RELEASE" && echo "production ($PROD) = ancêtre de RELEASE : OK"
curl -fsS https://api.kpbeducation.cloud/api/health | jq '.push'   # {configured: true, fcm: true, oneSignal: true}
curl -fsS https://api.kpbeducation.cloud/api/config/app \
  | jq '.features | {eef, eefTeaser, eefSpace, eefHelpBubble, eefPrivateSchools, scholarshipMatch, onboardingV2, followPushPrimer, homeNextStep}'
#   attendu : false, true, true, false, false, false, false, true, true
curl -fsS https://api.kpbeducation.cloud/api/config/app \
  | jq '.features | {referralInstallReferrer, referralOnboardingCode, referralLeaderboard, community, assistBridge, caseMessaging}'
#   attendu : false, false, false, false, false, et caseMessaging null (serveur de la 58) ou false
#   (serveur de la 59) — jamais true à la soumission
```

- **Si la production n'est pas un ancêtre de `RELEASE`** (déployée depuis une autre branche, ou
  en avance) : **ne pas continuer** ; le préflight échouera.
- **Si `push.fcm` vaut `false`** : **ne pas continuer** (la 59 ne recevrait aucune notification).
- **Si `scholarshipMatch`, `onboardingV2`, `caseMessaging` vaut `true`** (ou l'un des trois
  drapeaux du parrainage, ou `community`, ou `assistBridge`) : **ne pas continuer** ; Actions →
  **VPS ops** → `case-messaging-off`, `referral-leaderboard-off`, `referral-onboarding-code-off`,
  `referral-install-referrer-off`, `community-off`, `assist-bridge-shadow`, `scholarship-match-off`
  ou `onboarding-v2-off` (un retour arrière agit même `dry_run` coché) ; puis relancer la commande.
- **Si `eefSpace` vaut `false`** : la phrase « The "Études en France" space is open » des notes de
  revue est fausse ; prendre la variante du pack 57 §3, point 1, et recompter.
- Sur le Mac, avant l'étape 4 : `flutter --version` (3.44.1), `python3 --version`,
  `xcodebuild -version`. Les constats Xcode 27 des checklists précédentes (licence, cibles des
  Pods à iOS 15.0, `lipo -verify_arch`) valent toujours.

**Copie propre de `RELEASE`** — le préflight de l'AAB et l'archive iOS se font dans cette copie :

```bash
git worktree add ../kpb-release-59 "$RELEASE" && cd ../kpb-release-59
test "$(git rev-parse HEAD)" = "$RELEASE" && git status --porcelain     # rien à afficher
```

## 3. Android — l'AAB signé (≈ 15 min, sans toi) 🔒

1. Actions → **Flutter CI** → *Run workflow* → branche `main`, cocher **`release_android`**. Ne pas
   pousser de tag `v2.3.1`. Vérifier en tête de l'exécution que le commit est bien `RELEASE`.
2. Journal « Verify App Bundle signature » : comparer l'empreinte SHA-256 au **certificat de la clé
   d'importation** de Play Console (Intégrité de l'app).
3. Journal « Run strict Android store-artifact preflight » :
   `Préflight Android OK — 2.3.1 (59), com.karatou.android, SDK 36, …`.
4. Télécharger l'artefact **`app-release-android-aab`** de **cette** exécution.

   **NE PAS importer un AAB plus ancien** : ni celui de la 58 (Flutter CI, run **42491189220**,
   déjà en test interne : il n'en sort pas vers la production), ni celui de la 55 (run
   **37322572087**), ni celui de la 54 (run **36945000021**), ni un AAB de la 56 ou de la 57 : Play
   refuserait un `versionCode` déjà vu, ou enverrait une build sans la 59. Seul l'artefact du run
   de `RELEASE` s'importe (étape 6).
5. *Recommandé* — depuis `../kpb-release-59` :
   ```bash
   BUNDLETOOL_JAR=/chemin/bundletool-all-1.18.1.jar scripts/preflight-android-aab.sh \
     --aab app-release.aab --expected-cert-sha256 "<empreinte SHA-256 de Play Console>"
   # → « Préflight Android OK — 2.3.1 (59), … certificat Play concordant, AD_ID absent. »
   ```

## 4. iOS — l'archive (sur le Mac) 🔒

```bash
cd ../kpb-release-59
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
grep -E '^FLUTTER_BUILD_(NAME|NUMBER)=' ios/Flutter/Generated.xcconfig   # FLUTTER_BUILD_NAME=2.3.1 / FLUTTER_BUILD_NUMBER=59
```

*4. Le contrôle APRÈS la construction.*

```bash
scripts/preflight-ios-archive.sh --xcconfig ios/Flutter/Generated.xcconfig --posthog-only
# → « POSTHOG_API_KEY : N caractères, une seule clé phc_ au format attendu — OK »
# → « Replis compilés EEF : aucun define KPB_EEF_*_ENABLED à true — OK »
```

- Aucun autre `flutter build` ni `flutter run` ensuite. Aucun define pour la messagerie, le test
  « Mes 10 bourses » ni l'onboarding V2 : leurs drapeaux sont **serveur**.
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
- **Exporter l'IPA, puis la contrôler — obligatoire pour la 59**, comme pour la 58 : Organizer →
  *Distribute App* → *App Store Connect* → **Export**, puis :
  ```bash
  unzip -q Runner.ipa -d ipa
  scripts/preflight-ios-archive.sh --xcconfig ios/Flutter/Generated.xcconfig --app ipa/Payload/Runner.app
  # → « Préflight iOS OK — 2.3.1 (59) »
  ```
  Envoyer **cette** IPA (par Transporter, ou depuis l'Organizer de la **même** archive une fois
  l'IPA exportée contrôlée, comme pour la 58) — seulement avec le feu vert du propriétaire. Pas
  d'envoi direct depuis l'Organizer sans ce contrôle.
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
sert un ancêtre de `RELEASE` : étape 1) :

```bash
gh workflow run release-preflight.yml --ref main \
  -f ref="$RELEASE" -f backend_coupling=tolerates-old -f require_24h_stability=false
```

- `ref` = `RELEASE` (le SHA complet, pas `main`) ;
- `backend_coupling` = **`tolerates-old`** : la production doit être un **ancêtre** de `RELEASE`.
  Le journal dit « production is N commit(s) BEHIND » et « The coupled deploy is now OWED » : c'est
  le déploiement de l'étape 1, dû après l'envoi aux testeurs ;
- `require_24h_stability` = `false`, dérogation journalisée, conservée avec la preuve des sondes.

## 6. Recette sur appareil (TestFlight + Play Internal) 🔒

1. IPA → TestFlight ; AAB → Play Console → **Tests internes** (feu vert du propriétaire pour
   chacun). Installer **la ligne `2.3.1 (59)`** ; Android : `versionCode` 59.
2. **Temps A — contre la production telle qu'elle est** (`5332a128`) : dérouler
   **`docs/device-qa-build59.md`** sauf les lignes « serveur 59 », sur l'artefact, **en release**
   (jamais un build de debug). C'est la preuve du `tolerates-old` : dossier sans saisie, WhatsApp,
   refus de code lus au message anglais.
3. **Le déploiement de l'étape 1** (🔒, feu vert du propriétaire), puis **temps B** : les lignes
   « serveur 59 ». La messagerie se joue dans une **fenêtre** : Actions → **VPS ops** →
   `case-messaging-on` (simulation, puis application), un compte admin qui répond, un compte
   élève de test. La compétition se joue en **préproduction** (jamais ouverte en production pour
   la recette), comme « Mes 10 bourses » et la carte invité.
4. Avant de soumettre, **refermer** toute fenêtre de recette (Actions → **VPS ops** →
   `case-messaging-off`, `onboarding-v2-off`, `scholarship-match-off`), puis revérifier l'étape 2 :
   tous les drapeaux fermés à la revue valent `false`.
5. Un ✗ non résolu bloque la soumission.

### 6.1 Conditions de l'audit pour la recette (28/10/2026)

L'audit n'accepte une build qu'après une recette **sur TestFlight, en release**, sur **un iPhone,
dont un iPhone SE**, et **un Android d'entrée de gamme en 360 dp**. Elles valent pour la 59.
Chaque point a sa ligne dans `docs/device-qa-build59.md` :

- **vraie 3G** (pas le simulateur) : durée du bandeau au lancement, du retour de Google et des
  réponses du chat ;
- **vrai mode avion** : bandeau hors ligne global, toasts « Hors ligne » et « Connexion rétablie » ;
- **VoiceOver réel** sur les constats d'accessibilité ;
- **notifications réelles** : la demande d'autorisation, une alerte d'ouverture, le **tap** sur
  une notification, et **la réponse de l'équipe dans un dossier** (« … t'a répondu », temps B) ;
- **connexion Google** (jamais jouée par l'audit), et **un compte existant sur une installation
  neuve** (« Déjà un compte ? ») ;
- **☰ invité en 1re session**, **« Suivre » puis retour**, tunnel **« Être accompagné »** ;
- **espace parent sans prix**, et **WhatsApp toujours présent** dans le dossier ;
- **HorsLigne-1** (la carte « Études en France » revient après un démarrage hors ligne) et
  **HorsLigne-5** (l'alerte d'ouverture est posée côté serveur, pas seulement le favori).

La recette ne vaut que signée (appareil, OS, build, profil réseau, temps A ou B) en bas de la
fiche.

## 7. Consoles

| Quoi | Où | Note |
|---|---|---|
| Data Safety (Play), App Privacy (Apple) | **Pack 57 §4** | Inchangées pour la 59 : les messages de dossier sont déjà déclarés ; aucune donnée, aucun SDK, aucun hôte nouveau (pack 59 §4). Si elles n'ont pas été envoyées avec la 57 ou la 58, les envoyer avec la 59 |
| Questionnaire d'âge, communauté | Pack 57 §4.4 ; `docs/CONSOLE_ANSWERS.md` §3 bis | Inchangés : la messagerie du dossier relie un élève à l'équipe KPB, pas deux élèves |
| XC-06, D5 | Pack 57 §4.3 | Tranchés (18 et 19/10/2026), inchangés |

## 8. Soumettre 🔒

- **App Store** : dans la version **2.3.1**, rattacher la build **`59`** — jamais la 58 ni la 57.
  Si une fiche de version 2.3.1 a déjà été créée pour la 57 ou la 58, y remplacer la build (À
  VALIDER (propriétaire) : l'état de la fiche dans App Store Connect). « Nouveautés » = pack 59
  §2 ; *Notes for Review* = le texte **complet** du pack 59 §3, à coller **seul** (décompte refait
  par `test/release/mise_a_jour_59_checklist_test.dart`). Cocher **« Phased release for automatic
  updates »**.
- **Google Play** : production, notes = pack 59 §2 (bloc Google Play), **déploiement par paliers à
  10 %**. L'AAB importé est celui du run de `RELEASE` ; la 58 reste en test interne.
- Avant d'appuyer : la commande de l'étape 2 (`/config/app`) → `scholarshipMatch=false`,
  `onboardingV2=false`, `eefHelpBubble=false`, `eefPrivateSchools=false`, les trois drapeaux du
  parrainage à `false`, `community=false`, `assistBridge=false`, `caseMessaging=false` (ou absente),
  `eefSpace` conforme au texte des notes de revue.
- **Le jour de l'envoi**, reporter dans `docs/release-ledger.md` le SHA de `RELEASE` et « téléversée
  le … » sur la ligne `59` — après l'étape 5, jamais pendant.

## 9. Déploiement progressif, et ce qui vient après

Détail et seuils : **pack 57 §6**, valable pour la 59 (À VALIDER (propriétaire) pour les seuils).
L'étape 9 de la checklist de la 57 s'applique en lisant « 59 » pour « 57 » ; en bref :

1. **Play 10 %** (48 h au moins) → **50 %** (72 h au moins) → **100 %**, chaque élargissement au feu
   vert du propriétaire, si les critères du pack 57 §6.2 tiennent (plantages, ANR, 5xx,
   `push.fcm=true`, synchro, retours). Sinon : suspendre, couper l'interrupteur en cause, corriger
   dans une 60.
2. **iOS** : publication progressive (phased release) sur sept jours, mêmes critères.
3. **`KPB_RECOMMENDED_APP_VERSION=2.3.1`** (la version marketing, jamais le numéro de build) quand
   Play est à 100 % et la publication iOS terminée. Aucune 57 ni 58 n'étant chez les
   utilisateurs, la valeur 2.3.1 ne vise que la 59.
4. **`KPB_MIN_APP_VERSION`** reste `0.0.0` jusqu'à environ 85 % des comptes actifs en 2.3.1
   (`GET /admin/app-builds`), jamais pendant un palier.
5. **Le déploiement serveur dû** (étape 1), s'il n'a pas été fait pendant la recette : après l'envoi
   aux testeurs, au feu vert du propriétaire.
6. **Messagerie du dossier** : `KPB_CASE_MESSAGING_ENABLED=true` par Actions → **VPS ops** →
   `case-messaging-on` (simulation, puis application), **seulement quand l'équipe est prête à
   répondre depuis l'administration** (décision c du §0.1 : qui, quel délai). Un message laissé
   sans réponse vaut pire que le renvoi vers WhatsApp, qui reste affiché. Retour arrière :
   `case-messaging-off`. Seule la 59 lit la clé. Date : À VALIDER (propriétaire).
7. **Carte invité et test « Mes 10 bourses »** : `KPB_SCHOLARSHIP_MATCH_ENABLED=true` par
   `scholarship-match-on`, seulement après la validation juridique de la collecte de la
   nationalité (consentement explicite, décision c du 18/10/2026, textes validés le 19/10/2026)
   et les autres conditions de l'étape 4 du pack 57 §5 (couverture d'au moins 90 %, recette en
   préproduction). Sans lui, la carte invité de la 59 n'apparaît pas.
8. **Drapeaux fermés à la revue** (`community`, `assistBridge`, parrainage), puis onboarding V2,
   mode d'ouverture : dans l'ordre du pack 57 §5, après l'approbation, chacun par son action
   **VPS ops** (simulation, puis application). Une nouvelle compétition suit
   `docs/reglement-competition-ambassadeurs-TEMPLATE.md` et le runbook de la campagne. Dates : À
   VALIDER (propriétaire).
9. **`roll-omnes-fall-2027`** : seulement quand la 2.3.1 est installée chez la **majorité** des
   comptes actifs (`docs/runbook-rentrees-partenaires.md`).
10. Ne jamais poser `KPB_EEF_ENABLED=true`. Aucun tag `v2.3.1` poussé pendant la release.
