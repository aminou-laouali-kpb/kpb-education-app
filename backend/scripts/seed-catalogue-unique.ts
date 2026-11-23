/**
 * Seeds the "catalogue unique" GENERAL (non-partner) catalogue into Postgres:
 *   - d01..d12 fields (taxonomy used by these programs, the orientation engine
 *     and the mobile app — the base mock-catalog only seeds 3 demo fields)
 *   - Senegal country (authored; the deliverable only carried name/iso/currency)
 *   - 53 institutions + 212 programs across canada/germany/morocco/senegal/uk/usa
 *
 * Partner schools and their 94 programs are intentionally NOT seeded here — they
 * already live in src/modules/catalog/data/partner-schools.seed.ts.
 *
 * Create-only : une ligne déjà en base (domaine, pays, établissement,
 * formation) n'est JAMAIS réécrite. Un `update` complet vidait les
 * descriptions et liens des domaines enrichis dans l'admin, réactivait le
 * Sénégal retiré, et remplaçait `programIds` par la liste figée du seed — les
 * formations ajoutées dans l'admin devenaient inaccessibles dans l'app.
 * Seule écriture sur l'existant : une formation que CE lancement crée est
 * ajoutée au `programIds` de son établissement (sans rien retirer).
 *
 * Refused on a production database that already holds rows of this seed,
 * unless KPB_ALLOW_PRODUCTION_SEED=1 (see src/common/seed-safety.ts).
 *
 * Usage:
 *   npm run seed:catalogue-unique
 *   ts-node scripts/seed-catalogue-unique.ts
 */
import { existsSync } from 'node:fs';
import { loadEnvFile } from 'node:process';

import { PrismaClient } from '@prisma/client';

import { checkProductionSeed, linkedProgramIds } from '../src/common/seed-safety';
import {
  catalogueUniqueInstitutions,
  catalogueUniquePrograms,
} from '../src/common/data/catalogue-unique.seed';
import { ORIENTATION_FIELDS } from '../src/modules/orientation/orientation-fields.data';

// Le conteneur API n'embarque pas de `.env` (Compose fournit DATABASE_URL) :
// un chargement inconditionnel levait ENOENT avant même le garde-fou.
if (existsSync('.env')) loadEnvFile?.('.env');

// The catalogue-unique deliverable was authored with human-readable country ids
// (canada/germany/morocco/uk), but the canonical M5 countries use ISO codes
// (can/deu/mar/gbr). Without this remap the institutions/programs link to a
// non-existent country (germany, morocco → orphaned) or to the inactive legacy
// rows (canada, uk), so they never surface under their active country page.
// usa and senegal already match active country ids, so they pass through.
const COUNTRY_ID_REMAP: Record<string, string> = {
  morocco: 'mar',
  germany: 'deu',
  canada: 'can',
  uk: 'gbr',
};
const canonicalCountryId = (id: string): string => COUNTRY_ID_REMAP[id] ?? id;

// Senegal — authored locally (FR primary). Refine marketing copy as needed.
const SENEGAL = {
  code: 'SN',
  flagEmoji: '🇸🇳',
  nameFr: 'Sénégal',
  nameEn: 'Senegal',
  taglineFr: 'Étudier près de chez soi, dans un hub francophone en pleine croissance',
  taglineEn: 'Study close to home, in a fast-growing Francophone hub',
  nextIntakeLabelFr: 'Rentrée septembre 2026',
  nextIntakeLabelEn: 'September 2026 intake',
  mainLanguageFr: 'Français',
  mainLanguageEn: 'French',
  whyStudyFr:
    "Le Sénégal abrite un secteur privé de l'enseignement supérieur dynamique, surtout à Dakar, avec des écoles de management, de technologie et de communication reconnues dans la sous-région.",
  whyStudyEn:
    'Senegal has a dynamic private higher-education sector, especially in Dakar, with management, technology and communication schools well known across the region.',
  marketingDescriptionFr:
    "Une option d'études de qualité, proche culturellement et financièrement accessible, idéale pour démarrer un parcours avant une éventuelle mobilité internationale.",
  marketingDescriptionEn:
    'A quality study option that is culturally close and financially accessible — ideal to start a path before a possible international move.',
  whyStudyBulletsFr: [
    'Proximité géographique et culturelle',
    'Frais de scolarité abordables en zone XOF',
    'Écoles privées orientées employabilité',
  ],
  whyStudyBulletsEn: [
    'Geographic and cultural proximity',
    'Affordable tuition in the XOF zone',
    'Employability-focused private schools',
  ],
  costsOverviewFr:
    'Frais de scolarité et coût de la vie nettement inférieurs aux destinations européennes ou nord-américaines.',
  costsOverviewEn:
    'Tuition and living costs are well below European or North American destinations.',
  languageSectionFr: 'Enseignement majoritairement en français ; quelques programmes en anglais.',
  languageSectionEn: 'Teaching is mostly in French; a few programs are in English.',
  partnerSchoolsFr: '',
  partnerSchoolsEn: '',
  scholarshipsSectionFr: 'Bourses et facilités de paiement selon les établissements (à confirmer).',
  scholarshipsSectionEn: 'Scholarships and payment plans vary by institution (to be confirmed).',
  whatsAppPrefillFr:
    'Bonjour KPB Education, je souhaite être accompagné(e) pour étudier au Sénégal.',
  whatsAppPrefillEn:
    'Hello KPB Education, I would like guidance to study in Senegal.',
  tuitionRangeFr: '800 000 – 2 500 000 XOF/an (indicatif)',
  tuitionRangeEn: 'XOF 800,000 – 2,500,000/yr (indicative)',
  livingCostRangeFr: '100 000 – 250 000 XOF/mois (indicatif)',
  livingCostRangeEn: 'XOF 100,000 – 250,000/month (indicative)',
  visaOverviewFr:
    "Pas de visa étudiant requis pour les ressortissants de la CEDEAO ; titre de séjour selon la nationalité.",
  visaOverviewEn:
    'No student visa required for ECOWAS nationals; residence permit depending on nationality.',
  admissionDifficultyFr: 'Accessible (dossier + niveau requis selon le programme)',
  admissionDifficultyEn: 'Accessible (application + program-specific requirements)',
  popularFieldIds: ['d02', 'd01', 'd06'],
  displayOrder: 50,
  isActive: true,
};

type SeedClient = Pick<
  PrismaClient,
  'field' | 'country' | 'institution' | 'program'
>;

export async function seedCatalogueUnique(prisma: SeedClient): Promise<boolean> {
  const fieldIds = ORIENTATION_FIELDS.map((f) => f.id);
  const institutionIds = catalogueUniqueInstitutions.map((i) => i.id);
  const programIds = catalogueUniquePrograms.map((p) => p.id);
  const guard = await checkProductionSeed({
    seed: 'seed:catalogue-unique',
    countExistingRows: async () =>
      (await prisma.field.count({ where: { id: { in: fieldIds } } })) +
      (await prisma.country.count({ where: { id: 'senegal' } })) +
      (await prisma.institution.count({ where: { id: { in: institutionIds } } })) +
      (await prisma.program.count({ where: { id: { in: programIds } } })),
  });
  if (!guard.allowed) {
    console.error(guard.message);
    return false;
  }
  if (guard.message) console.warn(guard.message);

  const created = { fields: 0, institutions: 0, programs: 0 };

  // 1) Field taxonomy d01..d12 (mapped from the orientation field metadata).
  //    Create-only : les champs éditoriaux enrichis dans l'admin sont conservés.
  for (const f of ORIENTATION_FIELDS) {
    const data = {
      nameFr: f.nameFr,
      nameEn: f.nameEn,
      descriptionFr: '',
      descriptionEn: '',
      subjectsFr: [],
      subjectsEn: [],
      careersFr: f.sampleJobsFr ?? [],
      careersEn: f.sampleJobsEn ?? [],
      dailyLifeFr: [],
      dailyLifeEn: [],
      skillsFr: [],
      skillsEn: [],
      personalityTraitsFr: [],
      personalityTraitsEn: [],
      relatedCountryIds: [],
      relatedScholarshipIds: [],
    };
    if (await prisma.field.findUnique({ where: { id: f.id }, select: { id: true } })) {
      continue;
    }
    await prisma.field.create({ data: { id: f.id, ...data } });
    created.fields += 1;
  }

  // 2) Senegal country — create-only : un pays retiré (isActive=false) dans
  //    l'admin n'est pas réactivé, son texte n'est pas réécrit.
  await prisma.country.upsert({
    where: { id: 'senegal' },
    update: {},
    create: { id: 'senegal', ...SENEGAL },
  });

  // 3) Institutions (countryId remapped to the canonical M5 ISO id), créées
  //    avec `programIds` vide : la liste est calculée en 5) depuis les
  //    formations réellement rattachées, jamais recopiée du seed.
  const createdInstitutions = new Set<string>();
  for (const inst of catalogueUniqueInstitutions) {
    if (
      await prisma.institution.findUnique({ where: { id: inst.id }, select: { id: true } })
    ) {
      continue;
    }
    await prisma.institution.create({
      data: { ...inst, countryId: canonicalCountryId(inst.countryId), programIds: [] },
    });
    createdInstitutions.add(inst.id);
    created.institutions += 1;
  }

  // 4) Programs (countryId remapped to the canonical M5 ISO id) — create-only.
  const createdProgramsByInstitution = new Map<string, string[]>();
  for (const prog of catalogueUniquePrograms) {
    if (await prisma.program.findUnique({ where: { id: prog.id }, select: { id: true } })) {
      continue;
    }
    await prisma.program.create({
      data: { ...prog, countryId: canonicalCountryId(prog.countryId) },
    });
    const list = createdProgramsByInstitution.get(prog.institutionId) ?? [];
    list.push(prog.id);
    createdProgramsByInstitution.set(prog.institutionId, list);
    created.programs += 1;
  }

  // 5) `programIds` : un établissement créé ici reçoit ses formations
  //    rattachées en base ; un établissement existant reçoit seulement, EN
  //    PLUS de sa liste actuelle (maintenue par l'admin), les formations que
  //    ce lancement vient de créer pour lui.
  for (const inst of catalogueUniqueInstitutions) {
    const newlyCreated = createdProgramsByInstitution.get(inst.id) ?? [];
    if (createdInstitutions.has(inst.id)) {
      const attached = await prisma.program.findMany({
        where: { institutionId: inst.id },
        select: { id: true },
      });
      await prisma.institution.update({
        where: { id: inst.id },
        data: {
          programIds: linkedProgramIds(
            inst.programIds,
            attached.map((p) => p.id),
          ),
        },
      });
    } else if (newlyCreated.length > 0) {
      const current = await prisma.institution.findUnique({
        where: { id: inst.id },
        select: { programIds: true },
      });
      const kept = current?.programIds ?? [];
      await prisma.institution.update({
        where: { id: inst.id },
        data: {
          programIds: [...kept, ...newlyCreated.filter((id) => !kept.includes(id))],
        },
      });
    }
  }

  console.log(
    `Seeded catalogue unique (create-only): ${created.fields}/${ORIENTATION_FIELDS.length} fields, ` +
      `${created.institutions}/${catalogueUniqueInstitutions.length} institutions, ` +
      `${created.programs}/${catalogueUniquePrograms.length} programs created; ` +
      'existing rows left untouched (senegal included).',
  );
  return true;
}

async function main() {
  const prisma = new PrismaClient();
  try {
    if (!(await seedCatalogueUnique(prisma))) process.exitCode = 1;
  } finally {
    await prisma.$disconnect();
  }
}

if (require.main === module) {
  main().catch((e) => {
    console.error(e);
    process.exit(1);
  });
}
