# Catalogue Verification SOP

KPB-47 turns the verification badge into an operational promise: every sensitive catalogue row must carry a recent source, a timestamp, and the admin who checked it.

## Cadence And Ownership

| Category | Rows | Cadence | Owner |
| --- | --- | --- | --- |
| Pays: visa, couts et difficulte admission | `Country` | 30 days | Amina KPB |
| Etablissements: frais, niveaux et exigences | `Institution` | 180 days | Fatou Admin |
| Formations: frais, duree, langue et prerequis | `Program` | 180 days | Fatou Admin |
| Bourses: deadlines, financement et eligibilite | `Scholarship` | 30 days | Amina KPB |

## Workflow

1. Open the admin verification queue at `/verification`.
2. Review rows due for re-check, starting with missing source links and never-verified rows.
3. Confirm the row against an official source.
4. Save the verification. The admin API records `lastVerifiedAt`, `verifiedById`, `verifiedByName`, and `sourceUrl`.
5. If a source is unavailable, leave the row inactive or update the public copy so it does not overpromise.

## Le catalogue « Études en France » (ajouté le 20/09/2026)

10 247 formations dans 70 universités publiques françaises sont désormais
importables, et arrivent **inactives**. Tant qu'elles le sont, elles **ne sont
PAS dans la file `/verification`** (mise à jour du 29/09/2026) : cette file liste
les fiches PUBLIÉES dont la cadence est échue, et les 10 500 lignes en attente
n'ont jamais été publiées. Leur revue est le flux de PUBLICATION, qui demande un
outil dédié — à construire ; valider une ligne dans `/verification` ne pose que le
tampon de vérification, jamais `isActive`. Une fois publiées, elles entrent dans
la cadence « Formations » ci-dessus (180 jours), avec deux différences qui
changent la façon de les relire :

- **Le volume interdit la relecture ligne à ligne.** Ce qui doit être relu en
  priorité, c'est ce que la machine ne peut pas juger : le partage DAP /
  procédure Études en France, et les mentions de master, dont les données
  ouvertes datent de 2021 et peuvent avoir fermé depuis. Les 2e et 3e années
  de licence, elles, sont attestées par les effectifs de la rentrée 2024 :
  elles vieillissent moins vite.
- **La source est attachée, mais ce n'est PAS toujours la fiche de la formation**
  (corrigé le 29/09/2026 : cette procédure affirmait le contraire). Sur 10 502
  lignes, `sourceUrl` désigne :

  | Ce que la source est | Lignes | Ce que vérifier veut dire |
  | --- | ---: | --- |
  | la fiche Parcoursup de la formation | 4 140 | confirmer que la fiche existe toujours et dit la même chose |
  | une page de l'établissement (master) | 2 150 | idem — mais la page n'a pas été relue une à une |
  | **la racine du portail `monmaster.gouv.fr`** (masters) | **1 078** | **il n'y a pas de fiche à relire** : il faut en trouver une |
  | **la page du jeu de données ouvert** (L2 et L3) | **3 134** | idem : c'est la preuve que la formation existe, pas une page candidat |

  Soit **4 212 lignes (40 %) sans fiche de formation**. Pour elles, « confirmer la
  fiche » n'a pas d'objet : le relecteur doit retrouver la page de la formation sur
  le site de l'université (elle devient alors le `sourceUrl`), ou publier la ligne
  en sachant que l'étudiant qui touche « Voir la source officielle » arrive sur un
  portail ou un tableur. L'écran de publication de l'admin annonce ce nombre pour
  chaque établissement AVANT d'écrire ; il ne bloque pas, parce que refuser ces
  lignes reviendrait à ne rien publier du tout tant qu'on n'a pas re-sourcé
  3 134 L2/L3 à la main — c'est une décision de contenu (voir
  `docs/eef-catalog-pipeline.md` § 2.8), pas de code.

Le pipeline, ses limites et ses portes de CI : `docs/eef-catalog-pipeline.md`.

## Source Standard

Use official school, government, scholarship, Campus France, embassy, or partner pages. Avoid aggregator pages unless no official source exists and the row is explicitly marked for follow-up.

> **Propriétaires à nommer.** « Amina KPB » et « Fatou Admin » ci-dessus sont des
> personnages de jeux de test, pas des personnes. Tant qu'une personne réelle
> n'est pas nommée pour chaque cadence, la file de vérification n'a pas de
> propriétaire et le badge « Vérifié » reste vert sans que personne ne soit tenu
> de le rouvrir.

## La relecture mensuelle des bourses (mode d'emploi, écrit le 29/09/2026)

Le validateur refuse toute source (`checkedAt`) ou vérification (`verifiedAt`)
de plus de 30 jours : chaque mois, chaque fiche doit être rouverte.

**Annoncer qui relit quoi avant de commencer.** Le 29/09, deux sessions ont relu
les mêmes 33 fiches le même jour sans le savoir ; il a fallu comparer les deux
résultats champ par champ avant de fusionner. Le côté heureux : deux lectures
indépendantes se sont recoupées (44 champs reformulés, aucune contradiction de
fond sur ces 44) et ont chacune trouvé des corrections que l'autre avait
manquées. Un désaccord entre deux lectures se tranche en rouvrant la source, pas
en choisissant un camp.

Ce qui a fonctionné le 29/09 (33 fiches, dix relecteurs en parallèle, ~3 fiches
chacun) :

1. **Lire, ne pas recopier.** Ouvrir les cinq pages officielles de la fiche
   (présentation, éligibilité, avantages, candidature, dates du cycle) et
   comparer champ par champ : dates, montants, niveaux, pays éligibles, statut
   du cycle (ouvert, clos, prévu). Une citation par affirmation vérifiée, copiée
   mot pour mot.
2. **`checkedAt` = l'heure réelle de la lecture** (`date -u` au moment où la
   page est lue), une par fiche. Ne jamais poser une date « du jour » sur des
   fiches qu'on n'a pas relues : c'est faire affirmer au catalogue une
   vérification qui n'a pas eu lieu.
3. **Une page illisible n'est pas une page relue.** Écran anti-robot, PDF
   introuvable, page qui ne charge pas : la fiche garde sa date, le test de
   fraîcheur reste rouge pour elle, et une personne la relit dans un navigateur
   ordinaire. On ne contourne pas le blocage.
4. **Un cycle dont la clôture est passée devient `closed`** (avec sa date de
   clôture confirmée) ; il ne reste jamais `open`. Les URL du contenu doivent
   être celles de la source correspondante — le validateur le vérifie.
5. **Contrôler les preuves.** Chaque citation d'un rapport de relecteur doit se
   retrouver mot pour mot dans la page enregistrée (le 29/09 : 858 sur 858
   retrouvées ; les citations d'une lecture faite par un outil qui résume la
   page, comme `WebFetch`, ne sont pas vérifiables de cette façon et sont
   signalées comme telles dans le journal).
6. **Déployer, puis réaligner la production** : `publish-catalog` (import →
   reconcile → switch). Sans `reconcile`, les lignes déjà en base gardent
   l'ancien contenu.

Les preuves de la vague du 29/09 : `docs/catalog-verification-2026-09-29.md`.

## Structurer l'éligibilité des bourses (catalogue 1.5.0, chantier D)

« Mes 10 bourses » n'exclut un élève que sur une règle **dure**, **tamponnée
depuis moins de 400 jours** et une réponse **confirmée** par l'élève. Le
tampon (`eligibilityStructuredAt`) est propre à la relecture des CRITÈRES :
il ne se confond pas avec `lastVerifiedAt`, qui certifie la relecture des
pages officielles.

**État au 1.5.0 : 36 brouillons, 0 fiche tamponnée.** Les critères de
`backend/src/modules/scholarships-index/data/scholarship-catalog.eligibility.v1.ts`
ont été rédigés à partir du seul texte d'éligibilité de chaque fiche ; chaque
critère cite une ligne de la fiche, mot pour mot, avec sa source officielle
« eligibility ». Tant qu'ils ne sont pas relus, ils n'excluent personne : tout
écart s'affiche « à vérifier ».

Relire une fiche, c'est :

1. ouvrir sa source officielle « eligibility » et la lire en entier ;
2. pour chaque critère, vérifier le type, l'impact (`hard` seulement pour une
   nationalité, une résidence, un âge ou une expérience énoncés sans
   exception), les pays (ISO alpha-3), les bornes et la date de référence
   (`asOf`) ; quand la source donne une liste que la fiche ne reproduit pas
   (Taiwan ICDF « alliés diplomatiques », SI « 34 pays », IsDB, OCI…), la
   recopier dans la fiche d'abord, puis seulement la structurer ;
3. ajouter `reviewed: { at: '<ISO du jour>', by: '<Prénom Nom>' }` à
   l'entrée de la fiche, dans une PR relue ;
4. après fusion et déploiement : `catalog:reconcile --dry-run` puis
   `--apply` porte le tampon en base.

**La porte éditoriale.** `missing_structured_eligibility` est un
**avertissement** tant que les 36 fiches ne sont pas relues
(`STRUCTURED_ELIGIBILITY_GATE = 'warning'` dans
`scholarship-catalog.validator.ts`) : une erreur rendrait la CI rouge et
pousserait à tamponner sans relire. Le jour où `npm run verify:catalog`
affiche `36/36 reviewed and stamped`, passer la constante à `'error'` dans
une PR dédiée : toute fiche ajoutée ensuite sans éligibilité relue cassera
`scholarships:validate:merge-gate`. Un tampon de plus de 400 jours donne
`stale_structured_eligibility` (avertissement, horloge seule) : la fiche
redevient « à vérifier » jusqu'à la relecture suivante.

**Dépôt contre admin.** L'admin écrit le même bloc (niveaux, domaines,
critères, tampon). `catalog:reconcile` ne remplace JAMAIS un bloc tamponné en
base par un brouillon du dépôt, ni par un tampon du dépôt plus ancien ; il le
signale dans `keptFromDatabase`. Pour qu'une relecture faite dans l'admin
survive aux versions suivantes, la reporter dans le dépôt (`reviewed`).

## Publier le catalogue vérifié en production

Le catalogue vérifié vit dans le dépôt (`backend/src/modules/scholarships-index/data/`).
Le déployer ne le publie pas : **le code et les données sont deux chemins
distincts**, et c'est pour cela que 34 fiches vérifiées ont pu rester invisibles
pendant un mois pendant que la production servait 11 fiches de démonstration.

La CLI est compilée dans l'image (`dist/cli/`), donc exécutable dans le
conteneur. Chaque sous-commande exige `--dry-run` ou `--apply` : il n'y a pas de
mode par défaut.

```bash
docker compose exec -T api npm run catalog:import -- --dry-run
docker compose exec -T api npm run catalog:import -- --apply
docker compose exec -T api npm run catalog:reconcile -- --dry-run
docker compose exec -T api npm run catalog:reconcile -- --apply
docker compose exec -T api npm run catalog:switch -- --dry-run
docker compose exec -T api npm run catalog:switch -- --apply
```

> ### ⚠️ `import` ne corrige RIEN. C'est `reconcile` qui réaligne. (31/08/2026)
>
> `import` est idempotent par identifiant : il crée les fiches manquantes et
> **saute** celles qui existent déjà. C'est délibéré — il ne doit pas écraser une
> ligne à l'aveugle — mais la conséquence l'était moins : **une correction
> apportée à une fiche du dépôt n'atteignait jamais la production une fois la
> ligne créée.**
>
> Mesuré en production le 31/08/2026, après `catalog:switch --apply` (30 fiches
> publiées, catalogue 1.3.0) : `york_pise_2027_forecast` et
> `jj_wbgsp_2027_forecast` servaient `dateConfidence: "estimated"` alors que le
> dépôt dit `confirmed` depuis la re-vérification du 24/08 (commit `1176f22`).
> L'écart était conservateur — « À venir, généralement aux mois de … » au lieu
> d'une date ferme, donc aucun étudiant n'a vu de fausse échéance — mais il
> grandit à chaque version du catalogue.
>
> Rien ne le disait : `"skippedExisting": 34` se lit « rien à faire » alors qu'il
> veut dire « 34 fiches non réalignées, donc potentiellement périmées ». Le
> compteur s'appelle désormais `existingNotUpdated`, et `import --dry-run` liste
> les écarts **champ par champ** :
>
> ```json
> "existingNotUpdated": 34,
> "existingAligned": 32,
> "existingDrifted": 2,
> "drift": [
>   { "id": "york_pise_2027_forecast", "realign": 4, "keptFromDatabase": 0,
>     "fields": ["cycle.dateConfidence : estimated → confirmed", "…"] }
> ]
> ```
>
> **L'ordre `import` → `reconcile` → `switch` n'est pas une préférence.**
> `reconcile` doit passer AVANT `switch`, sinon on publie la version périmée
> avant de la corriger.
>
> **`reconcile` ne publie ni n'approuve jamais.** Il n'écrit ni `isActive` ni
> `moderationStatus`, et sa transaction est annulée si l'état de modération
> d'une seule fiche a bougé pendant l'opération. La modération reste
> fail-closed : publier est le travail de `switch`, sur décision explicite.
>
> **Ce que `reconcile` refuse d'écraser**, en le signalant dans son rapport
> plutôt qu'en le taisant :
>
> | Cas | Qui fait foi | Pourquoi |
> | --- | --- | --- |
> | Cycle activé depuis l'admin (`activatedAt`) | la base | Réaligner rétrograderait une date ferme confirmée par un humain en « À venir » — le défaut d'aujourd'hui, dans l'autre sens |
> | **Vérification révoquée** (`setVerification(..., false)` → `lastVerifiedAt` nul) | la base | La révocation ne touche NI `isActive` NI `moderationStatus` : la fiche reste active et n'est masquée que par `lastVerifiedAt: { not: null }`. Reposer le tampon la **republierait sans relecture**. Un `lastVerifiedAt` nul est un signal, pas un vide — seule une nouvelle vérification humaine le repose |
> | `lastVerifiedAt` en base plus récent que celui du dépôt | la base | Un contrôle humain du mois dernier ne se remplace pas par un tampon de catalogue plus ancien. `lastVerifiedAt`, `verifiedById`, `verifiedByName` et **`sourceUrl`** se déplacent d'un bloc : `verificationData` les écrit ensemble, et garder le nom du relecteur en réécrivant sa source attribuerait sa vérification à un lien qu'il n'a pas ouvert |
> | Étape de candidature présente en base et absente du catalogue | la base | `ScholarshipWorkspaceStep.sourceStepId` est en `onDelete: SetNull` : la supprimer détacherait la progression des étudiants |
> | Tags posés dans l'admin, ou tag d'une version antérieure du catalogue | la base | Les tags s'ajoutent, ne se remplacent pas — `publish` retrouve les lignes par ce tag |
> | **Éligibilité structurée tamponnée en base** (`eligibilityStructuredAt` posé), face à un brouillon du dépôt ou à un tampon du dépôt plus ancien | la base | Une relecture humaine ne se remplace pas par des critères non relus ou plus anciens. `eligibleLevels`, `fieldsScope`, `eligibilityCriteria` et le tampon se déplacent d'un bloc (catalogue 1.5.0) |
>
> Sur tout le reste — texte, avantages, éligibilité, dates du cycle, étapes —
> **le dépôt fait foi**. Une modification faite dans l'admin sur un champ
> éditorial sera donc écrasée. C'est le sens voulu (une correction relue en PR
> doit atteindre la production), et c'est pourquoi le `--dry-run` liste chaque
> champ avant d'écrire.

> ### ⚠️ `--confirmed-only` a été RETIRÉ de ces commandes (30/08/2026)
>
> Ce drapeau écarte par construction toute fiche dont le cycle est `estimated`
> — c'est-à-dire **exactement** les bourses « à venir ». Mesuré en production le
> 30/08 : 34 fiches vérifiées en base, **10 servies à l'app**, dont 4 en licence.
> Les 22 manquantes étaient les fiches à dates estimées, dont les six licences
> panafricaines (Ashesi, ALU, AUC) et les trois européennes.
>
> Le drapeau avait un sens tant que l'app ne savait afficher qu'une date ferme :
> publier une projection au jour près aurait été un mensonge. Depuis la build 50,
> l'app rend « À venir, généralement aux mois de … » pour ces fiches et ne leur
> applique ni compte à rebours, ni badge « bientôt clôturé », ni notification
> d'échéance. La raison de les cacher a disparu ; le drapeau, non.
>
> Le remettre re-cacherait 22 fiches sur 34. Si un jour il faut publier une
> vague strictement confirmée, ajouter `--confirmed-only` **à cet appel-là**, en
> connaissance de cause.
>
> Ces commandes s'exécutent aussi depuis GitHub Actions → **VPS ops
> (feature flag / catalogue)** → `publish-catalog`, pour qui n'a pas d'accès SSH.

> **`import` n'est pas optionnel, et l'ordre n'est pas une préférence.** `switch`
> publie les fiches *déjà présentes en base* puis dépublie les anciennes. Lancé
> sans `import`, il ne trouve rien à publier et dépublie quand même : l'onglet
> Bourses se vide. C'est arrivé en production le 14 août 2026. La CLI refuse
> désormais ce cas, mais la règle reste : **`import` d'abord, toujours.**
>
> Et lisez la sortie du `--dry-run` au lieu de la parcourir : `"published": 0`
> est le signal qu'il ne faut pas passer à `--apply`.

**Pourquoi `switch` et pas `publish` puis `deactivate-legacy`.** `switch` fait les
deux dans une seule transaction, en publiant avant de dépublier : il n'existe
donc aucun instant où l'onglet Bourses est vide pour les utilisateurs. Lancées
séparément, les deux commandes laissent une fenêtre.

**Pourquoi `--confirmed-only` a existé, et pourquoi il ne s'applique plus.**
Une build déjà distribuée pouvait ne pas savoir afficher une date estimée
autrement que comme une date ferme ; publier d'abord les seules fiches
confirmées évitait de faire mentir une app en circulation. Ce paragraphe
annonçait déjà la sortie : « les fiches estimées se publient avec la build qui
sait les présenter, en relançant sans le drapeau ».

**Cette build est la 50** (30/08/2026). Elle rend « À venir, généralement aux
mois de … » pour les cycles estimés, et surtout elle ne leur applique plus ce
qui aurait menti : ni compte à rebours (`_deadlineBadge`), ni badge « bientôt
clôturé » (`ScholarshipModel.windowStatus` sort sur `deadlineIsEstimated`), ni
« Date limite » ferme sur la fiche détail, ni rappel J-30/…/J-1 ni digest
hebdomadaire (`hasEstimatedDeadline`, côté backend). La condition posée ici est
donc remplie, et vérifiable ligne à ligne.

**Ce que la CLI refuse.** Elle écarte une fiche dont la clôture est passée ou
absente, une fiche que la porte de qualité refuse, et elle annule la transaction
entière si, à l'arrivée, une fiche publiée n'a pas de date de vérification.
Contrairement à l'ancien script, une anomalie sur une fiche n'empêche plus
l'import des autres : le refus global était une falaise — une seule campagne
close rendait les 33 autres fiches inimportables.

**Après l'opération**, vérifier de l'extérieur :

```bash
curl -s https://api.kpbeducation.cloud/api/catalog/scholarships | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['source'], len(d['items']))"
```

La provenance doit être `database`, et aucun identifiant de la liste legacy
(`chevening_uk`, `mccall_macbain`, `rhodes_oxford`, …) ne doit subsister.
