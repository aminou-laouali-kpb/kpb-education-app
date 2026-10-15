# Versioned scholarship catalog

`scholarship-catalog.v1.ts` is the only bulk-import input for scholarships.
Its `records` collection accepts only opportunities checked against current,
official HTTPS sources. The legacy mock catalog is tracked under `backlog` and
is not considered verified or importable.

Required evidence per record:

- bilingual title, description, benefits, eligibility and requirements;
- structured level (`secondary`, `bachelor`, `master`, `doctorate`), mirrored
  exactly by the record's level tags (`level_tags_mismatch` otherwise);
- ordered bilingual application steps;
- an estimated or confirmed annual application cycle;
- official HTTPS sources for overview, eligibility, benefits, application and
  cycle dates;
- a named verifier and a verification timestamp no older than 30 days.

Commands:

```bash
npm run scholarships:validate:structure
npm run verify:scholarships
npm run scholarships:import:dry-run
npm run scholarships:import
```

Catalog version `1.5.0` contains 36 distinct opportunities (re-read against
their official sources on 2026-09-29, Gates Cambridge and CMU-Africa on
2026-10-07, see `docs/catalog-verification-2026-09-29.md`) and meets every
launch target (multi-level records count once in each applicable level):
4 secondary, 17 Bachelor, 27 Master and 2 doctoral matches. `1.5.0` adds the
structured eligibility below and the `doctorate` level (Gates Cambridge, UCT). The
validator checks the unique-record minimum separately, so one multi-level
opportunity cannot artificially satisfy the total-volume gate. A cycle copied forward from a prior
official call is always `forecast` + `estimated`, and its copy explicitly says
that confirmation is still required. Announced future cycles are `forecast` +
`confirmed`; only calls currently accepting applications may be `open` +
`confirmed`.

The strict validator fails on a missing volume target or any record-level
quality issue. The structure-only command remains the fast CI check, while the
dry-run command verifies the exact import set without writing to the database.

`import` is create-only: existing database ids are reported as not updated and
are never rewritten by it. Corrections reach existing rows through
`catalog:reconcile` (see `docs/catalog-verification-sop.md`). Imported records are inactive and pending moderation, so an
admin must review and publish them.

## Structured eligibility (`1.5.0`, chantier D)

Each record carries an optional `eligibility { fieldsScope, criteria,
structuredAt, structuredBy }` block, persisted by `import`/`reconcile` into
`eligibleLevels` (from `levels`), `fieldsScope`, `eligibilityCriteria`,
`eligibilityStructuredAt` and `eligibilityStructuredBy`. The criteria use the
typed v1 format of `scholarship-match/eligibility-criteria.ts`.

The 36 blocks live in `scholarship-catalog.eligibility.v1.ts` and are
**drafts**: written from each record's own eligibility text, each criterion
quoting one eligibility line verbatim (`officialTextFr/En`) with the record's
official eligibility source. `structuredAt` is `null` and `structuredBy` is
`draft` until an editor re-reads the criteria against the source and adds
`reviewed: { at, by }` to the record's entry. The matching engine never
excludes a student on an unstamped (or 400-day-old) block: it shows « à
vérifier » instead.

The validator rejects malformed criteria, quotes that are not a line of the
record, sources that are not declared official sources, and inconsistent
stamps. `missing_structured_eligibility` (no block, or a draft) is a
**warning** today (`STRUCTURED_ELIGIBILITY_GATE` in the validator); it becomes
an error once all 36 records are stamped. `reconcile` never overwrites a
newer admin stamp, and never replaces stamped criteria with a repository
draft. `npm run verify:catalog` prints the coverage (stamped / drafts /
missing, in the repository and among served rows). Procedure:
`docs/catalog-verification-sop.md`.
