/**
 * Catalogue Amérique du Nord — CLI autour de
 * src/modules/catalog/north-america-import.ts.
 *
 * Crée des universités NON partenaires (`isPartner: false`) du Canada et des
 * États-Unis et leurs formations phares, depuis
 * scripts/data/amerique-du-nord-2027.json (provenance fait par fait :
 * scripts/data/amerique-du-nord-2027.sources.md ; sélection et critères :
 * docs/catalogue-amerique-du-nord.md).
 *
 * CRÉATION SEULE et rejouable : un établissement déjà en base n'est jamais
 * réécrit (seuls les ids de ses formations manquantes sont AJOUTÉS à
 * `programIds`), une formation déjà en base n'est pas touchée, un homonyme
 * déjà en base sous un autre id (l'Université d'Ottawa, `uottawa`) bloque la
 * création. Relancé après application : 0 écriture.
 *
 *   npm run import:north-america                 # simulation, n'écrit rien
 *   npm run import:north-america -- --apply      # écrit
 *
 * Garde de production (src/common/seed-safety.ts), à l'application seulement :
 * autorisée tant qu'aucune ligne `na-*` n'est en base, refusée ensuite sauf
 * KPB_ALLOW_PRODUCTION_SEED=1 — nécessaire pour la seconde passe Canada
 * (17/10/2026) si la première est déjà appliquée : seuls les établissements et
 * formations absents sont créés.
 */
import { existsSync, readFileSync } from 'node:fs';
import * as path from 'node:path';
import { loadEnvFile } from 'node:process';

import { Prisma, PrismaClient } from '@prisma/client';

import { checkProductionSeed, linkedProgramIds } from '../src/common/seed-safety';
import {
  EU_ID_PREFIX,
  EU_SEED_NAME,
  NA_COUNTRIES,
  NA_ID_PREFIX,
  NA_SEED_NAME,
  type NaSource,
  naPlanWriteCount,
  planNaCorrections,
  planNorthAmerica,
  validateNaSource,
} from '../src/modules/catalog/north-america-import';
import { M5_COUNTRY_SEEDS } from '../src/modules/countries/data/m5-countries.seed';

if (existsSync('.env')) loadEnvFile?.('.env');

const prisma = new PrismaClient();
/// `--europe` : universités non partenaires de Belgique et d'Allemagne
/// (scripts/data/europe-2027.json, ids `eu-*`), même format et mêmes garanties.
const EUROPE = process.argv.slice(2).includes('--europe');
const SOURCE = path.join(__dirname, 'data', EUROPE ? 'europe-2027.json' : 'amerique-du-nord-2027.json');
const ID_PREFIX = EUROPE ? EU_ID_PREFIX : NA_ID_PREFIX;
const SEED_NAME = EUROPE ? EU_SEED_NAME : NA_SEED_NAME;
const COUNTRY_LABEL: Record<string, string> = { can: 'Canada', usa: 'États-Unis', bel: 'Belgique', deu: 'Allemagne' };

type ProgramData = ReturnType<typeof planNorthAmerica>['newInstitutions'][number]['programs'][number];

function toCreate(p: ProgramData): Prisma.ProgramCreateManyInput {
  return {
    ...p,
    campusOfferings: p.campusOfferings
      ? (p.campusOfferings as unknown as Prisma.InputJsonValue)
      : Prisma.DbNull,
  };
}

async function main() {
  const apply = process.argv.slice(2).includes('--apply');
  if (!existsSync(SOURCE)) {
    console.error(`Source introuvable : ${SOURCE}`);
    process.exit(1);
  }
  const doc = JSON.parse(readFileSync(SOURCE, 'utf8')) as NaSource;
  const errors = validateNaSource(doc);
  const dates = [...new Set(doc.institutions.map((i) => i.consultedAt ?? doc.consultedAt))].sort();
  console.log(`Source : ${SOURCE} (consultée le ${dates.join(' et le ')}, taux BCE du ${doc.exchangeRates.date})`);
  if (errors.length) {
    console.error('\nERREURS — rien ne sera écrit :');
    for (const e of errors) console.error(`  ✗ ${e}`);
    process.exit(1);
  }

  const institutions = await prisma.institution.findMany({
    select: { id: true, nameFr: true, nameEn: true, programIds: true },
  });
  const ids = doc.institutions.map((i) => i.id);
  const programs = await prisma.program.findMany({
    where: { institutionId: { in: ids } },
    select: { id: true, institutionId: true, nameFr: true, levelFr: true },
  });
  const plan = planNorthAmerica(doc, institutions, programs);
  const corrections = planNaCorrections(
    doc,
    await prisma.program.findMany({
      where: { id: { in: (doc.corrections?.programs ?? []).map((c) => c.programId) } },
      select: { id: true, tuitionFr: true, applicationFeeEur: true, durationFr: true, requirementsFr: true, isActive: true },
    }),
    await prisma.institution.findMany({
      where: { id: { in: (doc.corrections?.institutions ?? []).map((c) => c.institutionId) } },
      select: { id: true, tuitionLabelFr: true },
    }),
  );

  // Pays de destination absents (la Belgique, 12/11/2026) : créés depuis la
  // fiche M5 versionnée, jamais réécrits s'ils existent.
  const countryIds = [...new Set(doc.institutions.map((i) => NA_COUNTRIES[i.countryId].countryId))];
  const existingCountries = new Set(
    (await prisma.country.findMany({ where: { id: { in: countryIds } }, select: { id: true } })).map((c) => c.id),
  );
  const missingCountries = countryIds.filter((id) => !existingCountries.has(id));
  for (const id of missingCountries) {
    if (!M5_COUNTRY_SEEDS.some((c) => c.id === id)) {
      console.error(`Pays « ${id} » absent de la base ET de m5-countries.seed.ts — rien ne sera écrit.`);
      process.exit(1);
    }
    console.log(`\n══ Pays à créer : ${id} (fiche m5-countries.seed.ts)`);
  }

  for (const country of Object.keys(COUNTRY_LABEL)) {
    const own = doc.institutions.filter((i) => i.countryId === country);
    if (!own.length) continue;
    console.log(`\n══ ${COUNTRY_LABEL[country]} : ${own.length} établissement(s) dans la source`);
    for (const inst of own) {
      const fresh = plan.newInstitutions.find((n) => n.institution.id === inst.id);
      const extra = plan.programAdditions.find((a) => a.institutionId === inst.id);
      const skip = plan.skipped.find((s) => s.id === inst.id);
      const state = fresh ? 'À CRÉER' : skip ? 'IGNORÉ' : extra ? 'à compléter' : 'inchangé';
      const created = fresh?.programs ?? extra?.programs ?? [];
      console.log(`── ${inst.id}  [${state}]  ${inst.nameFr} — non partenaire (relevé du ${inst.consultedAt ?? doc.consultedAt})`);
      console.log(`   formations à créer : ${created.length} / ${inst.programs.length}`);
      for (const p of created) {
        console.log(
          `     + ${p.levelFr.padEnd(20)} ${p.nameFr.slice(0, 70)}${p.tuitionMinEur ? ` — ${p.tuitionMinEur} €/an (plancher)` : ''}`,
        );
      }
      if (extra?.addProgramIds.length) console.log(`   + ${extra.addProgramIds.length} id(s) ajouté(s) à programIds`);
    }
  }
  for (const s of plan.skipped) console.log(`  ⚠ ${s.id} (${s.name}) : ${s.reason}`);

  if (corrections.programs.length || corrections.institutions.length || corrections.skipped.length) {
    console.log('\n══ Corrections de lignes déjà publiées (prix complétés)');
    for (const c of corrections.institutions) console.log(`   ~ ${c.id} : libellé de frais → ${c.data.tuitionLabelFr.slice(0, 80)}`);
    for (const c of corrections.programs) {
      const what = [
        c.data.tuitionFr && `frais → ${c.data.tuitionFr.slice(0, 70)}`,
        c.data.durationFr && `durée → ${c.data.durationFr}`,
        c.data.requirementsFr && `conditions → ${c.data.requirementsFr.length} ligne(s)`,
        c.data.applicationFeeEur != null && `frais de candidature → ${c.data.applicationFeeEur} €`,
        c.data.isActive === false && 'HORS LIGNE (admissions suspendues)',
      ];
      console.log(`   ~ ${c.id} : ${what.filter(Boolean).join(' ; ')}`);
    }
    for (const s of corrections.skipped) console.log(`  ⚠ ${s.id} : ${s.reason}`);
  }

  const writes =
    naPlanWriteCount(plan) + missingCountries.length + corrections.programs.length + corrections.institutions.length;
  console.log(`\nTOTAL : ${writes} écriture(s) prévue(s).`);
  if (!apply) {
    console.log('\n── SIMULATION — aucune écriture. Relancer avec --apply. ──');
    return;
  }
  if (writes === 0) {
    console.log('\n── Rien à écrire : la source est déjà appliquée. ──');
    return;
  }

  const guard = await checkProductionSeed({
    seed: SEED_NAME,
    countExistingRows: async () =>
      (await prisma.institution.count({ where: { id: { startsWith: ID_PREFIX } } })) +
      (await prisma.program.count({ where: { id: { startsWith: ID_PREFIX } } })),
  });
  if (!guard.allowed) {
    console.error(guard.message);
    process.exitCode = 1;
    return;
  }
  if (guard.message) console.warn(guard.message);

  let written = 0;
  for (const id of missingCountries) {
    const seed = M5_COUNTRY_SEEDS.find((c) => c.id === id)!;
    const { quiz, lastVerifiedAt, sourceUrl, ...fields } = seed;
    await prisma.$transaction(async (tx) => {
      if (await tx.country.findUnique({ where: { id }, select: { id: true } })) return;
      await tx.country.create({
        data: {
          ...fields,
          isActive: true,
          lastVerifiedAt: lastVerifiedAt ? new Date(lastVerifiedAt) : null,
          sourceUrl: sourceUrl ?? null,
        },
      });
      await tx.countryEligibilityQuiz.create({
        data: {
          countryId: id,
          questions: quiz.questions as unknown as Prisma.InputJsonValue,
          verdicts: quiz.verdicts as unknown as Prisma.InputJsonValue,
        },
      });
    });
    console.log(`   pays créé : ${id}`);
    written += 1;
  }

  for (const { institution, programs: rows } of plan.newInstitutions) {
    const done = await prisma.$transaction(
      async (tx) => {
        // Revérifiée DANS la transaction : un établissement créé entre la
        // lecture et l'écriture (autre import, admin) est laissé tel quel.
        if (await tx.institution.findUnique({ where: { id: institution.id }, select: { id: true } })) {
          return false;
        }
        if (rows.length) await tx.program.createMany({ data: rows.map(toCreate), skipDuplicates: true });
        const attached = await tx.program.findMany({
          where: { institutionId: institution.id },
          select: { id: true },
        });
        await tx.institution.create({
          data: {
            ...institution,
            programIds: linkedProgramIds(institution.programIds, attached.map((p) => p.id)),
          },
        });
        return true;
      },
      { timeout: 60_000 },
    );
    console.log(done ? `   créé : ${institution.id}` : `   ${institution.id} : créé entre-temps, laissé intact`);
    if (done) written += 1;
  }

  for (const add of plan.programAdditions) {
    await prisma.$transaction(
      async (tx) => {
        if (add.programs.length) {
          await tx.program.createMany({ data: add.programs.map(toCreate), skipDuplicates: true });
        }
        if (add.addProgramIds.length) {
          // `push` ajoute sans relire ni réécrire ce qui est déjà dans la liste.
          await tx.institution.update({
            where: { id: add.institutionId },
            data: { programIds: { push: add.addProgramIds } },
          });
        }
      },
      { timeout: 60_000 },
    );
    written += 1;
  }

  for (const c of corrections.institutions) {
    // Revérifiée à l'écriture : la ligne doit porter encore l'ancienne valeur.
    const prev = doc.corrections!.institutions.find((x) => x.institutionId === c.id)!.previousTuitionLabelFr;
    const r = await prisma.institution.updateMany({ where: { id: c.id, tuitionLabelFr: prev }, data: c.data });
    written += r.count;
  }
  for (const c of corrections.programs) {
    // Revérifiée à l'écriture : frais encore à l'ancienne valeur, durée encore vide.
    const where: Prisma.ProgramWhereInput = { id: c.id };
    if (c.whereTuitionFr !== undefined) where.tuitionFr = c.whereTuitionFr;
    if (c.data.durationFr !== undefined) where.durationFr = '';
    if (c.whereRequirementsFr !== undefined) where.requirementsFr = { equals: c.whereRequirementsFr };
    if (c.data.applicationFeeEur !== undefined && c.data.tuitionFr === undefined) where.applicationFeeEur = null;
    const r = await prisma.program.updateMany({ where, data: c.data });
    written += r.count;
  }

  console.log(`\n── ÉCRIT : ${written} écriture(s). ──`);
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
