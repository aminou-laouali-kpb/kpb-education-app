# Runbook — rentrée décalée OMNES, reconduction 2027 et groupe IGENSIA Education

Opérations du catalogue partenaires (chantier E/J, sources et décisions du
propriétaire du 16/10/2026) :

| Opération `vps-ops` | Script | Source (dans `backend/scripts/data/`) | Ce qu'elle écrit |
|---|---|---|---|
| `dedupe-omnes` | `npm run dedupe:omnes` | table `OMNES_PROGRAM_ID_ALIASES` (`src/modules/catalog/catalog-dedupe.ts`) | Doublons OMNES d'automne : offres des alias ajoutées à la fiche canonique, campus retiré de son intitulé, alias hors ligne (`isActive = false`) |
| `import-omnes-spring` | `npm run import:omnes-spring` | `omnes_spring_27.csv` (extrait de `omnes_spring_27.pdf`) | Offres de printemps 2027 des formations OMNES (ECE, ESCE, INSEEC) ; formations OMNES manquantes |
| `roll-omnes-fall-2027` | `npm run roll:omnes-fall-2027` | `omnes_fall_26.xlsx` (référence des offres non retouchées) ; règle : `src/modules/catalog/omnes-fall-roll.ts` | Offres d'automne 2026 reconduites en 2027 (même jour et mois), marquées `rolledFromIntake` / `intakeEstimated` ; `intakePeriods` des écoles OMNES |
| `import-igensia` | `npm run import:igensia` | `igensia_2027.csv` (de `igensia_2027.pdf`), `abc_2027.csv` (de `abc_2027.xlsx`) ; faits des sites officiels : `igensia_2027.sources.md` | Écoles IGENSIA School of Business, IGENSIA Tech, IGENSIA RH, American Business College et leurs formations ; sur des fiches déjà en base, comble fiche RNCP, langue, durée / admission d'ABC |

Prérequis : la migration `20261021120000_program_recognition` (colonnes
`Program.recognitionFr/En`) est déployée — elle part avec la release, comme
toute migration. `import-omnes-spring` exige aussi les écoles `omnes-*` du seed
d'automne (déjà en production).

## Ce qui est garanti

- **Rien d'existant n'est réécrit.** Une formation déjà en base ne reçoit que
  les offres (campus + rentrée) qui lui manquent, ajoutées à la FIN de
  `campusOfferings` ; ses autres champs et ses offres déjà là ne bougent pas.
  Une école déjà en base ne reçoit que ses dates de rentrée et formations
  manquantes (`push`).
- **Une retouche faite dans l'admin pendant l'opération est gardée** : chaque
  fiche n'est réécrite que si son `updatedAt` n'a pas bougé depuis la lecture.
  La ligne « modifiée entre-temps, laissée intacte » dit de relancer.
- **Rejouable** : après application, la simulation annonce « 0 écriture ».
- **Garde de production** (`src/common/seed-safety.ts`) : la première
  application passe ; une relance qui trouverait encore quelque chose à écrire
  est refusée sans `KPB_ALLOW_PRODUCTION_SEED=1`. On regarde d'abord pourquoi
  (fiche supprimée à la main, autre import…) avant de forcer.

## Reconduction des rentrées d'automne 2026 → 2027

Décision du propriétaire (16/10/2026) : OMNES n'a pas publié sa grille
2027-2028 ; toutes les rentrées d'automne 2026 sont reconduites d'un an, même
jour et même mois. La grille d'automne n'a que trois mois : août (31/08),
septembre et octobre 2026 → août, septembre et octobre 2027. Les offres de
rentrée décalée (janvier – mars 2027) ne bougent pas.

- Une offre reconduite garde son campus et ses prix (tarifs 2026-2027) et
  porte `rolledFromIntake` (date d'origine, « 14/09/2026 · 01/10/2026 » pour
  une offre à deux dates) et `intakeEstimated: true`. L'app affiche sous
  l'offre « Date reconduite de 2026, à confirmer · tarif 2026-2027 » (EN :
  « Date carried over from 2026, to be confirmed · 2026-2027 fee »), et
  « (à confirmer) » à côté de la rentrée sur les cartes et le comparateur.
- **Seules les offres non retouchées** sont reconduites : campus, chaque
  date et les deux prix identiques à `omnes_fall_26.xlsx` pour la formation
  (alias de `dedupe-omnes` compris), aucun autre champ. Une offre retouchée
  dans l'admin, une fiche créée à la main, une offre qui mêlerait 2026 et une
  autre date, ou dont la reconduction ferait un doublon, est **signalée**
  (« ⚠ … laissée telle quelle ») et jamais modifiée : à reprendre à la main.
- Les `intakePeriods` des écoles OMNES : chaque date d'automne 2026 que plus
  aucune offre ne porte est remplacée, à sa place, par la date 2027 ; les
  dates de printemps et le texte libre ne bougent pas. Une date 2026 qu'une
  offre signalée porte encore est gardée.
- Les alias mis hors ligne par `dedupe-omnes` sont reconduits aussi (comptés
  à part dans le rapport) : la base est la même quel que soit l'ordre.
- Une base vierge (`seed:omnes`) naît directement reconduite : aucune
  rentrée d'automne 2026, la simulation annonce « 0 écriture ».
- Liste des offres reconduites, à faire confirmer par OMNES (date de
  l'automne 2027 et tarif 2027-2028) : `docs/omnes-rentrees-reconduites-2027.md`.
  Une date confirmée se corrige dans l'admin en retirant les deux marques.

**Ordre et interactions.** À passer après `dedupe-omnes` et
`import-omnes-spring`. L'import de printemps n'écrit que des dates de
janvier – mars 2027 : il ne réintroduit aucune date 2026 et ne double pas une
offre reconduite (elle n'a pas sa date, ni sa session). Rejoué sur
Postgres 15 local dans les deux ordres (`dedupe → spring → roll` et
`dedupe → roll → spring`), la base finale est identique, octet pour octet, et
chaque relance des trois opérations annonce « 0 écriture » ; les tests
(`src/modules/catalog/omnes-fall-roll.spec.ts`) jouent aussi
`roll → dedupe → spring`.

## Doublons

Une même formation doit retomber sur la même fiche, quelle que soit la grille
(casse, accents, tirets, campus resté dans l'intitulé : « BCh- Bordeaux - B1 -
… »). Les ids OMNES sont en production : on ne change pas leur calcul ; une
variante retombe sur l'id EXISTANT par la table explicite
`OMNES_PROGRAM_ID_ALIASES` (21 alias). Le test-garde
`src/modules/catalog/catalog-duplicates.spec.ts` vérifie, sur tous les seeds et
imports, qu'aucune école n'a deux formations au même nom normalisé et au même
niveau, et qu'aucune école n'est en double ; une nouvelle grille qui écrit une
formation connue autrement le fait échouer : ajouter la variante à la table.
Les imports refusent aussi de créer une formation dont une homonyme est déjà en
base sous un autre id (fiche saisie dans l'admin) : la ligne « fiche homonyme
déjà en base » du rapport dit laquelle rapprocher à la main. Les blocs
« ECE / ESCE / INSEEC — Rentrée décalée 2027 » de `universites-partenaires.csv`
ne deviennent jamais des écoles (`assertTargetsAreSchools`).

## Procédure

Pour chacune des opérations, dans cet ordre (`dedupe-omnes`,
`import-omnes-spring`, `roll-omnes-fall-2027`, puis `import-igensia`) —
Actions → **VPS ops** → Run workflow :

1. **Simulation** : `action` = l'opération, `dry_run` coché. Lire le rapport :
   par école, formations à créer / complétées / inchangées et offres ajoutées.
   Attendu à la première fois :
   - `dedupe-omnes` : 12 fiches canoniques complétées (dont 2 seulement
     renommées : campus ou tiret dans l'intitulé), 12 alias hors ligne ;
     `TOTAL : … (24 écriture(s))`.
   - `import-omnes-spring` : 28 formations créées (ECE 10, ESCE 2,
     INSEEC 16), 94 complétées (ECE 8, ESCE 15, INSEEC 71), 286 offres de
     printemps en tout (ECE 18, ESCE 17, INSEEC 251) ; `TOTAL : 125 écriture(s)`.
     Ces nombres valent si les fiches OMNES n'ont pas été modifiées depuis le
     seed ; un écart se lit ligne à ligne dans le rapport.
   - `roll-omnes-fall-2027` : formations / offres reconduites ECE 54 / 70,
     ESCE 46 / 55, HEIP 10 / 20, INSEEC 144 / 529, Sup de Pub 26 / 73 (747
     offres), plus 12 fiches hors ligne (alias) ; 5 écoles (dates 2026
     remplacées : ECE 7, ESCE 7, HEIP 5, INSEEC 18, Sup de Pub 4) ; « Dates
     reconduites par mois : 08 → 19 ; 09 → 522 ; 10 → 218 » (alias compris) ;
     `TOTAL : 297 écriture(s) prévue(s), 0 offre(s) signalée(s)`. Chaque ligne
     « ⚠ » est une offre retouchée à la main, laissée en 2026 : à reprendre
     dans l'admin.
   - `import-igensia` : 4 écoles « À CRÉER », 22 formations (ISB 12,
     IGENSIA Tech 2, IGENSIA RH 3, ABC 5), 34 offres ; `TOTAL : 4 écriture(s)`.
     Si la première version de l'import est déjà passée : 21 « fiches
     comblées » et « école comblée » pour ABC ; `TOTAL : 22 écriture(s)`.
     Cette relance-là demande `KPB_ALLOW_PRODUCTION_SEED=1` (des lignes
     `igensia-*` existent déjà).
   Une ligne `ERREURS — rien ne sera écrit` arrête tout : la source contient
   une valeur que les tables fermées ne connaissent pas.
2. **Application** : même `action`, `dry_run` décoché. Le job enchaîne
   `npm run verify:catalog`, qui doit finir sur `OK` (références pays, domaines,
   écoles partenaires avec au moins une formation, et le total servi sous la
   limite de 1 000 formations des builds installées : ~59 formations de plus).
3. **Vérification** : relancer la simulation. Attendu : `TOTAL : 0 écriture(s)`.
   Dans l'app, la recherche « IGENSIA », « ABC » ou « American Business College »
   trouve les nouvelles écoles ; une fiche OMNES comme « ECE - B1 - Cybersécurité
   et réseaux » montre Paris deux fois : « Rentrée décalée · mars 2027 » et
   « Rentrée d'octobre 2027 » suivie de « Date reconduite de 2026, à confirmer
   · tarif 2026-2027 », chacune avec son prix.

## Nouvelle grille

Quand le propriétaire envoie une nouvelle grille (PDF / XLSX), sur un poste :

```bash
cd backend
pip install pdfplumber openpyxl
python3 -I scripts/extract-catalog-sources.py omnes-spring <grille.pdf> > scripts/data/omnes_spring_27.csv
python3 -I scripts/extract-catalog-sources.py igensia <grille.pdf> > scripts/data/igensia_2027.csv
python3 -I scripts/extract-catalog-sources.py abc <portefeuille.xlsx> > scripts/data/abc_2027.csv
npx jest src/modules/catalog/omnes-spring-import.spec.ts src/modules/catalog/igensia-import.spec.ts
```

Les tests épinglent les comptes par école de la grille actuelle : une nouvelle
grille les fait échouer, c'est voulu. Recompter sur le PDF (une date de
rentrée par ligne), mettre les tests à jour, puis passer par une PR.

## Rentrées passées

L'app n'annonce jamais une rentrée passée (horloge de
`lib/app/core/utils/program_intakes.dart`) : ni sur les cartes, ni dans la
fiche (tuile « Rentrée », offres par campus), ni dans le comparateur, ni dans
le repli sur les rentrées de l'école, ni dans le libellé de rentrée d'un pays.
Les `intakePeriods` d'une école (« 01/10/2027 ») s'écrivent en toutes lettres
(« octobre 2027 ») sans réécrire la base. Depuis `roll-omnes-fall-2027`,
aucune formation OMNES n'est sans rentrée à venir : l'ancienne liste
`omnes-formations-sans-rentree-2027.md` est remplacée par celle des offres
reconduites à faire confirmer, `docs/omnes-rentrees-reconduites-2027.md`.

## Libellé « prochaine rentrée » des pays

`nextIntakeLabelFr/En` de `backend/src/modules/countries/data/m5-countries.seed.ts`
(« Septembre 2027 » pour la France, l'Allemagne, le Maroc, la Turquie, les
Émirats et l'Espagne depuis la reconduction : « Septembre 2026 » est passé) ne passe en base que par
`npm run seed:countries-m5`, qui RÉÉCRIT chaque pays (`upsert` avec mise à
jour) — corrections de l'admin comprises. `seed:omnes` ne crée la France que
si elle manque (`update` vide) et aucune opération `vps-ops` ne lance
`seed:countries-m5` : modifier le fichier ne touche pas la production, où le
libellé reste « Septembre 2026 ». L'app masque déjà un libellé passé
(`upcomingIntakeText`) : la carte pays n'annonce rien plutôt qu'une date
fausse. Aucun écran de l'admin n'édite ce champ ; l'aligner en production
(mise à jour ciblée, ou `seed:countries-m5` en connaissance de cause) est une
décision du propriétaire (À VALIDER). Les États-Unis (« Septembre 2026 ») ne
sont pas touchés ici : chantier Canada / États-Unis en cours.
