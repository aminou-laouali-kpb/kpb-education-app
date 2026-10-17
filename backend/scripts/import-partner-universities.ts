/**
 * CLI around src/modules/catalog/partner-import.ts.
 *
 * Scope is an explicit ALLOWLIST (`TARGETS`), not "everything in the file".
 * The CSV also carries OMNES rows (INSEEC, ECE, ESCE, Sup de Pub, HEIP) that
 * are ALREADY in production under `omnes-*`, listed campus-by-campus where the
 * database stores one campus-agnostic Program carrying `campusOfferings[]`.
 * Importing those blindly would re-explode that grouping into duplicates.
 * Universiapolis is excluded too: its 15 rows are 5 cursus listed year by year
 * ("1re année", "2e année"…) — study years, not degree levels.
 *
 * Idempotent: ids are derived deterministically and writes are `upsert` with an
 * EMPTY update, so a re-run creates nothing and never clobbers a fiche the team
 * edited by hand. This script only fills gaps.
 *
 *   npm run import:partners                             # dry run, writes nothing
 *   npm run import:partners -- --apply                  # writes
 *   npm run import:partners -- --skip=partner-schiller-tampa
 */
import { existsSync, readFileSync } from 'node:fs';
import * as path from 'node:path';
import { loadEnvFile } from 'node:process';

import { PrismaClient } from '@prisma/client';

import {
  COUNTRY_BY_LABEL,
  FIELD_BY_LABEL,
  KNOWN_LEVELS,
  LANGUAGES_BY_LABEL,
  TARGETS,
  assertTargetsAreSchools,
  type BackfillableKey,
  type PlannedProgram,
  type Target,
  institutionBlankFills,
  normalizeLevel,
  parseCsv,
  parseTuitionMinEur,
  stableId,
} from '../src/modules/catalog/partner-import';
import { programNameKey } from '../src/modules/catalog/catalog-dedupe';

if (existsSync('.env')) loadEnvFile?.('.env');

const prisma = new PrismaClient();
const DEFAULT_CSV = path.join(__dirname, 'data', 'universites-partenaires.csv');

async function main() {
  const args = process.argv.slice(2);
  const apply = args.includes('--apply');
  const skip = new Set(
    args.filter((a) => a.startsWith('--skip=')).map((a) => a.slice(7)),
  );
  const csvPath = args.find((a) => !a.startsWith('--')) ?? DEFAULT_CSV;

  if (!existsSync(csvPath)) {
    console.error(`CSV introuvable : ${csvPath}`);
    process.exit(1);
  }
  const rows = parseCsv(readFileSync(csvPath, 'utf8'));
  console.log(`Source : ${csvPath} (${rows.length} lignes)\n`);

  const targets = TARGETS.filter((t) => !skip.has(t.id));
  const errors: string[] = [...assertTargetsAreSchools(targets)];
  const warnings: string[] = [];
  const plan: {
    target: Target;
    exists: boolean;
    programs: PlannedProgram[];
    overviewFr: string;
    fills: Partial<Record<BackfillableKey, string>>;
  }[] = [];

  for (const target of targets) {
    const group = rows.filter((r) => r.Institution === target.csvName);
    if (!group.length) {
      errors.push(`Aucune ligne pour "${target.csvName}" dans le CSV.`);
      continue;
    }
    const csvCountry = COUNTRY_BY_LABEL[group[0].Pays];
    if (!csvCountry) {
      errors.push(`Pays non mappé : "${group[0].Pays}" (${target.csvName})`);
    } else if (csvCountry !== target.countryId) {
      warnings.push(
        `${target.id} : le CSV dit "${group[0].Pays}" (${csvCountry}), on écrit "${target.countryId}".`,
      );
    }

    const programs: PlannedProgram[] = [];
    const seen = new Set<string>();
    for (const r of group) {
      const fieldId = FIELD_BY_LABEL[r.Filiere];
      if (!fieldId) {
        errors.push(`Filière non mappée : "${r.Filiere}" (${r.Programme})`);
        continue;
      }
      const teaching = LANGUAGES_BY_LABEL[r.Langue];
      if (teaching === undefined) {
        errors.push(`Langue non mappée : "${r.Langue}" (${r.Programme})`);
        continue;
      }
      const nameFr = r.Programme.trim();
      if (!nameFr) {
        errors.push(`Programme sans nom (${target.id})`);
        continue;
      }
      const id = stableId('partner-p-', `${target.id}|${nameFr}`);
      // Doublon interne : même id, ou même nom normalisé (casse, accents…).
      const key = `${programNameKey(nameFr)}#${normalizeLevel(r.Niveau)}`;
      if (seen.has(id) || seen.has(key)) {
        warnings.push(`${target.id} : doublon interne ignoré — "${nameFr}"`);
        continue;
      }
      seen.add(id);
      seen.add(key);

      const levelFr = normalizeLevel(r.Niveau);
      if (levelFr && !KNOWN_LEVELS.has(levelFr)) {
        warnings.push(
          `${target.id} : niveau hors référentiel conservé tel quel — "${r.Niveau}" (${nameFr})`,
        );
      }
      const tuitionMinEur = parseTuitionMinEur(r.Cout);
      programs.push({
        id,
        nameFr,
        levelFr,
        rawLevel: r.Niveau,
        fieldId,
        durationFr: r.Duree === 'Non précisée' ? '' : r.Duree,
        tuitionFr: r.Cout,
        tuitionMinEur,
        languageFr: r.Langue === 'Non précisée' ? '' : r.Langue,
        teachingLanguages: teaching,
        campusOfferings:
          target.campuses.length > 1
            ? target.campuses.map((campus) => ({
                campus,
                tuitionUpfront: tuitionMinEur,
                tuitionInstallments: null,
                intake: null,
              }))
            : null,
      });
    }

    // La description est identique sur toutes les lignes d'un établissement ;
    // on prend celle de la première.
    const overviewFr = (group[0].Description ?? '').trim();
    const incoming = {
      overviewFr,
      overviewEn: overviewFr,
      locationFr: target.campuses.join(' · '),
      locationEn: target.campuses.join(' · '),
    };
    const existing = await prisma.institution.findUnique({
      where: { id: target.id },
      select: {
        id: true,
        overviewFr: true,
        overviewEn: true,
        locationFr: true,
        locationEn: true,
      },
    });
    const fills = existing ? institutionBlankFills(existing, incoming) : {};
    plan.push({ target, exists: existing != null, programs, overviewFr, fills });
  }

  let creates = 0;
  let skipped = 0;
  const toWrite: {
    target: Target;
    programs: PlannedProgram[];
    overviewFr: string;
    fills: Partial<Record<BackfillableKey, string>>;
  }[] = [];
  for (const { target, exists, programs, overviewFr, fills } of plan) {
    // Comparaison par nom NORMALISÉ (casse, accents, espaces, tirets) : une
    // fiche créée à la main dans l'admin sous un autre id n'est pas doublée.
    const present = new Set(
      (
        await prisma.program.findMany({
          where: { institutionId: target.id },
          select: { nameFr: true },
        })
      ).map((p) => programNameKey(p.nameFr)),
    );
    const fresh = programs.filter((p) => !present.has(programNameKey(p.nameFr)));
    creates += fresh.length;
    skipped += programs.length - fresh.length;
    toWrite.push({ target, programs: fresh, overviewFr, fills });

    console.log(
      `── ${target.id}  [${exists ? 'établissement existant' : 'À CRÉER'}]  pays=${target.countryId}`,
    );
    console.log(
      `   ${fresh.length} programme(s) à créer` +
        (programs.length - fresh.length
          ? `, ${programs.length - fresh.length} déjà présent(s) — ignoré(s)`
          : ''),
    );
    console.log(
      `   tuitionMinEur : ${fresh.filter((p) => p.tuitionMinEur != null).length}/${fresh.length}` +
        ` · teachingLanguages : ${fresh.filter((p) => p.teachingLanguages.length).length}/${fresh.length}`,
    );
    for (const p of fresh.slice(0, 3)) {
      console.log(`     · ${p.levelFr || '(sans niveau)'} — ${p.nameFr.slice(0, 62)}`);
    }
    if (fresh.length > 3) console.log(`     · … ${fresh.length - 3} de plus`);
    const filled = Object.keys(fills);
    if (filled.length) {
      console.log(`   colonnes vides à combler : ${filled.join(', ')}`);
    }
    console.log();
  }

  if (warnings.length) {
    console.log('AVERTISSEMENTS');
    for (const w of warnings) console.log(`  ⚠ ${w}`);
    console.log();
  }
  if (errors.length) {
    console.error('ERREURS — rien ne sera écrit :');
    for (const e of errors) console.error(`  ✗ ${e}`);
    process.exit(1);
  }

  console.log(`TOTAL : ${creates} programme(s) à créer, ${skipped} ignoré(s).`);
  if (!apply) {
    console.log('\n── SIMULATION — aucune écriture. Relancer avec --apply. ──');
    return;
  }

  for (const { target, programs, overviewFr, fills } of toWrite) {
    // Le comblement N'EST PAS fait ici. `fills` a été calculé pendant la phase
    // de lecture ; l'appliquer dans cet `update` écraserait le texte d'un
    // administrateur qui aurait rempli la colonne entre-temps. Il est appliqué
    // plus bas, colonne par colonne, sous un `WHERE col = ''` qui revérifie le
    // vide au moment exact de l'écriture.
    await prisma.institution.upsert({
      where: { id: target.id },
      update: {},
      create: {
        id: target.id,
        nameFr: target.nameFr,
        nameEn: target.nameEn,
        countryId: target.countryId,
        locationFr: target.campuses.join(' · '),
        locationEn: target.campuses.join(' · '),
        overviewFr,
        overviewEn: overviewFr,
        studyLevels: [...new Set(programs.map((p) => p.levelFr).filter(Boolean))],
        tuitionLabelFr: '',
        tuitionLabelEn: '',
        languageRequirementsFr: '',
        languageRequirementsEn: '',
        intakePeriods: [],
        programIds: [],
        isPartner: true,
      },
    });
    for (const p of programs) {
      await prisma.program.upsert({
        where: { id: p.id },
        update: {},
        create: {
          id: p.id,
          institutionId: target.id,
          countryId: target.countryId,
          fieldId: p.fieldId,
          nameFr: p.nameFr,
          nameEn: p.nameFr,
          levelFr: p.levelFr,
          levelEn: p.levelFr,
          durationFr: p.durationFr,
          durationEn: p.durationFr,
          tuitionFr: p.tuitionFr,
          tuitionEn: p.tuitionFr,
          languageFr: p.languageFr,
          languageEn: p.languageFr,
          requirementsFr: [],
          requirementsEn: [],
          teachingLanguages: p.teachingLanguages,
          ...(p.tuitionMinEur != null ? { tuitionMinEur: p.tuitionMinEur } : {}),
          ...(p.campusOfferings ? { campusOfferings: p.campusOfferings } : {}),
        },
      });
    }

    // Comblement atomique : `updateMany` produit un
    // `UPDATE … WHERE id = ? AND col = ''`. Si la colonne a été remplie depuis
    // la lecture, le `WHERE` ne trouve rien et l'écriture n'a pas lieu — la
    // garantie « ne jamais écraser » est tenue par la base, pas par le script.
    for (const [key, value] of Object.entries(fills)) {
      const { count } = await prisma.institution.updateMany({
        where: { id: target.id, [key]: '' },
        data: { [key]: value },
      });
      console.log(
        count
          ? `   comblé : ${key}`
          : `   ${key} : rempli entre-temps, laissé intact`,
      );
    }
  }
  console.log('\n── ÉCRIT ──');
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
