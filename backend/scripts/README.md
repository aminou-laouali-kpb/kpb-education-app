# Backend data scripts (KPB roadmap)

## 1) Countries launch seed

```bash
npm --prefix backend run seed:countries
```

Seeds the 9 launch countries required by the KPB product scope.

## 2) OMNES import template

```bash
npm --prefix backend run import:omnes -- "/absolute/path/to/OMNES_FALL_26_TOUT_PROGRAMME_030426.xlsx"
```

Bundled workbook (repo):

```bash
npm --prefix backend run import:omnes:bundled
```

This generates:

- `backend/scripts/output/omnes-programs-normalized.json` (747 programmes)

## 3) Base catalog seed (M5 countries + catalogue unique)

```bash
npm --prefix backend run seed:catalog
```

Runs `seed:countries-m5`, then `seed:catalogue-unique` (d01..d12 fields,
Senegal, general non-partner institutions and programs).

It no longer chains `seed:omnes` and `seed:partners`: both now run on their own,
on purpose (sections 4 and 5). Note that the two seeds it still runs upsert
their rows with a full update — re-running them reverts admin edits on those
rows — and have no production guard yet.

## 4) OMNES programs

```bash
npm --prefix backend run import:omnes:bundled   # writes the normalized JSON
npm --prefix backend run seed:omnes             # 292 formations, 5 schools
```

## 5) Partner schools only (annexe 05)

```bash
npm --prefix backend run seed:partners          # 76 programmes, 7 schools
```

## Seed safety: create-only, production guard

`seed:omnes` and `seed:partners` are **create-only** and never delete:

- a school (`omnes-*`, `partner-*`) that already exists is left exactly as it
  is, **with all its programs**, even if it was edited in the admin or a
  program was removed from it. Mundiapolis and Universiapolis, imported under
  the same `partner-*` prefix, are never touched;
- a missing school is created together with its missing programs, in one
  transaction; its `programIds` lists the programs actually attached to it;
- re-running them is therefore idempotent: the second run creates nothing.

Consequence: a fix to the seed data (e.g. a `fieldId`) only reaches rows the
seed creates. Rows already in a database must be corrected in the admin or by
a dedicated, reviewed script.

`seed:omnes`, `seed:partners` and `prisma:seed` **refuse to run against
production** (exit code 1, message in French and English) unless the database
holds none of the rows they would write — a true first install. For the two
catalog seeds that means no `omnes-*` / `partner-*` row at all, imported ones
included: a database holding Mundiapolis alone is not a first install. Production
means `NODE_ENV=production` (set by the API image and `docker-compose.yml`), or
a `DATABASE_URL` whose host is not `localhost`, `127.0.0.1`, `::1` or
`postgres-test`, or a missing `DATABASE_URL`. CI seeds `localhost` and is not
affected.

To run one anyway, deliberately and for that run only:

```bash
KPB_ALLOW_PRODUCTION_SEED=1 npm run seed:partners
# inside the API container:
docker compose exec -e KPB_ALLOW_PRODUCTION_SEED=1 api npm run seed:partners
```

Only the exact value `1` lifts the guard. Remember that `prisma:seed`, unlike
the two catalog seeds, still rewrites every row it knows (admin accounts' profile,
demo catalog, articles, parcours…).

The decision lives in `src/common/seed-safety.ts` (tested by
`seed-safety.spec.ts`).

## Prerequisites

- `DATABASE_URL` must be exported in your shell before running `seed:countries`.
- For importer runs, pass an absolute path to the OMNES `.xlsx` source file.
