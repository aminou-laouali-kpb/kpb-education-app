# KPB Education relaunch API contracts

These are the working contracts represented in the current scaffolding.

## Profiles

- `GET /profiles/me`
- `PATCH /profiles/me`

Purpose:
- load the current user profile
- progressively enrich profile data after onboarding

## Orientation

- `POST /orientation/sessions`
- `GET /orientation/results/:id`

Purpose:
- submit guided orientation answers
- retrieve scored recommendations and next actions

## Catalog

- `GET /catalog/fields`
- `GET /catalog/countries`
- `GET /catalog/institutions`
- `GET /catalog/programs`
- `GET /catalog/scholarships`

Purpose:
- feed Explore, Scholarships, and recommendation surfaces

**Frontière de l'import « Études en France ».** `GET /catalog/institutions` et
`GET /catalog/programs` ne servent **jamais** une ligne créée par cet import
(identifiants `eef-univ-…` / `eef-prog-…`), qu'elle soit publiée ou non : le
paramètre `institutionId` ne la fait pas réapparaître. Une formation dont
l'ÉTABLISSEMENT est de l'import en est aussi, même saisie à la main (identifiant
généré, active par défaut) : sans cette règle elle serait servie sur une carte
sans école, l'école étant, elle, exclue. C'est la surface de
TOUTES les builds, y compris celles déjà installées qui la chargent en un seul
appel (`limit=1000`) ; y laisser des lignes EEF actives aurait évincé des
formations partenaires de la liste de tout le monde. L'espace « Études en France » a ses
propres routes (`/etudes-en-france/*`). La règle vit en un seul endroit :
`backend/src/common/eef-provenance.ts`.

### `GET /catalog/programs` : pagination, aucun plafond de catalogue (17/10/2026)

Décision du propriétaire : le maximum de choix, sans plafond de formations.
Le catalogue n'est plus borné ; seule **une page** l'est (`limit` ≤ 1 000).

| Paramètre | Sens |
|---|---|
| `limit` | Taille de page, 1 à 1 000 (défaut et maximum 1 000 ; une valeur non entière est ignorée). |
| `offset` | Rang de la première ligne (défaut 0). |
| `q`, `fieldId`, `countryId`, `institutionId` | Filtres inchangés. |
| `view` | `compact` : chaque formation **sans** les clés à plat dupliquées (`nameFr`, `nameEn`, `levelFr`… `recognitionEn`), les objets localisés (`name: {fr, en}`…) restant servis. Mesuré sur le catalogue amorcé (767 formations) : 1 185 → 780 Kio, gzip 83 → 60 Kio. Toute autre valeur, ou son absence : la forme complète d'avant. |

Réponse : `{ items, total, limit, offset, nextOffset, source }`. `total` compte
**tout** le catalogue filtré ; `nextOffset` est le rang de la page suivante, ou
`null` quand tout est servi (clé nouvelle : un client plus ancien l'ignore).

**Ordre (le même pour tous).** Trois tranches disjointes, chacune triée par
`nameFr` puis `id` (ordre total, pages sans chevauchement) :

1. les formations des établissements **partenaires** publiés (la clause de
   `/catalog/institutions?partnerOnly=true`) ;
2. les autres formations dont `applicationDeadline` est **à venir** (≥ minuit
   UTC du jour) ;
3. le reste (sans date limite, ou date passée).

Code : `backend/src/modules/catalog/program-snapshot-order.ts`. L'app trie
elle-même chaque liste affichée ; l'ordre serveur ne décide que de ce qui tombe
dans la première page.

**Builds récentes** (`lib/app/core/repositories/app_api_client/catalog.dart`) :
pages de 500 en `view=compact` enchaînées sur `nextOffset` jusqu'à épuisement (garde-fou : 60
pages), dédoublonnées par `id` ; si `total` change en cours de route (import,
date limite qui passe à minuit UTC), la lecture recommence une fois. Une page en
échec fait échouer toute la lecture : le cache Hive précédent reste servi, jamais
un catalogue tronqué.

**Builds déjà installées** (2.3.x et antérieures) : elles envoient `limit=1000`
sans `offset` et ne lisent pas `nextOffset`. Au-delà de 1 000 formations
publiques, elles ne reçoivent que la première page : tous les partenaires, puis
les formations datées à venir, puis les autres par ordre alphabétique jusqu'à
1 000. Ce qu'elles ne reçoivent pas n'existe pas pour elles : absent de la liste
Universités, de la recherche, des filtres et de leurs compteurs (calculés sur la
liste reçue) ; une fiche ouverte depuis un favori ou un lien affiche « Formation
introuvable » ; l'aperçu de l'établissement saute la formation ; le comparateur
compte encore `programIds` (servi complet par `/catalog/institutions`), donc un
nombre de formations supérieur à ce qu'elles listent. `verify:catalog` imprime
ce manque à chaque passage, et n'en fait un constat que si les formations
**partenaires** dépassent à elles seules la première page.

## Matches (Phase 0 / P0-D — kit US-003/US-004)

- `GET /matches/aha-moment?limit=3` (student auth)
- `GET /matches/school/:institutionId` (student auth)

Purpose:
- deterministic admission-probability scoring (algorithm v1, 5 weighted
  factors — see `docs/phase0-new-plan-alignment.md` and the kit's
  `matching_algorithm.md`)
- `aha-moment` returns the top-N institutions (best program each) across the
  caller's target countries/fields, for the post-onboarding reveal
- `school/:institutionId` returns the best-scoring program of one institution

Response item shape:

```json
{
  "institutionId": "…",
  "institutionName": { "fr": "…", "en": "…" },
  "programId": "…",
  "programName": { "fr": "…", "en": "…" },
  "probability": 0.74,
  "zone": "green | yellow | blue",
  "isEstimate": false,
  "algorithmVersion": "v1",
  "factors": [
    { "name": "academic", "weight": 0.3, "score": 1, "isEstimate": false }
  ],
  "narrative": { "fr": "…", "en": "…" }
}
```

`aha-moment` wraps items as `{ "items": [...], "isEstimate": bool }`.
Zones: green > 0.70 · yellow 0.30–0.70 · blue < 0.30. Missing inputs score a
neutral 0.5 with `isEstimate`; ≥2 missing caps probability at 0.65.

Les formations et établissements de l'import « Études en France » ne sont
**jamais** recommandés ici, publiés ou non : `GET /matches/school/:institutionId`
sur l'un d'eux répond 404 `Institution not found.`. L'espace a sa propre
shortlist (`GET /etudes-en-france/shortlist`). Même règle, même fichier que le
catalogue général.

## Content

- `GET /content/service-offers`
- `GET /content/support-destinations`
- `GET /content/articles`

Purpose:
- feed the mobile relaunch with dashboard-managed offers, destination coverage, and editorial content

## Community

- `GET /community/forum-categories`
- `GET /community/forum-tags`

Purpose:
- expose dashboard-managed forum taxonomy to the mobile community layer

## Cases

- `GET /cases`
- `GET /cases/:id`
- `POST /cases`
- `GET /cases/:id/messages`
- `POST /cases/:id/messages`
- `POST /cases/:id/documents`

Purpose:
- create and manage the unified student-facing `My Cases` experience
- support counselor/admin updates, service messaging, and document handling

## Admin case operations

- `GET /admin/cases`
- `POST /admin/cases/:id/assign`
- `POST /admin/cases/:id/tasks`
- `POST /admin/cases/:id/internal-notes`
- `POST /admin/cases/:id/timeline-events`

Purpose:
- power counselor and admin case ownership, internal workflow, and operational follow-up

## Appointments

- `GET /appointments`
- `POST /appointments`

Purpose:
- schedule counseling and mentoring sessions linked to cases

## Saved Items

- `GET /saved-items`
- `POST /saved-items`
- `DELETE /saved-items/:id`

Purpose:
- persist saved countries, fields, programs, institutions, and scholarships

## Avis sur un conseiller

- `GET /counsellors/:id` (public) — fiche d'un conseiller approuvé, avec ses
  20 derniers avis **publiés**
- `POST /counsellors/:id/reviews` (auth étudiant) — laisser un avis
- `PATCH /admin/counsellors/reviews/:reviewId/publish` (admin) — publier ou
  dépublier

Corps de `POST /counsellors/:id/reviews` :

```json
{ "rating": 5, "body": "…", "caseId": "…", "reviewerName": "…" }
```

| Champ | Règle |
|---|---|
| `rating` | entier de 1 à 5 |
| `body` | texte ; **tronqué à 1 000 caractères, pas refusé** (le champ de saisie de l'app n'a aucune limite, et un 400 lui ferait perdre le texte) ; **peut être vide** — la note seule suffit |
| `caseId` | obligatoire, 64 caractères au plus |
| `reviewerName` | **accepté et ignoré**, de toute longueur : les builds 49 à 53 l'envoient encore, et la validation globale (`forbidNonWhitelisted`) répondrait 400 à tous leurs avis si le champ n'était pas déclaré |

**L'auteur et le nom affiché viennent du jeton**, jamais du corps. Le nom
publié est le `fullName` du profil vérifié (« KPB » s'il est vide) — un nom que
l'utilisateur maîtrise via `PATCH /profiles/me` : la requête ne peut plus le
déclarer, ce qui ne dit pas qu'il est civil ou exact. Un `reviewerUserId` dans
le corps est refusé en 400 : il n'est pas ignoré en silence. Auparavant le corps
était un type en ligne, effacé à l'exécution, et le service recopiait ce que le
client envoyait ; l'app n'envoyait jamais l'auteur, donc les avis n'en avaient
aucun en base, la suppression de compte (`deleteMany WHERE reviewerUserId = …`)
ne les trouvait pas, et le nom civil de l'étudiant survivait à l'effacement de
son compte.

**Le dossier lie l'avis à un parcours réel — il ne le prouve pas.** Il doit
exister, appartenir à l'appelant, avoir été traité par CE conseiller, et être
terminé : exactement ce que l'app ne propose qu'à ce moment-là. « Terminé » reste
un contrôle de cohérence : le statut d'un dossier n'est fixé que par l'équipe
(`PATCH /admin/cases/:id`) — il n'existe plus de `PATCH /cases/:id` côté
étudiant, qui laissait le propriétaire se déclarer « terminé » lui-même (aucun
écran de l'app ne l'appelait). Ce n'est pas une preuve de la qualité du
parcours ; la modération reste la défense de fond.

| Réponse | Cas |
|---|---|
| `201` | avis enregistré, **en modération** (`isPublished = false`) |
| `400` | corps invalide : note hors 1–5, `caseId` absent, champ non déclaré… |
| `401` | jeton absent ou invalide — y compris quand la base est absente : le garde d'authentification répond avant le service |
| `403` | le dossier est celui de l'appelant, mais un autre conseiller l'a traité |
| `404` | dossier inconnu **ou appartenant à quelqu'un d'autre** — même réponse, pour ne pas confirmer l'existence du dossier d'autrui |
| `409` | dossier pas encore terminé, **ou déjà noté** (un avis par dossier ; sans contrainte d'unicité en base, la garde est au mieux-effort) |
| `503` | défense en profondeur du service quand `execute` rend `null` — jamais un `201` au corps vide. Atteignable seulement si le garde laisse passer |

Les avis publiés que `GET /counsellors/:id` sert ne portent que `id`,
`counsellorId`, `reviewerName`, `rating`, `body` et `createdAt` — les mêmes
colonnes que `GET /impact/reviews`. L'identifiant interne de l'auteur et celui
du dossier n'en sortent pas : depuis que l'auteur est renseigné, les servir aurait
publié une clé de rattachement au profil.

**La même porte que `/impact/reviews`.** Un avis publié n'apparaît sur la fiche
que si son AUTEUR a un reçu `public_testimonial` actif (notice en vigueur à
l'accord, non retirée ; reçu non révoqué ; pour un mineur, autorisation parentale
vérifiée, non révoquée, non expirée). La règle est écrite une fois
(`impact/public-testimonial-consent.ts`) et importée par les deux surfaces. Deux
conséquences : la modération (`isPublished`) est nécessaire mais pas suffisante,
et un avis sans auteur — ceux d'avant la reprise, ou dont le dossier a disparu —
ne s'y affiche jamais. Retirer son accord fait disparaître l'avis de la fiche
sans toucher à la modération. La lecture est bornée : les 200 avis publiés les
plus récents sont examinés, les 20 premiers consentants sont servis, et seuls les
reçus de leurs auteurs sont lus. Aucun client de l'app n'appelle cette fiche
(`getCounsellor` existe dans le client mais aucun écran ne s'en sert).

**Effacement et export.** La suppression de compte efface les avis que
l'utilisateur a signés ET ceux, sans auteur, qui portent l'un de ses dossiers
(`reviewsOfUser`, `profiles.service.ts`) ; les compteurs du conseiller sont
recalculés. L'export RGPD les rend à leur auteur (`counsellorReviews`). Un avis
sans auteur posé sur le dossier d'un AUTRE n'est jamais touché.

**Reprise de l'existant.** La migration
`20260929120000_counsellor_review_author_backfill` rattache les avis déjà
enregistrés sans auteur au propriétaire du dossier noté — seulement si ce
dossier a bien été traité par le conseiller noté : un rattachement rend l'avis
éligible à la publication au titre du consentement de CE propriétaire. Les
autres restent sans auteur ; l'effacement et l'export les retrouvent par leur
dossier tant qu'il existe. Restent les avis dont le dossier a disparu (compte
déjà supprimé) ou n'a jamais été renseigné : leur auteur est irrécupérable, et
les anonymiser ou les supprimer est une décision d'exploitation.

## Partner leads

- `GET /partner-leads`
- `POST /partner-leads`

Purpose:
- support lightweight partner acquisition outside the student case flow

## Recherche du catalogue « Études en France » (Phase 1)

- `GET /etudes-en-france/search`

**Publique**, et c'est une décision produit, pas un oubli : « catalogue
gratuit, accompagnement payant » (plan § 2). Un étudiant doit pouvoir chercher
sa formation avant de créer un compte — c'est ce qui lui donne une raison d'en
créer un. La route vit donc dans son propre contrôleur, à côté de celui de la
déclaration d'intérêt, qui lui est authentifié au niveau de la classe.

### Paramètres

| Paramètre | Forme | Notes |
|---|---|---|
| `q` | texte | découpé en mots (6 max, 10 après découpage des composés). **Tous** les mots doivent être satisfaits ; un mot l'est s'il figure dans l'intitulé ou la ville, **sans tenir compte des accents ni de la casse** (« genie » trouve « Génie civil »), s'il désigne l'**établissement** par un mot de son nom ou son sigle (« sorbonne », « UPEC »), ou s'il désigne un **niveau** (« licence », « master », « L2 »). Voir *Ce que la recherche libre comprend*. |
| `procedureType` | CSV | `dap_blanche`, `dap_jaune`, `eef`, `parcoursup`, `hors_eef` |
| `cycle` | CSV | `licence1`, `licence2`, `licence3`, `but1`, `deust`, `sante`, `ingenieur`, `master` |
| `fieldId` | CSV | `d01`..`d12` |
| `selectivity` | CSV | `selective`, `non_selective` |
| `campusCity` | CSV | vocabulaire ouvert (vient du catalogue) |
| `institutionId` | CSV | vocabulaire ouvert |
| `cursor` | opaque | rendu par la page précédente |
| `limit` | entier | défaut 20, plafond 50 |

Chaque paramètre de liste accepte les **deux formes** : séparée par des
virgules (`?cycle=master,licence1`) et répétée (`?cycle=master&cycle=licence1`).
Express livre la seconde sous forme de tableau ; les refuser serait une
chausse-trappe, puisque c'est la forme que produisent naturellement les clients
HTTP. Un paramètre scalaire répété (`?cursor=a&cursor=b`) retient la première
valeur.

Une valeur hors référentiel fermé rend **400 `EEF_SEARCH_BAD_PARAM`**, avec le
paramètre fautif et les valeurs admises. L'ignorer silencieusement ferait
afficher des compteurs qui ne correspondent pas à la demande. Un
`institutionId` inconnu, lui, rend zéro résultat : c'est la bonne réponse, pas
une erreur. Chaque facette accepte au plus 20 valeurs — une liste `IN` sans
borne se fabrique avec une simple URL.

### Réponse

```jsonc
{
  "items": [ /* même forme que GET /catalog/programs */ ],
  "total": 10247,
  "page": { "limit": 20, "hasMore": true, "nextCursor": "TDEgLSBEcm9pdAB..." },
  "facets": {
    "procedureType": [{ "value": "eef", "count": 7125 }, "…"],
    "cycle": ["…"], "fieldId": ["…"], "selectivity": ["…"],
    "campusCity": ["…"], "institutionId": ["…"]
  },
  "facetsTruncated": ["campusCity", "institutionId"],
  "catalogPublished": true,
  "source": "database"
}
```

### Ce que chaque item porte

La forme de `GET /catalog/programs`, **plus** (ajouts seulement : un client qui ne
connaît que la première forme continue de tout lire) :

| Champ | Sens |
|---|---|
| `procedureType`, `cycle`, `selectivity` | la procédure (DAP blanche, Études en France…), le cycle exact, la sélectivité publiée |
| `healthAccess` | `true` pour une 1re année d'accès santé — PASS ou L.AS (`eef-health-access.ts`). **Pas** `cycle === 'sante'` : ce cycle compte aussi 61 diplômes paramédicaux (orthophoniste, ergothérapeute…) qui n'en sont pas. L'app y accroche le badge « Accès santé » |
| `campusCity`, `formationCode` | où se déroule la formation, son code officiel |
| `recommendedBachelors`, `admissionModes` | licences conseillées à l'entrée et modalités de candidature, telles que l'établissement les publie |
| `institution` | l'établissement, en résumé : `id`, `name`, `acronym`, `location`, `institutionType`, `websiteUrl`, `logoUrl` (servi à la largeur standard de Wikimedia), `logoSourceUrl`, `logoLicence` |

`institution` est servi aussi dans les items de la **shortlist**
(`tiers[].items[].program`). Sans lui, « L1 - Droit » — proposée par quarante
universités — s'affichait quarante fois sans qu'aucune soit nommée. Il ne porte
ni la présentation ni l'effectif daté (c'est la fiche) ; il est `null` si
l'établissement n'est plus dans la liste des établissements publiés, ce que la
clause de la requête exclut déjà.

### `catalogPublished`

Vrai si le catalogue publié contient **au moins une formation, quel que soit le
filtre**. Faux ⇒ rien n'est encore publié : l'écran doit dire « le catalogue
arrive », pas « ta recherche est trop étroite » — ce que `total: 0` seul ne
permet pas de distinguer. Sans filtre, `total` répond ; avec un filtre, une sonde
(une seule formation publiée, sans aucun filtre) est posée **dans la même
transaction** que la page, le total et les facettes : lue après, une publication
survenue entre les deux ferait coexister un résultat vide d'un instant et un
`catalogPublished` d'un autre.

### Ce que la recherche libre comprend

- **Sans accents.** La comparaison se fait sur `Program.searchText` (intitulé +
  ville, normalisés : minuscules, sans accents, ponctuation en espaces), écrit à
  l'import, **recalculé quand l'intitulé est modifié dans l'admin**, et rattrapé
  sur les lignes existantes par `npm run eef:backfill:search` (qui comble les
  vides ET répare les textes périmés). Une ligne dont ce texte est encore nul
  retombe sur la comparaison brute d'avant (insensible à la casse, pas aux
  accents) : **jamais moins de résultats qu'avant**.
- **Par établissement.** Un mot désigne un établissement s'il **commence** un mot
  de son nom, ou s'il est son sigle (`Institution.acronym`, publié par le
  ministère). Jamais par un morceau au milieu d'un mot, et sous trois lettres seul
  le sigle entier compte. Seuls les établissements **publiés** sont candidats : un
  établissement en attente n'est trouvable par personne.
- **Par niveau.** `licence` → L1, L2, L3, licence pro ; `bachelor` → les mêmes et
  BUT ; `l1`/`l2`/`l3`, `master` (`m1`, `m2`), `but`, `deust`, `ingenieur` ;
  `sante`/`health` → toute la famille « Études de santé » (PASS, L.AS et diplômes
  paramédicaux).
- **Par l'accès aux études médicales.** `medecine`, `pharmacie`, `kine`,
  `maieutique`, `odontologie`, `dentaire`, `las` (« L.AS », « L AS »), `paces`,
  `mmopk`… → une 1re année **PASS ou L.AS seulement** — pas les diplômes
  paramédicaux, qu'on trouve par leur nom. `las` ne se cherche pas dans le texte
  (il est dans « plastiques ») ; `pass` se cherche dans le texte (il est dans
  l'intitulé des PASS, et seulement là).
- **Les mots vides** (`de`, `la`, `et`…) sont ignorés, sauf s'il n'y a rien
  d'autre. Un mot composé (« paris-saclay », « l'économie ») est découpé en ses
  mots.

### Ce que la pagination garantit

**Curseur, pas offset.** Le curseur porte la POSITION — le dernier couple
`(nameFr, id)` vu — et non un rang. Deux conséquences :

- *Correction* : si un administrateur publie une fiche pendant qu'un étudiant
  fait défiler, un offset décale tout d'un rang et lui fait sauter une
  formation sans qu'il le sache. Le curseur, non.
- *Coût constant* : mesuré sur les 10 247 lignes, page 205 sur 205 — offset
  4,4 ms → 23,4 ms, curseur 3,8 ms → 4,8 ms. L'écart croît avec la taille du
  catalogue ; c'est la correction qui est l'argument fort, le coût n'en est
  que la conséquence visible.

L'ordre est **total** (`nameFr` puis `id`). `nameFr` seul ne l'est pas —
« L1 - Droit » est servi par quarante universités — et un ordre partiel fait
sauter des lignes au curseur.

### Ce que les facettes garantissent

Chaque facette est comptée **sans son propre filtre**. Choisir « master » ne
fait donc pas tomber à zéro le compte des licences : l'étudiant voit toujours
ce qu'il obtiendrait en changeant d'avis, sans avoir à défaire son filtre. Le
total, lui, tient compte de tous les filtres.

Page, total et facettes sont lus dans **une seule transaction**, en isolation
`RepeatableRead` : servis séparément — ou même dans une transaction
`READ COMMITTED`, où chaque instruction a son propre instantané — ils
décriraient deux instants différents, « 1 240 résultats » au-dessus d'une liste
qui en montre d'autres.

`campusCity` et `institutionId` ont des dizaines de valeurs : les 20 plus
fournies sont rendues, et `facetsTruncated` le dit. Pour la liste COMPLÈTE des
villes — un filtre « Ville » avec recherche —, voir la section « Villes de
campus » plus bas (`GET /etudes-en-france/cities`).

### Pas de repli sur les jeux de démonstration

`/catalog/*` sait dégrader vers `mock-catalog` hors production. Pas ici : il
n'existe aucun échantillon « Études en France », et en fabriquer un servirait
des formations qui n'existent pas. Base indisponible ⇒ **503
`CATALOG_UNAVAILABLE`**, dans tous les environnements.

La route ne sert que des lignes **relues** (`isActive = true`) et rattachées à
la France, résolue en base par son **code** — `FRA` comme `FR`, le référentiel
M5 étant en ISO 3166-1 alpha-3 — et jamais par un identifiant écrit en dur. La
règle est partagée avec l'import (`eef-country.ts`) : elle vivait en double, et
c'est pour cela que l'erreur y vivait aussi.

**Une formation n'est servie que si son établissement est publié**
(`Institution.isActive = true`, même pays). `Program` n'a aucune relation vers
`Institution` : la garde est une clause `institutionId IN (établissements
publiés)`, lue UNE fois puis appliquée à la page, au total et aux six facettes,
qui décrivent donc le même ensemble. Une formation activée sous une université
que personne n'a relue n'est pas servie ; publier l'université la fait
apparaître. Une liste vide sert **zéro** ligne, jamais « tout » (prouvé sur une
base réelle, lignes en place).

La liste contient les établissements ACTIFS du pays — partenaires compris (ESSEC,
OMNES…), pas seulement ceux de l'import. Ce qui garde leurs formations hors de
cette recherche est la **provenance** : la recherche ne sert que les lignes de
l'import (identifiant `eef-prog-…`, ou établissement `eef-univ-…`) — la clause
dont le catalogue général est le contraire. Une formation partenaire, même
qualifiée d'une procédure et d'un cycle, n'y entre donc jamais et reste dans
`/catalog/programs` : une ligne, un espace. La shortlist suit la même règle.

## Villes de campus « Études en France »

- `GET /etudes-en-france/cities`

**Publique** et **en lecture seule**, pour la même raison que la recherche : un
étudiant filtre avant de créer un compte. Elle vit dans le même contrôleur
(`EefSearchController`), jamais sous un contrôleur gardé.

### Pourquoi elle existe

La facette `campusCity` de `/search` s'arrête à 20 valeurs (`facetsTruncated`) :
les 20 premières villes ne couvrent que 4 201 formations sur 10 029. Un filtre
« Ville » avec recherche a besoin de la liste entière. La servir par la
recherche aurait obligé à relever le plafond de la facette, donc à alourdir
**chaque** réponse de recherche de toutes les villes, alors que l'écran ne les
lit qu'à l'ouverture du filtre.

### Paramètres

| Paramètre | Forme | Notes |
|---|---|---|
| `q` | texte | comme `/search` : mots normalisés sans accents, établissement et niveau compris. Il porte aussi sur le nom de la ville : `q=epinal` ne laisse que Épinal |
| `procedureType` | CSV | `dap_blanche`, `dap_jaune`, `eef`, `parcoursup`, `hors_eef` |
| `cycle` | CSV | `licence1`, `licence2`, `licence3`, `licence_pro`, `but1`, `deust`, `sante`, `ingenieur`, `master` |
| `fieldId` | CSV | `d01`..`d12` |
| `institutionId` | CSV | vocabulaire ouvert, 20 valeurs au plus |
| `selectivity` | CSV | `selective`, `non_selective` |

Les six filtres sont **ceux de `/search`**, avec le même validateur : mêmes
formes (CSV ou paramètre répété, ou les deux), mêmes valeurs admises, même
plafond de 20 valeurs, même **400 `EEF_SEARCH_BAD_PARAM`** sur une valeur
inconnue.

**`campusCity` est ignoré**, ainsi que `cursor` et `limit` : ils ne sont pas lus,
donc les envoyer n'est pas une erreur — un client qui rejoue telle quelle l'URL
de sa recherche obtient la liste. `campusCity` est ignoré parce que le compteur
d'une ville répond à « combien en aurais-je si je choisissais **cette** ville ? » :
avec la ville déjà choisie dans la clause, toutes les autres tomberaient à zéro
et l'étudiant ne pourrait plus en changer. C'est le même principe que pour les
facettes de `/search`, comptées sans leur propre filtre.

### Réponse

```jsonc
{
  "cities": [
    { "value": "Paris", "count": 783 },
    { "value": "Toulouse", "count": 297 },
    "…"
  ],
  "total": 10502,
  "catalogPublished": true,
  "source": "database"
}
```

| Champ | Sens |
|---|---|
| `cities[].value` | la ville **telle que le catalogue l'écrit** — la chaîne exacte à renvoyer dans `campusCity` de `/search`, apostrophes et accents compris (`Saint-Martin-d'Hères`, `Épinal`) |
| `cities[].count` | le nombre de formations que `/search` rendrait avec `campusCity=<value>` **et** les autres filtres de la requête : c'est son `total`, ni plus ni moins |
| `total` | le nombre de formations qui correspondent aux filtres **hors ville**, y compris celles qui n'ont pas de ville |
| `catalogPublished` | comme `/search` : vrai si le catalogue publié contient au moins une formation, **quel que soit le filtre**. Zéro ville avec `catalogPublished: true` se dit « aucune ville pour ces filtres », pas « le catalogue arrive » |
| `source` | toujours `database` |

### Ce que la route garantit

- **Aucune troncature.** Toutes les villes rendues, pas de plafond, pas de
  `facetsTruncated`.
- **Ordre.** Nombre de formations **décroissant**, puis nom **croissant sans
  tenir compte des accents ni de la casse** (« Épinal » se range avec les E, pas
  après « Zola »). Deux graphies ex æquo une fois les accents ôtés sont
  départagées par la valeur brute : l'ordre ne dépend pas de celui où la base
  les a rendues. Le client qui filtre au clavier peut reclasser par nom ; il
  doit comparer des textes normalisés de la même façon (minuscules, sans
  accents, ponctuation en espaces).
- **Même périmètre que la recherche.** C'est le même constructeur de clause
  (`buildEefSearchWhere`) : seules les formations **publiées** (`isActive`,
  établissement publié, provenance de l'import, procédure qualifiée), la même
  normalisation de `q`, la même résolution des noms d'établissement. Une règle de
  publication écrite deux fois finit par ne plus être la même des deux côtés, et
  c'est un compteur qui ment. Une liste d'établissements publiés vide donne
  **zéro** ville, jamais « toutes ».
- **Une formation sans ville n'apparaît dans aucune ville** (valeur nulle ou
  blanche), mais reste dans `total`. La somme des `count` peut donc être
  inférieure à `total`.
- **Un seul instantané.** Les villes, le total et la sonde de `catalogPublished`
  sont lus dans une transaction `RepeatableRead`, comme la recherche.
- **Pas de repli.** Base indisponible ⇒ **503 `CATALOG_UNAVAILABLE`**
  (`details.resource` : `eef-cities`), dans tous les environnements ; `source`
  vaut donc toujours `database`. Aucun échantillon : il servirait des villes sans
  formation.

### Poids de la réponse

Mesuré le 02/10/2026 sur les 10 502 formations du catalogue 1.3.0, toutes
publiées dans une base jetable chargée par `npm run eef:import` : **276 villes
distinctes, 9 336 octets** de JSON compact (2,4 Ko sur le fil, compression
active), **29 ms** de médiane côté base, contre 83 ms pour une page de
`/search`. Le calcul sur les fichiers versionnés donne exactement la même
réponse. Chaque filtre la réduit (`cycle=master` : 64 villes, 2,1 Ko). Tant que
les villes viennent de l'import versionné, aucun catalogue publié ne peut donner
plus que ces 9,3 Ko : le plus gros cas est le catalogue entier, sans filtre.
Aucune réduction n'est nécessaire (seuil de réflexion : environ 60 Ko).

### Limites connues

- **Une ville peut y figurer sous deux graphies.** Le catalogue vient de deux
  jeux ouverts qui n'écrivent pas les communes de la même façon : 14 villes
  apparaissent deux fois (« Saint-Denis » 157 et « St Denis » 82, « Créteil » 118
  et « Creteil » 68, « Clermont-Ferrand » et « Clermont Ferrand »…), soit 1 457
  formations. La route les rend telles quelles — chaque entrée est exacte :
  `campusCity=Créteil` ne rend pas les formations de « Creteil ». Le correctif
  vit à l'import (écrire une graphie canonique), pas dans ce point d'accès.
- **`value` ne contient ni virgule ni espace de tête ou de queue aujourd'hui**
  (vérifié sur les 10 502 formations), ce que le filtre de `/search` suppose :
  il découpe sur la virgule et rogne les espaces. Une commune dont le nom en
  porterait ne pourrait pas être choisie — son compteur serait rendu, mais
  `campusCity=<value>` ne la retrouverait pas.

## Shortlist « Études en France » (Phase 2)

- `GET /etudes-en-france/shortlist`

**Authentifiée**, et réservée aux comptes `student`. La recherche est publique
parce qu'elle répond à « qu'existe-t-il ? » ; celle-ci répond à « lesquelles
pour MOI » et lit donc la déclaration d'intérêt de l'appelant. Sans identité,
la question n'a pas de sens, et il n'existe aucun repli anonyme à servir. Un
compte `parent` reçoit **403** plutôt qu'une liste calculée sur son propre
profil, qu'il lirait comme celle de son enfant.

### Aucun pourcentage, et ce n'est pas une omission

Le plan (§ 6) prévient qu'« un pourcentage opaque dans un produit payant se
retourne au premier refus d'admission ». Cette route va plus loin : elle n'en
sert aucun. Le catalogue ne publie ni taux d'admission, ni capacité d'accueil,
ni nombre de candidats — un « 72 % de chances » aurait été un nombre inventé
portant l'autorité d'un nombre mesuré.

Ce qui est servi à la place : des **faits publiés**, chacun nommé par un code
fermé et accompagné de la valeur attestée. L'étudiant peut être en désaccord
avec le classement ; il ne peut pas être trompé sur ce qui le fonde.

### Les trois étages n'existent pas toujours

Constat qui a façonné toute la route : `selectivity` est **constante à
l'intérieur d'un cycle**. Sur les 10 502 formations, tous les masters, toutes
les L2, toutes les L3, tous les BUT et tous les DEUST sont `selective`, toutes
les lignes `sante` `non_selective` ; seule la L1 varie (1 778 non sélectives,
734 sélectives). Trier des masters là-dessus aurait rendu trois étages qui sont
le même étage sous trois noms.

Et là où elle varie, elle ne parle pas de l'étudiant. « Non sélective » est la
catégorie de Parcoursup, donc des élèves de terminale française : pour un
candidat en demande d'admission préalable, l'université examine le dossier et
peut le refuser (décision n° 5 du 02/10/2026,
`docs/eef-dossier-relecture-procedures.md`). Les 2 428 non sélectives du chemin
post-bac sont toutes en DAP : les ranger en « sécurité » — ce que faisait l'axe
`selectivity`, retiré le 02/10/2026 — promettait ce que la décision dément.

Le classement repose donc sur ce qui varie, qui est attesté ET qui décrit le
candidat, et il diffère selon la porte d'entrée :

| `path` | Cycles servis | `ranking.basis` | Étages |
|---|---|---|---|
| `master` | `master` | `admission_effort` | `securite` (dossier seul) · `cible` (+ entretien) · `ambition` (+ examen ou concours) · `unranked` (modalité non publiée) |
| `post_bac` | `licence1` `but1` `deust` `sante` | `null` | `unranked` seul — la sélectivité Parcoursup ne dit rien d'un candidat en DAP |
| `licence_continuation` | `licence2` `licence3` `licence_pro` | `null` | `unranked` seul — aucune donnée ouverte ne classe ce chemin |

Mesuré sur les fichiers versionnés du catalogue, sans domaine déclaré :
1 259 / 1 474 / 262 / 249 sur le chemin master. L'axe discrimine réellement.

Un étage **vide n'est pas servi** : une colonne vide se lit « rien pour toi »,
ce qui est faux quand les autres sont pleines. `unranked` n'est pas un
quatrième étage, c'est l'aveu qu'il n'y en a pas pour ces lignes-là.

### Le chemin d'entrée vient du COUPLE de niveaux

La feuille de déclaration pose deux questions avec le même menu de six mots, et
« licence » y veut dire « je suis au niveau licence » sans dire si l'étudiant
entre en L1, continue en L3, ou sort diplômé. L'ambiguïté n'est pas bénigne :
entrer en L1 se demande par DAP blanche avant mi-décembre, continuer en L2 se
demande par la procédure Études en France sur un autre calendrier.

La table est donc **fermée** et porte sur des couples, jamais sur un niveau
seul. Un couple absent rend un motif, jamais un chemin « le plus probable » :

| `currentLevel` \| `targetLevel` | Résultat |
|---|---|
| `terminale\|licence`, `bac\|licence` | `post_bac` |
| `licence\|licence` | `licence_continuation` |
| `licence\|master`, `master\|master` | `master` |
| `terminale\|master`, `bac\|master`, `master\|licence`, tout `autre` | `blocked: declaration_unmappable` |
| `*\|doctorat` | `blocked: level_not_in_catalog` |

### Ce que la route sélectionne

Seulement des formations qui se demandent **par la procédure de l'espace** :
`procedureType` dans `dap_blanche`, `dap_jaune`, `eef` — liste fermée
(`EEF_SHORTLIST_PROCEDURES`), qu'une valeur nouvelle ne rejoint pas sans
décision. Le cycle ne suffit pas à le dire : la 1re année de Sciences Po
(Paris) est une `licence1` en `hors_eef` (39 lignes), le DCG une `licence1` en
`parcoursup` (1 ligne). Sont donc écartées :

| `procedureType` | Pourquoi |
|---|---|
| `hors_eef` | Admission propre à l'établissement (Sciences Po Paris en 1re année, cycles d'ingénieurs). |
| `parcoursup` | Autre plateforme, autre calendrier, et `/config/app` ne sert que la campagne Études en France : `campaign_dates_served_separately` serait faux. |
| `NULL` | Formation saisie à la main, sans procédure. La recherche ne la sert pas non plus. |

La recherche continue de servir les deux premières, avec la phrase de leur
procédure. Parmi les formations retenues, deux strates, servies dans cet
ordre :

1. **`linked`** — la formation est reliée à un domaine déclaré dans un sens ou
   dans l'autre : son propre `fieldId`, **ou** l'un des domaines de ses
   licences conseillées. La seconde branche est l'apport de cette route : pour
   un étudiant de « droit, économie », **594 masters** conseillent son domaine
   sans être classés dedans, et aucun filtre par domaine du diplôme ne les
   montrerait jamais.
2. **`open`** — l'établissement publie « Toutes licences » (302 masters). Vraie
   information, mais qui ne dit rien de l'étudiant : elle ne sert donc qu'à
   compléter un étage que la première strate n'a pas rempli.

Le `total` de chaque étage compte l'**étage entier** (réunion des deux
strates), pas la strate qui l'a rempli — sans quoi un étage pouvait annoncer
« 3 formations » en en montrant cinq.

### Paramètres

| Paramètre | Forme | Notes |
|---|---|---|
| `limit` | entier | Par étage. Défaut **5**, maximum **10**. Une valeur illisible retombe sur le défaut : une taille de page absurde n'est pas une raison de refuser la liste. |

### Réponse

```json
{
  "declaration": { "currentLevel": "licence", "targetLevel": "master", "fieldIds": ["d02"] },
  "path": "master",
  "blocked": null,
  "ranking": { "basis": "admission_effort" },
  "tiers": [
    {
      "tier": "securite",
      "total": 374,
      "items": [
        {
          "program": { "id": "eef-prog-…", "name": { "fr": "…", "en": "…" }, "…": "…" },
          "reasons": [
            { "code": "bachelor_domain_recommended", "value": "d02" },
            { "code": "admission_file_only", "value": "Dossier" }
          ]
        }
      ]
    }
  ],
  "limit": 5,
  "disclosures": [
    "tuition_not_published",
    "french_level_not_published",
    "campaign_dates_served_separately"
  ],
  "source": "database"
}
```

`program` est l'objet servi par la recherche et par `/catalog/*` (`mapProgram`) :
une fiche amputée obligerait le client à deux lectures de la même formation.

### Les motifs

Codes fermés, jamais de prose : la phrase se traduit côté client, ce qui
garantit la parité FR/EN par construction. Chaque code voyage avec la valeur
attestée qui l'a produit, pour que la justification soit vérifiable sur la
fiche officielle.

| Code | Valeur | Sens |
|---|---|---|
| `field_declared` | `d01`…`d12` | Le domaine de la formation est déclaré. |
| `bachelor_domain_recommended` | `d01`…`d12` | Une licence conseillée par l'établissement relève d'un domaine déclaré. |
| `bachelor_any_accepted` | `Toutes licences` | L'établissement publie qu'il accepte toute licence. |
| `admission_file_only` | `Dossier` | Candidature sur dossier. |
| `admission_interview` | `Entretien` | La candidature comporte un entretien. |
| `admission_exam` | `Examen`, `Concours` | La candidature comporte un examen ou un concours. |

**Aucun motif de sélectivité**, sur aucun chemin — `selectivity_open` et
`selectivity_arbitrated` ont été retirés le 02/10/2026, avant qu'aucun client ne
les lise. Sur un master, la sélectivité vaut `selective` pour chaque ligne — la
loi du 23 décembre 2016 en fait une règle, pas une caractéristique de
l'établissement. Sur le chemin post-bac, « non sélective » est la catégorie
Parcoursup des élèves de terminale française et ne dit rien d'un candidat en
DAP (« la capacité d'accueil est la seule limite publiée » y était faux). Le
fait reste écrit dans les exigences d'admission de chaque formation, que le
catalogue 1.3.0 formule pour la DAP.

Les motifs d'admission (`admission_*`) ne sont émis que sur le chemin `master` :
ils justifient l'étage, et c'est le seul chemin qui en a.

Une modalité hors du référentiel fermé **n'est pas servie comme motif** :
inventer un libellé donnerait à l'écran une phrase qu'il ne sait pas traduire.
La ligne, elle, reste classée par ce qu'on sait lire, et tombe dans `unranked`
si rien ne l'est.

### Ce que la réponse avoue

| Code | Sens |
|---|---|
| `tuition_not_published` | Les droits réellement payés dépendent d'une exonération que les données ouvertes ne publient pas. |
| `french_level_not_published` | Aucun jeu ouvert ne publie le niveau de français exigé formation par formation. |
| `campaign_dates_served_separately` | Les dates de campagne sont servies par `/config/app`, jamais figées dans une ligne de catalogue. |
| `no_field_declared` | Aucun domaine déclaré : la liste n'est resserrée sur aucune filière. |
| `no_ranking_data` | Le chemin d'entrée ne porte aucune donnée qui classe le candidat (`post_bac`, `licence_continuation`) : tout est `unranked`. |

Les trois premiers sont vrais pour chaque ligne du catalogue, donc dits une
fois en tête de réponse : les répéter par formation serait du bruit, les taire
ferait passer le silence pour une absence de frais, d'exigence ou d'échéance.

### Quand aucune liste n'est possible

**200**, avec `path: null` et un `blocked` qui nomme ce qui manque. La lecture a
réussi ; ce qui manque est une réponse de l'étudiant, et un 4xx ferait afficher
un écran de panne là où il faut poser une question. La déclaration partielle est
renvoyée telle quelle, pour que l'écran pré-remplisse ce qui était déjà dit.

| `blocked` | Ce que l'écran doit demander |
|---|---|
| `no_declaration` | La déclaration d'intérêt, qui n'existe pas encore. |
| `target_level_missing` | Le niveau visé — c'est lui qui décide du chemin, il est donc réclamé en premier. |
| `current_level_missing` | Le niveau courant, sans lequel « viser une licence » reste ambigu. |
| `declaration_unmappable` | Une correction : le couple déclaré n'est pas interprétable. |
| `level_not_in_catalog` | Rien. Le catalogue s'arrête au master ; il n'y a pas de champ à corriger. |

Aucune requête de catalogue n'est posée dans ces cas.

### Pas de repli sur les jeux de démonstration

Encore moins qu'ailleurs : ce n'est pas une liste demandée par mots-clés, c'est
une **recommandation nominative**. Servir des formations d'échantillon
reviendrait à recommander des établissements qui n'existent pas. Base
indisponible ⇒ **503 `CATALOG_UNAVAILABLE`**.

La route ne sert que des lignes **relues** (`isActive = true`) — vérifié sur la
base réelle : catalogue non relu ⇒ **0 servi sur 10 247** — et rattachées à la
France résolue par son **code**, par la règle partagée avec l'import et la
recherche (`eef-country.ts`).

Comme la recherche, elle exige un **établissement publié** : une recommandation
nominative dont l'établissement n'a jamais été relu serait la pire surface
possible pour cette barrière. La liste des établissements publiés est lue une
fois et sert à chaque étage et à chaque total.

Les étages et leurs totaux sont lus dans **une seule transaction**
`RepeatableRead` : servis séparément, une publication concurrente ferait
apparaître la même formation dans deux colonnes, ou dans aucune.

## Espace « Études en France » (Phase 0)

- `GET /etudes-en-france/interest`
- `POST /etudes-en-france/interest`

Authentifiés (`StudentAuthGuard`) : une déclaration d'intérêt sans identité ne
serait pas rappelable, et c'est le contact qu'on cherche à collecter.

Purpose:
- enregistrer qui veut être prévenu à l'ouverture de l'espace, et qui se déclare
  intéressé par le Premium

Réponse (les deux routes) :

```json
{
  "declared": true,
  "currentLevel": "terminale",
  "targetLevel": "licence",
  "fieldIds": ["info"],
  "wantsPremium": true,
  "consentedAt": "2026-08-21T10:00:00.000Z"
}
```

Deux invariants que le client suppose, et sur lesquels des tests existent des
deux côtés :

- **`declared: true` est la seule preuve d'écriture.** Un 2xx dont le corps ne
  l'affirme pas est traité par le client comme un ÉCHEC. Un 200 n'est pas une
  preuve d'écriture ; le corps l'est.
- **Le service échoue fermé.** Base indisponible ⇒ `503`, jamais un objet
  d'apparence normale. Rendre un succès sans écriture ferait afficher « c'est
  noté » pour une ligne qui n'existe nulle part.

`consentedAt` est horodaté par le SERVEUR à la réception, donc non antidatable
par un client, et rafraîchi à chaque redéclaration : la preuve qui compte est le
dernier consentement donné.

L'écriture est un `upsert` sur `userId` (unique) : une redéclaration corrige la
ligne au lieu d'en créer une seconde.

### `PATCH /etudes-en-france/interest`

Met à jour les **niveaux et les domaines** d'une déclaration existante — rien
d'autre. Comptes `student` seulement.

```json
{ "targetLevel": "master", "fieldIds": ["d07", "d02"] }
```

- **Ne touche ni au consentement ni à l'intérêt Premium.** `POST` est un
  remplacement complet : `wantsPremium` retombe à `false` s'il n'est pas renvoyé
  et `consentedAt` / `consentVersion` sont réécrits à chaque appel. S'en servir
  pour « modifier mon profil » effacerait l'intérêt Premium et fabriquerait un
  consentement au rappel commercial que l'étudiant n'a pas redonné. Le `PATCH`
  n'écrit que les colonnes reçues ; `consent`, `consentVersion`, `wantsPremium`
  (et tout champ inconnu) sont **refusés en 400**, pas ignorés.
- **Trois états par champ** : absent = inchangé ; chaîne vide ou tableau vide =
  effacé ; valeur = remplacée. `null` est refusé (400).
- **Corps sans aucun champ** : 400.
- **Sans déclaration préalable : 404 `EEF_INTEREST_NOT_DECLARED`**, jamais une
  création — la ligne existerait sans consentement. Le client passe par `POST` et
  sa feuille de consentement.
- Réponse : la même forme que `POST`, avec le `consentedAt` **d'origine**.

### `DELETE /etudes-en-france/interest`

Retire la déclaration du profil authentifié. **Idempotente** : retirer une
déclaration absente rend le même corps que retirer celle qui existait
(`declared: false`), parce que le résultat qui compte est « cette personne n'est
plus dans la liste » et qu'un 404 obligerait l'écran à distinguer deux cas pour
afficher la même chose.

Cette route existe parce que le texte de consentement promet un retrait. Elle a
manqué : la promesse a précédé le mécanisme, et les seules issues réelles étaient
d'écrire à une adresse générique ou de supprimer le compte entier pour retirer
une ligne de prospection.

**Invariant client** : un corps qui dit encore `declared: true` est traité comme
un ÉCHEC. Afficher « tu es retiré » sur une ligne toujours en base est le même
mensonge que « c'est noté » sur une ligne jamais écrite.

### Les bornes de campagne sont des JOURS, pas des instants

**Format du fil : `AAAA-MM-JJ`, un jour nu.** `/config/app` sert `opensAt` /
`closesAt` sans heure ni décalage, quoi que l'exploitation ait écrit dans la
variable d'environnement. Le client relit les composantes du texte reçu, ce qui
en fait une seconde ligne de défense et non le mécanisme principal.

Ce format est une correction, et elle a deux moitiés parce que le défaut en avait
deux. La borne était sérialisée en instant UTC par le serveur, puis reprojetée
dans le fuseau de l'appareil par le client :

| Valeur écrite par l'exploitation | Servie autrefois | Fuseau du téléphone | Ce qui s'affichait |
|---|---|---|---|
| `2026-10-01T00:00:00Z` | `2026-10-01T00:00:00.000Z` | UTC+0/+1 (Dakar, Niamey) | 1er octobre ✓ |
| `2026-10-01T00:00:00Z` | `2026-10-01T00:00:00.000Z` | UTC−1/−4 (Cabo Verde, diaspora) | **30 septembre** ✗ |
| `2026-10-01T00:00:00+02:00` (heure de Paris) | **`2026-09-30T22:00:00.000Z`** | **tous** | **30 septembre** ✗ |

La dernière ligne est celle qui compte, et elle explique pourquoi le correctif
client ne suffisait pas : `new Date(raw).toISOString()` avait déjà détruit le
jour côté serveur. Aucune lecture du fil ne pouvait le retrouver — et écrire
l'heure de Paris est le réflexe naturel pour une procédure française, donc ce
n'était pas un cas de bord mais le cas de production, donnant la mauvaise date à
**tout le public d'un coup**.

Deux conséquences pour qui pose ces variables :

- **N'écrivez pas d'heure.** `2026-10-01` est la forme attendue. Une heure
  écrite est ignorée — `2026-10-01T23:30:00-05:00` désigne bien le 1er octobre —
  mais elle laisse croire qu'elle compte, et c'est cette croyance qui a produit
  le défaut.
- **Les deux bornes sont INCLUSIVES.** « Jusqu'au 15 novembre » inclut le 15
  entier. La comparaison était auparavant faite sur l'instant, donc la campagne
  passait « close » à la première seconde du jour de clôture — un étudiant
  ouvrant l'app le matin de sa date limite lisait que c'était terminé.

Une valeur illisible, un mois 13 ou un 30 février rendent `null` **des deux
côtés**, et l'app n'annonce alors AUCUNE date. `new Date(Date.UTC(2026, 12, 1))`
vaut janvier 2027 et `DateTime(2026, 1, 32)` vaut le 1er février : normaliser
une faute de frappe fabriquerait une échéance que personne n'a écrite, et
qu'un étudiant lirait comme une information.

Gardé par `test/release/campaign_wire_day_test.dart` (le format du fil) et
`test/features/etudes_en_france/eef_campaign_day_test.dart` (le décodage). Le
premier existe parce que les deux côtés étaient verts pendant que le défaut
vivait dans la couture : les tests mobiles décodaient la valeur d'exploitation
directement, contournant la normalisation serveur, et un test backend figeait
cette normalisation comme contrat.

### Interrupteurs de la build 56 dans `features` : `eefHelpBubble`, `eefPrivateSchools`

Deux booléens **stricts** ajoutés à `features`, toujours présents dans la réponse du backend
de la 56, **`false` par défaut**. Un backend plus ancien ne les sert pas : le client lit une
clé absente comme `false` (comme une valeur non booléenne, ou un serveur injoignable).

| Clé | Variable d'environnement | Sens |
|---|---|---|
| `features.eefHelpBubble` | `KPB_EEF_HELP_BUBBLE_ENABLED` | La bulle « Une question ? » du hub et du catalogue. |
| `features.eefPrivateSchools` | `KPB_EEF_PRIVATE_SCHOOLS_ENABLED` | La ligne et la feuille d'information sur les écoles privées. |

Ils sont **indépendants** : ils ne dérivent ni de `eef` (l'ancien commutateur, qui ouvre
`eefSpace`), ni de `eefSpace`, ni l'un de l'autre, et ouvrir l'un ne modifie aucune autre
clé. Le client exige `eefSpace` vrai EN PLUS pour montrer quoi que ce soit. Seule la valeur
`true` (casse et espaces tolérés) les ouvre. Ouverture et fermeture : actions `vps-ops`
`eef-bubble-on|off` et `eef-private-schools-on|off` (`docs/runbook-ouverture-espace-reel.md`).
Gardé par `backend/src/modules/config/app-config.controller.spec.ts`,
`test/core/services/remote_feature_flags_test.dart`, `test/release/config_env_relay_test.dart`
(relais compose) et `test/release/vps_ops_eef_switches_test.dart`.

### Interrupteurs « Suivre » / Mes suivis / notifications dans `features`

Booléens ajoutés à `features` (chantiers G puis K), **`true` par défaut** côté serveur comme côté app.
Ils existent pour **couper** une fonction de la build sur les téléphones installés, sans
soumission store. Seule la valeur `false` (casse et espaces tolérés) les ferme ; une variable
absente, vide ou mal tapée les laisse ouverts. Un backend plus ancien ne les sert pas : l'app
lit une clé absente comme `true`.

| Clé | Variable d'environnement | Sens |
|---|---|---|
| `features.followPushPrimer` | `KPB_FOLLOW_PUSH_PRIMER_ENABLED` | Feuille d'explication avant la demande d'autorisation, au premier « Suivre ». |
| `features.followOpeningAlert` | `KPB_FOLLOW_OPENING_ALERT_ENABLED` | « Suivre » pose aussi l'alerte d'ouverture (`POST /me/scholarship-alerts/:id`). |
| `features.openingAlertToggle` | `KPB_OPENING_ALERT_TOGGLE_ENABLED` | Interrupteur « Me prévenir à l'ouverture » de la fiche. |
| `features.followedScholarships` | `KPB_FOLLOWED_SCHOLARSHIPS_ENABLED` | Section « Bourses suivies » de Mes suivis. |
| `features.notificationsUnreadCount` | `KPB_NOTIFICATIONS_UNREAD_COUNT_ENABLED` | Point de la cloche allumé par les non-lus serveur. |
| `features.followedScholarshipOptOut` | `KPB_FOLLOWED_SCHOLARSHIP_OPT_OUT_ENABLED` | Ligne de préférence « Bourses que je suis ». |
| `features.homeFollowedEntry` | `KPB_HOME_FOLLOWED_ENTRY_ENABLED` | Bouton « Mes suivis » de l'accueil. |
| `features.homeNextStep` | `KPB_HOME_NEXT_STEP_ENABLED` | Carte « Ta prochaine étape » de l'accueil élève. |
| `features.homeScholarships` | `KPB_HOME_SCHOLARSHIPS_ENABLED` | Section « Tes bourses » de l'accueil. |
| `features.homeDeadlines` | `KPB_HOME_DEADLINES_ENABLED` | Section « Tes échéances » de l'accueil élève. |
| `features.homePartners` | `KPB_HOME_PARTNERS_ENABLED` | Bloc écoles partenaires de l'accueil. |
| `features.homeIntelligence` | `KPB_HOME_INTELLIGENCE_ENABLED` | Entrée KPB Intelligence de l'accueil. |
| `features.homeParcours` | `KPB_HOME_PARCOURS_ENABLED` | Bloc Parcours de l'accueil. |
| `features.homeCounselor` | `KPB_HOME_COUNSELOR_ENABLED` | Bloc conseiller WhatsApp de l'accueil. |

Gardé par `backend/src/modules/config/app-config.controller.spec.ts` et
`test/release/config_env_relay_test.dart` (relais compose).

### Interrupteur « Mes 10 bourses » dans `features` : `scholarshipMatch`

Un booléen **strict**, toujours présent, **`false` par défaut** (seule la valeur `true`, casse
et espaces tolérés, l'ouvre). Un backend plus ancien ne le sert pas : l'app lit une clé absente
comme `false`.

| Clé | Variable d'environnement | Sens |
|---|---|---|
| `features.scholarshipMatch` | `KPB_SCHOLARSHIP_MATCH_ENABLED` | La carte du test « Mes 10 bourses » et ses résultats. La MÊME variable coupe les routes `/scholarships/match/*` (404 `{disabled: true}`). |

Indépendant de tout autre drapeau. Gardé par `backend/src/modules/config/app-config.controller.spec.ts`
et `test/release/config_env_relay_test.dart` (relais compose, défaut `false`). Contrat des routes :
section « Mes 10 bourses » plus bas.

### Interrupteur « Onboarding la valeur d'abord » dans `features` : `onboardingV2`

Un booléen **strict**, toujours présent, **`false` par défaut** (seule la valeur `true`, casse
et espaces tolérés, l'ouvre). Un backend plus ancien ne le sert pas : l'app lit une clé absente
comme `false` et garde l'ancien parcours.

| Clé | Variable d'environnement | Sens |
|---|---|---|
| `features.onboardingV2` | `KPB_ONBOARDING_V2_ENABLED` | Nouvel onboarding (chantier I3) : aucun champ pré-rempli sans choix de l'élève (niveau, pays, domaine, budget…), « Passer » dès la page 1, erreurs affichées dans le champ. Coupé : l'ancien parcours, inchangé. |

Purement côté app : aucune route serveur ne dépend de ce drapeau, et le contrat de
`PATCH /profiles/me` est inchangé (un champ non choisi n'est simplement pas envoyé). L'âge et
le consentement du tuteur restent exigés dans les deux parcours. Indépendant de tout autre
drapeau. Gardé par `backend/src/modules/config/app-config.controller.spec.ts` et
`test/release/config_env_relay_test.dart` (relais compose, défaut `false`).

### Ce que `GET /config/app` sert d'autre que des drapeaux (build 54)

Route publique, sans authentification. Quatre ajouts, tous **absents sur un
serveur plus ancien** — le client les traite comme « rien à afficher », jamais
comme une valeur de repli :

| Clé | Forme | Variable d'environnement | Sens |
|---|---|---|---|
| `recommendedVersion` | `"2.3.0"` ou `null` | `KPB_RECOMMENDED_APP_VERSION` | En dessous, l'app affiche un bandeau **qu'on ferme**. À ne pas confondre avec `minVersion`, qui bloque l'app derrière un écran sans sortie. Une valeur qui n'est pas `x.y.z` vaut `null` : « pas de bandeau », jamais « bandeau pour tous ». |
| `eefCampaign.platformUrl` | URL https | `KPB_EEF_PLATFORM_URL` | La plateforme officielle, affichée sous la date et dans la mention de non-affiliation. Repli serveur vérifié : `https://www.campusfrance.org/fr`. |
| `eefCampaign.suspendedSources` | `[{country, url}]` | `KPB_EEF_SUSPENDED_SOURCES` (`Pays\|https://…;Autre\|https://…`) | La page officielle qui justifie la suspension d'un pays. **Un élément par pays de `suspendedCountries` seulement** : la source d'une suspension ne voyage pas sans suspension. Connue sans configuration : le Niger (`ne.diplomatie.gouv.fr/informations-visas`). |
| `eefCatalog` | `{producer, producerUrl, licence, licenceUrl, sources[], updatedAt, catalogVersion}` | — (constante) | La mention de paternité de la Licence Ouverte 2.0, posée en pied de l'écran catalogue. `updatedAt` est un **jour nu** `AAAA-MM-JJ`. |

### Suspension des visas étudiants américains : `usVisaSuspension` (17/10/2026)

Toujours présente. Sert l'avis des fiches établissement, formation et pays des
**États-Unis** : « Les demandes de visa étudiant sont actuellement suspendues
pour les ressortissants de : … ».

```json
"usVisaSuspension": {
  "countries": [{ "code": "BF", "nameFr": "Burkina Faso", "nameEn": "Burkina Faso" }, …],
  "visaTypes": ["F", "M", "J"],
  "lastVerifiedAt": "2026-10-17",
  "sourceUrl": "https://travel.state.gov/content/travel/en/News/visas-news/suspension-of-visa-issuance-to-foreign-nationals-to-protect-the-security-of-the-united-states.html"
}
```

| Variable d'environnement | Effet |
|---|---|
| `KPB_US_VISA_SUSPENDED_COUNTRIES` | Codes ISO alpha-2 séparés par des virgules. **Vide : la liste vérifiée le 17/10/2026** (proclamation 10998 : BF, ML, NE, TD, CG, BJ, CI, SN, GA, MR, BI, TG). `none` : liste vide, l'app ne montre plus l'avis. Une valeur sans aucun code lisible garde le défaut (une faute de frappe ne retire pas l'avis). |
| `KPB_US_VISA_SUSPENSION_VERIFIED_AT` | Jour `AAAA-MM-JJ` de la vérification. Une liste personnalisée sans date est servie avec `lastVerifiedAt: null`. |
| `KPB_US_VISA_SUSPENSION_SOURCE_URL` | La page officielle ouverte par le bouton (https seulement). Défaut : la page du Département d'État ci-dessus. |

**Mettre la liste à jour, sans build** : poser les variables dans le `.env` du
VPS (elles sont relayées par `docker-compose.yml`), recréer le conteneur API,
puis relire `curl https://…/api/config/app | jq .usVisaSuspension`. L'app
embarque la même liste par défaut (`lib/app/core/models/us_visa_suspension.dart`)
pour un serveur plus ancien ou injoignable ; elle la remplace dès que la
réponse arrive.

**Vie privée** : l'app compare la liste au pays de résidence du profil, **sur le
téléphone**. Aucun pays, aucune nationalité, aucun « concerné / pas concerné »
ne part vers le serveur ni vers les mesures d'audience (le renvoi WhatsApp
mesuré porte une source et un contexte constants : `us_visa_notice` /
`us_visa`).

**Toute URL servie est `https`, sans identifiants**, sinon elle est écartée :
ces valeurs sont écrites à la main, et `javascript:` ne doit jamais atteindre un
bouton « ouvrir ». Côté client, une adresse non ouvrable masque le lien au lieu
de l'afficher mort.

**`eefCatalog` est une constante TypeScript** (`eef-catalog-attribution.ts`), pas
une lecture de `manifest.json` : le manifeste vit dans `src/` et n'est pas copié
dans `dist/`, donc le lire au démarrage marcherait en test et échouerait en
production, en silence. Le risque devient qu'elle oublie un réimport, et
`eef-catalog-attribution.spec.ts` le couvre : il compare la constante au
manifeste (version, jour de récupération, familles de jeux citées, licence) et
**échoue au premier réimport qui ne la met pas à jour**.

#### En-têtes de version de l'app

Depuis la build 54, chaque requête de l'app porte `X-KPB-App-Version`
(`2.3.0`) et `X-KPB-App-Build` (`54`). Avant, le serveur ne pouvait pas
distinguer une 53 d'une 54 : toute décision « par version » — montrer des lignes
aux seules builds qui savent les afficher, mesurer qui a mis à jour — était
impossible. La version d'une application publiée est la même pour tous ses
utilisateurs : ce n'est ni un identifiant ni une donnée de profil. Un en-tête
absent (build antérieure, plugin indisponible) ne doit jamais faire échouer une
requête.

Le serveur les lit depuis le 13/10/2026 (`AppBuildInterceptor`,
`backend/src/modules/app-builds/`), pour les seules requêtes authentifiées par
`StudentAuthGuard` : il note sur le profil la dernière version, la dernière
build et la date de passage (`lastAppVersion`, `lastAppBuild`,
`lastAppSeenAt`). Rien ne change sur le fil — ni route, ni corps, ni code de
réponse — et l'écriture n'est pas attendue : au plus une par compte et par 6 h,
plus tôt seulement si la build ou la version change (une mise à jour), jamais
plus d'une par minute. Une valeur illisible (version hors motif `2.3.0[-suffixe]` ou plus de
32 caractères, build hors 1–9 999 999, en-tête répété) vaut « inconnue » et
n'efface jamais une valeur déjà connue. Une requête sans en-tête rafraîchit
quand même la date : un compte vu sans build connue est une build ≤ 53, pas un
compte inactif. Lecture en agrégat seulement : `GET /admin/app-builds`.

### Le consentement, sur le fil

`POST /etudes-en-france/interest` exige deux champs, et les refuse absents :

| Champ | Règle |
|---|---|
| `consent` | doit valoir exactement `true`. Un `false` explicite est refusé, pas enregistré |
| `consentVersion` | l'identifiant du texte affiché à l'écran, borné à 64 caractères |

`consentedAt` reste horodaté **par le serveur** : le client ne l'envoie pas et ne
peut donc pas l'antidater. Mais l'horodatage seul ne prouvait que « non
antidatable » — sans `consent`, un `POST` au corps vide fabriquait une preuve de
consentement, le `now()` ayant simplement déménagé de Postgres vers Node. Et sans
`consentVersion`, on ne pourrait produire qu'une date, jamais la phrase acceptée.

`test/features/etudes_en_france/eef_consent_version_test.dart` apparie la
constante client à une empreinte des textes FR et EN : le texte ne peut plus
changer sans que la version bouge.

### `DELETE /admin/etudes-en-france/interest/:id`

Le même retrait, exécuté par l'équipe pour une demande reçue par e-mail ou
WhatsApp. Ouvert aux mêmes rôles que la LECTURE — pas restreint à
l'administration comme l'export : l'export fait sortir des données du périmètre,
ce retrait les fait disparaître, et un droit qu'on exerce lentement s'exerce mal.

## Admin — liste d'intérêt « Études en France »

- `GET /admin/etudes-en-france/interest/summary`
- `GET /admin/etudes-en-france/interest?take=&skip=`
- `GET /admin/etudes-en-france/interest/export.csv`

Rôles : `admin`, `super_admin`, `commercial`, `counselor`. Volontairement PAS
`moderator` ni `content_manager` — ce sont des noms, des e-mails et des numéros
de téléphone, et la modération de forum n'a rien à en faire.

Purpose:
- lire et exporter la liste des prospects, sans quoi elle ne quitte jamais
  Postgres et personne ne rappelle personne

L'export est servi en `text/csv; charset=utf-8` avec
`Content-Disposition: attachment`, un BOM UTF-8 (sans lui Excel sous Windows
rend « Côte d'Ivoire » en « CÃ´te d'Ivoire »), et chaque cellule neutralisée
contre l'évaluation de formules par un tableur — voir `eef-interest-csv.ts`.

## Admin — publication de l'import « Études en France »

- `GET  /admin/etudes-en-france/publication/institutions`
- `POST /admin/etudes-en-france/publication/institutions/:id/publish`
- `POST /admin/etudes-en-france/publication/institutions/:id/unpublish`

Rôles : `admin`, `super_admin` **seulement** — `content_manager` édite le
catalogue mais ne signe pas sa publication. Sans session administrateur la route
répond 401 : le relecteur inscrit est celui de la SESSION, jamais un identifiant
fabriqué. Publier est l'acte qui rend visibles, à un étudiant sans compte
(`/etudes-en-france/search` est publique), des fiches que personne n'avait relues.

Corps de `publish` et `unpublish` (tout est optionnel) :

```json
{ "apply": false, "programIds": ["eef-prog-…"], "expectedPrograms": 153 }
```

- **`apply` absent ou faux : simulation.** La réponse est le PLAN, rien n'est
  écrit. `apply` doit être le booléen `true` (une chaîne ou un nombre → 400).
- **Pour écrire, `expectedPrograms` doit valoir exactement le nombre annoncé par la
  simulation** (`plan.programs.toPublish.length`, ou `toDeactivate.length` au
  retrait). Absent → 400 ; différent → 409 et rien n'est écrit. C'est une
  confirmation saisie et un contrôle de concurrence à la fois.
- `programIds` restreint l'acte à ces formations (au moins une, sans doublon,
  5 000 au plus). Sans lui : toutes les formations encore inactives de
  l'établissement — au retrait, toutes les formations publiées ET l'établissement.
  Avec lui, l'établissement reste publié au retrait.
- Le plan est **recalculé dans la transaction d'écriture**, qui s'exécute en
  `RepeatableRead` ; une formation qui n'est plus publiable, ou que quelqu'un
  d'autre a publiée ou modifiée entre-temps, annule l'ensemble (409, rien n'est
  écrit).
- **Les routes génériques ne publient pas l'import.** `PATCH /admin/catalog/programs/:id`,
  `PATCH /admin/catalog/institutions/:id` et `POST /admin/catalog/programs` répondent
  **409** quand elles ACTIVERAIENT une ligne de l'import (préfixe `eef-prog-` /
  `eef-univ-`, ou formation sous un établissement de l'import) qui n'est pas déjà
  publiée : sans cela, elles contourneraient la vérification de la source, de la
  procédure et du domaine, et la signature du relecteur. Désactiver et modifier une
  ligne déjà publiée restent permis ; les fiches de l'équipe ne sont pas concernées.

Réponse d'une simulation de publication :

```json
{
  "mode": "dry-run",
  "plan": {
    "institutionId": "eef-univ-…",
    "institutionName": "…",
    "institution": { "alreadyActive": false, "willActivate": true, "refusals": [] },
    "programs": {
      "toPublish": ["eef-prog-…"],
      "alreadyActive": 0,
      "refused": [{ "id": "…", "nameFr": "…", "reasons": ["program_procedure_missing"] }],
      "activeInvalid": [],
      "genericSource": { "ministryPortal": 0, "ministryDataset": 0 }
    },
    "publishable": true,
    "nothingToDo": null
  }
}
```

Refus d'établissement : `institution_not_from_import` (une fiche partenaire n'est
jamais publiable par cette voie), `institution_source_missing` (source absente ou
non HTTPS), `institution_has_invalid_active_program` (au moins une formation
DÉJÀ active sous cet établissement encore en attente ne passe pas les contrôles :
l'activer la rendrait visible ; elle est listée dans `programs.activeInvalid`, avec
ses motifs). Refus de formation : `program_unknown`, `program_not_from_import`,
`program_wrong_institution`, `program_source_missing`,
`program_procedure_missing`, `program_field_unknown`. Un établissement refusé
annonce `toPublish: []`. Une écriture sans rien à publier répond 422 avec le plan.

`programs.genericSource` compte, parmi les formations à publier, celles dont la
source n'est pas la fiche de la formation : racine du portail Mon Master
(`ministryPortal`) ou page du jeu de données ouvert (`ministryDataset`). C'est un
signal, jamais un refus (`docs/eef-catalog-pipeline.md` § 2.8).

Une écriture réussie répond `mode: "applied"` avec `programsPublished`,
`institutionActivated`, `verifiedBy` (`id`, `name`) et `verifiedAt`. Elle pose
`isActive`, `lastVerifiedAt`, `verifiedById` et `verifiedByName` sur chaque
formation publiée, et sur l'établissement **quand il devient visible ou n'avait
aucun tampon** : le relecteur d'hier n'est pas écrasé. Le retrait ne touche PAS
aux tampons, et annonce `plan.savedByStudents` : le nombre d'étudiants qui
perdent la formation de leur liste (leur enregistrement, lui, n'est pas supprimé).

`GET …/institutions` liste les établissements de l'import (jamais un partenaire)
avec `programsPending`, `programsPublished`, `hasLogo`, la source et le dernier
relecteur, plus les totaux.

## Admin — file de revérification du catalogue

- `GET /admin/catalog/verification-due` (rôles `admin`, `super_admin`, `content_manager`)

Les fiches dont la revérification est due : jamais vérifiées, ou vérifiées il y a
plus que la cadence de leur catégorie (pays et bourses 30 jours ; établissements
et formations 180 jours). Pays et bourses : actifs seulement (les bourses aussi
APPROUVÉES). Établissements et formations : actifs ou non — une fiche non EEF que
l'équipe a désactivée à la main reste dans la file —, à l'exception des lignes de
l'import encore en attente (voir plus bas).

```json
{
  "items": [
    {
      "entityType": "institution",
      "id": "…",
      "label": "…",
      "context": "…",
      "category": "institution_scolarite",
      "categoryLabel": "…",
      "cadenceDays": 180,
      "owner": "…",
      "lastVerifiedAt": null,
      "verifiedByName": null,
      "sourceUrl": null,
      "dueAt": null,
      "daysSinceVerification": null,
      "isOverdue": true
    }
  ],
  "total": 1234,
  "truncated": true,
  "policies": [ … ]
}
```

- **`items` est plafonné à 500.** L'ordre est TOTAL : les jamais-vérifiés d'abord
  (les plus périssables en tête — une bourse à 30 jours avant une formation à 180),
  puis les vérifiées par ÉCHÉANCE la plus ancienne, puis par identifiant. Par
  échéance et non par âge : une bourse vérifiée il y a 100 jours est en retard de
  70 jours, une formation vérifiée il y a 181 jours l'est de un.
  **Le plafond n'affame aucune catégorie** : chacune de celles qui ont des lignes
  reçoit au moins 500 ÷ (nombre de catégories présentes) places — 125 avec les
  quatre —, le reste se remplit dans l'ordre global, et la réponse garde l'ordre
  global. Sans cela, deux universités publiées d'un coup (plus de 800 formations
  « jamais vérifiées ») chassaient toutes les bourses en retard de la page.
  **`total`** est le compte COMPLET ; **`truncated`** vaut `true` quand il en
  reste (strictement plus de 500).
- `total` et `truncated` sont additifs pour la FORME de la réponse, pas pour son
  contenu : l'admin déjà déployé afficherait « 500 ouvertes » sans avertissement
  pour une file de 10 599. Déployer l'API et l'admin ensemble (`deploy.yml`, scope
  `full`, remplace les deux). Côté admin, l'absence de `total` se lit « la longueur
  de la liste » : un nouvel admin sur un ancien backend fonctionne.
- La page `/verification` affiche un avis quand la file est tronquée, ne baisse
  le compte qu'UNE fois par ligne validée (un double clic ne le fausse plus), et
  distingue « tout est traité » de « les lignes affichées sont traitées, d'autres
  attendent » (bouton pour recharger).
- **Les lignes de l'import « Études en France » encore en attente n'y sont
  pas** (identifiant `eef-…` ET `isActive = false`) : leur revue est le flux de
  PUBLICATION, qui demande un outil dédié — **à construire**. Valider une ligne
  ici ne pose que le tampon de vérification (`lastVerifiedAt`, `verifiedByName`),
  jamais `isActive`. Une ligne EEF publiée y entre normalement ; une fiche non
  EEF désactivée à la main, aussi.
- **Une seule définition** (`backend/src/modules/admin-catalog/verification-due.ts`,
  les QUATRE catégories : pays, établissements, formations, bourses) sert la file,
  le SLA quotidien de 07 h et le compteur « Action immédiate requise » du tableau
  de bord. Un test fait tourner les trois sur une horloge figée et exige les
  mêmes clauses, catégorie par catégorie. Le SLA compte sur la file COMPLÈTE,
  jamais sur la version plafonnée.

## Admin — éligibilité structurée des bourses (« Mes 10 bourses », chantier D4)

Gardes `AdminAuthGuard` + `RolesGuard`, rôles admin, super_admin,
content_manager (comme l'édition du contenu des bourses). Le moteur est celui de
`backend/src/modules/scholarship-match/` (assess, rank, reasons), réutilisé tel
quel. Les routes à segment fixe sont déclarées AVANT `AdminScholarshipsController`.

### Écriture : `POST /admin/catalog/scholarships` et `PATCH /admin/catalog/scholarships/:id` (étendues)

Champs additionnels, lus STRICTEMENT (une valeur présente mais invalide → 400,
rien n'est écrit) ; une clé absente laisse la colonne intacte :

| Champ | Forme |
| --- | --- |
| `eligibleLevels` | `('secondary'\|'bachelor'\|'master'\|'doctorate')[]` ; `null` = vide. 400 `INVALID_ELIGIBLE_LEVELS`. |
| `fieldsScope` | `'unknown'\|'all'\|'listed'` ; `null` = `unknown`. 400 `INVALID_FIELDS_SCOPE`. |
| `eligibilityCriteria` | Critères v1 (`eligibility-criteria.ts`), vérifiés par `validateEligibilityCriteria` ; la copie normalisée est stockée. 400 `INVALID_ELIGIBILITY_CRITERIA` avec `message: string[]` et `issues: [{path, code, message}]` (`path` = `[2].countries[0]`). |
| `markStructured` | `true` : « Conditions vérifiées » — tamponne `eligibilityStructuredAt` (maintenant) et `eligibilityStructuredBy` (nom de l'admin, sinon e-mail) sur le contenu FINAL ; 400 `ELIGIBILITY_LEVELS_REQUIRED` sans niveau, 400 `INVALID_ELIGIBILITY_CRITERIA` si les critères stockés sont illisibles. `false` : retire le tampon. |

Un contenu d'éligibilité MODIFIÉ sans `markStructured: true` retire le tampon
(la fiche redevient un brouillon : ses règles n'excluent plus). Rien de changé,
rien de demandé : aucune écriture. Chaque écriture d'éligibilité écrit, dans la
même transaction, un `AdminAuditEvent` : `purposeCode: 'scholarship_eligibility'`,
`entityType: 'Scholarship'`, `action` ∈ `scholarship.eligibility_updated |
scholarship.eligibility_structured | scholarship.eligibility_unstamped`,
`changes` = `{changedFields, eligibleLevels, fieldsScope, criteriaCount,
criteriaKeys, stamped, stampCleared, previousStructuredAt}` (aucune donnée
personnelle, aucune citation). `GET /admin/scholarships/moderation` sert
désormais `eligibleLevels`, `fieldsScope`, `eligibilityCriteria`,
`eligibilityStructuredAt` et `eligibilityStructuredBy`.

### Routes

| Route | Rôle |
| --- | --- |
| `GET /admin/scholarships/eligibility-coverage` | Porte de lancement, sur les bourses PUBLIQUES (`publicScholarshipWhere`) : `{generatedAt, freshnessDays: 400, launchGatePercent: 90, total, structuredFresh, stale, unstructured, notAnalyzed, invalidCriteria, coveragePercent, launchReady, toStructure: [{id, nameFr, nameEn, state, structuredAt, structuredBy}], toStructureIds, truncated}`. `state` ∈ `not_analyzed` (aucun niveau) `\| unstructured` (jamais tamponnée) `\| stale` (tampon ≥ 400 j) ; liste triée dans cet ordre puis par nom, 500 au plus. `coveragePercent` est arrondi PAR DÉFAUT à 0,1 ; `launchReady` = `structuredFresh / total ≥ 90 %` (faux sur un catalogue vide). |
| `GET /admin/scholarships/eligibility-options` | Table ISO 3166-1 du serveur (`common/iso-countries.ts`) pour l'éditeur : `{countries: [{code, nameFr, nameEn, priority, selectable}], freshnessDays, launchGatePercent, maxResults}`. `selectable: false` pour un territoire inhabité (valide dans un critère, jamais proposé à un élève). |
| `POST /admin/scholarships/match-preview` | « Tester un profil », SANS RIEN PERSISTER. Corps `MatchPreviewDto` : les champs du test (`nationalityCode`, `secondNationalityCode`, `countryOfResidence`, `birthDate` AAAA-MM-JJ, `guardianConsented`, `highestDiploma`, `scholarshipTargetLevel`, `fieldIds[]`, `targetCountryIds[]`, `gradeBandOn20`, `englishLevel`, `frenchLevel`, `languageTests[]`, `workExperienceBand`), plus `lang`, `confirmed` (défaut `true`) et `focusScholarshipId` (une fiche évaluée à part, publique ou non). Jetons tolérants : un jeton inconnu est abandonné et nommé dans `dropped`, jamais une 400 ; un champ non déclaré → 400. Réponse 200 : `{persisted: false, algorithmVersion, generatedAt, lang, profile, dropped, readiness, counts, items (≤ 10, rang, section), beyondLimitCount, excluded, excludedSummary, notAnalyzed, focus}` ; chaque point porte `code`, `label` (rendu serveur), `criterionKey?`, `officialText?`, `sourceUrl?`. Candidates : exactement celles du test élève (`CandidateSnapshotService` : bourses publiques, 500 au plus, même ordre de coupe, même cycle servi — ouvert, sinon prévision, sinon le plus récent), relues à chaque appel au lieu du cache de 60 s ; aucune écriture. |

## Admin content operations

- `GET /admin/service-offers`
- `POST /admin/service-offers`
- `PATCH /admin/service-offers/:id`
- `GET /admin/support-destinations`
- `POST /admin/support-destinations`
- `PATCH /admin/support-destinations/:id`
- `GET /admin/articles`
- `POST /admin/articles`
- `PATCH /admin/articles/:id`
- `GET /admin/forum-categories`
- `POST /admin/forum-categories`
- `PATCH /admin/forum-categories/:id`
- `GET /admin/forum-tags`
- `POST /admin/forum-tags`
- `PATCH /admin/forum-tags/:id`
- `GET /admin/forum-moderation`

Purpose:
- let operations teams add service offers, destination coverage, articles, forum categories, and topic tags from the dashboard

## Admin notifications

- `GET /admin/notifications/templates`
- `POST /admin/notifications/templates`
- `PATCH /admin/notifications/templates/:id`
- `GET /admin/notifications/campaigns`
- `POST /admin/notifications/campaigns`
- `POST /admin/notifications/campaigns/preview`
- `GET /admin/notifications/campaigns/:id/deliveries`

Purpose:
- manage grouped or specific campaigns across push, in-app, and email channels
- attach critical campaign events to case timelines when needed

## Audiences de campagne « Études en France » (LIV-24)

Deux audiences de campagne s'ajoutent à `all_students`, `country`, etc. :

| Audience | Filtre | Qui |
|---|---|---|
| `eef_interest` | aucun exigé ; `exceptCountries` optionnel | Les étudiants qui ont une ligne `EefInterest` — donc qui ont déclaré leur intérêt **et** accepté d'être rappelés (un retrait supprime la ligne). L'ensemble est borné par la table : elle ne peut pas retomber sur « tout le monde ». |
| `all_students_except_countries` | `exceptCountries` **exigé** | Tous les étudiants sauf les pays donnés. Une exclusion absente, vide ou illisible donne **zéro** destinataire — jamais « tous les étudiants », la diffusion que ce nom prétend éviter. |

`exceptCountries` accepte une liste, une chaîne séparée par des virgules, ou le
jeton **`eef_suspended`**, qui désigne les pays de `KPB_EEF_SUSPENDED_COUNTRIES` —
**la même liste que celle que `/config/app` sert à l'app.** Écrire `["Niger","NE"]`
à la main dans chaque campagne, c'est oublier un pays le jour où la liste change :
« la campagne est ouverte » partirait vers un pays dont l'État dit que les
dossiers ne sont pas traités. Le jeton peut figurer dans la liste à côté d'autres
pays.

La comparaison est **insensible à la casse** (`countryOfResidence` est un texte
saisi : « Niger », « NIGER », parfois un code), **sans jokers** (`%` et `_` sont
échappés : exclure « Mal_ » n'exclut pas « Mali ») et couvre **les écritures d'un
même pays** (avec ou sans accents, apostrophe droite ou typographique — comme
l'app, qui replie accents et apostrophes avant de comparer). Elle est **exacte** :
« Niger » n'exclut pas le « Nigeria ». Prouvé contre un vrai Postgres
(`campaign-audience.postgres.spec.ts`), pas seulement par des doubles.

**Un filtre présent mais mal formé vaut « personne ».** Sont refusés — `400` à la
création, `filterInvalid` et zéro destinataire à l'aperçu et à l'envoi : une clé de
filtre inconnue (`exceptCountry`), `exceptCountries: null`, une entrée qui n'est pas
du texte, une entrée en `snake_case` autre que `eef_suspended` (un jeton mal écrit,
ex. `eef_suspendd`, serait sinon lu comme un nom de pays que personne ne porte, et
l'envoi partirait vers TOUS les étudiants, Niger compris), et le jeton
`eef_suspended` quand `KPB_EEF_SUSPENDED_COUNTRIES` est vide.

**L'aperçu** (`POST /admin/notifications/campaigns/preview`) renvoie en plus, pour
ces deux audiences, `excludedCountries` (les pays réellement lus) et
`excludedRecipients` (le nombre de comptes retirés). Un `0` là où le Niger a des
comptes est une faute de frappe, pas une réussite.

**Limite assumée :** un compte dont le pays est **vide** (profil non complété) ne
peut pas être exclu — on ne sait pas qu'il est au Niger — et reçoit l'annonce.

**Consentement :** `eef_interest` vise ceux qui ont déclaré leur intérêt. Si une
annonce d'ouverture automatisée est couverte par le texte `eef-consent-v1` reste
une question juridique ouverte (`docs/eef-consent-v1.md`, question 4).

**Piège connu, inchangé :** l'audience `country` filtre sur le pays de
**résidence** (`countryOfResidence`), pas sur le pays visé. `country: france`
toucherait les résidents de France, pas les candidats à la France.

## Admin users and reporting

- `GET /admin/users`
- `POST /admin/users`
- `PATCH /admin/users/:id`
- `GET /admin/reports/overview`
- `GET /admin/reports/funnel`
- `GET /admin/reports/counselor-performance`
- `GET /admin/reports/campaign-performance`

Purpose:
- manage internal roles and provide the first reporting layer for cases, counseling, and campaigns

## Admin — adoption des builds de l'app

`GET /admin/app-builds` — mêmes rôles que `GET /admin/dashboard` (admin,
super_admin, counselor, commercial). Pour décider quand relever `minVersion` ou
changer de fournisseur de push. Que des comptages, aucune ligne par compte ;
503 sans base plutôt que des zéros.

| Champ | Sens |
|---|---|
| `windowDays`, `since` | Fenêtre d'activité : 30 jours avant `generatedAt` |
| `activeProfiles` | Comptes (élève, parent, partenaire) vus dans la fenêtre — le dénominateur des parts |
| `byBuild[]` | `{ build, count, share, shareAtOrAbove }`, de la plus récente à la plus ancienne. `shareAtOrAbove` = part qui resterait ouverte si l'app exigeait cette build au minimum |
| `byVersion[]` | `{ version, count, share }`, de la plus récente à la plus ancienne |
| `unknownBuild`, `unknownVersion` | `{ count, share }` : vus sans valeur lisible — en pratique les builds ≤ 53 |
| `neverSeen` | `{ count, share }` sur `allProfiles` : comptes sans aucune requête authentifiée depuis la mise en service |

Les parts sont des ratios 0–1 arrondis à 4 décimales ; `byBuild` + `unknownBuild`
somment à `activeProfiles`. Un compte multi-appareils compte pour la dernière
build enregistrée.

## Annonce d'ouverture des bourses suivies (chantier C)

« Suivre » une bourse = favori + alerte d'ouverture + rappels de date limite
(décision propriétaire). Ce contrat est figé par le lot « schema » du chantier
(migration, DTO, types partagés `backend/src/modules/scholarships-index/opening/scholarship-opening.contract.ts`,
miroir admin `admin/lib/scholarship-opening-types.ts`) ; les routes nouvelles
arrivent avec les lots « fanout » et « student-api ». Toute modification passe
par ce fichier et par le contrat partagé.

**Compatibilité.** Aucune route existante ne change de méthode, de chemin, de
gardes ni de clés de réponse ; les clés nouvelles sont additives. La
`ValidationPipe` globale refuse les champs inconnus (`forbidNonWhitelisted`) :
l'admin se déploie **strictement après** le backend, et un retour arrière du
backend après l'admin impose celui de l'admin.

### Qui suit, qui est prévenu

- **suit(u, s)** = un `SavedItem(u, 'scholarship', s)` OU une
  `ScholarshipAlertSubscription(u, s)` avec `mutedAt IS NULL`.
- **prévenu à l'ouverture(u, s)** = suit(u, s) ET aucune alerte (u, s) en
  sourdine (`mutedAt IS NOT NULL`) : la sourdine prime sur le favori.
- Favoris orphelins ignorés (chaque requête joint `Scholarship`). Un invité ne
  suit rien : toutes les routes de suivi exigent `StudentAuthGuard`.
- **Désinscription globale** `followed_scholarship_updates`
  (`UserProfile.disabledNotificationTypes`) : coupe le push seulement, l'entrée
  d'inbox est écrite (`skipped / opt_out`). Ne coupe jamais les rappels de date
  limite (transactionnels). Les builds 53/56 conservent cette clé inconnue.

### Modes (`KPB_SCHOLARSHIP_OPENING_MODE`, lu à chaque appel)

| Mode | `activate` | Audience | Miroir cloche ↔ favori | Audience des rappels |
|---|---|---|---|---|
| `legacy` (défaut, et valeur illisible) | envoi immédiat dans la requête, première activation seulement | alertes non en sourdine | non | favoris |
| `outbox_alerts` | annonce programmée (`KPB_OPENING_HOLD_SECONDS`, 120 s), annulable, puis worker | alertes non en sourdine | non | favoris |
| `outbox_followers` | idem | favoris ∪ alertes, moins sourdines | oui | favoris ∪ alertes |

La portée (`alerts` / `followers`) est figée sur le cycle à la programmation.
`KPB_PUSH_OUTBOX_ENABLED=false` arrête le worker (programmations et push en
attente patientent ; une annonce en retard de plus de 24 h est abandonnée, un
push en attente depuis plus de 72 h expire). Réglages et bornes :
`OPENING_TUNABLE_ENV` dans le contrat partagé, relayés par `docker-compose.yml`
(vide = défaut du code).

Règles d'envoi : rien entre 21 h et 8 h locales (`KPB_PUSH_QUIET_START`/`END`,
décalage tiré du pays de résidence, UTC+0 par défaut — Africa/Abidjan) ; au plus
1 push d'ouverture par 30 min et 2 par jour local et par étudiant ; deux lignes
ou plus envoyables ensemble partent en un push groupé. Pas d'annonce
rétroactive : tout cycle ouvert ou activé avant la migration porte
`openingPreExisting = true`.

### Erreurs

Corps de `GlobalExceptionFilter` : `{statusCode, message, requestId, code?, details?, timestamp}`.
Chaque erreur nouvelle porte un `message` français complet (l'admin déjà déployé
n'affiche que lui).

| Statut | `code` | `details` | Quand |
|---|---|---|---|
| 409 | `OPENING_BUSY` | — | `activate`, annulation ou arrêt : le cycle est verrouillé par un envoi en cours de préparation (> 5 s d'attente, `lock_timeout`), ou la transaction a expiré ; à réessayer |
| 409 | `OPENING_NOT_RETROACTIVE` | — | `notify: true` sur un cycle `openingPreExisting` |
| 400 | `OPENING_CONFIRMATION_REQUIRED` | `{toNotify, threshold}` | `toNotify > seuil` sans `expectedRecipients` |
| 403 | `OPENING_REQUIRES_ADMIN` | `{toNotify, threshold}` | `toNotify > seuil` et rôle ni `admin` ni `super_admin` |
| 409 | `OPENING_AUDIENCE_CHANGED` | `{toNotify, expectedRecipients}` | hausse au-delà de max(10, 10 %) ou franchissement du seuil non confirmé ; rien n'est écrit |
| 409 | `OPENING_NOT_SCHEDULED` | `{lastFanoutAt}` | annulation sans annonce programmée |

Le seuil (`KPB_OPENING_CONFIRM_THRESHOLD`, 500) se compare en `toNotify > seuil` :
500 exactement ne demande pas de confirmation.

### `POST /admin/scholarships/:id/activate` (existante, étendue)

Corps : les champs d'avant, inchangés, plus
- `academicYear` : même forme (`2027` ou `2027-2028`, même message d'erreur) ;
  deux années non consécutives (`2027-2029`) sont désormais refusées (400) ;
- `notify?: boolean` — `false` = « Enregistrer les dates sans prévenir » ;
  absent = comportement d'avant (annonce à la première activation seulement) ;
- `expectedRecipients?: integer` (0 – 1 000 000) — le `toNotify` confirmé à
  l'aperçu ; exigé au-delà du seuil.

Réponse 200 — les six premières clés et leurs types sont ceux d'avant :

```json
{
  "scholarshipId": "chevening", "cycleId": "clx…", "status": "open",
  "firstActivation": true, "subscribers": 312, "pushesSent": 0,
  "academicYear": "2027-2028", "mode": "outbox_followers",
  "notification": { "state": "scheduled", "toNotify": 312,
                    "fanoutAt": "2026-10-15T14:34:00.000Z", "reason": null }
}
```

`notification.state` ∈ `scheduled | already_scheduled | nothing_to_send | sent_legacy | none` ;
`reason` ∈ `null | dates_only | already_announced | pre_existing_open | legacy_first_activation_only`.
`subscribers` : en `legacy`, les alertes non en sourdine lues ; sinon l'audience
de la portée avant déduplication. `pushesSent` : 0 hors `legacy`.
`notification.toNotify` (et les gardes de seuil, de rôle et d'audience
confirmée) : le `toNotify` de l'aperçu dans **tous** les modes, `legacy`
compris — déjà prévenus pour ce cycle ou pour un autre cycle de la bourse depuis
30 jours exclus. En `legacy`, la désinscription globale garde l'entrée d'inbox
et coupe le push, et l'aperçu ne compte aucun report (envoi immédiat). L'envoi
legacy étant synchrone (il peut durer plusieurs minutes), chaque push relit
l'état de l'élève juste avant de partir — alerte non en sourdine, push permis,
pas de `followed_scholarship_updates` — comme le worker à l'envoi ; l'entrée
d'inbox déjà écrite reste.

Audit `AdminAuditEvent` (`entityType: 'ScholarshipCycle'`, `purposeCode: 'scholarship_opening'`) :
`scholarship_cycle.opened | notify_scheduled | notified_legacy | dates_updated |
notify_cancelled | notify_stopped | fanout_completed | fanout_expired`.
`result` dit ce qui s'est réellement passé :
- `success` — le geste a eu lieu ;
- `skipped` — une annonce programmée abandonnée par le worker sans rien
  écrire pour les étudiants, `reasonCode` ∈ `not_public_at_fanout |
  cycle_closed_at_fanout | fanout_too_late` ;
- `refused` — une activation refusée (403 `OPENING_REQUIRES_ADMIN`, 409
  `OPENING_AUDIENCE_CHANGED`, 409 `OPENING_NOT_RETROACTIVE`), `reasonCode` = le
  code d'erreur, `action` = l'annonce tentée (`notify_scheduled`, ou
  `notified_legacy` en `legacy`). C'est la seule écriture d'un refus ; sans
  donnée personnelle (`changes` : `academicYear, notify, mode, scope, toNotify,
  expectedRecipients, threshold, actorRole`). Sur une année dont le cycle
  n'existe pas encore, l'événement porte sur la bourse (`entityType:
  'Scholarship'`, `entityId` = la bourse).

### Routes de l'équipe (nouvelles)

Mêmes gardes et rôles que `/admin/scholarships` (admin, super_admin,
content_manager). `X-Request-Id` du client repris s'il est sûr
(`^[A-Za-z0-9._:-]{1,128}$`), sinon généré, et renvoyé en en-tête.

| Route | Rôle |
|---|---|
| `GET /admin/scholarships/:id/opening-preview?academicYear=&opensAt=&closesAt=` | Aperçu : cycles, cible, complétude (`readiness`), audience et répartition des envois, copie FR/EN, 5 derniers événements (`recentEvents`, ceux des cycles et les refus portés par la bourse). Lecture seule. |
| `POST /admin/scholarships/:id/cycles/:cycleId/opening/cancel` | Annule une annonce programmée (rien n'a été écrit pour les étudiants) → `{cycleId, cancelled: true}` ; sinon 409 `OPENING_NOT_SCHEDULED`. 409 `OPENING_BUSY` si le cycle reste tenu plus de 5 s par un envoi en préparation (rien n'est annulé). |
| `POST /admin/scholarships/:id/cycles/:cycleId/opening/stop` | Arrête les push restants : `pending` → `skipped/stopped_by_staff`, entrées d'inbox gardées → `{cycleId, stopped, inFlight}`. 409 `OPENING_BUSY` si le cycle reste tenu plus de 5 s par un envoi en préparation (rien n'est arrêté ; à réessayer). |
| `GET /admin/scholarships/:id/cycles/:cycleId/opening-report` | Rapport : inbox (total, lues), push par état et raison, par fournisseur. Additif : `fanout.lastScheduleEnd`, le dernier événement qui a mis fin à une programmation du cycle (`OPENING_SCHEDULE_END_ACTIONS` : `notify_cancelled`, `fanout_completed`, `fanout_expired` ; refus exclus), au format de `recentEvents`, ou `null`. Quand `fanout.scheduledAt` redevient `null`, il dit pourquoi : envoi fait (`outcome: sent`), annulé (`notify_cancelled`, `actorName`) ou abandonné par le worker (`outcome: skipped`, `reasonCode` ∈ `not_public_at_fanout`, `cycle_closed_at_fanout`, `fanout_too_late`). |
| `GET /admin/scholarships/opening-todo` | Cycles servis ouverts jamais annoncés, ni sautés, ni programmés, ni pré-existants (100 au plus), triés par `notifiable`. Chaque ligne porte `followers` (suivent, toute portée) et `notifiable` (« abonnés à prévenir » : l'audience de la portée, le même nombre que la colonne « Abonnés » de `opening-overview` et, pour ce cycle jamais annoncé, que le `toNotify` de l'aperçu hors prévenus depuis 30 jours pour un autre cycle). |
| `GET /admin/scholarships/opening-overview` | Colonnes « Abonnés » (`followers`, `notifiable`) et « Annoncé » de la liste. Additif : `announcedTarget` (`{cycleId, academicYear, announcedAt, newFollowers}` ou `null`) quand le cycle que l'aperçu propose par défaut est déjà annoncé ; la colonne « Abonnés à prévenir » montre alors `newFollowers` (abonnés arrivés depuis l'annonce et pas encore prévenus pour ce cycle : le `toNotify` de l'aperçu de ce cycle, hors prévenus depuis 30 jours pour un autre cycle), jamais `notifiable`, qui compterait des abonnés déjà prévenus. |

Chaque événement de `recentEvents` porte `outcome` ∈ `sent | skipped | refused`
(tiré de `result` : `success` → `sent`) et, pour `skipped` et `refused`,
`reasonCode?: string` (le motif ou le code d'erreur ci-dessus) : un envoi
abandonné ou une activation refusée ne se lisent jamais comme un envoi fait,
quelle que soit l'action affichée.

Les formes exactes sont les interfaces `OpeningPreviewResponse`,
`CancelOpeningResponse`, `StopOpeningResponse`, `OpeningReportResponse`,
`OpeningTodoResponse` et `OpeningOverviewResponse` du contrat partagé.
**Vocabulaire du rapport :** « acceptées par le fournisseur », jamais « reçues »
ni « délivrées » — un 200 de FCM ou de OneSignal ne dit pas que le téléphone a
affiché la notification. `push.accepted` compte des lignes,
`push.acceptedPushes` des push (un groupé = 1).

### Routes étudiant

Nouvelles (builds récentes) :

- `PATCH /me/scholarship-alerts/:scholarshipId` — corps `{notifyOpening: boolean}`.
  `false` met l'annonce en sourdine (la bourse reste suivie : rappels, liste) ;
  `true` vaut la cloche allumée. 404 si la bourse n'est pas approuvée et active.
  → `{scholarshipId, following, notifyOpening}`, `following` relu après écriture.
- `GET /me/followed-scholarships?lang=fr|en` — bourses suivies, closes
  comprises (200 au plus) → `{items, total, globalOptOut}` ;
  `displayStatus` ∈ `open | opening_confirmed | forecast | closed` (cycle choisi
  par `selectCurrentCycle`) ; `detailAvailable: false` quand la fiche
  répondrait 404.
- `GET /me/notifications/unread-count` → `{unreadCount}`.
- `POST /me/notifications/read-by-ref` — corps `{refs: string[]}` (1 à 20,
  `^[A-Za-z0-9:_-]+$`, 200 caractères au plus) ; une référence est une
  `dedupeKey` sans son `:<userId>` (ex. `scholarship-opened:<cycleId>`) ;
  limité à l'étudiant connecté → `{updated}`.

Existantes, mêmes formes, sémantique ajustée :

| Route | Changement |
|---|---|
| `GET /me/scholarship-alerts` | les alertes en sourdine sont masquées |
| `POST /me/scholarship-alerts/:id` | efface la sourdine ; en `outbox_followers`, pose aussi le favori (`impliedFollow` si c'est cet appel qui l'a créé) |
| `DELETE /me/scholarship-alerts/:id` | favori créé par la cloche → supprime alerte et favori ; favori de l'étudiant → sourdine ; sinon suppression comme avant |
| `DELETE /saved-items/:id` (bourse) | supprime l'alerte en sourdine (tous modes) ; en `outbox_followers`, toute alerte |
| `POST /saved-items` (bourse) | le favori devient celui de l'étudiant (`impliedFollow = false`) |
| `GET /scholarships`, `GET /scholarships/:id` | `isAlertEnabled` / `alert.*` ne lisent que l'alerte non en sourdine ; bloc additif `follow: {following, viaFavorite, viaAlert, notifyOpening, globalOptOut}` sur la fiche |

### Charge utile push v1 (données, toutes des chaînes)

Annonce seule — route que les builds ≤ 56 savent ouvrir ; `notificationKey`
permet à la build FCM de marquer l'entrée lue au tap (`POST /me/push-opens`) :

```json
{ "route": "/scholarships/<sid>", "scholarshipId": "<sid>", "cycleId": "<cid>",
  "type": "scholarship_opened", "kind": "scholarship_opened",
  "notificationKey": "scholarship-opened:<cid>:<uid>", "ref": "scholarship-opened:<cid>" }
```

Push groupé — `count` compte toutes les lignes, `refs` et `scholarshipIds`
portent les 20 plus récentes ; **pas** de `scholarshipId` (un lecteur ancien
ouvrirait une bourse arbitraire). Titre « {n} bourses que tu suis sont
ouvertes » seulement si chaque ligne annonce une ouverture ; dès qu'une ligne
est un « Dates confirmées » (`data.variant = dates_confirmed`, ouverture à
venir), « {n} bourses que tu suis ont du nouveau » / « Regarde les dates. » :

```json
{ "route": "/deadlines", "type": "scholarship_opened_bundle", "kind": "scholarship_opened_bundle",
  "count": "3", "refs": "scholarship-opened:<c1>,scholarship-opened:<c2>,…",
  "scholarshipIds": "<s1>,<s2>,…" }
```

### Migrations `20261015120000…120200_scholarship_follow_*` — exploitation

Trois fichiers, additifs seulement (colonnes nullables ou à défaut constant,
index, reprises idempotentes), parce que `prisma migrate deploy` exécute chaque
fichier dans une transaction implicite :

1. `…120000_scholarship_follow_fanout` — colonnes, index de `ScholarshipCycle`,
   reprises de `ScholarshipCycle` (`openingPreExisting`, `openingNotifiedAt =
   activatedAt`, `pre_existing_open`). `SET LOCAL lock_timeout = '5s'` : en cas
   d'échec, `npx prisma migrate resolve --rolled-back 20261015120000_scholarship_follow_fanout`
   puis relancer à une heure creuse.
2. `…120100_scholarship_follow_indexes` — `CREATE INDEX IF NOT EXISTS` sur
   `SavedItem` et `UserNotification`. Lancer `db-info.yml` d'abord ; au-delà
   d'environ un million de lignes, construire les index **avant** le déploiement :

   ```sql
   CREATE INDEX CONCURRENTLY IF NOT EXISTS "SavedItem_itemType_itemId_idx" ON "SavedItem"("itemType", "itemId");
   CREATE INDEX CONCURRENTLY IF NOT EXISTS "UserNotification_pushStatus_pushNotBefore_idx" ON "UserNotification"("pushStatus", "pushNotBefore");
   CREATE INDEX CONCURRENTLY IF NOT EXISTS "UserNotification_cycleId_kind_idx" ON "UserNotification"("cycleId", "kind");
   -- doit être vide (un CONCURRENTLY raté laisse un index INVALID) :
   SELECT indexrelid::regclass FROM pg_index WHERE NOT indisvalid;
   ```
3. `…120200_scholarship_follow_notification_backfill` — `UserNotification.cycleId`
   recopié depuis `data`, `ScholarshipCycle.openingAudience` compté.

Avant le déploiement, cette requête doit être vide (sinon ces cycles ne
pourraient plus être réactivés, `academicYear` exigeant deux années consécutives) :

```sql
SELECT "scholarshipId", "academicYear" FROM "ScholarshipCycle"
WHERE NOT CASE
  WHEN "academicYear" ~ '^\d{4}$' THEN true
  WHEN "academicYear" ~ '^\d{4}-\d{4}$'
    THEN split_part("academicYear", '-', 2)::int = split_part("academicYear", '-', 1)::int + 1
  ELSE false
END;
```

Geler les activations admin pendant le déploiement du backend : un cycle activé
par l'ancien code entre la migration et la nouvelle image échapperait à
`openingPreExisting`. Pas de migration descendante : un backend plus ancien
ignore les colonnes.

## « Mes 10 bourses » — API élève (chantier D)

Le test d'éligibilité : l'élève répond à ce qui manque, le serveur rend **jusqu'à 10** bourses
(« Compatibles avec ton profil », puis « À vérifier avant de postuler »), jamais une bourse
exclue, jamais de pourcentage. Moteur : `backend/src/modules/scholarship-match/`.

### Portes communes (`/scholarships/match/*`)

Dans cet ordre :

1. drapeau `KPB_SCHOLARSHIP_MATCH_ENABLED` coupé → **404** `{statusCode: 404, disabled: true, code: "scholarship_match_disabled", message}`, avant toute authentification ;
2. `StudentAuthGuard` (jeton Supabase) → **401** sans jeton valide ;
3. compte `parent` ou `partner` → **403** (le test est caché pour eux en v1).

Chaque chemin a au moins deux segments : `GET /scholarships/:id` ne peut pas les capturer.
503 sans base de données.

### `GET /scholarships/match/state?lang=fr|en`

`lang` inconnu → `fr`. Réponse :

```jsonc
{
  "algorithmVersion": "sm-1",
  "readiness": {
    "ready": false,                 // rien ne manque ET récapitulatif validé
    "required": ["nationalityCode"],// clés obligatoires vides
    "toConfirm": ["englishLevel"],  // valeurs utilisées, pas encore confirmées
    "optional": ["languageTests"],  // « améliore la précision »
    "targetLevelOptions": ["bachelor", "master", "doctorate"] // + "secondary" si ≤ 19 ans et catalogue lycée
  },
  "prefill": [{ "key": "nationalityCode", "value": "ner", "source": "countryOfResidence", "ambiguous": true }],
  "answers": {                      // valeurs actuelles, jetons connus seulement (récapitulatif)
    "nationalityCode": "ner", "secondNationalityCode": null, "residence": "ner",
    "birthDate": "2006-05-10", "guardianConsented": false, "highestDiploma": "bac",
    "scholarshipTargetLevel": "bachelor", "fieldIds": ["d01"], "targetCountryIds": [],
    "gradeBandOn20": "12_14", "englishLevel": "b1", "frenchLevel": null, "languageTests": [],
    "workExperienceBand": null, "confirmedAt": null
  },
  "options": {
    "version": "3f1c…",            // 16 hex : change quand une liste change (cache app 24 h)
    "countries": [{ "code": "ner", "name": "Niger", "priority": true }],   // ISO 3166-1 alpha-3
    "destinations": [{ "id": "fra", "name": "France" }],                  // pays du catalogue public, `int` compris
    "fields": [{ "id": "d01", "name": "Informatique & Intelligence Artificielle" }]
  },
  "latestRun": null,                // ou un run rendu (forme ci-dessous)
  "isStale": false,
  "staleReasons": [],               // "profile" | "catalog" | "algorithm"
  "catalogSize": 29,                // bourses analysées (« On analyse 29 bourses… »)
  "alertsOptIn": false
}
```

Clés de `readiness` : `nationalityCode`, `residence`, `birthDate`, `guardianConsent` (mineur
sans accord), `highestDiploma`, `scholarshipTargetLevel`, `fields`, `gradeBandOn20`,
`englishLevel`, `workExperienceBand` (Master/Doctorat) ; facultatives : `targetCountryIds`,
`frenchLevel`, `languageTests`, `secondNationalityCode`. **Le serveur possède ces listes ;
l'app ignore les clés qu'elle ne connaît pas.**

Les candidates sont lues au plus une fois par minute (cache mémoire de 60 s, 500 fiches au
plus, fiches publiques seulement — `publicScholarshipWhere`).

### `POST /scholarships/match/runs` — limité à 10 par minute (429 au-delà)

Corps (tous facultatifs) : `{lang?: string, trigger?: string, answers?: object, confirm?: boolean}`.
Seules ces quatre clés sont admises au premier niveau (`forbidNonWhitelisted`). `trigger` ∈
`wizard | rerun | stale_refresh | edit`, toute autre valeur est enregistrée `other`.

`answers` est **tolérant** : une clé inconnue, un jeton inconnu ou une valeur du mauvais type
sont **abandonnés** (jamais un 400). Clés comprises :

| Clé | Valeurs |
|---|---|
| `nationalityCode`, `secondNationalityCode` | code ISO alpha-3 (ou alpha-2 / nom, normalisés) ; `secondNationalityCode: null` efface |
| `residence` | idem ; écrit `countryOfResidence` (nom français) seulement s'il change de pays |
| `birthDate` | `AAAA-MM-JJ`, 16 ans au moins |
| `guardianConsent` (`true`), `guardianName`, `guardianContact` | accord du représentant légal, horodaté par le serveur une seule fois |
| `highestDiploma` | `none bac bac_plus_2 licence master doctorat` |
| `scholarshipTargetLevel` | `secondary bachelor master doctorate` (jamais écrit dans `targetLevel`) |
| `fieldIds` | ≤ 3 parmi `d01…d12` ; `[]` = « Pas encore décidé » |
| `targetCountryIds` | alpha-3 ou `int` ; `[]` efface |
| `gradeBandOn20` | `lt10 10_12 12_14 14_16 16_plus` |
| `englishLevel`, `frenchLevel` | `none a1_a2 b1 b2 c1_c2` ; `frenchLevel: null` efface |
| `languageTests` | `[{type: ielts|toefl_ibt|duolingo|tcf|tef, score, takenAt?}]` ; entrée invalide abandonnée |
| `workExperienceBand` | `none lt12 12_24 24_36 36_60 60_plus` |

Dans **une transaction** : réponses écrites sur le profil, `scholarshipProfileConfirmedAt` posé
par le serveur si `confirm: true`, anciens champs réécrits quand la correspondance est univoque
(`b1` → `languageLevel: "Intermediate"`, `12_14` → `gradeRange: "12 - 14/20"`…), calcul, run
enregistré, runs élagués aux 5 derniers. Un échec n'importe où annule tout, réponses comprises.
Une valeur **changée sans** `confirm: true` retire la confirmation.

Réponses (toujours **200**) :

- `{status: "profile_incomplete", readiness}` — **rien n'est écrit** (ni réponses, ni run) ;
- `{status: "ok", run, diff}` :

```jsonc
{
  "run": {
    "id": "…", "createdAt": "2026-10-13T12:00:00.000Z", "algorithmVersion": "sm-1", "trigger": "wizard",
    "counts": { "eligible": 6, "toVerify": 4, "excluded": 12, "notAnalyzed": 3, "candidates": 25 }, // sur TOUTES les candidates
    "items": [{                     // ≤ 10, compatibles d'abord, jamais `not_eligible`
      "scholarshipId": "…", "cycleId": "…", "rank": 1,
      "section": "compatible",      // | "to_verify"
      "status": "eligible",         // | "to_verify"
      "isNew": false,               // absente du run précédent (faux au premier run)
      "available": true,            // faux : la fiche n'est plus publique (« Plus disponible »)
      "name": "Bourse Eiffel",
      "scholarship": { "countryId": "fra", "countryName": "France", "fundingType": "partially_funded",
                       "fundingLabel": "…", "levelLabel": "…", "deadlineAt": null, "deadlineLabel": "…",
                       "applicationUrl": "…", "sourceUrl": "…" },        // null si indisponible
      "window": { "cycleId": "…", "academicYear": "2027-2028", "status": "open|forecast|closed|suspended",
                  "dateConfidence": "confirmed|estimated", "opensAt": null, "closesAt": "…",
                  "estimatedOpenAt": null, "estimatedCloseAt": null }, // statut recalculé à l'horloge ; null si indisponible
      "reasons": [{ "code": "level_accepted", "label": "Niveau Master accepté" }],       // ≤ 3
      "toVerify": [{ "code": "language_missing", "label": "IELTS 6.5 en anglais demandé — tu n’as pas indiqué de score",
                     "official": { "text": "<citation exacte>", "sourceUrl": "https://…" } }] // official: null sans critère source
    }],
    "excludedSummary": {            // « Pourquoi certaines bourses n'apparaissent pas »
      "groups": [{ "group": "level", "count": 12, "label": "12 visent un autre niveau",
                   "scholarships": [{ "id": "…", "name": "…" }] }],      // ≤ 20 noms ; groupes level|nationality|age|experience|suspended
      "notAnalyzedCount": 3, "notAnalyzedLabel": "3 bourses récentes pas encore analysées par KPB"
    },
    "levelCatalog": { "level": "doctorate", "count": 1,
                      "label": "1 bourse doctorale dans notre catalogue pour l’instant" }, // label null si ≥ 10
    "precisionLimitedBy": null      // "kpb" | "answers" quand ≥ la moitié est « à vérifier »
  },
  "diff": { "previousRunId": "…", "addedIds": ["…"], "removedIds": ["…"] } // vides au premier run
}
```

Les libellés (`label`) sont rendus par le serveur dans la langue demandée ; aucun libellé KPB ne
contient « % » ni « chance(s) ». Les citations officielles (`official.text`) en sont exemptées.
Le run stocké garde un `inputsSummary` minimisé (niveau visé, nombre de domaines, compléments
présents, confirmation) : ni nationalité, ni date de naissance, ni moyenne.

### `PUT /scholarships/match/alerts`

Corps `{enabled: boolean}` (booléen strict, 400 sinon) → `{enabled, optedInAt: string|null}`.
Pose `scholarshipMatchAlertsOptInAt` (une date déjà posée est gardée) ou l'efface. Opt-in
EXPLICITE du futur push hebdomadaire « nouvelles bourses compatibles ».

### `POST /me/scholarship-alerts` — « Suivre les N compatibles »

Corps `{scholarshipIds: string[]}` (≤ 10, chaque id ≤ 64 caractères) → **200**
`{subscribedIds: string[], skippedIds: string[]}`. Même porte que
`POST /me/scholarship-alerts/:scholarshipId` (bourse approuvée et active), même effet par bourse
(cloche allumée, sourdine levée, favori posé en `outbox_followers`), dans une transaction.
Un identifiant qui ne passe pas la porte est ignoré (`skippedIds`), jamais une erreur pour le lot.
Idempotent : un favori déjà présent n'est jamais retiré. Route sans paramètre : aucun conflit
avec `:scholarshipId`.

### Dossiers liés à une bourse

- `POST /cases` accepte `scholarshipId?: string` (≤ 64). Gardé seulement si la fiche existe ;
  sinon le dossier est créé sans lien (jamais un 400 pour une fiche inconnue).
- `GET /cases?scholarshipId=…` → les dossiers DE L'ÉLÈVE liés à cette bourse (déduplication
  de « Être accompagné ») ; sans le paramètre, la liste d'avant.
- Chaque dossier rendu (élève, `GET /admin/cases`, conseiller) porte `scholarshipId: string|null` ;
  la liste commerciale des leads aussi. Lecture seule côté équipe.
- Les lectures STAFF (`GET /admin/cases` admin et conseiller, et les réponses des écritures
  `/admin/cases/:id…`) portent en plus `scholarship: {id, nameFr, nameEn, sourceUrl|null,
  applicationUrl|null} | null`, lu par la relation dans la même requête (pas de N+1) ; `null`
  quand le dossier n'est pas lié ou que la fiche a été supprimée (SET NULL). La réponse élève et
  la diffusion Socket.IO `caseUpdated` ne le portent pas. Un admin plus ancien l'ignore ; l'admin
  courant affiche l'identifiant seul si la clé manque (backend plus ancien).

### `GET /profiles/me` (lecture seule)

Clés ajoutées : `nationalityCode`, `secondNationalityCode`, `highestDiploma`,
`scholarshipTargetLevel`, `gradeBandOn20`, `englishLevel`, `frenchLevel`, `languageTests`
(relu par la garde), `workExperienceBand`, `scholarshipProfileConfirmedAt`,
`scholarshipMatchAlertsOptIn` (booléen). Elles ne s'écrivent QUE par
`POST /scholarships/match/runs` : `PATCH /profiles/me` ne les connaît pas (un 400 y bloquerait la
synchronisation du profil). Les builds plus anciennes les ignorent (`profile_api_codec.dart` lit
des clés explicites).

### RGPD

`GET /profiles/me/export` contient `scholarshipMatchRuns` et `scholarshipAlertSubscriptions`
(clés présentes même vides) ; les colonnes du profil y sont déjà par construction. La
suppression du compte les emporte par cascade (prouvé contre PostgreSQL :
`scholarship-match-api.postgres.spec.ts`).

## Liste des bourses : recherche, statut et tri (chantier I)

`GET /scholarships` (élève connecté, `StudentAuthGuard`) garde ses paramètres d'avant
(`lang`, `level`, `fields`, `countryId`, `fundingType`, `limit` 1–100, `offset`) et
accepte trois paramètres **optionnels**. Les builds en store ne les envoient pas : sans
eux, la réponse est exactement celle d'avant (tri par pertinence, total lu en base).

| Paramètre | Valeurs | Effet |
|---|---|---|
| `q` | texte libre, espaces repliés, tronqué à 100 caractères ; vide = absent | Recherche insensible à la casse dans `nameFr`, `nameEn`, `countryNameFr`, `countryNameEn`. Ajoutée en `AND` : la clause publique (`publicScholarshipWhere`, dont l'`OR` sur `deadlineAt`) reste intacte. |
| `status` | `open`, `upcoming`, `forecast`, séparés par des virgules (`open,upcoming`) ; vide = absent | Filtre sur le statut du cycle SERVI, avec la règle d'urgence de l'app (`scholarshipUrgencyOf`) : clôture confirmée passée ou cycle fermé par l'équipe → `closed`, jamais listée par ce filtre ; cycle servi `closed` SEULEMENT parce que sa clôture ESTIMÉE est passée → `forecast` (l'app dit « Date à confirmer ») ; cycle `open` dont `opensAt` est à venir → `upcoming` ; `open` sinon ; ouverture confirmée à venir (cycle non estimé) → `upcoming` ; le reste (estimé, à confirmer) → `forecast`. Sans cycle : une date limite → `open`, rien → `forecast`. |
| `sort` | `relevance` (défaut), `deadline`, `verified`, `title` | `relevance` : `matchScore` décroissant puis date limite (l'ordre d'avant). `deadline` : clôture la plus proche (`closesAt`, sinon `estimatedCloseAt`, sinon `deadlineAt`), dates inconnues en dernier. `verified` : `lastVerifiedAt` décroissant. `title` : titre dans la langue demandée, A→Z, sans tenir compte des accents ni de la casse. |

**Tolérants** (comme `fundingType` ou `limit`) : une valeur inconnue n'est jamais un 400.
Un statut inconnu est retiré (`status=open,expired` → `open` ; `status=expired` → aucun
filtre), un tri inconnu vaut `relevance`, un `q` trop long est tronqué, une clé répétée
(`status=open&status=upcoming`) est lue. L'écho `query` dit ce qui a été réellement appliqué.

**Clés inconnues de la route** : `GET /scholarships` lit ses paramètres un par un
(`@Query('nom')`, aucun DTO de requête) ; le `ValidationPipe` (`forbidNonWhitelisted`) ne
s'applique donc pas à la query string de cette route, et un serveur antérieur au chantier I
**ignore** `q`, `status` et `sort` sans 400 (prouvé en HTTP par
`scholarships-list.http.spec.ts`).

Réponse : `{items, total, limit, offset, hasMore, fieldFilterRelaxed, databaseUnavailable, query}`.

- `total` : nombre réel de bourses correspondantes (`count` en base, indépendant du
  plafond de 500 candidates). Avec `status`, filtre calculé en mémoire, c'est le nombre
  de la liste filtrée.
- `query` (**additif**) : `{q: string|null, status: string[]|null, sort}`, ce que le
  serveur a APPLIQUÉ. Un client qui ne trouve pas cette clé parle à un backend plus
  ancien, qui a ignoré `q`, `status` et `sort` ; l'app filtre alors le statut elle-même
  sur la page reçue, ne montre pas de total, et masque le bouton « Trier » (un tri
  qu'elle ne peut pas obtenir du serveur ne s'affiche pas).
- Chaque item porte déjà `countryId` (alpha-3, sert au drapeau) et `lastVerifiedAt`.

## Compétition ambassadeurs (parrainage, novembre 2026)

Code : `backend/src/modules/referrals/` (`referrals.service.ts`, `campaigns/`). Exploitation :
`docs/runbook-campagne-ambassadeurs.md`. Migration additive
`20261022120000_referral_campaigns`.

### `POST /referrals/redeem` (existante, étendue — compatible avec l'app 2.3.0)

Corps inchangé `{ code }` (4 à 16 caractères), réponse inchangée `{attributed, alreadyReferred}`.

- **Codes unifiés** : `code` peut être le code personnel (`UserProfile.referralCode`) OU le code
  ambassadeur (`Ambassador.code`, « KTOU-AB-1a2b3c »). Recherche sur la forme normalisée
  (majuscules, sans espace, tiret, point ni soulignement) : l'app met le texte en majuscules ;
  `ktou-ab-1a2b3c`, `KTOUAB1A2B3C`, `k7pq-2mza` sont acceptés. Les codes existants restent
  valides (rattrapage `Ambassador.codeNormalized`).
- Le filleul est rattaché au **profil** du parrain (`Referral`, seule source du comptage) ; si ce
  parrain a une ligne `Ambassador`, une `AmbassadorReferral` est créée (`refereeName` =
  « Prénom I. ») et `totalReferrals` incrémenté.
- Inchangé : 404 code inconnu, 403 auto-parrainage, 403 parrainage croisé, 403 si un dossier
  existe, idempotent (`alreadyReferred`).
- **Nouveau** : **429** `{code: "referral_code_rate_limited"}` au-delà de
  `REFERRAL_CODE_HOURLY_LIMIT` (30) rattachements au même parrain dans l'heure ; rien n'est créé.
- **Nouveau** : empreintes anti-fraude relevées au mieux (jamais bloquantes) dans
  `ReferralAttributionSignal` : HMAC de l'IP, de sa plage (/24, /48), des jetons push déjà
  enregistrés du filleul, et de l'en-tête facultatif `X-KPB-Device-Id` (build 57+ ; absent de
  l'app installée).

### `POST /referrals/ambassador/activate` (existante, gardée)

- Ligne `Ambassador` existante → tableau de bord, comme avant (aucune écriture).
- Sinon **403** `{code: "ambassador_activation_admin_only"}`, sauf
  `AMBASSADOR_SELF_ACTIVATION_ENABLED=true` (programme rémunéré rouvert). L'app installée
  n'appelle pas cette route (aucun bouton tant que `KPB_AMBASSADOR_CASH_ENABLED` est faux).

### `GET /referrals/dashboard` (existante)

`activated: true` seulement si la ligne `Ambassador` a `cashProgramEnabled = true` (toutes les
lignes antérieures à la migration). Un ambassadeur activé pour la compétition reçoit l'aperçu
non activé : l'app affiche l'écran de candidature, jamais des commissions promises.
`POST /referrals/withdraw` refuse (400) sans `cashProgramEnabled`.

### `GET /referrals/campaigns/current` (élève, préparée pour la build 57)

`{participating: false}` ou `{participating: true, campaign: {slug, nameFr, nameEn, status,
phase, startsAt, endsAt, provisional}, me: {publicName, city, code, rank, qualified, toReview,
pending, rankable}, serverTime}`. `Cache-Control: private, no-store`.

### `GET /public/campaigns/:slug/leaderboard` — sans authentification

- `Cache-Control: public, max-age=30` (et cache serveur de 30 s), **30 requêtes / min / IP**,
  `Access-Control-Allow-Origin: *` (lu par `kpbeducation.cloud/classement/`, sans cookie).
- 404 pour un slug inconnu ou une campagne `draft`. `?city=` filtre (sans accents ni casse).
- Réponse — liste de champs **fermée** :

```json
{
  "campaign": {
    "slug": "ambassadeurs-novembre-2026", "nameFr": "…", "nameEn": "…",
    "status": "live", "phase": "upcoming|running|ended", "timeZone": "Africa/Lagos",
    "startDate": "2026-11-01", "endDate": "2026-11-10",
    "startsAt": "2026-10-31T23:00:00.000Z", "endsAt": "2026-11-10T23:00:00.000Z",
    "prizes": [{"rank": 1, "amountFcfa": 100000}],
    "rulesUrl": "https://…" , "provisional": true, "updatedAt": "…"
  },
  "serverTime": "…",
  "cities": ["Maradi", "Niamey"],
  "entries": [{"rank": 1, "name": "Aïcha K.", "city": "Niamey", "qualified": 12}]
}
```

  Jamais d'e-mail, d'identifiant interne, de code, de compteur « à vérifier » ni de donnée de
  filleul. Seuls les participants **classables** apparaissent (actif, ambassadeur activé, âge
  connu, mineur avec autorisation parentale `verified`). `rank` est null à 0 qualifié.
  `provisional` vaut false seulement quand la campagne est `closed`.

### Qualification (calcul, `campaigns/campaign-qualification.ts`)

Un filleul est **qualifié** à `qualifiedAt = max(rattachement, création du compte, complétion
du profil)` si : rattachement (`Referral.createdAt`) dans `[startsAt, endsAt[` ; compte créé dans
la fenêtre (règle par défaut `requireAccountCreatedInWindow`) ; e-mail vérifié (profil relié à
Supabase, `supabaseUserId`) ; profil complété (`campaigns/profile-completion.ts` : élève,
consentement, téléphone, date de naissance, ≥ 1 domaine, ≥ 1 pays visé, accord du tuteur si
mineur — les champs obligatoires de l'onboarding de la build 56 ; le pays de résidence n'en fait
pas partie) ; et `qualifiedAt < endsAt`. `UserProfile.profileCompletedAt` est posé une fois, au
`PATCH /profiles/me` qui complète le profil (ou au recalcul). Statuts : `pending`, `qualified`,
`flagged` (signal automatique, ne compte pas), `excluded` (décision de l'équipe). Signaux :
`disposable_email`, `device_duplicate`, `ip_burst`, `ip_block_burst`, `velocity_burst`,
`referee_is_participant`. Classement : qualifiés décroissants, puis instant où le compte a été
atteint, puis inscription. Recalcul toutes les 5 min (campagnes `live`, gel automatique à
`endsAt`) et à la demande ; n'écrit que les différences.

### Routes de l'équipe — `admin/referral-campaigns`, `admin/ambassadors`

Lecture : Admin, SuperAdmin, Commercial. Écriture, décisions, versements, export : Admin,
SuperAdmin. `Cache-Control: private, no-store`. Chaque écriture crée un `AdminAuditEvent`
(`purposeCode = "referral_campaign"`) et renvoie `X-Request-Id`.

| Route | Effet |
|---|---|
| `GET /admin/referral-campaigns` | Liste + compteurs |
| `POST /admin/referral-campaigns` | Création (`draft`) : `{slug, nameFr, nameEn, startDate, endDate, timeZone?, prizes?, rulesText?, rulesUrl?, eligibleCities?, eligibleCountries?, qualificationRule?}` — jours inclusifs lus dans `timeZone` (défaut `Africa/Lagos`). 409 slug pris |
| `GET/PATCH /admin/referral-campaigns/:id` | Lecture / édition ; `live` et `frozen` : noms et règlement seulement (400 `campaign_field_locked`) |
| `POST /admin/referral-campaigns/:id/transition` | `{action: launch\|freeze\|unfreeze\|validate_podium\|close}` ; 409 si impossible. `close` exige le podium validé ; `validate_podium` refusé après un versement |
| `POST /admin/referral-campaigns/:id/recompute` | Recalcul : `{created, updated, deleted, unchanged, participantsUpdated, profilesStamped, skipped?}` |
| `GET /admin/referral-campaigns/:id/leaderboard?city=&country=` | Classement complet (non classables compris, `unrankableReason`) |
| `POST /admin/referral-campaigns/:id/participants` | `{ambassadorId \| email, publicName?, city?, country?, minorStatus?}` ; ambassadeur activé exigé, ville/pays éligibles, nom public sans e-mail ni numéro |
| `PATCH /admin/referral-campaigns/:id/participants/:pid` | Nom public, ville, pays, statut (+ motif), âge, autorisation parentale (`verified` pose date et admin), note |
| `GET /admin/referral-campaigns/:id/participants/:pid/referrals` | Filleuls : nom, e-mail, dates, statut, signaux, décision |
| `POST /admin/referral-campaigns/:id/referrals/:rid/decision` | `{decision: validated\|excluded\|clear, reason?}` — motif requis pour exclure |
| `GET /admin/referral-campaigns/:id/prizes` | Lauréats figés au podium |
| `POST /admin/referral-campaigns/:id/prizes/:rank/payout` | `{payoutReference, paidAt?, paidAmountFcfa?, recipient?, payoutMethod?, note?}` ; lauréat mineur → `recipient: parent` exigé |
| `GET /admin/referral-campaigns/:id/export.csv?scope=leaderboard\|referrals` | CSV (BOM, cellules neutralisées) |
| `GET /admin/ambassadors?search=&approved=yes\|no` | Ambassadeurs |
| `POST /admin/ambassadors` | `{email, city, displayName?, campus?}` : crée ou reprend la ligne `Ambassador`, `approvedAt`, codes ambassadeur et personnel, `cashProgramEnabled` false à la création |
| `POST /admin/ambassadors/:id/revoke` | `{reason}` : retire l'activation (non classé ensuite) |
