# Runbook — rentrée décalée OMNES et groupe IGENSIA Education

Deux imports ADDITIFS du catalogue partenaires (chantier E/J, sources du
propriétaire du 16/10/2026) :

| Opération `vps-ops` | Script | Source (dans `backend/scripts/data/`) | Ce qu'elle écrit |
|---|---|---|---|
| `import-omnes-spring` | `npm run import:omnes-spring` | `omnes_spring_27.csv` (extrait de `omnes_spring_27.pdf`) | Offres de printemps 2027 des formations OMNES (ECE, ESCE, INSEEC) ; formations OMNES manquantes |
| `import-igensia` | `npm run import:igensia` | `igensia_2027.csv` (de `igensia_2027.pdf`), `abc_2027.csv` (de `abc_2027.xlsx`) | Écoles IGENSIA School of Business, IGENSIA Tech, IGENSIA RH, American Business College et leurs formations |

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

## Procédure

Pour chacune des deux opérations, dans cet ordre (`import-omnes-spring`, puis
`import-igensia`) — Actions → **VPS ops** → Run workflow :

1. **Simulation** : `action` = l'opération, `dry_run` coché. Lire le rapport :
   par école, formations à créer / complétées / inchangées et offres ajoutées.
   Attendu à la première fois :
   - `import-omnes-spring` : 37 formations créées (ECE 11, ESCE 3,
     INSEEC 23), 90 complétées (ECE 7, ESCE 14, INSEEC 69), 286 offres de
     printemps en tout (ECE 18, ESCE 17, INSEEC 251) ; `TOTAL : 130 écriture(s)`.
     Ces nombres valent si les fiches OMNES n'ont pas été modifiées depuis le
     seed ; un écart se lit ligne à ligne dans le rapport.
   - `import-igensia` : 4 écoles « À CRÉER », 22 formations (ISB 12,
     IGENSIA Tech 2, IGENSIA RH 3, ABC 5), 34 offres ; `TOTAL : 4 écriture(s)`.
   Une ligne `ERREURS — rien ne sera écrit` arrête tout : la source contient
   une valeur que les tables fermées ne connaissent pas.
2. **Application** : même `action`, `dry_run` décoché. Le job enchaîne
   `npm run verify:catalog`, qui doit finir sur `OK` (références pays, domaines,
   écoles partenaires avec au moins une formation, et le total servi sous la
   limite de 1 000 formations des builds installées : ~59 formations de plus).
3. **Vérification** : relancer la simulation. Attendu : `TOTAL : 0 écriture(s)`.
   Dans l'app, la recherche « IGENSIA », « ABC » ou « American Business College »
   trouve les nouvelles écoles ; une fiche OMNES comme « ECE - B1 - Cybersécurité
   et réseaux » montre Paris deux fois : « Rentrée d'octobre 2026 » et
   « Rentrée décalée · mars 2027 », chacune avec son prix.

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
