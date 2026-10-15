import { ServiceUnavailableException } from '@nestjs/common';

import { ISO_COUNTRIES } from '../../common/iso-countries';
import { publicScholarshipWhere } from '../../common/public-scholarship-where';
import type { PrismaService } from '../prisma/prisma.service';
import {
  CandidateSnapshotService,
  toMatchCandidate,
  type CandidateRow,
} from '../scholarship-match/candidate-snapshot';
import { isHonestLabel } from '../scholarship-match/reasons';
import type { MatchPreviewDto } from './dto/match-preview.dto';
import {
  buildMatchPreview,
  droppedPreviewKeys,
  eligibilityOptions,
  ScholarshipEligibilityAdminService,
} from './scholarship-eligibility-admin.service';

const NOW = new Date('2026-10-13T12:00:00.000Z');
const DAY_MS = 24 * 60 * 60 * 1000;
const daysAgo = (days: number) => new Date(NOW.getTime() - days * DAY_MS);
const date = (iso: string) => new Date(`${iso}T00:00:00.000Z`);

const QUOTE = {
  officialTextFr: 'Texte officiel.',
  officialTextEn: 'Official text.',
  sourceUrl: 'https://example.org/eligibility',
};

function row(overrides: Record<string, unknown> = {}) {
  return {
    id: 'sch-x',
    nameFr: 'Bourse X',
    nameEn: 'Scholarship X',
    countryId: 'fra',
    countryNameFr: 'France',
    countryNameEn: 'France',
    typeOfFundingFr: 'Bourse complète',
    typeOfFundingEn: 'Fully funded',
    levelEligibleFr: 'Master',
    levelEligibleEn: 'Master',
    deadlineLabelFr: '15 janvier 2027',
    deadlineLabelEn: '15 January 2027',
    applicationUrl: null,
    sourceUrl: null,
    fundingType: 'fully_funded',
    eligibleLevels: ['master'],
    fieldsScope: 'all',
    relatedFieldIds: [],
    eligibilityCriteria: [],
    eligibilityStructuredAt: daysAgo(30),
    eligibilityStructuredBy: 'KPB',
    deadlineAt: null,
    cycles: [
      {
        id: 'cyc-1',
        academicYear: '2026-2027',
        status: 'open',
        dateConfidence: 'confirmed',
        opensAt: date('2026-09-01'),
        closesAt: date('2027-01-15'),
        estimatedOpenAt: null,
        estimatedCloseAt: null,
      },
    ],
    ...overrides,
  };
}

/** « Eiffel » : Master, 29 ans au plus, exclut les Français (binationaux compris). */
const EIFFEL = row({
  id: 'sch-eiffel',
  nameFr: 'Bourse Eiffel',
  nameEn: 'Eiffel Scholarship',
  eligibilityCriteria: [
    {
      type: 'nationality',
      key: 'pas-francais',
      impact: 'hard',
      appliesTo: 'nationality',
      mode: 'exclude',
      countries: ['fra'],
      officialTextFr: 'Les candidats de nationalité française ne sont pas éligibles.',
      officialTextEn: 'French nationals are not eligible.',
      sourceUrl: 'https://www.campusfrance.org/fr/eiffel',
    },
    {
      type: 'age',
      key: 'age-max',
      impact: 'hard',
      max: 29,
      maxInclusive: true,
      asOf: { kind: 'unspecified' },
      ...QUOTE,
    },
  ],
});
const LICENCE = row({ id: 'sch-licence', nameFr: 'Bourse Licence', eligibleLevels: ['bachelor'] });
const NOT_ANALYZED = row({ id: 'sch-vide', nameFr: 'Bourse vide', eligibleLevels: [] });

const PROFILE: MatchPreviewDto = {
  nationalityCode: 'ner',
  countryOfResidence: 'Niger',
  birthDate: '2000-05-10',
  highestDiploma: 'licence',
  scholarshipTargetLevel: 'master',
  gradeBandOn20: '12_14',
  englishLevel: 'b2',
  workExperienceBand: 'none',
  fieldIds: ['engineering'],
};

/**
 * Un Prisma qui n'offre QUE des lectures : toute autre méthode (create,
 * update, upsert, delete, $transaction, $executeRaw…) fait échouer le test.
 */
function readOnlyPrisma(rows: unknown[], extra: Record<string, unknown> = {}) {
  const calls: Array<{ method: string; args: unknown }> = [];
  const scholarship = new Proxy(
    {},
    {
      get(_target, method: string) {
        if (method === 'findMany') {
          return async (args: unknown) => {
            calls.push({ method, args });
            return rows;
          };
        }
        if (method === 'findUnique') {
          return async (args: { where: { id: string } }) => {
            calls.push({ method, args });
            return extra[args.where.id] ?? null;
          };
        }
        throw new Error(`Écriture ou lecture inattendue : scholarship.${method}`);
      },
    },
  );
  const client = new Proxy(
    { scholarship },
    {
      get(target, model: string) {
        if (model === 'scholarship') return target.scholarship;
        throw new Error(`Accès inattendu au client Prisma : ${model}`);
      },
    },
  );
  const prisma = {
    isEnabled: true,
    execute: async (fn: (c: unknown) => unknown) => fn(client),
  } as unknown as PrismaService;
  return { prisma, calls };
}

/** Le service tel que Nest le câble : candidates lues par le service du test élève. */
function adminService(prisma: PrismaService) {
  return new ScholarshipEligibilityAdminService(prisma, new CandidateSnapshotService(prisma));
}

describe('ScholarshipEligibilityAdminService — aperçu « Tester un profil »', () => {
  it('ne lit que les bourses publiques et n’écrit RIEN', async () => {
    const { prisma, calls } = readOnlyPrisma([EIFFEL, LICENCE, NOT_ANALYZED]);
    const service = adminService(prisma);
    const preview = await service.matchPreview(PROFILE, NOW);
    expect(preview.persisted).toBe(false);
    expect(calls).toHaveLength(1);
    expect(calls[0].method).toBe('findMany');
    expect((calls[0].args as { where: unknown }).where).toEqual(publicScholarshipWhere(NOW));
    expect((calls[0].args as { take: number }).take).toBe(500);
  });

  it('lit les candidates exactement comme le test élève (même requête, même cycle servi)', async () => {
    const { prisma, calls } = readOnlyPrisma([]);
    await adminService(prisma).matchPreview(PROFILE, NOW);
    const studentCalls: unknown[] = [];
    const studentPrisma = {
      isEnabled: true,
      execute: async (fn: (c: unknown) => unknown) =>
        fn({
          scholarship: {
            findMany: async (args: unknown) => {
              studentCalls.push(args);
              return [];
            },
          },
        }),
    } as unknown as PrismaService;
    await new CandidateSnapshotService(studentPrisma, () => NOW).get();
    expect(calls[0].args).toEqual(studentCalls[0]);

    // Un cycle ouvert sert la fiche même si une prévision plus récente existe
    // (D4 servait jusqu'ici le plus récent : un autre cycleId que l'élève).
    const twoCycles = row({
      id: 'sch-deux-cycles',
      cycles: [
        {
          id: 'cyc-prevision',
          academicYear: '2027-2028',
          status: 'forecast',
          dateConfidence: 'estimated',
          opensAt: null,
          closesAt: null,
          estimatedOpenAt: date('2027-09-01'),
          estimatedCloseAt: date('2028-01-15'),
        },
        ...(row().cycles as unknown[]),
      ],
    });
    const preview = await adminService(readOnlyPrisma([twoCycles]).prisma).matchPreview(
      PROFILE,
      NOW,
    );
    expect(preview.items[0]).toMatchObject({ scholarshipId: 'sch-deux-cycles', cycleId: 'cyc-1' });
  });

  it('rend statuts, raisons, points à vérifier et exclusions avec leurs libellés', async () => {
    const { prisma } = readOnlyPrisma([EIFFEL, LICENCE, NOT_ANALYZED]);
    const service = adminService(prisma);
    const preview = await service.matchPreview(PROFILE, NOW);

    expect(preview.counts).toEqual({
      candidateCount: 3,
      eligibleCount: 1,
      toVerifyCount: 0,
      excludedCount: 1,
      notAnalyzedCount: 1,
    });
    expect(preview.items.map((item) => [item.scholarshipId, item.status, item.rank])).toEqual([
      ['sch-eiffel', 'eligible', 1],
    ]);
    const eiffel = preview.items[0];
    expect(eiffel.name).toBe('Bourse Eiffel');
    expect(eiffel.reasons.map((point) => point.code)).toEqual(
      expect.arrayContaining(['level_accepted', 'nationality_not_excluded', 'age_within_limit']),
    );
    // La citation officielle accompagne le point issu d'un critère.
    expect(eiffel.reasons.find((point) => point.criterionKey === 'pas-francais')).toMatchObject({
      officialText: 'Les candidats de nationalité française ne sont pas éligibles.',
      sourceUrl: 'https://www.campusfrance.org/fr/eiffel',
    });
    expect(preview.excluded).toHaveLength(1);
    expect(preview.excluded[0]).toMatchObject({ scholarshipId: 'sch-licence', status: 'not_eligible' });
    expect(preview.excluded[0].exclusions[0].code).toBe('level_other');
    expect(preview.notAnalyzed).toEqual([{ scholarshipId: 'sch-vide', name: 'Bourse vide' }]);
    for (const entry of [...preview.items, ...preview.excluded]) {
      for (const point of [...entry.reasons, ...entry.toVerify, ...entry.exclusions]) {
        expect(point.label.length).toBeGreaterThan(0);
        expect(isHonestLabel(point.label)).toBe(true);
      }
    }
  });

  it('un binational français est exclu d’Eiffel (sémantique « une des nationalités »)', async () => {
    const { prisma } = readOnlyPrisma([EIFFEL]);
    const preview = await adminService(prisma).matchPreview(
      { ...PROFILE, secondNationalityCode: 'fra' },
      NOW,
    );
    expect(preview.items).toHaveLength(0);
    expect(preview.excluded[0].exclusions.map((point) => point.code)).toContain(
      'nationality_excluded',
    );
  });

  it('un profil non confirmé n’exclut jamais : « à vérifier »', async () => {
    const { prisma } = readOnlyPrisma([LICENCE]);
    const preview = await adminService(prisma).matchPreview(
      { ...PROFILE, confirmed: false },
      NOW,
    );
    expect(preview.items[0]).toMatchObject({ scholarshipId: 'sch-licence', status: 'to_verify' });
    expect(preview.items[0].toVerify.map((point) => point.code)).toContain('profile_unconfirmed');
    expect(preview.readiness.toConfirm.length).toBeGreaterThan(0);
  });

  it('évalue à part une bourse non publique demandée en focus', async () => {
    const draft = row({ id: 'sch-draft', nameFr: 'Brouillon', eligibilityStructuredAt: null });
    const { prisma, calls } = readOnlyPrisma([EIFFEL], { 'sch-draft': draft });
    const preview = await adminService(prisma).matchPreview(
      { ...PROFILE, focusScholarshipId: 'sch-draft' },
      NOW,
    );
    expect(calls.map((call) => call.method)).toEqual(['findMany', 'findUnique']);
    expect(preview.focus).toMatchObject({
      public: false,
      entry: { scholarshipId: 'sch-draft', status: 'to_verify' },
    });
    expect(preview.focus?.entry.toVerify[0].code).toBe('eligibility_not_structured');
    // Le focus ne se mêle jamais aux résultats.
    expect(preview.items.map((item) => item.scholarshipId)).toEqual(['sch-eiffel']);
    expect(preview.counts.candidateCount).toBe(1);
  });

  it('signale les valeurs saisies que le moteur n’a pas pu lire, sans 400', () => {
    expect(
      droppedPreviewKeys({
        nationalityCode: 'Atlantide',
        countryOfResidence: 'RDC',
        birthDate: '2001-02-30',
        scholarshipTargetLevel: 'phd',
        englishLevel: 'b2',
        languageTests: [{ type: 'ielts', score: 6.5 }, { type: 'inconnu', score: 1 }],
      }),
    ).toEqual(['nationalityCode', 'birthDate', 'scholarshipTargetLevel', 'languageTests']);
  });

  it('est déterministe à `now` fixé', () => {
    const candidates = [EIFFEL, LICENCE, NOT_ANALYZED].map((r) =>
      toMatchCandidate(r as unknown as CandidateRow),
    );
    const a = buildMatchPreview(PROFILE, candidates, null, NOW);
    const b = buildMatchPreview(PROFILE, [...candidates].reverse(), null, NOW);
    expect(b).toEqual(a);
  });

  it('rend les libellés en anglais sur demande', async () => {
    const { prisma } = readOnlyPrisma([EIFFEL]);
    const preview = await adminService(prisma).matchPreview(
      { ...PROFILE, lang: 'en' },
      NOW,
    );
    expect(preview.lang).toBe('en');
    expect(preview.items[0].name).toBe('Eiffel Scholarship');
    expect(preview.items[0].reasons.find((p) => p.criterionKey === 'pas-francais')?.officialText).toBe(
      'French nationals are not eligible.',
    );
  });
});

describe('ScholarshipEligibilityAdminService — couverture', () => {
  it('compte les bourses PUBLIQUES seulement', async () => {
    const { prisma, calls } = readOnlyPrisma([
      row({ id: 'a' }),
      row({ id: 'b', eligibilityStructuredAt: null }),
    ]);
    const coverage = await adminService(prisma).coverage(NOW);
    expect((calls[0].args as { where: unknown }).where).toEqual(publicScholarshipWhere(NOW));
    expect(coverage).toMatchObject({
      total: 2,
      structuredFresh: 1,
      unstructured: 1,
      coveragePercent: 50,
      toStructureIds: ['b'],
    });
  });

  it('répond 503 sans base de données', async () => {
    const prisma = { isEnabled: false } as unknown as PrismaService;
    await expect(adminService(prisma).coverage(NOW)).rejects.toBeInstanceOf(
      ServiceUnavailableException,
    );
  });
});

describe('eligibilityOptions — la table ISO du serveur, servie à l’éditeur', () => {
  it('sert chaque pays de la table partagée, groupe de tête d’abord', () => {
    const options = eligibilityOptions();
    expect(options.countries).toHaveLength(ISO_COUNTRIES.length);
    expect(options.countries[0]).toMatchObject({ code: 'ner', nameFr: 'Niger', priority: true });
    const firstOther = options.countries.findIndex((country) => !country.priority);
    expect(options.countries.slice(firstOther).every((country) => !country.priority)).toBe(true);
    expect(options.countries.find((country) => country.code === 'ata')?.selectable).toBe(false);
    expect(options).toMatchObject({ freshnessDays: 400, launchGatePercent: 90, maxResults: 10 });
  });
});
