# Runbook — catalogue Amérique du Nord (universités non partenaires)

Import ADDITIF, création seule, de 20 universités non partenaires du Canada et
des États-Unis et de leurs 97 formations phares (demande du propriétaire du
16/10/2026). Sélection et critères : `docs/catalogue-amerique-du-nord.md`.

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
  `KPB_ALLOW_PRODUCTION_SEED=1` (seulement utile après un ajout à la source).
- Le document est validé avant toute lecture de la base (ids `na-<pays>-<slug>`,
  domaines `d01..d12`, niveaux `Bachelor` / `BBA` / `Master`, libellés de frais
  lisibles par l'app, URL https, mention « KPB n'est pas partenaire ») : une
  erreur arrête tout.

## Procédure

Actions → **VPS ops** → Run workflow :

1. **Prérequis** : `npm run verify:catalog` doit laisser une marge d'au moins
   97 formations sous la limite de 1 000 des builds installées (dernière ligne
   « … (n/1000 programs) »).
2. **Simulation** : `action` = `import-north-america`, `dry_run` coché.
   Attendu à la première fois : 20 établissements « À CRÉER » (Canada 10,
   États-Unis 10), 97 formations ; `TOTAL : 20 écriture(s)`.
3. **Application** : même action, `dry_run` décoché. Le job enchaîne
   `npm run verify:catalog`, qui doit finir sur `OK`.
4. **Vérification** : relancer la simulation → `TOTAL : 0 écriture(s)`. Dans
   l'app (écran Universités, vue « Tous ») : filtre Canada / États-Unis,
   recherche « Houston », « UQAM », « McGill » ; aucune fiche ne porte le badge
   partenaire.

En local (Postgres) :

```bash
cd backend
npm run import:north-america               # simulation
npm run import:north-america -- --apply    # 20 établissements, 97 formations
npm run import:north-america -- --apply    # 0 écriture
npm run verify:catalog
```

## Mettre à jour la source

Modifier `scripts/data/amerique-du-nord-2027.json` (un fait = une URL dans
`amerique-du-nord-2027.sources.md`), puis :

```bash
npx jest src/modules/catalog/north-america-import.spec.ts src/modules/catalog/catalog-duplicates.spec.ts
```

Les tests épinglent les comptes (10 + 10 établissements, 97 formations) : un
ajout les fait échouer, c'est voulu. Un nouvel établissement ou une nouvelle
formation sont créés au prochain passage ; une **correction** d'une fiche déjà
en base ne l'est pas (création seule) : elle se fait dans l'admin.
