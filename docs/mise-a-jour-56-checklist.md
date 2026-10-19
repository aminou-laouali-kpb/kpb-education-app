# Mise à jour 2.3.0 (56) — la checklist du 05/10/2026

> **⚠️ REMPLACÉE par la 57 le 18/10/2026 : suivre `docs/mise-a-jour-57-checklist.md`.**
> La 2.3.0 est en vente (App Store depuis le 07/10/2026, et Google Play : constat du 16/10/2026) ;
> la build suivante est la `2.3.1 (57)` (`pubspec.yaml`, préflights et registre posés le 18/10/2026).
> À VALIDER (propriétaire) : que la build en vente est bien la 56, sa date de téléversement et le
> SHA archivé (`docs/release-ledger.md`, ligne `56`). Le contenu ci-dessous est conservé tel
> qu'écrit ; pour tout numéro de version ou de build à venir, lire 57. Les papiers de la 57 :
> `docs/release-57-store-pack.md`, `docs/device-qa-build57.md`.

> **Ce que ce fichier est.** L'ordre exact des opérations pour archiver, vérifier et
> soumettre la 56, avec les commandes. Il **remplace** `docs/mise-a-jour-55-checklist.md` :
> décision du propriétaire du 05/10/2026 (« 56 »), on n'envoie **que la 56**. La 55
> (`2.3.0 (55)`) a été téléversée sur App Store Connect le 04/10/2026 à 01 h 20 mais **jamais
> soumise** à l'App Review ; son AAB signé (Flutter CI, run 37322572087) n'a **jamais été
> importé** dans Play. Elle est abandonnée, son numéro est consommé (`docs/release-ledger.md`).
> La 56 porte tout ce que portait la 55, plus la bulle verte WhatsApp, la visite guidée, la
> feuille « écoles privées » (derrière deux interrupteurs serveur fermés) et le retrait de
> l'avertissement de suspension. Les textes à coller sont dans `docs/release-56-store-pack.md`
> (qui reprend les notes de version de `docs/release-55-store-pack.md`) ; la recette appareil
> dans `docs/device-qa-build54.md` §A et §B (toujours valables : lire `2.3.0 (56)` là où la
> fiche écrit `(54)`), `docs/device-qa-build55.md` (aides, retrait, Niger, anglais) **et**
> `docs/device-qa-build56.md` (bulle, visite, écoles privées).
>
> **État de départ — relevé du 03/10/2026, NON remesuré le 05/10** : production = backend
> `0641601` (en ligne depuis le 03/10 à 17 h 06 UTC), **sans** les clés `eefHelpBubble` /
> `eefPrivateSchools` ; `features` = `eef=false`, `eefTeaser=true`, `eefSpace=false` ;
> catalogue publié (10 029 formations). **Une fenêtre de recette `eef-space-on` a pu rouvrir
> `eefSpace` depuis** : ne pas la croire fermée, la mesurer à l'étape 1 (si elle vaut `true`,
> `eef-space-off` puis revérifier **avant** de continuer).
> **Aucune build 2.3.0 n'est en vente** : dernier envoi iOS accepté pour la vente `2.2.0 (53)`
> (en vente depuis le 13/09), dernier bundle Android 53. La 55 est seule dans TestFlight.
>
> **🔒 = étape de distribution.** Archive, AAB importé, IPA envoyée, soumission : **aucune
> ne se fait sans le feu vert explicite du propriétaire, donné pour cette étape.** Le reste
> (lire, comparer, lancer un préflight en lecture seule) se fait librement.
>
> **Ce que la mise à jour ne fait PAS** : ouvrir l'espace, allumer la bulle ou les écoles
> privées, envoyer une notification. Tout cela vient après, quand la 56 est en vente et
> adoptée (`docs/runbook-ouverture-espace-reel.md`).

## Ce qui change par rapport à la checklist de la 55

- **L'étape 0 gagne une partie « décisions à avoir prises AVANT d'archiver »** : deux textes
  de la feuille « écoles privées » sont **compilés** dans le binaire ; les trancher après
  l'archive coûterait une 57.
- **Version attendue : `2.3.0 (56)`** partout (`pubspec.yaml`, les deux préflights).
- **`RELEASE` n'est pas écrit dans ce document** : c'est le SHA de `main` après la fusion de
  #326 et de la PR de préparation de la 56. Il se relève (étape 0), il ne se devine pas.
- **L'AAB de la 55 (run 37322572087) et celui de la 54 (run 36945000021) ne s'importent pas**
  (étape 2).
- **La version 2.3.0 d'App Store Connect reçoit la build 56 à la place de la 55** (étape 7).
- **Couplage backend : `tolerates-old`, mais le contrôle « le backend de la release est celui
  de la production » change** : #319 a modifié quatre fichiers de `backend/` et
  `docker-compose.yml` depuis `0641601`. Il faut constater **exactement** ceux-là (étape 1).
- **La porte « 24 heures » du préflight se franchit par la dérogation**
  `require_24h_stability=false`, après la preuve des sondes (étape 4).
- **Le contrôle de la clé PostHog** (`--posthog-only`, saisie seule, longueur) est celui de
  la correction du 04/10 (étape 3).
- La recette ajoute `docs/device-qa-build56.md` (bulle, visite, écoles privées, gardes de
  boutiques) aux fiches 54 et 55.

## 0. Ce qui doit être vrai avant d'archiver

### 0.1 Décisions à avoir prises AVANT d'archiver

Ces décisions changent des **textes compilés** : une fois l'archive faite, la seule action
possible est de laisser le drapeau fermé. Elles sont détaillées dans
`docs/release-56-store-pack.md` §7 ; ce tableau dit seulement **ce qu'il faut avoir tranché
pour archiver**. La décision **a** est **tranchée le 06/10/2026** : il n'y a plus rien à
faire.

| | Décision | Si la réponse est… | Conséquence sur l'archive |
|---|---|---|---|
| **a** | **KPB est-il rémunéré par des écoles privées ?** | Décision **tranchée le 06/10/2026 : la phrase est retirée** de l'app (le point 4 de la feuille ne dit plus que « service privé, pas un service de l'État ») | Rien à faire avant l'archive : le retrait est déjà dans le code de la 56. Si cela change un jour, une mention de transparence devra être réintroduite AVANT d'allumer `eefPrivateSchools` |
| **b** | **La phrase sur les frais** : « en général plus élevés que dans le public », ou son repli | Phrase gardée avec relecture juridique, sinon basculer `_useFeesFallback` (clé `eef_help_private_point_fees_fallback`, non affichée par défaut) | Texte **compilé** : à trancher **avant l'archive** |
| **c** | **Niger : aucune mention d'école privée** | **Retenu** (ni ligne, ni option, ni feuille ; bulle neutre à 2 lignes ; visite : seule la carte 1 est neutre) | Déjà codé (`EefHelp.isSuspended()`) ; rien à faire. Reste une question au juridique, hors archive |
| **d** | **Qui répond au +33 7 68 67 42 92, à quelles heures ?** | Sans personne nommée, **la bulle ne s'allume pas** (`eef-bubble-on`) | Hors archive : ne bloque pas l'archive, bloque l'allumage |

**Les interrupteurs restent FERMÉS à l'archive (état A).** La 56 part espace fermé
(`eefSpace=false`, décision XC-03) **et** les deux interrupteurs `features.eefHelpBubble` et
`features.eefPrivateSchools` fermés : le relecteur Apple voit la vitrine de la 53, exactement
comme avec la 55. Ils ne s'allument qu'après l'adoption de la 56, par `vps-ops`
(`eef-bubble-on`, `eef-private-schools-on`), jamais pendant la revue.

Si **b** change le code, c'est une PR de plus **avant** de relever `RELEASE` : le
préflight, l'AAB et l'archive portent tous sur le même commit.

### 0.2 L'état à constater

Dans la suite, **`RELEASE`** = le SHA complet (40 caractères) de `main` au moment d'archiver.

1. **#326 (la vitrine sans avertissement) et la PR de préparation de la 56 sont fusionnées
   dans `main`** (`version: 2.3.0+56`, registre, préflights, ces documents), **ainsi que la PR
   du retrait de la phrase de rémunération** (feuille écoles privées, décision a). Cette
   phrase est un texte **compilé** : tant que la PR n'est pas fusionnée, `main` la contient
   encore, et un AAB, un préflight ou une archive lancés sur ce commit l'embarquent pour
   toujours. **Ordre imposé : commit, PR, CI verte, fusion, puis relever `RELEASE`** ; ne rien
   lancer sur un commit antérieur à cette fusion.
2. **`docs/device-qa-build55.md`, `docs/device-qa-build56.md` et
   `docs/analytics-event-contract.md` sont sur `main`** : les renvois de cette checklist, du
   pack et du registre pointent vers eux.
3. Les quatre CI sont vertes **sur le SHA exact** : Backend CI, Admin CI, Flutter CI,
   Release safeguards CI (exécutions `push` de `main`, GitHub → Actions, filtrer sur le commit).
4. `RELEASE` = le dernier commit de `main`, et **plus rien ne se fusionne sur `main`** jusqu'à
   la fin de l'étape 4 : le workflow Flutter CI de l'étape 2 partage son groupe de
   concurrence avec les exécutions de `main` (le lancement serait annulé), et le préflight
   vérifie les CI du SHA exact. **Le commit de `main` doit être `RELEASE`, rien d'autre.**
5. **Ni dépendance native ni manifeste n'a changé depuis la production.** Un
   `pubspec_overrides.yaml` temporaire (non suivi), utilisé en local, remplace les
   `dependency_overrides` de `pubspec.yaml` — qui épinglent `connectivity_plus` en 6.x et
   `device_info_plus` en 11.x tant que le Xcode du CI est trop ancien — et réécrit
   `pubspec.lock`. Il a déjà été relevé dans un dossier de travail (`connectivity_plus`
   6.1.5 → 7.3.1, `device_info_plus` 11.5.0 → 12.4.0, deux plugins natifs) : un `git add -A`
   l'aurait embarqué. Aucun test du dépôt ne le garde (`test/release` ne lit `pubspec.lock`
   que pour `webview_flutter`). Les commandes ci-dessous le détectent, et **elles font foi
   pour les phrases « ni dépendance, ni manifeste » du §6 et du pack (§5, fait n° 6)** : à
   vérifier sur le SHA final, pas à croire. Si l'une d'elles affiche autre chose que
   l'attendu, **ne pas archiver** : faire restaurer `pubspec.lock` et supprimer
   `pubspec_overrides.yaml` par le porteur de la branche, puis recommencer l'étape 0.

```bash
git fetch origin
git rev-parse origin/main        # relever ce SHA complet (40 caractères)
```

```bash
export RELEASE=<SHA>             # coller ici le SHA relevé ci-dessus : jamais un SHA écrit de mémoire
test "$(git rev-parse origin/main)" = "$RELEASE" && echo "RELEASE = tête de main : OK"
```

```bash
git show "$RELEASE:pubspec.yaml" | grep '^version:'        # version: 2.3.0+56
git log --oneline 0641601.."$RELEASE"                        # la 56 y figure : #319 à #322, #324, #326 et la préparation

# Ni dépendance native ni manifeste n'a bougé depuis la production :
git diff --stat 0641601 "$RELEASE" -- pubspec.lock ios/Runner/Info.plist \
  ios/Runner/PrivacyInfo.xcprivacy android/app/src/main/AndroidManifest.xml android/app/build.gradle   # ne doit RIEN afficher
# Podfile.lock : SEULE la somme de contrôle du Podfile change (le Podfile relève les cibles des Pods
# à iOS 15.0 pour Xcode 27, voir l'étape 1) ; aucune version de Pod ne bouge :
git diff -U0 0641601 "$RELEASE" -- ios/Podfile.lock | grep '^[+-]' | grep -v '^+++\|^---'
#   exactement deux lignes : -PODFILE CHECKSUM: 4a45804a…  puis  +PODFILE CHECKSUM: 1ee049d4…
git ls-tree -r --name-only "$RELEASE" | grep -c '^pubspec_overrides.yaml$'   # 0 : le fichier ne doit pas être suivi
git diff -U0 0641601 "$RELEASE" -- pubspec.yaml | grep '^[+-]' | grep -v '^[+-]#' | grep -v '^+++\|^---'
#   exactement deux lignes : -version: 2.3.0+54  puis  +version: 2.3.0+56
git show "$RELEASE:pubspec.lock" | grep -A7 -E '^  (connectivity_plus|device_info_plus):$' | grep '^    version:'
#   "6.1.5" puis "11.5.0" (les épinglages de pubspec.yaml)
```

## 1. Vérifications de départ (5 min)

```bash
# La phrase de rémunération est-elle bien absente du commit à archiver ? (texte compilé : après
# l'archive, plus de retour possible)
git show "$RELEASE:lib/app/core/translations/app_translations.dart" | grep -c eef_help_private_disclosure
#   0 : la clé de la phrase de rémunération n'existe plus (FR comme EN). Autre chose : ne PAS
#   signer l'AAB ni archiver, la PR du retrait n'est pas dans RELEASE.
# Le backend de production est-il bien celui que la 56 suppose ?
curl -fsS https://api.kpbeducation.cloud/api/health/version      # sha : commence par 0641601
git merge-base --is-ancestor 0641601 "$RELEASE" && echo "production = ancêtre de RELEASE : OK"
# Ce que le backend de RELEASE a de plus que la production : EXACTEMENT #319.
git diff --stat 0641601 "$RELEASE" -- backend admin docker-compose.yml
git log --oneline 0641601.."$RELEASE" -- backend admin docker-compose.yml
# L'espace et les deux interrupteurs sont-ils bien fermés ?
curl -fsS https://api.kpbeducation.cloud/api/config/app \
  | jq '.features | {eef, eefTeaser, eefSpace, eefHelpBubble, eefPrivateSchools}'   # false, true, false, null, null
```

- **Si `eefSpace` (ou `eefHelpBubble`, `eefPrivateSchools`) vaut `true`** — typiquement une
  fenêtre de recette `eef-space-on` restée ouverte — **ne pas continuer** : lancer
  `eef-private-schools-off`, `eef-bubble-off` puis `eef-space-off`
  (`docs/runbook-ouverture-espace-reel.md`), puis **relancer cette commande** jusqu'à lire
  `false` (ou `null`). L'étape 7 redemande le même état fermé avant de soumettre ; le
  préflight (étape 4), lui, ne le contrôle pas.

- **Le couplage est `tolerates-old`, et le contrôle n'est plus « rien à afficher ».** Le
  backend de production (`0641601`) ne sert pas les clés `eefHelpBubble` / `eefPrivateSchools` ;
  la 56 les lit « faux » quand elles manquent (**clé absente = fermé**), donc elle fonctionne
  avec lui. Le `git diff --stat` doit lister **exactement quatre fichiers** — #319
  (`b220050`) — et le `git log` **une seule ligne** :
  - `backend/src/modules/config/app-config.controller.ts` et `….controller.spec.ts`
  - `backend/src/modules/etudes-en-france/publication/eef-space.ops.spec.ts`
  - `docker-compose.yml`

  (Mesuré le 05/10/2026 : 4 fichiers, 229 insertions, 3 suppressions.) `jq` affiche `null`
  pour les deux clés absentes : c'est le résultat attendu, pas une erreur.
- **Si le diff touche un autre fichier, ou le log un autre commit**, le backend de la
  release est plus en avance que ce que la 56 suppose : ne pas continuer sans arbitrer
  (déployer le backend au SHA `RELEASE` — `deploy.yml`, `scope=full` — puis lancer le
  préflight en `requires-new`, étape 4).
- **Ne pas déployer le backend avant le préflight de la 56.** Il n'est nécessaire que pour
  *allumer* la bulle ou les écoles privées (après l'adoption). Et jamais un déploiement à un
  commit **postérieur** à `RELEASE` : le préflight exige que la production soit un
  **ancêtre** de `RELEASE`, jamais en avance (un run du 02/10 a échoué ainsi).
- Si la production ne répond plus `0641601…` (un autre déploiement a eu lieu), relire
  `docs/release-ledger.md` avant toute chose.
- Sur le Mac, avant l'étape 3 :

```bash
flutter --version          # 3.44.1, comme le CI
python3 --version          # doit afficher une version
xcodebuild -version
```

  Observé le 03/10/2026 sur le Mac où ces documents ont été préparés : `/usr/bin/python3`
  répondait « You have not agreed to the Xcode license agreements. Please run 'sudo xcodebuild
  -license' » (alors que `xcodebuild -version` répondait « Xcode 27.0 »).
  `scripts/preflight-ios-archive.sh` appelle `python3` : sans licence acceptée, il
  échouerait. Le même défaut bloque `flutter test` (le hook natif du paquet `objective_c`
  appelle `xcrun` : « Building native assets failed ») et bloquerait `flutter build ios`.
  **Accepter la licence est une action du propriétaire, dans un Terminal**
  (`sudo xcodebuild -license accept`). *Faite depuis : `python3 --version` répond sur ce Mac.
  Si la commande ci-dessus répond encore « You have not agreed… », la refaire avant
  d'archiver.*

  **Xcode 27 (installé le 03/10/2026) et ce projet — constats mesurés sur la 55, à refaire
  sur la 56 (même code natif, mêmes dépendances) :**
  - **Cibles de déploiement des Pods.** Xcode 27 n'accepte que les cibles iOS 15.0 à 27.0.x : un
    Pod resté à 9.0, 11.0, 12.0 ou 13.0 fait échouer le build (« error: The iOS … deployment target
    … range of supported deployment target versions is 15.0 to 27.0.x »). L'app est déjà à 15.0
    (Runner, `platform :ios`) ; **le `ios/Podfile` relève donc au plancher de l'app tout Pod en
    dessous de 15.0** (`post_install`, 264 cibles à 15.0 après `pod install`). Si ce message
    apparaît à l'étape 3, l'arbre n'a pas cette correction : ne pas contourner dans Xcode, la
    ramener depuis `RELEASE`.
  - **Build pour appareil : passe.** Compilation non signée de la 55 sous Xcode 27 le 03/10/2026
    (`flutter build ios --release --no-codesign`) : `** BUILD SUCCEEDED **`, `Runner.app` en
    `2.3.0`, `MinimumOSVersion` 15.0, architecture `arm64`. **Le même contrôle sur la 56 n'a pas
    été fait** : à constater à l'étape 3 (`CFBundleVersion` doit être 56).
  - **Simulateur : ne passe pas avec Flutter 3.44.1.** Flutter appelle `lipo -verify_arch arm64
    x86_64` ; le `lipo` d'Xcode 27 refuse deux architectures d'un coup (exit 1) et accepte une
    seule : `Binary …/Flutter.framework/Flutter does not contain architectures "arm64 x86_64"`.
    Sans effet sur l'archive (une seule architecture, `arm64`). Pour la recette, installer la
    build depuis TestFlight / Play Internal, pas depuis le simulateur — **les cas de
    `docs/device-qa-build56.md` n'ont donc jamais été joués**.
  - Si un autre échec propre à Xcode 27 survient à l'archive, le recours est d'archiver avec
    Xcode 26.x installé à côté (developer.apple.com/download/all, puis `xcode-select`), sans
    changer le code.

**Copie propre de `RELEASE`** — à créer maintenant : le préflight de l'AAB (étape 2, point 5) et
l'archive iOS (étape 3) se font **dans cette copie**, pas dans le dossier de travail habituel. Les
deux scripts de préflight épinglent la version attendue du commit où on les lance : depuis un
dossier resté sur un commit d'avant la préparation de la 56 (qui épingle encore le numéro de la
55), `scripts/preflight-android-aab.sh` rejetterait l'AAB 56 (« versionCode différent de 55 »).

```bash
git worktree add ../kpb-release-56 "$RELEASE" && cd ../kpb-release-56
test "$(git rev-parse HEAD)" = "$RELEASE" && git status --porcelain     # rien à afficher
```

## 2. Android — l'AAB signé (≈ 15 min, sans toi) 🔒

1. Actions → **Flutter CI** → *Run workflow* → branche `main`, cocher **`release_android`**.
   **Ne pas pousser de tag `v2.3.0`** : l'exécution sur tag est rouge par construction, et le
   préflight lit la dernière exécution du commit. Vérifier en tête de l'exécution que le commit
   est bien `RELEASE` — d'où la règle de l'étape 0 : rien d'autre ne fusionne sur `main`
   entre `RELEASE` et la fin de l'étape 4.
2. Dans le journal « Verify App Bundle signature », relever l'empreinte SHA-256 et la comparer à
   Play Console → Intégrité de l'app → **certificat de la clé d'importation**. Le CI ne compare
   qu'à son propre keystore : c'est cette comparaison-là qui prouve que Play acceptera le bundle.
3. Le journal « Run strict Android store-artifact preflight » doit finir par
   `Préflight Android OK — 2.3.0 (56), com.karatou.android, SDK 36, …`.
4. Télécharger l'artefact **`app-release-android-aab`** de **cette** exécution.

   **NE PAS importer l'AAB de la 55** (Flutter CI, run **37322572087**) : la 55 est abandonnée
   et sa build ne contient ni la bulle, ni la visite, ni les écoles privées, ni le retrait de
   l'avertissement ; Play l'accepterait pourtant (55 > 53) et l'importer enverrait une build
   remplacée. **Ni celui du run 36945000021** (02/10, commit `47a1295`) : c'est la 54, jamais
   envoyée non plus. Aucun envoi vers Play n'est fait par le CI : c'est le propriétaire qui
   importe (étape 5), et **seul** l'artefact du run de `RELEASE`.
5. *Recommandé* — recouper localement, **depuis la copie propre `../kpb-release-56`** (étape 1),
   avec l'empreinte **de Play Console** (le script ne rouvre aucun keystore) :
   ```bash
   # JDK 17+ requis (JAVA_HOME) ; bundletool-all 1.18.1, la version qu'utilise le CI :
   # https://github.com/google/bundletool/releases/download/1.18.1/bundletool-all-1.18.1.jar
   BUNDLETOOL_JAR=/chemin/bundletool-all-1.18.1.jar scripts/preflight-android-aab.sh \
     --aab app-release.aab --expected-cert-sha256 "<empreinte SHA-256 de Play Console>"
   # → « Préflight Android OK — 2.3.0 (56), … certificat Play concordant, AD_ID absent. »
   ```

## 3. iOS — l'archive (sur le Mac) 🔒

Partir de la **copie propre** de `RELEASE` créée à l'étape 1 : le dossier de travail habituel
contient du travail en cours (`git status`), et le contrôle ci-dessous exige une arborescence vide.

```bash
cd ../kpb-release-56
test "$(git rev-parse HEAD)" = "$RELEASE" && git status --porcelain     # rien à afficher
flutter pub get && (cd ios && pod install)
```

**La clé PostHog : quatre gestes, UN BLOC À LA FOIS.** Le 04/10/2026, deux constructions de la 55
ont été faites avec une clé fausse : la première avec une clé **vide**, la seconde avec une clé
**doublée** (`phc_…phc_…`). Cause : des lignes collées d'un coup au moment de la saisie
(`read -rs` ne lit qu'une ligne). **Ne jamais coller deux lignes d'un coup ici.** Chaque bloc
ci-dessous se lance seul, et on attend son résultat avant de passer au suivant.

*1. La saisie — seule dans sa commande.* Le terminal n'affiche rien pendant la frappe :
coller **la clé et rien d'autre**, puis Entrée **une seule fois**.

```bash
read -rs POSTHOG_API_KEY && export POSTHOG_API_KEY      # la vraie clé phc_ du projet (jamais dans le dépôt, jamais collée dans un chat)
```

*2. Le contrôle AVANT la construction — la longueur, jamais la clé.* Comparer la longueur
affichée à celle de la clé dans PostHog (*Project settings*, la clé du projet commence par
`phc_`) : **elles doivent être égales**. Repère : la clé de la 55 faisait 48 caractères, mais la
longueur n'est pas figée par ce dépôt — la forme `phc_` + 30 à 60 lettres ou chiffres est ce que
le contrôle exige. **0** = vide ; **le double de la longueur attendue** = collée deux fois. Le
verdict « forme OK » fait foi ; s'il n'est pas « forme OK » ou si la longueur n'est pas celle de
PostHog, refaire la saisie (bloc 1) — ne pas construire.

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
grep -E '^FLUTTER_BUILD_(NAME|NUMBER)=' ios/Flutter/Generated.xcconfig   # FLUTTER_BUILD_NAME=2.3.0 / FLUTTER_BUILD_NUMBER=56
```

*4. Le contrôle APRÈS la construction — ce que la build a vraiment compilé.*
`ios/Flutter/Generated.xcconfig` est **régénéré** par `flutter build` : c'est lui, et non la
variable du terminal, qui dit quelle clé est partie dans le binaire. Le préflight décode
`DART_DEFINES` en mémoire et ne montre que la longueur et le verdict :

```bash
scripts/preflight-ios-archive.sh --xcconfig ios/Flutter/Generated.xcconfig --posthog-only
# → « POSTHOG_API_KEY : N caractères, une seule clé phc_ au format attendu — OK »
#   (N = la longueur lue dans PostHog ; le verdict OK fait foi)
# → « Replis compilés EEF : aucun define KPB_EEF_*_ENABLED à true — OK »
```

Il exige **une seule** définition `POSTHOG_API_KEY`, `phc_` suivi de 30 à 60 lettres ou chiffres
(donc ni vide, ni doublée, ni avec une espace, un tiret ou un guillemet), et n'affiche jamais la
clé. **Il refuse** une clé vide, absente, doublée (« la clé a été collée deux fois »), trop
courte ou mal formée : dans ce cas, recommencer au bloc 1. Le contrôle `grep -c '^phc_'` plus bas
**ne voit pas** une clé doublée (un seul `phc_` en début de ligne dans le binaire) : il ne
remplace pas celui-ci.

- **Aucun autre `flutter build` ni `flutter run` ensuite** (ils réécrivent
  `Generated.xcconfig`). Ne pas ajouter `KPB_API_BASE_URL` ni `KPB_EEF_SPACE_ENABLED`.
  Aucun define pour la bulle ni pour les écoles privées : leurs interrupteurs sont **serveur**.
  Ce n'est plus une simple consigne : le préflight iOS (`--posthog-only` ci-dessus, puis le
  mode complet) **refuse** un binaire compilé avec `KPB_EEF_ENABLED`, `KPB_EEF_SPACE_ENABLED`,
  `KPB_EEF_HELP_BUBBLE_ENABLED` ou `KPB_EEF_PRIVATE_SCHOOLS_ENABLED` à `true` : face au
  backend `0641601`, qui ne sert pas les clés, c'est ce repli compilé qui déciderait, et le
  relecteur verrait la bulle ou les écoles privées. L'AAB, lui, est construit par
  `flutter-ci.yml` sans aucun de ces defines (un test de contrat le garde).
- Ouvrir Xcode avec un PATH propre (un « Copy failed » est le conflit `rsync` / PATH) :
  `env PATH="/usr/bin:/bin:/usr/sbin:/sbin" /Applications/Xcode.app/Contents/MacOS/Xcode ios/Runner.xcworkspace`
  → *Any iOS Device* → **Product → Archive**. Le journal doit montrer
  « Successfully submitted symbols » (dSYM).
- Contrôler l'archive :
  ```bash
  A="<chemin>.xcarchive/Products/Applications/Runner.app"
  scripts/preflight-ios-archive.sh --xcconfig ios/Flutter/Generated.xcconfig --archive-plist "$A/Info.plist"
  strings "$A/Frameworks/App.framework/App" | grep -c '^phc_'     # doit afficher 1
  ```
  Signature automatique : l'échec attendu à ce stade est « n'est pas signée avec un
  certificat Apple Distribution ». Tout échec **avant** celui-là (version, build, clé PostHog,
  orientations) : recommencer le `flutter build ios`.
- Organizer → *Distribute App* → *Custom* → *App Store Connect* → *Export*, puis :
  ```bash
  unzip -q Runner.ipa -d ipa
  scripts/preflight-ios-archive.sh --xcconfig ios/Flutter/Generated.xcconfig --app ipa/Payload/Runner.app
  # → « Préflight iOS OK — 2.3.0 (56) »
  ```
  Envoyer **cette** IPA par Transporter — seulement avec le feu vert du propriétaire.
  La build 55, déjà dans TestFlight, **n'est pas touchée** : on ne la supprime pas et on ne la
  rattache à aucune version.
- Rejets connus : **90474** (un bundle iPad doit déclarer les quatre orientations) et **90101**
  (on ne retire pas l'iPad d'une app publiée) — le préflight les contrôle ; **ITMS-90062**
  (version marketing non supérieure à celle en vente) ne se produit pas : 2.3.0 > 2.2.0, et
  aucune 2.3.0 n'a jamais été soumise.

## 4. Préflight de release (≈ 5 min, lecture seule)

Actions → **Release preflight (backend before mobile)** — ou, en ligne de commande :

**Avant de lancer — la porte « 24 heures de stabilité » ne peut PAS passer.** Elle échoue
**quelle que soit la date** (constaté le 03/10/2026, run 37163074707, `RELEASE` de l'époque =
`6e0ea8d` : « only 5 successful scheduled probes in 24h; require at least 80 »), et ce n'est pas
le redéploiement du backend qui en est la cause. `scripts/verify-uptime-window.sh` exige **au
moins 80 sondes réussies** sur 24 h et un **trou maximal de 30 minutes** ; or la tâche planifiée
`.github/workflows/uptime.yml` déclare `*/15 * * * *` mais GitHub ne l'exécute, sur ce dépôt,
qu'environ **5 fois par jour** (d'après `gh run list --event schedule`, avec des trous de plus de
5 h). Aucune attente ne la rend vraie. La bonne marche est **`require_24h_stability=false`**,
une dérogation **journalisée** par le workflow (« 24-hour uptime evidence was explicitly
waived »), **après avoir vérifié que les sondes des 24 dernières heures sont toutes en
succès** :

```bash
gh run list --workflow uptime.yml --event schedule --limit 30 --json createdAt,conclusion,status \
  --jq '[.[] | select(.status == "completed" and .createdAt > (now - 86400 | todate))]
        | {sondes: length, hors_succes: ([.[] | select(.conclusion != "success")] | length)}
        | if .sondes < 3 or .hors_succes > 0
          then error("preuve insuffisante : sondes=\(.sondes), hors_succes=\(.hors_succes)")
          else . end'
# attendu : un objet {sondes: ≈ 5, hors_succes: 0} ET aucune erreur. La commande ÉCHOUE si elle
# voit moins de 3 sondes ou un seul échec. « sondes = 0 » n'est PAS une preuve : `gh` a déjà
# rendu une liste vide alors que 4 à 5 sondes réussies existaient dans les 24 h (cause non
# isolée) — relancer jusqu'à voir des sondes. Un échec réel dans les 24 h reste un échec : le
# regarder (gh run view) avant de déroger.
```

Puis lancer le préflight **avec la dérogation** :

```bash
gh workflow run release-preflight.yml --ref main \
  -f ref="$RELEASE" -f backend_coupling=tolerates-old -f require_24h_stability=false
```

*Correctif de fond, à proposer en PR APRÈS l'archive (jamais sur `main` pendant une release en
cours)* : des seuils réalistes (environ 4 sondes, trou maximal d'environ 8 h) ou une sonde
externe fiable (`docs/DEPLOYMENT.md`). Tant qu'il n'est pas fait, `true` échoue toujours.

Les trois champs du workflow :

- `ref` = `RELEASE` (le SHA complet, pas `main`) ;
- `backend_coupling` = **`tolerates-old`**. `requires-new` exigerait que la production serve
  `RELEASE` (12 premiers caractères), ce qui n'est pas le cas : elle sert `0641601`.
  `tolerates-old` exige que la production soit un ancêtre de `RELEASE` (vérifié à l'étape 1)
  et laisse un avertissement « le déploiement couplé est dû » : **il l'est pour de bon, mais
  seulement pour allumer** la bulle et les écoles privées (#319 est le seul changement de
  `backend/` depuis `0641601`, étape 1) — pas pour archiver ni pour soumettre ;
- `require_24h_stability` = **`false`**, pour la raison ci-dessus. La dérogation est journalisée
  dans le résumé du run ; la conserver avec la preuve du §5 du pack de la 55 (reprise par celui
  de la 56, §6).

Ce que le workflow vérifie (il échoue, il ne devine pas) : le SHA est atteignable depuis
`main` ; les quatre CI sont vertes sur ce SHA ; `VPS_HEALTH_URL` répond ; la page `/app` sert la
redirection vers la fiche de l'App Store (`id1128659292`) ; la porte de livraison publique
passe ; un **heartbeat de sauvegarde** de moins de 8 h ; un **exercice de restauration isolé**
de moins de 90 jours ; et, quand `require_24h_stability` est vrai, 24 h de sondes de
disponibilité (inatteignable, voir plus haut : on déroge).

Deux pièges : le heartbeat de sauvegarde ne se rafraîchit pas à la main — il tourne toutes les
6 h à h+23 UTC, attendre le prochain si besoin ; l'exercice de restauration doit dater de moins
de 90 jours (sinon *Backup restore drill*, exécution réelle, avec l'approbation de
l'environnement de production).

## 5. Recette sur appareil (TestFlight + Play Internal) 🔒

Installer **la build envoyée** impose de l'envoyer d'abord aux pistes de test : IPA par Transporter
→ TestFlight ; AAB → Play Console → **Tests internes**. Ces deux envois sont des étapes de
distribution : feu vert du propriétaire.

1. Installer la build depuis TestFlight / Play Internal (pas un build de debug : le contrat de
   soumission exige que la preuve vienne de l'artefact). **Choisir la ligne `2.3.0 (56)`, pas la
   55** : TestFlight liste les deux. L'app n'affiche pas sa version : la lire dans TestFlight, et
   `versionCode` 56 côté Android (A1 de la fiche).
2. Dérouler le **§A** de `docs/device-qa-build54.md` (vitrine, Niger, déclaration, plus de « % »,
   lettres IA, notifications, CGU, état A étanche…).
3. *Facultatif mais recommandé* — **fenêtre de recette du hub (voie 2)** : aucune build qui
   contient le hub n'est en vente (la 55 n'a jamais été soumise), donc `vps-ops` →
   `eef-space-on` (simulation, puis application) n'ouvre le hub qu'aux testeurs (les 49 à 53
   ignorent `eefSpace`). Dérouler le §B, le §B-filtres et le §B-aide de
   `docs/device-qa-build54.md`, puis `docs/device-qa-build55.md` (aides, « Me retirer », Niger,
   anglais), puis **`docs/device-qa-build56.md`** (visite, bulle, écoles privées) :
   `eef-bubble-on` et `eef-private-schools-on` ne s'allument **que** pendant la fenêtre, et
   `eef-bubble-on` demande qu'une personne soit nommée pour répondre (décision d). Le cas
   « repli » de Filtres-8 (route `/cities` indisponible) ne se teste pas contre la production :
   voie 1 ou voie 3 du §B. Tuer et relancer l'app après chaque bascule. **Les allumer sur un
   backend qui ne porte pas leurs clés est refusé** : pour tester la bulle et les écoles
   privées sur la production, il faut d'abord déployer le backend au SHA de la 56 — c'est le
   seul cas où ce déploiement précède la soumission, et **il vient après le préflight de
   l'étape 4**.
   **Puis `eef-private-schools-off`, `eef-bubble-off`, `eef-space-off`**, et vérifier que
   `eefSpace`, `eefHelpBubble` et `eefPrivateSchools` valent `false` ou sont absents (commande
   de l'étape 1) **avant** de soumettre **et avant toute promotion Play vers la production**.
4. Un ✗ non résolu bloque la soumission (§D de la fiche).

## 6. Consoles

| Quoi | Où | Note |
|---|---|---|
| Questionnaire d'âge (App Store **et** IARC) | `store-listing-copy.md` §9 (D2) | Garder la preuve des réponses. D2 n'est pas tranchée dans le dépôt |
| App Privacy / Data Safety | `CONSOLE_ANSWERS.md` | **Inchangés pour la 56 sous réserve** : les aides et la bulle n'ouvrent que WhatsApp avec un message préécrit sans donnée personnelle, et les filtres n'envoient rien de nouveau. **À vérifier sur le SHA final** : ni dépendance ni manifeste n'a changé (les commandes de l'étape 0 ne doivent rien afficher — sinon « inchangés » tombe) ; le message des boutons (pack 55 §3, point 1) et de la bulle (pack 56 §3, point 1) ; les nouveaux événements (`docs/analytics-event-contract.md`) |
| Contrôles qui dépendent de l'artefact (clé `phc_` = 1, `AD_ID` absent) | `CONSOLE_ANSWERS.md`, en-tête | L'en-tête dit « refaire sur l'archive 54 » : **lire 56** — les refaire sur l'archive et l'AAB de la 56 avant de changer l'en-tête |
| Finalités « Marketing » (XC-06) | `CONSOLE_ANSWERS.md` §0quater | La politique publiée dit que l'équipe commerciale lit les déclarations : à déclarer, sauf avis contraire du juridique (**non tranché dans le dépôt**) |
| Play → *Government apps* : « non » ; non-affiliation en fin de description longue | **Pack 56 §4** (texte FR/EN propre à la 56, **sans « suspensions »** : ne pas coller celui du pack 55 §4) | |
| Compte de démonstration étudiant, **exclu des listes d'appel** | Pack 56 §3 | La note de revue le promet |

## 7. Soumettre 🔒

- **App Store** : ouvrir la version **2.3.0** (celle à laquelle la 55 aurait été rattachée) et y
  rattacher la **build 56** (une fois traitée par TestFlight) **à la place de la 55** : dans la
  fiche de version, section « Build », choisir `56` ; ne pas choisir `55`. « Nouveautés » = pack 55
  §2.1 (la 56 n'ajoute rien de visible hors drapeau : pack 56 §2) ; *Notes for Review* = le texte
  **complet** du pack 56 §3 (à coller **seul**, il remplace le bloc de `store-listing-copy.md` §7.1
  **et** l'addendum de la 55). **Compter les caractères du texte final avant de coller : le champ
  est limité à 4 000 caractères (à vérifier à la saisie dans App Store Connect).** Le décompte du
  pack §3 est refait par `test/release/store_pack_56_test.dart` ; l'adresse du compte de
  démonstration et sa méthode de lecture du code y sont réservées (40 et 120 caractères) : si
  l'une dépasse sa réserve, recompter. Revue accélérée : inutile en état A (l'espace reste
  fermé après l'approbation).
- **Google Play** : production par paliers 5 / 20 / 100 % ; notes de version = pack 55 §2.1 (bloc
  Google Play). **L'AAB importé est celui du run de `RELEASE` (la 56)**, jamais celui de la 55.
- Avant d'appuyer : `curl … | jq '.features | {eef, eefTeaser, eefSpace, eefHelpBubble,
  eefPrivateSchools}'` → `false, true, false, null (ou false), null (ou false)`.
- Conserver les preuves du pack 55 §5 et du pack 56 §6 (sorties des préflights, `phc_` = 1,
  dSYM, questionnaires, captures **sans** hub, bulle, visite ni feuille).
- **Le jour de l'envoi**, reporter dans `docs/release-ledger.md` le SHA de `RELEASE` à la place
  du marqueur `<RELEASE>` et la mention « téléversée le … » sur la ligne `56` — **après** l'étape 4,
  jamais pendant (rien ne fusionne tant que le préflight n'est pas fini).
  Le test `test/release/build_number_test.dart` accepte les deux états de cette ligne (avant :
  `<RELEASE>` et « non téléversée » ; après : « téléversée le JJ/MM/AAAA » et le SHA de 40
  caractères, formulation exacte dans l'en-tête du registre) et refuse un état **mixte** :
  la PR de report passe donc la CI, et l'on ne garde jamais « non téléversée » pour la
  contenter.

## 8. Après la soumission — ne pas faire tout de suite

- `eef-space-on` pour tous : seulement quand la 56 est **en vente sur les deux stores et
  adoptée** (seuil d'adoption à fixer : `docs/ouverture-espace-eef.md` § 6) ; les corrections de
  procédure sont déjà appliquées et le juridique est tranché. Puis, séparément, dans l'ordre du
  runbook : déployer le backend au SHA de la 56, `eef-bubble-on` (après la décision d),
  `eef-private-schools-on` (après a, b, c, et idéalement quelques jours plus tard).
- L'annonce d'ouverture : après l'ouverture seulement, vers **tous les étudiants, Niger compris**,
  texte neutre (`docs/ouverture-espace-eef.md` § 4). L'audience `eef_interest` reste inutilisée.
  **L'outillage dit encore le contraire** : l'agent `kpb-notifications` ordonne d'exclure les pays
  suspendus et `kpb_draft_notification` avertit si on ne le fait pas. L'avertissement est attendu
  (décision du 03/10) ; lui donner la consigne explicitement et ne pas ajouter `exceptCountries`
  (`docs/ouverture-espace-eef.md` § 4, « Ce que l'outillage dit encore »).
- **`KPB_MIN_APP_VERSION=2.3.0`** : jamais avant que la 2.3.0 soit réellement téléchargeable sur
  les deux stores et déployée à 100 % (elle enferme sinon tout le monde derrière un écran sans
  sortie) ; en pratique, pas pour cette build.
- `recommended-version-set` : sans effet sur la 53 (elle ne lit pas la clé) ; utile pour les
  passages **après** la 56.
- Ne jamais poser `KPB_EEF_ENABLED=true` (il retire la vitrine aux builds 49 à 53).
- Aucun tag `v2.3.0`, aucune notification.
