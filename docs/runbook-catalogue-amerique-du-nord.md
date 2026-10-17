# Runbook — catalogue Amérique du Nord (universités non partenaires)

Import ADDITIF, création seule, de 36 établissements non partenaires du Canada
et des États-Unis et de leurs 172 formations phares : première passe du
16/10/2026 (20 établissements, 97 formations), seconde passe Canada du
17/10/2026 (16 établissements — Québec, Nouveau-Brunswick, collèges de
l'Ontario —, 75 formations). Sélection et critères :
`docs/catalogue-amerique-du-nord.md`.

| Opération `vps-ops` | Script | Source (dans `backend/scripts/data/`) | Ce qu'elle écrit |
|---|---|---|---|
| `import-north-america` | `npm run import:north-america` | `amerique-du-nord-2027.json` ; provenance : `amerique-du-nord-2027.sources.md` | Établissements `na-ca-*` / `na-us-*` (`isPartner: false`) et formations `na-…--<slug>` |

## Ce qui est garanti

- **Création seule** : un établissement déjà en base n'est jamais réécrit ;
  seules ses formations manquantes sont créées et leurs ids AJOUTÉS à
  `programIds` (`push`). Une formation déjà en base n'est pas touchée.
- **Homonymes refusés** : un établissement de même nom (sigle final ignoré)
  sous un autre id — l'Université d'Ottawa existe déjà sous `uottawa` — ou une
  formation de même nom et niveau dans l'établissement : rien n'est créé, la
  ligne « ⚠ » du rapport le dit.
- Une formation **supprimée** dans l'admin est recréée au passage suivant
  (comme pour les autres imports additifs) : pour la retirer, la mettre hors
  ligne (`isActive = false`) plutôt que la supprimer.
- **Simulation par défaut**, `--apply` pour écrire ; relancé après
  application : `TOTAL : 0 écriture(s)`.
- **Garde de production** (`src/common/seed-safety.ts`) : l'application est
  autorisée tant qu'aucune ligne `na-*` n'existe ; ensuite il faut
  `KPB_ALLOW_PRODUCTION_SEED=1`. C'est le cas de la **seconde passe si la
  première est déjà appliquée** : l'opération vps-ops ne passe pas cette
  variable, il faut lancer l'application depuis le VPS (voir « Seconde passe »
  ci-dessous).
- Le document est validé avant toute lecture de la base (ids `na-<pays>-<slug>`,
  domaines `d01..d12`, niveaux `Bachelor` / `BBA` / `Master` / `Graduate
  certificate` / `Diplôme collégial`, types d'établissement (`universite_publique`,
  `ecole_universitaire`, `college_public`), date de relevé par établissement,
  programme de langue en amont repris dans les exigences linguistiques,
  libellés de frais lisibles par l'app, URL https, mention « KPB n'est pas
  partenaire ») : une erreur arrête tout.

## Procédure

Actions → **VPS ops** → Run workflow :

1. **Prérequis** : `npm run verify:catalog` doit laisser une marge d'au moins
   172 formations sous la limite de 1 000 des builds installées si rien n'est
   encore appliqué, 75 si la première passe l'est (dernière ligne
   « … (n/1000 programs) »).
2. **Simulation** : `action` = `import-north-america`, `dry_run` coché.
   Attendu sur une base sans ligne `na-*` : 36 établissements « À CRÉER »
   (Canada 26, États-Unis 10), 172 formations ; `TOTAL : 36 écriture(s)`.
   Si la première passe est déjà appliquée : 16 « À CRÉER » (les `na-ca-*` de
   la seconde passe, relevé du 2026-10-17), 20 « inchangé » ;
   `TOTAL : 16 écriture(s)`.
3. **Application** : même action, `dry_run` décoché. Le job enchaîne
   `npm run verify:catalog`, qui doit finir sur `OK`.
4. **Vérification** : relancer la simulation → `TOTAL : 0 écriture(s)`. Dans
   l'app (écran Universités, vue « Tous ») : filtre Canada / États-Unis,
   recherche « Houston », « UQAM », « McGill », « Humber », « UQTR »,
   « Moncton », « CCNB » ; aucune fiche ne porte le badge partenaire ; une
   formation Humber affiche plusieurs rentrées (janvier, mai, septembre 2027).

### Seconde passe quand la première est déjà en production

L'application est alors refusée par la garde (« REFUS : base de production…
contient déjà n ligne(s) »). Après une simulation propre (16 écritures, aucun
« ⚠ »), depuis le VPS :

```bash
docker compose exec -T -e KPB_ALLOW_PRODUCTION_SEED=1 api npm run import:north-america -- --apply
docker compose exec -T api npm run verify:catalog
docker compose exec -T api npm run import:north-america   # TOTAL : 0 écriture(s)
```

La création seule garantit qu'aucune fiche de la première passe n'est
réécrite.

En local (Postgres) :

```bash
cd backend
npm run import:north-america               # simulation
npm run import:north-america -- --apply    # 36 établissements, 172 formations
npm run import:north-america -- --apply    # 0 écriture
npm run verify:catalog
```

## Mettre à jour la source

Le JSON est produit par `scripts/generate-north-america.py` (versionné) :
modifier le générateur (un fait = une URL dans
`amerique-du-nord-2027.sources.md`), puis `python3
scripts/generate-north-america.py` (réécrit le JSON ; les 20 établissements de
la première passe doivent rester identiques), puis :

```bash
npx jest src/modules/catalog/north-america-import.spec.ts src/modules/catalog/catalog-duplicates.spec.ts
```

Les tests épinglent les comptes (26 + 10 établissements, 172 formations, 16
en seconde passe) : un ajout les fait échouer, c'est voulu. Un nouvel établissement ou une nouvelle
formation sont créés au prochain passage ; une **correction** d'une fiche déjà
en base ne l'est pas (création seule) : elle se fait dans l'admin.
