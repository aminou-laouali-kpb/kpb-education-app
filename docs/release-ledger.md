# Release ledger

Un numéro listé sous **Consommés** ne peut plus figurer dans `pubspec.yaml`.
Le numéro sous **Courant** est le seul autorisé. Le test
`test/release/build_number_test.dart` lit ce fichier.

Version marketing EN VENTE : `2.2.0` (depuis le 13/09/2026). Le test lit cette ligne :
la version de `pubspec.yaml` doit lui être strictement supérieure (ITMS-90062). La mettre
à jour le jour où une nouvelle version passe en vente, pas avant.

La ligne du numéro courant a **deux états**, et le test accepte les deux mais refuse tout
état mixte :

- **avant l'archive** : « EN COURS (archive à faire) : non téléversée, non soumise » et
  « Commit à archiver : `<RELEASE>` », jamais un SHA ;
- **après l'envoi** (le jour de l'archive, après la dernière étape de la checklist) :
  « téléversée le JJ/MM/AAAA » à la place du premier, et « Commit archivé : `RELEASE` =
  `<les 40 caractères du SHA>` » à la place du second. On ne garde alors plus aucun des
  trois marqueurs « avant ».

Un numéro ne passe sous **Consommés** que quand le numéro suivant est préparé.

## Consommés

- `46` — AAB CI du 31/07/2026, jamais téléversé sur Play
- `48` — consommé sur TestFlight le 12/08/2026
- `49` — installée et revue par le propriétaire le 29/08/2026
  (`docs/device-qa-build49.md`). Cette revue a produit neuf demandes ; les
  correctifs montent dans la 50, donc la 49 ne repart pas.
- `50` — téléversée sur TestFlight le 30/08/2026 à 02h15. Elle porte sept des
  neuf points de la revue. Trois manques constatés par le propriétaire sur cet
  artefact : les outils CV/lettres restaient masqués (drapeau de COMPILATION,
  donc impossible à ouvrir sans binaire neuf), PostHog partait sans clé, et la
  prélude Campus France restait éteinte côté serveur. La 50 ne repart pas.
- `51` — **jamais archivée ni téléversée.** Le numéro a porté le dépôt du
  31/08 au 03/09/2026 — plusieurs PR fusionnées et des artefacts de CI
  l'ont embarqué — mais aucune archive n'a été produite. Son contenu monte
  intégralement dans la 52, qui y ajoute la liste d'attente Premium. Brûlée
  plutôt que réutilisée : « build 51 » désigne déjà quelque chose de précis
  dans les échanges avec le propriétaire, et faire porter ce nom à un autre
  artefact aurait rendu toute trace ultérieure ambiguë.

- `52` — **livrée aux deux plateformes le 03/09/2026.** Archive iOS
  téléversée sur App Store Connect à 11h22 (« Uploaded to Apple ») ; AAB
  Android signé et vérifié par la CI le même jour (run 33752445518,
  artefact `app-release-android-aab`).

  Premier artefact dont la télémétrie et la lisibilité des plantages sont
  PROUVÉES et non supposées :
  - clé PostHog présente dans le binaire iOS (`strings` : 1 occurrence ;
    la 50 en avait 0) et exigée par la garde du job AAB avant construction ;
  - 55 dSYM produits et envoyés à Crashlytics — le journal d'archivage
    porte « Successfully submitted symbols for architecture arm64 » sous
    l'identifiant de la phase `30944CAE…` ;
  - AAB signé par LA clé d'upload attendue, empreinte SHA-256 comparée à
    celle du keystore installé par le job lui-même.

  Backend au même SHA que la build (`b6d8d769cc71` au moment de l'archive),
  couplage `requires-new` satisfait et vérifié par le préflight de release.
  La 52 ne repart pas.

- `53` — **`2.2.0 (53)`, livrée aux deux stores : la 2.2.0 est EN VENTE sur
  l'App Store depuis le 13/09/2026** (vérifié le 29/09/2026 : la page de la fiche
  affiche « 2.2.0 », mise en ligne le 13/09/2026). Rigoureusement le même code
  applicatif que la 52 : sa raison d'être était la version marketing, qui seule
  permet à `isVersionBelow` de distinguer une build d'une autre. Le détail de sa
  construction et de sa vérification est dans l'historique git de ce fichier. La
  53 ne repart pas, et le train « 2.2.0 » est fermé : App Store Connect refuse
  toute build dont la version marketing n'est pas supérieure à 2.2.0.

- `54` — **jamais envoyée aux boutiques (constat du 03/10/2026) ; numéro
  abandonné, la 55 la remplace.** Le numéro a porté le dépôt (`2.3.0+54`) et un AAB
  signé de la CI (Flutter CI, run 36945000021, le 02/10/2026, commit `47a1295`),
  jamais importé dans Play et sans les nouveautés de la 55 : cet AAB est OBSOLÈTE.
  Le 03/10, ni App Store Connect (TestFlight → Build Uploads : dernier envoi
  `2.2.0 (53)` du 04/09) ni Google Play Console (dernier bundle 53 / 2.2.0,
  importé le 04/09, en production « déploiement complet » depuis le 11/09) ne la
  contiennent, et aucune archive Xcode d'octobre n'existe sur le Mac du
  propriétaire. Les documents qui écrivaient « soumise le 02/10 » ou « en attente
  d'approbation » étaient faux. Son contenu monte intégralement dans la 55
  (`### Ce que 55 embarque`). Brûlée plutôt que réutilisée, comme la 51 : « build
  54 » désigne déjà des documents et un artefact de CI précis.

- `55` — **`2.3.0 (55)` : consommé le 04/10/2026 (téléversée sur App Store Connect à
  01 h 20), jamais soumise à l'App Review, remplacée par la 56.** Décision du
  propriétaire du 05/10/2026 (« 56 ») : on n'envoie QUE la 56, la 55 est abandonnée.
  Son AAB signé (Flutter CI, run 37322572087), jamais importé dans Play, ne
  doit PAS l'être : ce serait envoyer une build que la 56 remplace. Le numéro est
  consommé parce que la build est partie chez Apple, pas parce qu'elle a servi :
  il ne reprend jamais la place du courant. Elle avait été préparée le 03/10 comme la
  SEULE build 2.3.0, à la place de la 54 (décision du propriétaire, « option B ») ;
  son contenu complet est dans `### Ce que 55 embarque`, et la 56 le reprend en entier.
  La 55 n'ayant jamais été soumise, la version marketing `2.3.0` reste libre pour la 56.

## Courant

- `56` — **`2.3.0 (56)`, EN COURS (archive à faire) : non téléversée, non soumise.
  La SEULE build 2.3.0 à envoyer : elle remplace la 55 (décision du propriétaire,
  05/10/2026).** Elle porte tout ce que portait la 55 (`### Ce que 55 embarque`) plus
  ce que la 56 y ajoute (`### Ce que la 56 ajoute à la 55`) : la bulle verte WhatsApp, la
  visite guidée, la feuille « écoles privées », deux interrupteurs serveur fermés, le
  retrait de l'avertissement de suspension. Le numéro 55 est CONSOMMÉ (téléversé) ; la 56
  en est le successeur direct.

  **Version marketing : `2.3.0` reste valable.** App Store Connect refuse toute build
  dont la version marketing n'est pas **strictement supérieure** à celle en vente
  (ITMS-90062) ; la 2.2.0 est en vente depuis le 13/09/2026, et 2.3.0 > 2.2.0 tant
  qu'aucune 2.3.0 n'a été soumise : c'est le cas, la 55 ne l'ayant jamais été. La 56
  prend donc la fiche de version 2.3.0 d'App Store Connect **à la place de la 55**
  (on choisit la build 56 dans la fiche de version). Le test
  `test/release/build_number_test.dart` garde ce « strictement supérieur ».

  **Elle part avec l'espace réel ET les deux interrupteurs FERMÉS** (décision XC-03,
  état A de `docs/release-55-store-pack.md` ; `docs/release-56-store-pack.md`).
  Tout ce que la 56 ajoute pour « Études en France » est derrière `features.eefSpace`,
  que seul le serveur allume ; la bulle et la feuille « écoles privées » ont en plus
  leur interrupteur (`features.eefHelpBubble`, `features.eefPrivateSchools`, clé absente
  = fermé). À l'approbation, un utilisateur de la 56 voit la vitrine de la 53, comme avec
  la 55. L'ouverture est une opération serveur séparée
  (`docs/runbook-ouverture-espace-reel.md`), sans nouvelle soumission.

  **Commit à archiver : `<RELEASE>` — À RENSEIGNER.** C'est le SHA complet de `main`
  après la fusion de #326 (la vitrine sans avertissement) ET de la PR qui prépare la 56
  (version, préflights, ce registre, la checklist) ; **rien d'autre ne fusionne
  ensuite**. Tant que l'archive n'existe pas, ce marqueur reste tel quel : un SHA écrit
  à l'avance serait inventé (le test refuse un SHA de 40 caractères posé comme
  `RELEASE`). Il se relève avec `git rev-parse origin/main`
  (`docs/mise-a-jour-56-checklist.md`, étape 0) et se reporte ici le jour de
  l'archive.

  **Statut au 05/10/2026** : non archivée, non soumise, absente de TestFlight (la 55 y
  est, seule) et de Play. **Production : relevé du 03/10, NON remesuré le 05/10.**
  Backend `0641601` (en ligne depuis le 03/10 à 17 h 06 UTC), sans les clés
  `eefHelpBubble` / `eefPrivateSchools` ; `features` = `eefTeaser=true`, `eef=false`,
  `eefSpace=false` au 03/10. **Une fenêtre de recette `eef-space-on` a pu rouvrir
  `eefSpace` depuis** : ne pas lire « fermé » ici comme un état actuel ; l'étape 1 de la
  checklist le mesure et dit quoi faire s'il vaut `true`. Catalogue publié : 10 029
  formations dans 84 établissements, 473 en attente (mesuré le 01/10, total inchangé après
  `eef-reconcile` le 02/10).

  **Couplage backend** : `tolerates-old` (`### Couplage backend de la 56`). Le backend de
  production est TOUJOURS `0641601` ; la 56 le tolère (clé absente = fermé) ; le déployer
  au SHA de la 56 n'est nécessaire QUE pour allumer la bulle ou les écoles privées, et
  **ne se fait pas avant le préflight de la 56**.

### Ce que 55 embarque

**Depuis le 05/10/2026, c'est le contenu que la 56 reprend EN ENTIER** : la 55 est
abandonnée (jamais soumise), la 56 est construite au-dessus. Deux retraits, décidés
après ces lignes et décrits sous `### Ce que la 56 ajoute à la 55` : la « suspension
qui remplace la date » du héros et la « mise en garde de suspension avec sa source »
des mentions ci-dessous ne s'affichent plus (#324, #326).

Les points 1 à 4 sont ce que ce registre attribuait à la 54 avant l'abandon de son
numéro ; le point 5 est ce que la décision du 03/10 y ajoute.

**1. Le hub de l'espace « Études en France » (derrière `eefSpace`).**
- Hub : héros (où se dépose la candidature, suspension qui remplace la date, lien
  vers la plateforme officielle), catalogue, CV / lettres / entretien (même masque
  `aiToolsEnabled` que la boîte à outils), conseiller WhatsApp. Plus aucun module
  « en préparation ».
- Catalogue (serveur, #280 puis cette build) : recherche par nom d'université,
  sigle, ville, sans accents ; filtres Niveau, Domaine, Ville et Procédure (#314,
  point 5) ; carte qui nomme l'université, la ville et la procédure (DAP blanche /
  jaune, Études en France, Parcoursup, hors procédure) ; « le catalogue arrive »
  distinct de « ta recherche est trop étroite » ; une page suivante en panne garde
  la liste ; « Tout effacer » vide aussi le champ ; la barre de facettes n'a plus
  de hauteur fixe.
- Mentions : paternité de la Licence Ouverte 2.0 (producteur, licence, date de
  mise à jour **servis** par `/config/app`), non-affiliation avec lien vers la
  plateforme officielle, mise en garde de suspension avec sa source.
- Profil « Mon profil Études en France » : niveaux + domaines d01–d12 (préremplis
  depuis le profil par une table fermée), **Modifier par `PATCH`** (ni
  consentement redemandé, ni intérêt Premium effacé), **Me retirer** — la promesse
  « depuis cet écran » du texte de consentement est tenue. Texte
  `eef-consent-v1` **inchangé**, archivé dans `docs/eef-consent-v1.md`.
- Parents et partenaires arrivés par lien : « un espace pour les étudiants » (pas
  un 403 traduit en « reconnecte-toi »). Invité : catalogue public, invitation à
  créer un compte pour le profil.
- Aide à chaque étape floue (`EefHelpCard`) : une carte « C'est flou ? Tu veux de
  l'aide ? » dans le hub (elle **remplace** la tuile « Parler à un conseiller »),
  deux lignes (procédure/dates/dépôt sous le héros, documents sous les outils) et,
  dans le catalogue, sous les résultats, dans « aucun résultat », dans « le
  catalogue arrive » et — au-dessus des résultats — quand on filtre sur une
  procédure qu'on confond (dossier jaune, Parcoursup, hors procédure). Le bouton
  ouvre WhatsApp (`openWhatsAppOrToast`, le chemin commun) avec un message
  prérempli FR/EN qui **nomme l'étape et ne contient aucune donnée personnelle**.
  Pays suspendu (Niger) : jeu de textes **neutre** (« autres options »), jamais
  « démarre l'étude de ton dossier ». Aucune promesse d'admission ni de visa,
  aucun prix.
- Santé : « médecine », « pharmacie », « kiné », « L.AS »… mènent aux PASS et L.AS
  (serveur, #300 puis #301) ; la carte porte le badge « Accès santé » quand le
  serveur le dit (`healthAccess`, absent = pas de badge). Le filtre du cycle
  `sante` s'appelle « Études de santé » : il compte aussi 61 diplômes
  paramédicaux, sans badge.
- Mesure : `eef_space_viewed`, `eef_hub_tile_opened`, `eef_catalog_viewed`,
  `eef_catalog_searched`, `eef_catalog_failed`, `eef_help_card_shown`,
  `eef_help_cta_tapped` — des comptes et des identifiants fermés, **jamais le
  texte tapé** (`docs/analytics-event-contract.md`).

**2. Le socle qui rend les builds suivantes pilotables.**
- **En-têtes `X-KPB-App-Version` / `X-KPB-App-Build`** sur chaque requête (CAT-03) :
  avant, le serveur ne pouvait pas distinguer une 53 d'une 55. Ils ne cassent
  jamais une requête (lecture mémorisée, échec = pas d'en-tête).
- **Bandeau doux « une mise à jour est disponible »** piloté par
  `recommendedVersion` (XC-09), fermable, masqué sans lien de store. C'est le
  levier des passages suivants (55 → build suivante → forum) sans relever
  `minVersion` (qui bloque l'app). `vps-ops` → `recommended-version-set`.
- **Liens officiels servis** (XC-05) : `eefCampaign.platformUrl`,
  `suspendedSources` (https seulement, sans identifiants) ; `eefCatalog`
  (attribution, gardée contre `manifest.json` par un spec).

**3. Embarqué depuis la 53 (déjà sur `main`).** Lien profond `/parcours/<slug>` du
push « récit de la semaine » (#284) ; étiquettes OneSignal normalisées (#286) ;
email manquant qui bloquait la synchro du profil (#291) ; logos Wikimedia Commons
avec crédit de licence (#281, 330 px — MISS-01) ; client de recherche serveur
(#280).

**4. Conformité et correctifs ajoutés au dernier moment** (#287 et #288, intégrées
par #302 le 01/10).
- MISS-02 et #287 : **plus aucun pourcentage d'admission** dans l'app. La jauge
  « 85 % » codée en dur de la fiche établissement, les « 40 % » de repli des
  Universités et de Comparer, les « 74 % » de la fiche formation et de la carte
  partageable laissent place à un palier « match profil » calculé (Très bon
  match / Bon match / À explorer), **absent sans profil**. Un garde interdit le
  retour des jauges et tout palier littéral. Puce de ville du Logement lisible.
- #288 : génération IA (CV, lettres, entretien, relecture, orientation,
  diagnostic) avec un délai de **90 s** au lieu de 15 ; un délai dépassé dit
  « plus long que prévu », plus « vérifiez votre connexion ». Côté serveur
  (déployé) : raisonnement caché désactivé sur OpenRouter, **503** au lieu d'un
  modèle de lettre vierge présenté comme personnalisé, le nom de l'étudiant n'est
  plus envoyé à la personnalisation.
- FOR-M05 : « Un espace communautaire » retiré des CGU (web et app) tant que le
  forum n'est pas livré. LIV-28 : « Dernière mise à jour : septembre 2026 »
  (politique et CGU, web et app).
- Wikimedia déclaré comme destinataire dans les réponses de console
  (`CONSOLE_ANSWERS.md` §5).

**5. Ajouté par la décision du 03/10/2026.**
- **Filtres du catalogue (#314, fusionnée, backend `0641601` en production).** La
  rangée de puces est remplacée par quatre boutons — Niveau, Domaine, Ville,
  Procédure — qui ouvrent chacun une feuille de choix ; filtres actifs en puces
  supprimables. La liste des villes vient de `GET /etudes-en-france/cities` ; si
  la route manque (404, 405, 5xx : backend plus ancien que l'app), le client
  retombe sur les 20 villes de la facette `campusCity`, avec la mention « Villes
  principales », sans écran bloquant. Derrière `eefSpace`. Recette :
  `docs/device-qa-build54.md` §B-filtres.
- **Aide à la demande de dossier (#315, fusionnée le 03/10).** Un bouton « Demander de l'aide » sur chaque
  formation ; une ligne d'aide sous les filtres actifs ; une aide à l'étape
  « Préparer mon dossier » (CV, lettre, entretien), **uniquement depuis le hub de
  l'espace** ; les comptes du Niger voient ces aides en **variante neutre**.
  Derrière `eefSpace`. Le message prérempli nomme ce que l'étudiant regardait
  (formation, université et ville ; filtres posés ; ou outil), jamais son nom, son
  e-mail, son téléphone ni le nom de son pays ; pour un pays suspendu il dit que la
  procédure est suspendue « dans mon pays », sans le nommer — d'après
  `EefHelpMessages`, **à vérifier sur le SHA final**
  (`docs/device-qa-build55.md`, Aide-19 à Aide-31).
- **Lien « Me retirer » dans la feuille de déclaration d'intérêt** (#315).
  Décision juridique du 03/10/2026 : le texte consenti et `eef-consent-v1` ne
  changent pas. ⚠️ À vérifier à la recette (Aide-39 à Aide-42 de
  `docs/device-qa-build55.md`) : cette feuille est aussi ouverte par la vitrine
  (`eef_teaser_screen.dart`), donc ce lien peut être visible à l'approbation, espace
  éteint — mais seulement pour un étudiant qui a déjà déclaré son intérêt (« Modifier
  ma réponse ») : la feuille d'une première déclaration ne l'affiche pas.
- **Correctifs ajoutés avant l'archive (03/10/2026).** #310 : l'adresse du socket
  Socket.IO de la messagerie des dossiers n'était valide qu'en local (la
  dérivation `replaceFirst('/api', '')` coupait le premier « /api » de
  `https://api…`). #317 : le domaine coché dans la feuille « Ça m'intéresse » était
  illisible (gris sur bleu, 1,09:1) ; visible dès l'approbation, la vitrine ouvrant
  cette feuille. **`ios/Podfile` : les Pods sous iOS 15.0 sont relevés à 15.0**
  (`post_install`) parce que Xcode 27, installé sur le Mac du propriétaire le
  03/10, refuse les cibles de déploiement hors de 15.0 à 27.0.x et fait échouer
  le build ; l'app est déjà à 15.0, aucun appareil pris en charge ne change. Seule
  la somme de contrôle du Podfile bouge dans `ios/Podfile.lock`, aucune version
  de Pod. Compilation non signée pour appareil sous Xcode 27 vérifiée
  (`Runner.app` 2.3.0 (55), iOS minimum 15.0, `arm64`) ; le simulateur ne passe
  pas avec Flutter 3.44.1 (`lipo -verify_arch` à deux architectures, voir la
  checklist, étape 1).
- **Autres décisions juridiques du 03/10/2026** (`docs/ouverture-espace-eef.md`
  §6) : la phrase du héros sur Campus France est validée telle quelle ; l'annonce
  d'ouverture part vers tous les étudiants, Niger compris, avec un texte neutre
  (l'audience `eef_interest` reste inutilisée) ; la question EEF-UX-15 ne se pose
  pas pour cette build, aucune sélection de formations n'exigeant de profil
  déclaré.

**Ce que la 55 ne contient PAS** (et qu'aucun texte de fiche ne doit vanter) : la
fiche formation, l'onglet Universités, la sélection en trois étages, la checklist,
le projet d'études, les favoris synchronisés (une build ultérieure, numéro non
décidé : le « build 55 » qu'on leur donnait dans les documents antérieurs est
caduc, la 55 est celle-ci) ; le forum (build dédiée) ; aucun logo sur la carte du
catalogue (la fiche d'un établissement d'Explorer en dessine un, avec son crédit de
licence, quand l'établissement en a un : #281, point 3 ci-dessus ; aucun des 69
établissements servis n'en avait le 03/10) ; une nouvelle version de consentement
(`eef-consent-v1` est inchangé) ; et, à l'approbation, l'espace ouvert : le
catalogue est publié (10 029 formations, 84 établissements) mais reste derrière
`eefSpace`.

### Couplage backend de la 55 : `tolerates-old`

*(Historique : la 55 est abandonnée ; le couplage de la 56 est sous `### Couplage
backend de la 56`. Le raisonnement ci-dessous vaut toujours pour elle, avec une
exception : `backend/` a changé depuis `0641601`, une fois, par #319.)*

La 55 ne **dépend** d'aucun backend récent pour fonctionner : chaque appel neuf est
soit derrière `eefSpace` (que seul un backend récent peut allumer), soit tolérant à
une clé ou une route absente (`recommendedVersion`, `eefCatalog`, `platformUrl`,
`suspendedSources`, `catalogPublished` — lue « publié » quand elle manque ;
`GET /etudes-en-france/cities` — liste de repli quand la route est indisponible).
Un backend en retard se traduit par **moins de choses affichées**, jamais par une
erreur : c'est la définition de `tolerates-old`.

Le préflight se lance avec `backend_coupling=tolerates-old`, et la raison est de
mécanique, pas de contenu : `requires-new` exige que la production serve le SHA de
release (12 premiers caractères), or la production sert `0641601` et le SHA de
release sera celui de `main` après la fusion de la branche et de la préparation
de la 55. `tolerates-old` exige que la production soit un **ancêtre** du SHA de
release : `git merge-base --is-ancestor 0641601 <RELEASE>`. Pour que ce « en retard »
ne cache rien, `git diff --stat 0641601 <RELEASE> -- backend admin docker-compose.yml`
**ne doit rien afficher** : sinon le backend de la release n'est pas en production,
il faut déployer (`deploy.yml`, `scope=full`) puis revoir le couplage.

⚠️ **L'OUVERTURE de l'espace exige un backend qui porte le hub**, et c'est le cas :
`0641601` contient `PATCH /etudes-en-france/interest`, `catalogPublished`, la
recherche par `searchText`, la migration `20260930120000_eef_search_text_and_acronym`
(la dernière du dépôt, rien depuis), `eefCatalog`, `platformUrl`,
`suspendedSources` et `GET /etudes-en-france/cities`. `eef-space-on` refuse
d'écrire tant qu'aucune formation n'est publiée **ou** que le conteneur ne porte
pas ce backend (`eef-catalog-attribution.js`), et le workflow vérifie après coup
que `/config/app` sert `eefCatalog` et `platformUrl`. L'ordre —
déploiement backend `scope=full`, `eef-import`, publication du pilote, **puis**
`eef-space-on` — est dans `docs/runbook-ouverture-espace-reel.md`.

**Conditions techniques remplies au 03/10/2026** : backend `0641601` ; catalogue
publié par délégation (`eef-publish` : 10 029 formations, 473 en attente,
`docs/eef-publication-deleguee.md`) ; corrections de procédure appliquées le
02/10 (`eef-reconcile`, 3 834 formations réalignées, `docs/ouverture-espace-eef.md`
§1) ; questions juridiques tranchées le 03/10. Ce qui retient l'ouverture n'est
plus technique : **une 55 en vente et adoptée**, car aucune build des boutiques ne
contient le hub.

### Ce qui reste à faire par un humain avant la soumission

Voir `docs/mise-a-jour-56-checklist.md` (l'ordre exact, avec les commandes ; son étape 0
liste les décisions à avoir prises AVANT d'archiver), `docs/release-56-store-pack.md`
(notes de version, notes de revue recomptées, décisions), `docs/device-qa-build54.md`
§A et §B, dont le §B-filtres, `docs/device-qa-build55.md` (aides, retrait, Niger, anglais)
et `docs/device-qa-build56.md` (bulle, visite, écoles privées) — QA appareil, toujours
valable : lire « 56 » là où une fiche écrit « 54 » ou « 55 » pour un numéro de version.
`docs/CONSOLE_ANSWERS.md` §0quater (déclarations de console ; lire « 56 ») et
`docs/eef-consent-v1.md` (questions juridiques).

### Ce que la 56 ajoute à la 55

**Statut au 05/10/2026 : le code et les papiers de la 56 sont fusionnés ou en voie de
l'être ; la version `2.3.0+56` est posée par la PR de préparation ; aucune archive
n'existe, aucun envoi n'a eu lieu.** La 56 est le numéro courant (ligne `56` sous
**Courant**), pas un numéro consommé : le jour où l'IPA sera téléversée, sa ligne le dira
(« téléversée le … ») ; elle ne passera sous **Consommés** que quand le numéro suivant
sera préparé, car le test refuse un numéro consommé dans `pubspec.yaml`.

**Ce que la 56 ajoute** (tout est derrière `features.eefSpace`, éteint en production ; deux
éléments ont en plus leur propre interrupteur serveur, **fermé par défaut** : clé absente,
ancien backend et repli compilé valent « faux ») :
- **Interrupteurs** `features.eefHelpBubble` et `features.eefPrivateSchools` (#319), actions
  `vps-ops` `eef-bubble-on` / `-off` et `eef-private-schools-on` / `-off`, simulation par défaut
  pour les `-on` (`docs/runbook-ouverture-espace-reel.md`).
- **Bulle verte WhatsApp** (#320) : hub et catalogue seulement, 4 sujets (5 avec les écoles privées ; 2, neutres, pour un
  compte au pays suspendu), messages statiques sans donnée personnelle, par le chemin commun
  `openWhatsAppOrToast`.
- **Feuille « écoles privées »** (#321), livrée éteinte : ligne de l'état « aucun résultat » du
  catalogue et option de la bulle ; **rien pour un compte au pays suspendu** (Niger). Elle ne
  transmet rien aux écoles ; elle n'utilise ni la liste d'intérêt ni le profil EEF
  (`docs/eef-consent-v1.md`, note de la 56).
- **Visite guidée** du hub (#322, **fusionnée avant la soumission**) : 3 ou 4 cartes à la première
  ouverture, rejouable par « ? », état local à l'appareil. Elle n'a pas d'interrupteur à elle.
- **Outillage** : le préflight iOS refuse désormais une clé PostHog **doublée** ou mal formée
  (`scripts/preflight-ios-archive.sh`, mode `--posthog-only` juste après `flutter build ios`) ;
  la checklist de la 56 reprend ces corrections (porte « 24 heures » du préflight, saisie de la
  clé).
- **Avertissement de suspension retiré** (#324 : hub et catalogue ; #326 : vitrine), à la
  demande du propriétaire du 05/10/2026 : plus aucun compte, Niger compris, ne voit de
  bandeau jaune ni de lien « source officielle » de suspension, nulle part. Restent : la
  détection de la suspension (`EefCalendar`, `EefHelp.isSuspended()`), les aides et la
  bulle en variante neutre, et l'absence de date d'ouverture pour un pays suspendu. La 55
  montrait encore l'avertissement.

**Rien de visible hors drapeau**, donc rien dans les notes de version de la boutique : le
relecteur Apple voit la vitrine, comme avec la 55. **Aucune dépendance** : entre la
production (`0641601`) et la tête de la branche de préparation, `pubspec.lock`, les
manifestes iOS et Android et `android/app/build.gradle` n'ont pas bougé ; `pubspec.yaml` ne
change que par sa ligne `version:` (`2.3.0+54` → `2.3.0+56`) ; `ios/Podfile.lock` par la seule
somme de contrôle du `Podfile` (Xcode 27) — à re-prouver sur le SHA final
(`docs/release-56-store-pack.md` §6, `docs/mise-a-jour-56-checklist.md` étape 0).

### Couplage backend de la 56 : `tolerates-old`

La 56 ne **dépend** d'aucun backend récent : les deux clés neuves (`eefHelpBubble`,
`eefPrivateSchools`, servies depuis #319) sont lues « faux » quand elles manquent — clé
absente, ancien backend et repli compilé valent « fermé ». Le backend de production est
**toujours `0641601`**, sans ces clés : la 56 s'y comporte comme la 55 (vitrine), ce qui
est exactement l'état A. C'est la définition de `tolerates-old`, mode du préflight de
release.

Ce qui change par rapport à la 55 : `backend/` et `docker-compose.yml` ne sont plus
identiques à `0641601`. #319 (`b220050`) a touché **quatre fichiers** — le contrôleur de
configuration (`app-config.controller.ts`) et son spec, le spec des opérations
(`eef-space.ops.spec.ts`) et `docker-compose.yml` (les variables des deux
interrupteurs). Le contrôle « `git diff --stat 0641601 <RELEASE> -- backend admin
docker-compose.yml` ne doit rien afficher » est donc **remplacé** : il doit lister
exactement ces quatre fichiers, et
`git log --oneline 0641601..<RELEASE> -- backend admin docker-compose.yml` ne doit montrer
**que** `b220050`. Un autre commit signifie que le backend de la release est plus en
avance que prévu : ne pas continuer sans arbitrer (`docs/mise-a-jour-56-checklist.md`,
étape 1).

**Déployer le backend au SHA de la 56 n'est nécessaire QUE pour ALLUMER** la bulle ou les
écoles privées (`eef-bubble-on`, `eef-private-schools-on` refusent d'écrire sur un backend
qui ne porte pas leurs clés). **Ne pas le faire avant le préflight de la 56** : le
préflight exige que la production soit un **ancêtre** de `<RELEASE>`, jamais en avance
(un run du 02/10 a échoué ainsi) ; jamais un déploiement à un commit postérieur à
`<RELEASE>`. Une fois la 56 en vente et adoptée, déployer (`deploy.yml`, `scope=full`)
puis allumer dans l'ordre du runbook.

**Décisions encore ouvertes** (`docs/release-56-store-pack.md` §7) : phrase sur les frais ou
son repli, qui répond au +33768674292, XC-06 et D5. La première porte sur un **texte
compilé** : à trancher **avant l'archive**. Niger sans mention d'école privée est
**retenu** ; « 55 ou 56 » et la version marketing sont **tranchées** (la 56 seule, 2.3.0) ;
la rémunération par des écoles privées est **tranchée le 06/10/2026** : la phrase est retirée
de l'app.

**Papiers** : `docs/mise-a-jour-56-checklist.md` (l'ordre des opérations),
`docs/release-56-store-pack.md` (notes de revue recomptées, réponses de console,
décisions), `docs/device-qa-build56.md` (recette appareil, jamais jouée),
`docs/CONSOLE_ANSWERS.md` (ligne WhatsApp / Meta). Les papiers de la 55 portent un
bandeau « REMPLACÉE par la 56 ».

### Chantier L (16/10/2026) — préparation de la build 57 : conformité et pack de release, numéro NON posé

**État : papiers prêts, numéro non posé.** `pubspec.yaml` porte toujours `2.3.0+56` et la ligne
courante reste celle de la 56 (le test `test/release/build_number_test.dart` les lie). La 57 est
une **release unique** : chantiers B, C, D, F, G, H, I, K (#353 à #361), notifications par FCM
(#351), correctifs #349 et #350. Rien n'est déployé, archivé ni soumis par ce chantier.

**Constat du 16/10/2026 (mesures en lecture seule), que ce registre ne disait pas :**
- la **2.3.0 est en vente** : App Store (fiche FR, mise en ligne le 07/10/2026) et Google Play.
  La ligne « Version marketing EN VENTE » ci-dessus (2.2.0) et la ligne `56` (« non téléversée »)
  n'ont pas suivi l'envoi. À VALIDER (propriétaire) : que la build en vente est la 56, sa date de
  téléversement et son SHA archivé — à reporter dans la PR de préparation de la 57, pas avant
  (le test exige alors une version de `pubspec.yaml` strictement supérieure à 2.3.0) ;
- backend de production `28ac82dab0c2` (démarré le 12/10/2026), **sans** #351 ni les chantiers B à
  K ; `features.eefSpace=true` (l'espace « Études en France » est ouvert), `eefHelpBubble` et
  `eefPrivateSchools` à `false`, aucune clé des chantiers G, K, D, I.

**Ce que la 57 impose :**
- **version marketing `2.3.1`** (ITMS-90062 : 2.3.0 est approuvée ; et `isVersionBelow` ignore le
  numéro de build, `lib/app/core/utils/version_utils.dart`) — décidée par le propriétaire le 16/10/2026 ;
- **couplage `requires-new`** : la 57 n'embarque plus le SDK OneSignal ; sans le backend de #351 et
  `FCM_SERVICE_ACCOUNT_JSON`, elle ne reçoit aucune notification. Ordre : serveur (six migrations
  additives), puis admin, puis app ; préflight `backend_coupling=requires-new` ;
- tous les drapeaux nouveaux à leur défaut au lancement : interrupteurs d'urgence des chantiers G
  et K **ouverts**, `scholarshipMatch` et `onboardingV2` **fermés**,
  `KPB_SCHOLARSHIP_OPENING_MODE=legacy`.

**Papiers** : `docs/release-57-store-pack.md` (notes de version, « Notes for Review » recomptées,
Data Safety et App Privacy, tableau des drapeaux, paliers Play 10 % → 50 % → 100 % et publication
progressive iOS, `KPB_RECOMMENDED_APP_VERSION` / `KPB_MIN_APP_VERSION`, bascule
`legacy` → `outbox_alerts` → `outbox_followers`), `docs/mise-a-jour-57-checklist.md` (l'ordre des
opérations, dont la PR de préparation de la version), `docs/device-qa-build57.md` (recette appareil,
jamais jouée ; ferme A9 de la fiche 54), `docs/data-inventory.md` (§2 et §5 : test « Mes 10
bourses », suivis, notifications, transmission, conservation, export). Politique de
confidentialité mise à jour (in-app FR + EN, et `web/public/confidentialite.html`). Tests :
`test/release/store_pack_57_test.dart`, `test/release/mise_a_jour_57_checklist_test.dart`.

**Reste au propriétaire** : la validation juridique de la collecte de la nationalité (le drapeau
`scholarshipMatch` reste fermé d'ici là), la relecture des textes de la politique AVANT l'archive
(texte compilé), la PR de préparation (version, préflights, registre), les seuils
des paliers, XC-06 et D5.

### Ce que 52 embarque

- **Liste d'attente Karatou Premium (PR #258).** Point 8 de la revue du build
  49 : un bouton d'inscription gratuite, pour que l'équipe puisse compter la
  demande avant de construire le Pass. Table DÉDIÉE `PremiumWaitlistEntry`, et
  non un drapeau de plus sur `EefInterest` — ce dernier est un registre de
  consentement, et y cocher un intérêt Premium aurait fabriqué un consentement
  « Études en France » que l'étudiant n'a jamais donné.

  L'écran présente enfin le Pass pour ce qu'il est : une candidature accompagnée
  de bout en bout. Toujours **aucun prix, aucun tunnel d'achat, aucun verbe
  d'abonnement** (App Store 3.1.1) — et cette règle est désormais exécutable,
  un test balayant toutes les clés `premium_pitch_*` et `premium_waitlist_*`.

- **dSYM envoyés à Crashlytics (PR #257).** Le projet Xcode n'avait aucune phase
  `upload-symbols` : les plantages de la 50 sont arrivés en adresses mémoire
  brutes, inexploitables. La phase ne tourne QUE pendant un archivage
  (`ACTION=install`), et l'absence de dSYM y est fatale plutôt qu'avertie.

- **Garde PostHog côté Android (PR #257).** Le job AAB substituait le secret
  sans jamais le regarder — le défaut exact qui a envoyé la 50 iOS sans
  télémétrie. Mêmes trois règles des deux côtés désormais, appliquées AVANT la
  construction.

**Couplage backend : `requires-new`.** Deux raisons, et la première suffit :

1. La liste d'attente appelle `/premium/waitlist`, absente d'un backend
   antérieur — le bouton tomberait dans le vide.
2. `consentVersion` est validé contre une **liste fermée** côté serveur
   (`premium-waitlist-consent.ts`). Une app qui enverrait une version que le
   backend ne connaît pas se verrait refuser l'inscription en 400.

**Ce couplage est DÉJÀ satisfait** : le backend a été déployé le 03/09/2026 à
02h15 UTC au SHA `e9576c0831ab`, migration `20260903090000_premium_waitlist`
appliquée (« All migrations have been successfully applied »), et
`GET /premium/waitlist` est passé de 404 à 401 vu de l'extérieur.

<!-- Historique de la 50, conservé : -->
- ~~`50`~~ — revue du build 49 : jauge de progression, boîte à outils limitée à
  l'accueil, catalogue hors-ligne repassé en français, checklist de profil
  réparée, champs orphelins rouverts à l'édition (dont le budget), mesure
  d'audience active par défaut + clause CGU, bourses « à venir ».

  **Couplage backend : `requires-new`, et ce n'est PAS le cas de la 49.**
  La 49 était `tolerates-old` : contre un backend en retard, ses drapeaux
  retombaient sur `false` et ses entrées se masquaient. La 50 n'a pas cette
  propriété, pour une raison précise et vérifiable : `main.ts:68-71` monte la
  `ValidationPipe` avec `forbidNonWhitelisted: true`, et le profil envoie
  désormais `bacSeries` à chaque `PATCH /profiles/me`. Contre un backend sans
  ce champ au DTO, la requête ne perd pas un champ — elle est **rejetée en
  400**, donc TOUTE sauvegarde de profil échoue.

  Le backend doit donc être déployé AVANT la distribution, migration
  `20260829140000_profile_bac_series` comprise (additive : une colonne
  nullable, sans défaut ni reprise).

### Ce que 49 embarque en plus

- **Notice IA : OpenRouter nommé (PR #239, 26/08/2026).** Le consentement
  KPB Intelligence et la divulgation des outils (FR/EN) nomment désormais
  OpenRouter aux côtés de Groq, en cohérence avec la bascule du provider LLM
  (deepseek-v4-flash, routage épinglé zdr + data_collection=deny). Le backend
  et la politique web sont déjà en prod avec ce texte ; la 49 aligne l'app.
  Le numéro de build n'est PAS incrémenté : ce lot monte dans la 49, comme
  le lot EEF ci-dessous.

- **Espace « Études en France » — Phase 0.** La vitrine ET la coquille de
  l'espace, toutes deux **éteintes à la compilation**. Rien n'apparaît tant que
  `/config/app` ne les allume pas.

  Le numéro de build n'est PAS incrémenté : 49 est encore le courant et n'a pas
  été livrée. Ce lot monte dedans.

  Bascule côté serveur — **valeurs arrêtées** (campagne 2027-2028, voir
  `docs/eef-campaign-calendar-2027-2028-research.md`) :

  ```bash
  KPB_EEF_TEASER_ENABLED=true
  KPB_EEF_CAMPAIGN_OPENS_AT=2026-10-01
  KPB_EEF_SUSPENDED_COUNTRIES=Niger,NE
  # KPB_EEF_CAMPAIGN_CLOSES_AT — DÉLIBÉRÉMENT NON POSÉE (voir plus bas)
  ```

  **Pourquoi pas de clôture globale.** Les clôtures divergent : Maroc
  15 novembre 2026 (confirmé), Rwanda et Maurice 15 décembre (estimé), Algérie
  « information à venir », 91 couples pays × procédure non publiés. Une clôture
  globale ferait manquer la campagne à un étudiant marocain qui croirait avoir
  jusqu'en décembre. L'app affiche donc « À partir du 1er octobre 2026 » plus
  une ligne disant que les clôtures varient selon le pays. Les clôtures par
  pays arrivent avec le catalogue de la Phase 1, déjà structuré par pays.

  **Pourquoi le Niger est dans la liste des suspendus.** La page officielle de
  l'ambassade indique que la dénonciation de la convention du centre qui
  hébergeait Campus France rend impossible le traitement des dossiers
  d'étudiants nigériens. L'ouverture nationale de la plateforme reste exacte et
  sans effet pour eux ; la vitrine remplace donc la date par une mise en garde
  et un relais conseiller. `Niger` et `NE` sont tous deux listés parce que
  `countryOfResidence` est un nom saisi au clavier, pas un code. Une
  réouverture se traite en retirant la valeur — pas en passant au store.

  À l'ouverture réelle de l'espace, plus tard — **ne plus poser
  `KPB_EEF_ENABLED`** (corrigé le 30/09/2026, voir l'entrée « Build 54 —
  backend ») :

  ```bash
  KPB_EEF_SPACE_ENABLED=true         # action vps-ops « eef-space-on »
  ```

  `KPB_EEF_ENABLED` désactive `eefTeaser` côté serveur, et les builds 49 à 53
  le lisent : le poser leur retire leur vitrine et leur montre une coquille
  vide. `features.eefSpace` est une clé NOUVELLE, que seule la build 54 écoute ;
  elle ne touche ni à `eef` ni à `eefTeaser`.

  Sans variable posée, l'app **n'annonce aucune date** : une date mal
  configurée vaut `null`, jamais un repli. Retour arrière : remettre la variable
  à `false`, sans passer par les stores.

  Vérification après bascule : `GET /config/app` doit répondre
  `features.eefTeaser: true`. La liste des intéressés se lit sur
  `GET /admin/etudes-en-france/interest` (résumé, liste, `export.csv`).

  **Les variables atteignent bien le conteneur, désormais.** Elles étaient
  documentées ici et dans le runbook, et absentes du bloc `environment:` de
  `docker-compose.yml` : le `.env` ne sert qu'à l'interpolation, donc les poser
  n'avait AUCUN effet. Corrigé, et `test/release/config_env_relay_test.dart`
  interdit la répétition — il compare les variables lues par `/config/app` au
  relais compose et à `.env.example`.

  **Où se pose réellement cette bascule** : `docs/cutover-build49.md`, étape
  9 bis. Ce n'est pas une redondance — ce runbook est ce qu'on suit ligne à
  ligne le soir de la livraison, et il dit AUSSI pourquoi ces variables ne se
  posent qu'après le déploiement couplé, et non avant.

  **Une migration s'applique désormais.** Ce lot ajoute
  `backend/prisma/migrations/20260821120000_eef_interest`, appliquée par le
  `prisma migrate deploy` du déploiement `scope=full`. Elle est additive — une
  table neuve, trois index, une clé étrangère — donc sans effet sur les données
  en place. Le runbook affirmait qu'il n'y avait rien à migrer : c'était vrai
  quand il a été écrit, et l'étape 1 a été corrigée.

  **Le sens du couplage ne change pas.** La 49 reste `tolerates-old` au
  préflight : contre l'ancien backend, les clés `eefTeaser` / `eef` /
  `eefCampaign` sont absentes, les drapeaux retombent sur `false`, et les quatre
  points d'entrée se masquent — même mécanique que le masquage des outils IA. Le
  déploiement couplé reste dû, maintenant pour deux raisons : `AiConsentGuard`
  et la table `EefInterest`.

## Déploiements backend sans build

Un déploiement du backend seul ne consomme aucun numéro de build : il n'a donc
pas de ligne sous **Consommés**, ni sous le numéro courant. Il est consigné ici
pour que l'ordre de livraison (`docs/DEPLOYMENT.md`, « le backend d'abord, le
mobile ensuite ») reste lisible.

### 29/09/2026 — frontière de l'import « Études en France » et auteur des avis conseillers

**État : prêt, PAS déployé.** Sur la branche `claude/campus-france-space-98orw9`,
non fusionné, sans PR : la CI ne se déclenche que sur `main` et sur les PR vers
`main`, elle n'a donc PAS encore tourné sur ces commits (le dernier run de la
branche date du 22/08/2026). La production tourne au SHA `113cc55a39cf` (démarrée le
22/09/2026) ; trois commits de `main` n'y sont pas non plus (#285, #286 —
étiquettes OneSignal pour la segmentation —, #291 — l'email manquant bloquait
toute la synchro du profil).

**Couplage : `tolerates-old` côté mobile.** Aucune route nouvelle, aucun champ
que les builds installées (49 à 53) devraient envoyer. **Côté admin, le
déploiement est couplé** : voir la file `/verification` ci-dessous.

- `GET /catalog/institutions`, `GET /catalog/programs` et `/matches/*` cessent de
  servir des lignes de l'import « Études en France ». **Aucune n'est publiée
  aujourd'hui : rien ne change à l'écran.** La garde est posée AVANT la première
  publication, ce qui est tout son sens (voir `docs/eef-catalog-pipeline.md`,
  § 2ter).
- `GET /etudes-en-france/search` et `/shortlist` ne servent plus QUE les lignes de
  l'import (même définition que l'exclusion ci-dessus) : une formation d'école
  partenaire que l'exploitation qualifierait d'une procédure resterait dans le
  catalogue général, et n'entrerait pas dans l'espace. Aucune ligne n'est publiée
  aujourd'hui : rien ne change à l'écran.
- `POST /counsellors/:id/reviews` : l'auteur vient du jeton. Le corps
  qu'envoient les builds 49 à 53 (`rating`, `body`, `reviewerName`, `caseId`) est
  **accepté tel quel** — `reviewerName` est déclaré et ignoré, sans quoi la
  validation globale (`forbidNonWhitelisted`) répondrait 400 à tous leurs avis.
  Un texte trop long est **tronqué à 1 000 caractères** (sans couper un emoji en
  deux) et non refusé : le champ de saisie de l'app n'a aucune limite, un 400 lui
  ferait perdre le texte. Ce qui change de leur point de vue : un avis sur un
  dossier qui n'est pas terminé (409), qui n'est pas le leur (404), qu'un autre
  conseiller a traité (403) ou qui est déjà noté (409) est refusé, alors qu'il
  était enregistré. L'app ne propose de noter qu'un dossier terminé, traité par
  son conseiller, une fois : ces refus ne correspondent à aucun parcours de
  l'app. « Un avis par dossier » est une garde au mieux-effort — aucune contrainte
  d'unicité en base.
- `GET /counsellors/:id` ne sert plus la clé de rattachement (`reviewerUserId`,
  `caseId`) des avis publiés, et ne sert que ceux dont l'auteur a un reçu
  `public_testimonial` actif — la porte de `/impact/reviews`. Aucun client de
  l'app n'appelle cette fiche.
- `PATCH /cases/:id` **côté étudiant est supprimé** (404). Il laissait le
  propriétaire fixer `status`, `assignedAdvisorName` et le texte de la prochaine
  étape de son propre dossier — donc se déclarer « terminé » et ouvrir le droit de
  noter un conseiller. Le client de l'app définissait `updateCase` sans qu'aucun
  écran ni test ne l'appelle (constaté sur l'historique disponible, qui remonte
  au 23/08/2026 : les builds antérieures ne peuvent pas être relues d'ici) ;
  l'équipe passe par `PATCH /admin/cases/:id`, inchangé. Si une build installée
  l'appelait, elle recevrait un 404.
- `GET /profiles/me/export` gagne un champ `counsellorReviews` (les avis que
  l'utilisateur a laissés) ; la suppression de compte efface ses avis, signés ou
  restés sans auteur mais posés sur l'un de ses dossiers. Additif.
- `GET /admin/catalog/verification-due` : les lignes de l'import « Études en
  France » **encore inactives** en sortent, ainsi que du compteur du tableau de
  bord et de l'alerte de 07 h — elles n'ont jamais été publiées, ce ne sont pas
  des fiches à REvérifier. Si l'import a été appliqué en production (le plan de
  livraison en mesure 10 247 formations, inactives), le code actuel les y liste
  comme « jamais vérifiées » : la page et l'alerte s'allègent d'autant le jour du
  déploiement. `total` et `truncated` s'ajoutent ; la file est plafonnée à
  500 éléments **sans qu'aucune catégorie soit affamée** (chacune de celles qui
  ont des lignes reçoit au moins 500 ÷ leur nombre de places — 125 avec les
  quatre) et triée dans un ordre total (jamais-vérifiés et plus périssables
  d'abord, puis échéance la plus ancienne). Les quatre catégories (pays,
  établissements, formations, bourses) partagent désormais UNE définition avec le
  compteur du tableau de bord et l'alerte de 07 h.

  **L'admin doit partir avec l'API (`scope=full`).** Un admin qui ne serait pas
  redéployé ignore `total` et `truncated` : il afficherait « 500 ouvertes »
  sans le moindre avertissement, alors qu'il en reste davantage. C'est le seul
  couplage de ce lot ; la page `/verification` de l'admin fourni ici affiche le
  nombre de lignes montrées sur le total réel, et invite à recharger une fois le
  lot validé.

- **Nouvelles routes admin de publication de l'import** (`admin/etudes-en-france/
  publication/*`, `admin` et `super_admin` seulement) : publier ou retirer un
  établissement et ses formations, simulation par défaut, relecteur = la session.
  Aucun client de l'app ne les appelle ; aucune ligne n'est publiée tant que
  personne ne s'en sert. Détail : `docs/api-contracts.md`. **Couplage admin :** le
  nouvel écran « Publication EEF » de l'admin appelle ces routes, donc le backend
  part AVANT l'admin (un admin plus ancien n'a simplement pas l'écran). L'écran a
  été exercé dans un navigateur contre un faux serveur qui réutilise le vrai plan
  du backend (parcours complet, refus, retrait), pas contre une base de production.
- **Publication de l'import : trois failles fermées après la revue automatique de la
  PR.** (1) `PATCH`/`POST /admin/catalog/…` ne peuvent plus ACTIVER une ligne de
  l'import (409) : la publication passe uniquement par « Publication EEF » ; les
  autres usages de ces routes sont inchangés. (2) Activer un établissement
  revalide ses formations déjà actives ; l'une invalide refuse l'établissement
  (`institution_has_invalid_active_program`, `plan.programs.activeInvalid`) — un
  motif de refus de plus, que l'écran affiche. (3) La transaction d'écriture est en
  `RepeatableRead` : une modification concurrente annule la publication (409) au
  lieu d'être publiée et signée. **Couplage admin :** un admin plus ancien
  ne connaît pas le nouveau motif et l'afficherait en clé brute ; le backend part
  AVANT l'admin, comme pour le reste du lot.
- **Documentation des sources corrigée, deux dossiers de décision ouverts.** La SOP
  et le pipeline affirmaient « chaque ligne porte sa fiche officielle » : c'est faux
  pour 4 212 lignes sur 10 502 (portail Mon Master, jeu de données ouvert) —
  `docs/eef-catalog-pipeline.md` § 2.8. L'écran de publication compte ces lignes
  avant de demander la signature (`programs.genericSource`). À faire trancher :
  `docs/eef-dossier-relecture-procedures.md` (partage DAP / Études en France) et
  `docs/eef-dossier-juridique-logos.md`.
- **Logos des établissements : 320 px → 330 px.** Wikimedia refuse les largeurs
  hors liste standard (HTTP 400) : les 26 logos SVG de l'import ne s'affichaient
  pas. Le serveur sert désormais 330 px, y compris pour une ligne importée avec
  l'ancien 320 px. Les builds installées affichent l'URL du serveur telle quelle :
  elles en profitent sans mise à jour ; le client Flutter est aligné pour la
  prochaine build. Détail : `docs/eef-catalog-pipeline.md` § 2.6bis.
- **Domaines de l'import « Études en France » réalignés sur l'orientation.**
  Dix domaines sur douze de l'import portaient le nom d'un autre (`d03` était
  « Finance », `d05` « Ingénierie »…). Les 10 502 formations versionnées sont
  réécrites (3 134 changent) et la recherche, le validateur et le classement de la
  shortlist ne parlent plus qu'une liste. Aucun effet à l'écran aujourd'hui
  (rien n'est publié). **Les lignes déjà importées en production gardent
  l'ancien domaine** : avant toute publication, `eef-purge-pending` puis
  `eef-import` (VPS ops, dry-run d'abord), après avoir lu `db-info` section 10.
  Détail et choix à confirmer : `docs/eef-catalog-pipeline.md` § 2.7.

**Une migration s'applique :** `20260929120000_counsellor_review_author_backfill`.
Des DONNÉES seulement — un `UPDATE` qui rattache les avis déjà enregistrés sans
auteur au propriétaire du dossier noté — sans changement de schéma,
idempotente, sur une table de quelques lignes. Appliquée par le
`prisma migrate deploy` du déploiement `scope=full`. L'ordre entre la migration
et le remplacement des conteneurs est sans conséquence, avec une réserve : entre
les deux — et après tout retour à l'ancien code — l'ancien service peut encore
créer un avis sans auteur ; rejouer le SQL de la migration (idempotent) le
rattache. Ce n'est pas un trou d'effacement : la suppression de compte et l'export
retrouvent aussi les avis sans auteur par le dossier de l'utilisateur.

**Avis orphelins — une décision à prendre, avec son chiffre.** Un avis dont le
dossier n'existe plus (compte déjà supprimé) ou n'a jamais été renseigné n'a plus
d'auteur retrouvable ; il peut porter un nom civil. Le compter avant de décider
(anonymiser `reviewerName`, ou supprimer) :

```sql
SELECT count(*) AS orphelins,
       count(*) FILTER (WHERE r."isPublished") AS dont_publies
FROM "CounsellorReview" AS r
WHERE r."reviewerUserId" IS NULL
  AND NOT EXISTS (SELECT 1 FROM "Case" AS c WHERE c."id" = r."caseId");
```

Validée à la main sur PostgreSQL 16 — les 64 migrations sur base neuve (puis
« No pending migrations to apply » au second passage), et un `migrate deploy` sur
une base peuplée de 7 avis (2 rattachés, 4 laissés à `NULL` faute de
correspondance, 1 déjà attribué et non écrasé), rejeu à `UPDATE 0`, et trois
mutants de la clause `WHERE` tous détectés — parce que la CI ne l'exécute pas
tant que son pas unitaire est rouge (voir ci-dessous). La CI, elle, tourne sur
PostgreSQL 15 et Node 20 : ces deux versions n'ont pas pu être exercées ici.

**Catalogue de bourses relu le 29/09/2026 — blocage levé par #292, version
1.4.0.** Le validateur refuse toute source contrôlée il y a plus de 30 jours : les
34 fiches, relues le 24/08, étaient périmées depuis le 23/09 et un seul test
(`scholarship-catalog.validator.spec.ts › reste importable à la date du jour`)
tenait `Backend CI` rouge sur `main`, donc bloquait `deploy.yml`, qui exige un run
vert sur le SHA exact. **#292 l'a levé le 29/09** (Backend CI vert sur `51a620a`) :
34 fiches relues, dont UP Mastercard relue au navigateur par l'équipe — le site
bloque les robots (Cloudflare), qu'on ne contourne pas.

Cette branche portait une **seconde relecture indépendante** des mêmes fiches
(`docs/catalog-verification-2026-09-29.md`, rapports bruts dans
`docs/evidence/catalog-2026-09-29/`). Comparée champ par champ à #292 avant la
fusion, elle y ajoute **58 champs sur 15 fiches**, dont deux qui changent ce que
l'étudiant lit sur le financement : en Licence la bourse Türkiye–IsDB est un
**prêt** à rembourser, et la demande d'aide ALU est un **dossier distinct**. Le
catalogue passe en 1.4.0. Le détail, et ce qui a été écarté, est dans le journal.

- **Trois clôtures proches** : UP **le 30/09** (le cycle doit passer en `closed`
  aujourd'hui), Chevening et Knight-Hennessy le 06/10. `catalog-freshness.yml`
  (issue #270) les signale ; `catalog:publish` saute les fiches périmées.
- **La production ne bénéficie pas de ces corrections toute seule.** Les lignes de
  bourses en base datent de l'import d'août (catalogue 1.3.0 mesuré le 31/08) :
  après le déploiement, lancer `publish-catalog` (VPS ops) — `import` →
  `reconcile` → `switch`, dans cet ordre. `import` seul ne corrige rien.
- **À revérifier** : la source « éligibilité » d'IsDB (`/scholarshipsprograms`) ne
  contient pas IsDB dans son HTML statique ; les écarts entre les formulaires PDF
  2027 d'UP et ses pages HTML (facultés, Master de première année seulement,
  moyenne minimale de 70 %).

### 30/09/2026 — backend de la build 54 : ouverture de l'espace, recherche, profil

**État : prêt, PAS déployé.** Sur la branche `claude/campus-france-space-98orw9`,
au-dessus de la fusion de la PR #293. Aucun client n'appelle encore ce qui est
nouveau ; rien n'est publié, `KPB_EEF_ENABLED` reste faux.

**Couplage : `tolerates-old` côté mobile.** Que des ajouts : une clé dans
`/config/app`, des champs dans les items de la recherche et de la shortlist, une
clé dans la réponse de la recherche, une route `PATCH`. Les builds 49 à 53 les
ignorent et continuent de tout lire. **Une migration** :
`20260930120000_eef_search_text_and_acronym` — deux colonnes nulles, aucune
réécriture de table, aucun index, aucune extension.

- **`features.eefSpace` : l'ouverture de l'espace pour la seule build 54.**
  `KPB_EEF_ENABLED` ne peut plus être le commutateur : les builds 49 à 53 le
  lisent, et pour elles il retire la vitrine et montre une coquille vide. La
  nouvelle clé (`KPB_EEF_SPACE_ENABLED`) n'est lue que par la 54, et ne touche ni
  à `eef` ni à `eefTeaser`. `eef` l'allume aussi. Relayée dans
  `docker-compose.yml`, documentée dans `.env.example`, gardée par
  `config_env_relay_test` et `delivery-gate.sh`.
- **Trois actions vps-ops.** `eef-space-on` (simulation par défaut ; refuse tant
  qu'aucune formation de l'import n'est publiée, refuse si `KPB_EEF_ENABLED=true`
  est posé ; le workflow PROUVE ensuite `features.eefSpace` depuis l'extérieur et
  que `eef` est resté faux), `eef-space-off` (le retour arrière, sans simulation) et
  `eef-campaign-set` (ouverture, clôture, pays suspendus — valeurs écrites dans le
  script, donc relues en PR, sans dépendre de `eef-teaser-on`). Exercées contre un
  faux `docker` (10 scénarios) et la requête de décompte contre un vrai Postgres.
- **Recherche libre : sans accents, par université, par niveau.** « genie » trouve
  508 formations au lieu d'1 (mesuré sur les 10 502 lignes : identique à « génie »),
  « sorbonne » 605, « UPEC » 215, « master droit rennes » 10. Mesuré sur la même
  base : le coût d'une requête ne change pas (~25 ms le `count`). Jamais moins de
  résultats qu'avant : une ligne sans texte normalisé retombe sur la comparaison
  brute. Détail : `docs/api-contracts.md`.
- **Chaque item nomme son établissement** (recherche et shortlist) et porte la
  procédure, le cycle, la sélectivité, la ville, le code de formation — de quoi
  afficher une carte utilisable. Le logo est servi avec sa licence.
- **`catalogPublished`** dans la réponse de la recherche : « rien n'est publié »
  se distingue enfin de « ta recherche est trop étroite ».
- **`PATCH /etudes-en-france/interest`** : modifier ses niveaux et ses domaines
  sans réécrire le consentement commercial ni effacer l'intérêt Premium. Sans
  déclaration préalable : 404, jamais une création.

**Après le déploiement, avant d'ouvrir quoi que ce soit :**

1. `eef-import` (simulation, puis application) : il comble maintenant
   `searchText` et `acronym` sur les lignes déjà en base (`eef:backfill:search`,
   rejouable : comble les vides et répare les textes périmés, par
   comparaison-échange, sans jamais écraser une modification concurrente).
   10 502 lignes en ~7 s sur une base de test. Renommer une formation dans l'admin
   recalcule son texte cherchable.
2. `db-info` section 11 : `sans_texte_cherchable` doit valoir 0. Tant qu'il ne
   l'est pas, « genie » ne trouve pas « Génie civil » sur ces lignes.
3. L'ouverture de l'espace réel : `eef-space-on` (simulation d'abord), jamais
   `KPB_EEF_ENABLED`.

**Ce qui n'est pas fait ici, et relève de la build 54 (section F)** : lire ces
champs côté Flutter, afficher l'établissement sur la carte, l'état vide « le
catalogue arrive » (`catalogPublished`), l'appel au `PATCH`, et lire `eefSpace`
dans `RemoteFeatureFlags` / `EefEntry`.

### 03/10/2026 — backend `0641601` : filtres du catalogue, limiteur unique

**État : EN PRODUCTION depuis le 03/10/2026 à 17 h 06 UTC.** Aucune migration
nouvelle : la dernière du dépôt reste `20260930120000_eef_search_text_and_acronym`.

**Couplage : `tolerates-old` côté mobile.** Les builds 49 à 53 n'appellent rien de
ce qui suit.

- **`GET /etudes-en-france/cities`** (#314) : la liste complète des villes du
  catalogue publié (la facette `campusCity` de `/search` est plafonnée à 20 valeurs,
  qui ne couvrent que 4 201 formations sur 10 029). Mêmes règles de publication et de
  filtres que `/search` ; `campusCity`, `cursor` et `limit` ignorés. Route publique,
  en lecture seule. Contrat : `docs/api-contracts.md`.
- **Un seul limiteur de débit** (#313). Avec `@nestjs/throttler` 6.x, le limiteur
  `auth` (10 requêtes par minute) déclaré à côté de `global` s'appliquait à TOUTES
  les routes : `GET /config/app` et la recherche publique recevaient un 429 à la
  11e requête par minute et par IP (constaté en production, en-tête
  `x-ratelimit-limit-auth: 10`). Il ne reste que `global` — 60 par minute et par IP
  et par route en production, 600 ailleurs — et la connexion admin garde 10 par
  minute par surcharge nommée.
- **Shortlist** (#307) : ne recommande que la procédure de l'espace de l'étudiant, et
  le post-bac n'a plus d'étage « sécurité ». L'app, à `0641601`, ne l'appelle pas.

### 15/10/2026 — chantier D « Mes 10 bourses » : backend + admin, drapeau FERMÉ

**État : prêt, PAS déployé.** Branche locale `d/integrated` (D1 schéma et moteur, D2 API
élève, D3 catalogue 1.5.0, D4 admin), non fusionnée, sans PR. **Ne se déploie pas avant le
préflight de la 56** (même règle que ci-dessus : la production reste au SHA relevé par la
checklist de la 56 tant que celle-ci n'est pas archivée).

**Couplage : `tolerates-old` côté mobile — aucun effet pour les builds en store.** Aucune
build (49 à 56) n'appelle `/scholarships/match/*` ni `POST /me/scholarship-alerts` ; aucun
champ requis n'est ajouté à un corps existant (`POST /cases` gagne un `scholarshipId`
FACULTATIF, gardé seulement si la fiche existe) ; `GET /profiles/me`, `/config/app` et les
dossiers gagnent des clés que les builds ignorent. Le seul effet visible sans drapeau : le
catalogue lit `eligibleLevels` quand il est rempli (une cible Licence reçoit le bonus de
niveau sur les fiches reprises des tags).

**Ordre de déploiement :**

1. **Backend d'abord.** Le workflow « Deploy backend (VPS) » remplace `api` et `admin`
   ensemble (`docs/DEPLOYMENT.md`) : c'est sans risque ici, puisque l'admin tolère un
   backend plus ancien (point 3) ; en déploiement manuel, `api` d'abord, santé vérifiée,
   puis `admin`. Le backend porte **une migration, additive** : `20261020120000_scholarship_match_v1` — deux types enum, onze
   colonnes nulles sur `UserProfile`, cinq colonnes avec défaut sur `Scholarship`, une
   colonne nulle + index + clé étrangère `SET NULL` sur `Case`, la table
   `ScholarshipMatchRun` (cascade à la suppression du compte) ; puis la reprise des niveaux
   des seules fiches `catalog:%` SANS tampon (une reprise non relue n'exclut personne).
   Rien n'est supprimé ni réécrit ; `lock_timeout` de 5 s.
2. **Drapeau `KPB_SCHOLARSHIP_MATCH_ENABLED` absent ou `false`** dans le `.env` de
   production (défaut `false` dans `docker-compose.yml`, gardé par
   `config_env_relay_test`). Vérifier depuis l'extérieur : `GET /api/config/app` →
   `features.scholarshipMatch: false`, et `GET /api/scholarships/match/state` → `404
   {disabled: true}` (avant toute authentification).
3. **Admin ensuite** (ou dans le même passage du workflow). L'admin tolère un backend plus ancien : le
   compteur de couverture se masque s'il ne répond pas, un dossier sans résumé de bourse
   affiche l'identifiant seul. À l'inverse, un admin plus ancien ignore les clés nouvelles.
4. `catalog:reconcile --dry-run` puis `--apply` : porte le catalogue 1.5.0 (niveau
   `doctorate` pour Gates Cambridge, critères en BROUILLON). Un brouillon du dépôt ne
   remplace jamais un bloc d'éligibilité tamponné en base (`keptFromDatabase`).

**Retour arrière :** drapeau coupé (la carte disparaît, les routes répondent 404
`{disabled: true}`) ; le code se ramène au tag précédent sans toucher au schéma (migration
additive, aucune colonne lue par l'ancien code).

**Procédure éditoriale, avant toute ouverture du drapeau** (détail :
`docs/catalog-verification-sop.md`, « Structurer l'éligibilité des bourses ») :

1. **Relire et tamponner les 36 fiches** du catalogue 1.5.0 : chaque critère contre sa
   source officielle « eligibility », listes de pays recopiées d'abord (Taiwan ICDF, SI,
   IsDB, OCI…), puis `reviewed: { at, by }` dans une PR relue, ou le bouton « Conditions
   vérifiées » de l'admin (l'admin écrit le même bloc ; reporter ensuite la relecture dans le
   dépôt pour qu'elle survive aux versions suivantes).
2. **Porte de lancement : au moins 90 % des bourses PUBLIQUES structurées et fraîches**
   (tampon de moins de 400 jours), lue sur `GET /admin/scholarships/eligibility-coverage`
   **en production** (carte « Couverture » de `/scholarships`) — fiches créées dans l'admin
   et collectées comprises, pas seulement celles du dépôt.
3. Contrôler quelques profils réels avec « Tester un profil » (`POST
   /admin/scholarships/match-preview` : mêmes candidates que l'élève, rien n'est écrit).
4. Quand `npm run verify:catalog` affiche `36/36 reviewed and stamped`, passer
   `STRUCTURED_ELIGIBILITY_GATE` à `'error'` dans une PR dédiée.
5. Seulement alors, et après la validation juridique de la collecte de la nationalité :
   drapeau en préproduction pour la recette, puis en production avec la build qui porte
   l'écran (chantier H) — jamais avant que cette build soit en store.

### 15/10/2026 — chantier I : bourses (liste, hors ligne, fiche) et onboarding V2, drapeau FERMÉ

**État : prêt, PAS déployé.** Branche locale `i/integrated` (I1 liste / hors ligne /
raccourcis + backend `GET /scholarships`, I2 fiche, I3 onboarding V2 et code OTP), non
fusionnée, sans PR. **Ne se déploie pas avant le préflight de la 56** (même règle que les
entrées ci-dessus).

**Ce qui change côté serveur** (aucune migration) :

- **`GET /scholarships`** gagne trois paramètres **optionnels et tolérants** : `q`
  (recherche), `status` (`open`, `upcoming`, `forecast`, séparés par des virgules) et
  `sort` (`relevance` par défaut, `deadline`, `verified`, `title`). Une valeur inconnue est
  ignorée (statut retiré, tri → `relevance`, `q` tronqué à 100 caractères), jamais un 400.
  La réponse gagne la clé **additive** `query` (ce qui a été appliqué). Sans ces
  paramètres, la réponse est celle d'avant (ordre, `total`). Contrat :
  `docs/api-contracts.md`, « Liste des bourses : recherche, statut et tri ».
- **Drapeau `features.onboardingV2`** (`KPB_ONBOARDING_V2_ENABLED`), **FERMÉ par défaut** :
  absent du `.env`, défaut `false` dans `docker-compose.yml` (gardé par
  `config_env_relay_test`), seule la valeur `true` l'ouvre. Fermé, absent ou backend plus
  ancien : l'app garde l'ancien onboarding, inchangé.

**Couplage : `tolerates-old` dans les deux sens.**

- *Builds en store (≤ 56) face au nouveau backend* : elles n'envoient ni `q`, ni `status`,
  ni `sort`, ignorent `query` et `onboardingV2`. Aucun effet.
- *Nouvelle app face à un backend sans le chantier I* (production actuelle) : la route lit
  ses paramètres un par un (`@Query('nom')`, pas de DTO) ; le `ValidationPipe`
  (`forbidNonWhitelisted`) ne s'y applique pas et les clés inconnues sont **ignorées, pas
  refusées** (prouvé en HTTP : `scholarships-list.http.spec.ts`). La liste s'affiche ;
  sans écho `query`, l'app filtre le statut elle-même sur la page reçue, n'affiche pas de
  total, et **masque le bouton « Trier »**. `onboardingV2` absent = fermé.

**Ordre de déploiement :**

1. **Backend** (workflow « Deploy backend (VPS) », `scope=full`), après le préflight de la
   56. Vérifier depuis l'extérieur : `GET /api/config/app` → `features.onboardingV2:
   false` ; `GET /api/scholarships?status=bogus&sort=bogus` (connecté) → 200 et
   `query: {status: null, sort: "relevance"}`.
2. **Build mobile** qui porte le chantier I (après la 56) — elle tolère le backend d'avant,
   l'ordre 1 → 2 n'est donc qu'une préférence (« Trier » visible dès le premier jour).
3. **Ouverture de l'onboarding V2** (`KPB_ONBOARDING_V2_ENABLED=true`) seulement quand
   cette build est en store et adoptée : une build plus ancienne ignore le drapeau.

**Retour arrière :** `KPB_ONBOARDING_V2_ENABLED` coupé (l'app relit le drapeau à la
prochaine ouverture de l'onboarding) ; le backend se ramène au tag précédent sans rien
toucher (aucune migration, la clé `query` est additive).

**Données locales :** le cache hors ligne des bourses (boîte Hive
`kpb.scholarships.cache`, première page par jeu de filtres et 60 fiches au plus) est vidé
à la déconnexion et à la perte de session, et n'est jamais relu après un 401 ou un 403.
