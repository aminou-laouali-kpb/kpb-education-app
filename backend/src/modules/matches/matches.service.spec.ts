import { HttpException, NotFoundException } from '@nestjs/common';

import { MatchesService } from './matches.service';
import { PrismaService } from '../prisma/prisma.service';
import {
  MatchScore,
  MatchZoneValue,
  ScoringProfile,
  ScoringProgram,
  canonicalLevel,
  gradeRangeMidpoint,
  scoreProgram,
} from './matching';

// Fixed clock so timing scores are deterministic in every factor test.
const NOW = new Date('2026-07-07T00:00:00.000Z');

function monthsFromNow(months: number): Date {
  return new Date(NOW.getTime() + months * 30 * 24 * 60 * 60 * 1000);
}

// A profile/program pair where every factor has data and scores at its best:
// grade 15+ vs min 12, matching field, advanced language, budget ratio ≥ 1.5,
// deadline > 6 months out, level aligned.
const fullProfile: ScoringProfile = {
  gradeRange: '15+/20',
  languageLevel: 'Advanced',
  targetLevel: 'Bachelor',
  monthlyBudgetEur: 1800,
  fieldIds: ['computer_science'],
  targetCountryIds: ['can'],
};

const fullProgram: ScoringProgram = {
  id: 'prog-1',
  institutionId: 'inst-1',
  countryId: 'can',
  fieldId: 'computer_science',
  nameFr: 'Bachelor en informatique',
  nameEn: 'Bachelor in Computer Science',
  levelFr: 'Licence',
  levelEn: 'Bachelor',
  minGpaRequired: 12,
  tuitionMinEur: 12000,
  applicationDeadline: monthsFromNow(8),
  teachingLanguages: ['fr', 'en'],
};

function factor(profile: ScoringProfile, program: ScoringProgram, name: string) {
  const result = scoreProgram(profile, program, { now: NOW });
  const found = result.factors.find((f) => f.name === name);
  if (!found) throw new Error(`missing factor ${name}`);
  return found;
}

describe('gradeRangeMidpoint', () => {
  it.each([
    ['10 - 12/20', 11],
    ['12 - 14/20', 13],
    ['15+/20', 16],
    [null, null],
    ['n/a', null],
  ])('%s → %s', (input, expected) => {
    expect(gradeRangeMidpoint(input)).toBe(expected);
  });
});

describe('canonicalLevel', () => {
  it.each([
    ['Bachelor', 'bachelor'],
    ['Licence', 'bachelor'],
    ['Master in Management', 'master'],
    ['Doctorat', 'phd'],
    ['High school', 'highschool'],
    ['Certificat', null],
    [null, null],
  ])('%s → %s', (input, expected) => {
    expect(canonicalLevel(input)).toBe(expected);
  });
});

describe('scoreProgram — factors', () => {
  it('academic: kit formula against minGpaRequired', () => {
    // grade 16 vs min 12 → (16-12+2)/4 = 1.5 → clamped 1.0
    expect(factor(fullProfile, fullProgram, 'academic').score).toBe(1);
    // grade 11 vs min 12 → (11-12+2)/4 = 0.25
    expect(
      factor({ ...fullProfile, gradeRange: '10 - 12/20' }, fullProgram, 'academic')
        .score,
    ).toBe(0.25);
  });

  it('academic: absolute scale when program publishes no requirement — estimate', () => {
    const f = factor(
      { ...fullProfile, gradeRange: '12 - 14/20' },
      { ...fullProgram, minGpaRequired: null },
      'academic',
    );
    expect(f.score).toBe(13 / 16);
    expect(f.isEstimate).toBe(true);
  });

  it('academic: missing gradeRange → neutral estimate', () => {
    const f = factor({ ...fullProfile, gradeRange: null }, fullProgram, 'academic');
    expect(f).toMatchObject({ score: 0.5, isEstimate: true });
  });

  it('field: binary match / mismatch / missing', () => {
    expect(factor(fullProfile, fullProgram, 'field').score).toBe(1);
    expect(
      factor({ ...fullProfile, fieldIds: ['business'] }, fullProgram, 'field').score,
    ).toBe(0.2);
    expect(
      factor({ ...fullProfile, fieldIds: [] }, fullProgram, 'field'),
    ).toMatchObject({ score: 0.5, isEstimate: true });
  });

  it('language: level ladder and missing sides', () => {
    expect(factor(fullProfile, fullProgram, 'language').score).toBe(0.8);
    expect(
      factor({ ...fullProfile, languageLevel: 'Beginner' }, fullProgram, 'language')
        .score,
    ).toBe(0.25);
    expect(
      factor({ ...fullProfile, languageLevel: null }, fullProgram, 'language'),
    ).toMatchObject({ score: 0.5, isEstimate: true });
    expect(
      factor(fullProfile, { ...fullProgram, teachingLanguages: [] }, 'language'),
    ).toMatchObject({ score: 0.5, isEstimate: true });
  });

  it('budget: annualized EUR ratio tiers', () => {
    // 1800*12/12000 = 1.8 → 1.0
    expect(factor(fullProfile, fullProgram, 'budget').score).toBe(1);
    // 1250*12/12000 = 1.25 → 0.7
    expect(
      factor({ ...fullProfile, monthlyBudgetEur: 1250 }, fullProgram, 'budget')
        .score,
    ).toBe(0.7);
    // 750*12/12000 = 0.75 → 0.4
    expect(
      factor({ ...fullProfile, monthlyBudgetEur: 750 }, fullProgram, 'budget')
        .score,
    ).toBe(0.4);
    // 400*12/12000 = 0.4 → 0.1
    expect(
      factor({ ...fullProfile, monthlyBudgetEur: 400 }, fullProgram, 'budget')
        .score,
    ).toBe(0.1);
    expect(
      factor({ ...fullProfile, monthlyBudgetEur: null }, fullProgram, 'budget'),
    ).toMatchObject({ score: 0.5, isEstimate: true });
  });

  it('timing: months-to-deadline ladder', () => {
    const withDeadline = (months: number) => ({
      ...fullProgram,
      applicationDeadline: monthsFromNow(months),
    });
    expect(factor(fullProfile, withDeadline(8), 'timing').score).toBe(1);
    expect(factor(fullProfile, withDeadline(4), 'timing').score).toBe(0.8);
    expect(factor(fullProfile, withDeadline(2), 'timing').score).toBe(0.5);
    expect(factor(fullProfile, withDeadline(0.5), 'timing').score).toBe(0.2);
    expect(factor(fullProfile, withDeadline(-1), 'timing').score).toBe(0);
    expect(
      factor(fullProfile, { ...fullProgram, applicationDeadline: null }, 'timing'),
    ).toMatchObject({ score: 0.5, isEstimate: true });
  });
});

describe('scoreProgram — totals, caps and guardrails', () => {
  it('full-data best case: 0.96 (Advanced language caps at 0.8), green, not an estimate', () => {
    const result = scoreProgram(fullProfile, fullProgram, { now: NOW });
    // 0.3·1 + 0.2·1 + 0.2·0.8 + 0.2·1 + 0.1·1 = 0.96
    expect(result.probability).toBe(0.96);
    expect(result.zone).toBe('green');
    expect(result.isEstimate).toBe(false);
  });

  it('one missing factor: isEstimate but no cap', () => {
    const result = scoreProgram(
      fullProfile,
      { ...fullProgram, applicationDeadline: null },
      { now: NOW },
    );
    // 0.3 + 0.2 + 0.16 + 0.2 + 0.1*0.5 = 0.91 — above the 0.65 cap, kept.
    expect(result.probability).toBe(0.91);
    expect(result.isEstimate).toBe(true);
  });

  it('two missing factors: capped at 0.65 (never GREEN on guesses)', () => {
    const result = scoreProgram(
      fullProfile,
      {
        ...fullProgram,
        applicationDeadline: null,
        teachingLanguages: [],
      },
      { now: NOW },
    );
    expect(result.probability).toBeLessThanOrEqual(0.65);
    expect(result.zone).toBe('yellow');
    expect(result.isEstimate).toBe(true);
  });

  it('level-mismatch guardrail caps at 0.20 (blue)', () => {
    const result = scoreProgram(
      { ...fullProfile, targetLevel: 'Master' },
      fullProgram, // Bachelor program
      { now: NOW },
    );
    expect(result.probability).toBeLessThanOrEqual(0.2);
    expect(result.zone).toBe('blue');
  });

  it('unmappable program level falls back to institution studyLevels', () => {
    const oddLevel = {
      ...fullProgram,
      levelFr: 'Certificat',
      levelEn: 'Certificate',
    };
    const capped = scoreProgram({ ...fullProfile, targetLevel: 'Master' }, oddLevel, {
      now: NOW,
      institutionStudyLevels: ['Bachelor'],
    });
    expect(capped.probability).toBeLessThanOrEqual(0.2);
    const allowed = scoreProgram(
      { ...fullProfile, targetLevel: 'Master' },
      oddLevel,
      { now: NOW, institutionStudyLevels: ['Bachelor', 'Master'] },
    );
    expect(allowed.probability).toBeGreaterThan(0.2);
  });

  it('deadline-passed guardrail caps at 0.10', () => {
    const result = scoreProgram(
      fullProfile,
      { ...fullProgram, applicationDeadline: monthsFromNow(-2) },
      { now: NOW },
    );
    expect(result.probability).toBeLessThanOrEqual(0.1);
    expect(result.zone).toBe('blue');
  });

  it('zone thresholds: green > 0.70, yellow 0.30–0.70, blue < 0.30', () => {
    // Mid case: mismatch field (0.2*0.2) + everything else strong.
    const yellow = scoreProgram(
      { ...fullProfile, monthlyBudgetEur: 400, fieldIds: ['business'] },
      fullProgram,
      { now: NOW },
    );
    // 0.3 + 0.04 + 0.16 + 0.02 + 0.1 = 0.62
    expect(yellow.zone).toBe('yellow');

    const blue = scoreProgram(
      {
        ...fullProfile,
        gradeRange: '10 - 12/20',
        fieldIds: ['business'],
        languageLevel: 'Beginner',
        monthlyBudgetEur: 400,
      },
      fullProgram,
      { now: NOW },
    );
    // 0.075 + 0.04 + 0.05 + 0.02 + 0.1 = 0.29 (rounded)
    expect(blue.zone).toBe('blue');
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// MatchesService — data loading and degraded mode.
//
// The rule this guards: a database outage must never turn into matches scored
// on `mock-catalog.ts` fixtures in production. Fixture matches are worse than
// fixture catalog rows — the app presents them as "this programme is a 70%
// match for YOU" about a programme that does not exist.
// ─────────────────────────────────────────────────────────────────────────────

const PROFILE_CAN_CS = {
  gradeRange: '15+/20',
  languageLevel: 'Advanced',
  targetLevel: 'Bachelor',
  monthlyBudgetEur: 1800,
  fieldIds: ['computer_science'],
  targetCountryIds: ['can'],
};

const DB_PROGRAM = {
  id: 'db-prog-1',
  institutionId: 'db-inst-1',
  countryId: 'can',
  fieldId: 'computer_science',
  nameFr: 'Licence en informatique (DB)',
  nameEn: 'BSc Computer Science (DB)',
  levelFr: 'Licence',
  levelEn: 'Bachelor',
  minGpaRequired: 12,
  tuitionMinEur: 12000,
  applicationDeadline: null,
  teachingLanguages: ['fr', 'en'],
};

const DB_INSTITUTION = {
  id: 'db-inst-1',
  nameFr: 'Université de test',
  nameEn: 'Test University',
  studyLevels: ['Bachelor', 'Master'],
};

type FailurePoint = 'programs' | 'institutions' | 'profile';

/** A PrismaService double that behaves like the real `execute()`: it runs the
 *  operation and lets database errors propagate (no silent null). */
function prismaDouble(opts: {
  isEnabled?: boolean;
  profile?: Record<string, unknown> | null;
  fail?: FailurePoint[];
  programRows?: unknown[];
  institutionRows?: unknown[];
}) {
  const fail = new Set(opts.fail ?? []);
  const boom = () => {
    throw Object.assign(new Error('connection refused'), {
      code: 'ECONNREFUSED',
    });
  };
  const upserts: Array<Record<string, unknown>> = [];
  const deletes: Array<Record<string, unknown>> = [];
  /// Les arguments réellement envoyés à `program.findMany`. Ce que le service
  /// DEMANDE compte autant que ce qu'il reçoit : une recommandation est une
  /// surface publique, et le filtre « relu » doit s'y voir.
  const programQueries: Array<Record<string, unknown>> = [];
  /// Idem pour les établissements : `schoolMatch` reçoit leur identifiant du
  /// client, donc c'est une porte d'entrée comme les autres.
  const institutionQueries: Array<Record<string, unknown>> = [];
  const client = {
    userProfile: {
      findUnique: async () =>
        fail.has('profile')
          ? boom()
          : opts.profile === undefined
            ? PROFILE_CAN_CS
            : opts.profile,
    },
    program: {
      findMany: async (args?: Record<string, unknown>) => {
        if (args) programQueries.push(args);
        return fail.has('programs') ? boom() : (opts.programRows ?? [DB_PROGRAM]);
      },
    },
    institution: {
      findMany: async (args?: Record<string, unknown>) => {
        if (args) institutionQueries.push(args);
        return fail.has('institutions')
          ? boom()
          : (opts.institutionRows ?? [DB_INSTITUTION]);
      },
    },
    match: {
      upsert: async (args: Record<string, unknown>) => {
        upserts.push(args);
        return { id: 'match-1' };
      },
      deleteMany: async (args: Record<string, unknown>) => {
        deletes.push(args);
        return { count: 0 };
      },
    },
    matchExplanation: { upsert: async () => ({ id: 'expl-1' }) },
  };

  const prisma = {
    isEnabled: opts.isEnabled ?? true,
    execute: jest.fn(async (op: (c: unknown) => Promise<unknown>) => {
      if (!(opts.isEnabled ?? true)) return null;
      return op(client);
    }),
    tryExecute: jest.fn(async (op: (c: unknown) => Promise<unknown>) => {
      if (!(opts.isEnabled ?? true)) return null;
      try {
        return (await op(client)) ?? null;
      } catch {
        return null;
      }
    }),
  };
  return { prisma, upserts, deletes, programQueries, institutionQueries };
}

function serviceWith(opts: Parameters<typeof prismaDouble>[0]) {
  const { prisma, upserts, deletes, programQueries, institutionQueries } =
    prismaDouble(opts);
  return {
    service: new MatchesService(prisma as unknown as PrismaService),
    prisma,
    upserts,
    deletes,
    programQueries,
    institutionQueries,
  };
}

describe('MatchesService', () => {
  const previousNodeEnv = process.env.NODE_ENV;
  const previousFlag = process.env.KPB_CATALOG_MOCK_FALLBACK;

  beforeEach(() => {
    jest.clearAllMocks();
    process.env.NODE_ENV = 'test';
    delete process.env.KPB_CATALOG_MOCK_FALLBACK;
  });

  afterAll(() => {
    if (previousNodeEnv === undefined) delete process.env.NODE_ENV;
    else process.env.NODE_ENV = previousNodeEnv;
    if (previousFlag === undefined) delete process.env.KPB_CATALOG_MOCK_FALLBACK;
    else process.env.KPB_CATALOG_MOCK_FALLBACK = previousFlag;
  });

  describe('healthy database', () => {
    it('scores database rows and tags them source="database"', async () => {
      const { service, upserts } = serviceWith({});

      const result = await service.ahaMoment('user-1', 5);

      expect(result.source).toBe('database');
      expect(result.items).toHaveLength(1);
      expect(result.items[0]).toMatchObject({
        programId: 'db-prog-1',
        institutionId: 'db-inst-1',
        source: 'database',
      });
      expect(result.items[0].institutionName.en).toBe('Test University');
      // Real rows are cached for the weekly recompute to diff against.
      expect(upserts).toHaveLength(1);
    });

    it('ahaMoment prunes cached rows that left the top (weekly diff baseline)', async () => {
      const { service, deletes } = serviceWith({});
      await service.ahaMoment('user-1', 5);
      expect(deletes).toEqual([
        {
          where: {
            userProfileId: 'user-1',
            programId: { notIn: ['db-prog-1'] },
          },
        },
      ]);
    });

    it('schoolMatch does not write into the weekly diff baseline', async () => {
      const { service, upserts } = serviceWith({});
      await service.schoolMatch('user-1', 'db-inst-1');
      expect(upserts).toHaveLength(0);
    });

    it('schoolMatch scores the database programs of that institution', async () => {
      const { service } = serviceWith({});

      const result = await service.schoolMatch('user-1', 'db-inst-1');

      expect(result.programId).toBe('db-prog-1');
      expect(result.source).toBe('database');
      expect(result.factors).toHaveLength(5);
    });

    it('ne recommande jamais une formation non relue', async () => {
      // L'import du catalogue « Études en France » crée 10 247 formations
      // `isActive: false`. Sans ce filtre, le moteur les proposerait à un
      // étudiant comme « 70 % de compatibilité » — sur des fiches que
      // personne n'a vérifiées.
      const { service, programQueries } = serviceWith({});

      await service.schoolMatch('user-1', 'db-inst-1');

      expect(programQueries).not.toHaveLength(0);
      for (const query of programQueries) {
        expect((query.where as Record<string, unknown>).isActive).toBe(true);
      }
    });

    // ── La frontière avec l'espace « Études en France » ──────────────────────
    //
    // Sans profil exploitable, `ahaMoment` se replie sur `loadPrograms({})`, donc
    // sur TOUT le catalogue actif, sans limite. Le jour où une université est
    // publiée, ses formations (facteurs neutres : ni frais ni note minimale)
    // entreraient en concurrence avec les écoles partenaires dans le « moment
    // aha », et chaque requête chargerait des milliers de lignes. L'espace EEF a
    // sa propre shortlist.
    const EXCLUDES_EEF_PROGRAMS = {
      OR: [
        { id: { startsWith: 'eef-prog-' } },
        { institutionId: { startsWith: 'eef-univ-' } },
      ],
    };
    const EXCLUDES_EEF_INSTITUTIONS = { id: { startsWith: 'eef-univ-' } };

    it('n’envoie au moteur aucune formation de l’import EEF, repli compris', async () => {
      // `programRows: []` force le repli : les DEUX requêtes de formations
      // doivent porter l'exclusion, pas seulement la première.
      const { service, programQueries } = serviceWith({
        programRows: [],
        institutionRows: [],
      });

      await service.ahaMoment('user-1');

      expect(programQueries).toHaveLength(2);
      for (const query of programQueries) {
        const where = query.where as Record<string, unknown>;
        expect(where.isActive).toBe(true);
        expect(where.NOT).toEqual(EXCLUDES_EEF_PROGRAMS);
      }
    });

    it('n’envoie au moteur aucun établissement de l’import EEF', async () => {
      const { service, institutionQueries } = serviceWith({});

      await service.ahaMoment('user-1');
      await service.schoolMatch('user-1', 'db-inst-1');

      expect(institutionQueries.length).toBeGreaterThan(0);
      for (const query of institutionQueries) {
        expect((query.where as Record<string, unknown>).NOT).toEqual(
          EXCLUDES_EEF_INSTITUTIONS,
        );
      }
    });

    it('schoolMatch ne retrouve pas une université EEF par son identifiant', async () => {
      // L'identifiant vient du client. La requête envoyée à la base doit donc
      // exclure la provenance EEF quel que soit l'identifiant demandé — c'est
      // elle qui rend « établissement introuvable », pas une confiance dans ce
      // que le client demande.
      const { service, institutionQueries } = serviceWith({
        institutionRows: [],
      });

      await expect(
        service.schoolMatch('user-1', 'eef-univ-0353074b'),
      ).rejects.toThrow(NotFoundException);

      const where = institutionQueries[0].where as Record<string, unknown>;
      expect(where.id).toEqual({ in: ['eef-univ-0353074b'] });
      expect(where.NOT).toEqual(EXCLUDES_EEF_INSTITUTIONS);
    });

    it('an empty database is not a degradation: no items, no fixtures', async () => {
      const { service } = serviceWith({ programRows: [], institutionRows: [] });

      const result = await service.ahaMoment('user-1');

      expect(result.items).toEqual([]);
      expect(result.source).toBe('database');
    });
  });

  describe('production refuses to score fixtures', () => {
    beforeEach(() => {
      process.env.NODE_ENV = 'production';
    });

    it('ahaMoment throws 503 MATCHES_UNAVAILABLE when the programs read fails', async () => {
      const { service } = serviceWith({ fail: ['programs'] });

      const error = await service.ahaMoment('user-1').catch((e) => e as unknown);

      expect(error).toBeInstanceOf(HttpException);
      const httpError = error as HttpException;
      expect(httpError.getStatus()).toBe(503);
      expect(httpError.getResponse()).toMatchObject({
        code: 'MATCHES_UNAVAILABLE',
        details: { resource: 'programs' },
      });
    });

    it('never leaks a fixture programme name in the 503 payload', async () => {
      const { service } = serviceWith({ fail: ['programs'] });

      const error = (await service
        .ahaMoment('user-1')
        .catch((e) => e as unknown)) as HttpException;

      const body = JSON.stringify(error.getResponse());
      expect(body).not.toContain('uottawa');
      expect(body).not.toContain('Ottawa');
    });

    it('schoolMatch throws 503 when the institutions read fails', async () => {
      const { service } = serviceWith({ fail: ['institutions'] });

      const error = await service
        .schoolMatch('user-1', 'db-inst-1')
        .catch((e) => e as unknown);

      expect(error).toBeInstanceOf(HttpException);
      expect((error as HttpException).getResponse()).toMatchObject({
        code: 'MATCHES_UNAVAILABLE',
        details: { resource: 'institutions' },
      });
    });

    it('refuses to score anything when no database is configured at all', async () => {
      const { service, prisma } = serviceWith({ isEnabled: false });

      await expect(service.ahaMoment('user-1')).rejects.toBeInstanceOf(
        HttpException,
      );
      expect(prisma.execute).not.toHaveBeenCalled();
    });

    it('logs the outage at error level instead of swallowing it', async () => {
      const { service } = serviceWith({ fail: ['programs'] });
      const errorSpy = jest
        .spyOn(service['logger'], 'error')
        .mockImplementation(() => undefined);

      await expect(service.ahaMoment('user-1')).rejects.toBeInstanceOf(
        HttpException,
      );

      expect(errorSpy).toHaveBeenCalledTimes(1);
      expect(errorSpy.mock.calls[0][0]).toContain('MATCHES_UNAVAILABLE');
    });

    it('never writes a fixture-scored match into the Match cache', async () => {
      const { service, upserts } = serviceWith({ fail: ['programs'] });

      await expect(service.ahaMoment('user-1')).rejects.toBeInstanceOf(
        HttpException,
      );

      expect(upserts).toEqual([]);
    });
  });

  describe('non-production degraded mode stays available but honest', () => {
    it('schoolMatch scores the mock catalog and tags it source="mock"', async () => {
      const { service } = serviceWith({
        fail: ['programs', 'institutions'],
      });

      const result = await service.schoolMatch('user-1', 'uottawa');

      expect(result.institutionId).toBe('uottawa');
      expect(result.programId).toBe('uottawa-cs');
      expect(result.source).toBe('mock');
      expect(result.factors).toHaveLength(5);
      expect(result.narrative.fr).toContain('Bachelor en informatique');
      expect(result.narrative.en).toContain('Bachelor in Computer Science');
    });

    it('warns (not silently) when it degrades', async () => {
      const { service } = serviceWith({ fail: ['programs', 'institutions'] });
      const warnSpy = jest
        .spyOn(service['logger'], 'warn')
        .mockImplementation(() => undefined);

      await service.schoolMatch('user-1', 'uottawa');

      expect(warnSpy).toHaveBeenCalled();
      expect(warnSpy.mock.calls[0][0]).toContain('mock-catalog');
    });

    it('does not cache fixture-scored matches either', async () => {
      const { service, upserts } = serviceWith({
        fail: ['programs', 'institutions'],
      });

      await service.schoolMatch('user-1', 'uottawa');

      expect(upserts).toEqual([]);
    });

    it('schoolMatch 404s on an unknown institution', async () => {
      const { service } = serviceWith({ fail: ['programs', 'institutions'] });

      await expect(service.schoolMatch('user-1', 'nope')).rejects.toThrow(
        NotFoundException,
      );
    });

    it('ahaMoment returns one entry per institution, tagged source="mock"', async () => {
      const { service } = serviceWith({ fail: ['programs', 'institutions'] });

      const result = await service.ahaMoment('user-1', 5);

      // Mock catalog: profile targets 'can' → uottawa-cs only.
      expect(result.source).toBe('mock');
      expect(result.items).toHaveLength(1);
      expect(result.items[0].institutionId).toBe('uottawa');
      expect(result.items[0].institutionName.en).toBe('University of Ottawa');
    });

    it('falls back to the whole catalog when preference filters match nothing', async () => {
      const { service } = serviceWith({
        fail: ['programs', 'institutions'],
        profile: {
          gradeRange: null,
          languageLevel: null,
          targetLevel: null,
          monthlyBudgetEur: null,
          fieldIds: [],
          targetCountryIds: ['xyz'], // matches no catalog row
        },
      });

      const result = await service.ahaMoment('user-1');

      expect(result.items.length).toBeGreaterThan(0);
      // Everything is missing on the profile side → estimates, capped ≤ 0.65.
      expect(result.isEstimate).toBe(true);
      for (const item of result.items) {
        expect(item.probability).toBeLessThanOrEqual(0.65);
      }
    });

    it('can be switched off with KPB_CATALOG_MOCK_FALLBACK=0', async () => {
      process.env.KPB_CATALOG_MOCK_FALLBACK = '0';
      const { service } = serviceWith({ fail: ['programs'] });

      await expect(service.ahaMoment('user-1')).rejects.toBeInstanceOf(
        HttpException,
      );
    });
  });

  describe('profile lookup', () => {
    it('404s when the profile does not exist (not a degradation)', async () => {
      const { service } = serviceWith({ profile: null });

      await expect(service.ahaMoment('ghost')).rejects.toThrow(
        NotFoundException,
      );
    });

    it('404s in degraded mode too — there is no mock profile to invent', async () => {
      const { service } = serviceWith({ fail: ['profile'] });

      await expect(service.ahaMoment('user-1')).rejects.toThrow(
        NotFoundException,
      );
    });

    it('503s in production when the profile read fails', async () => {
      process.env.NODE_ENV = 'production';
      const { service } = serviceWith({ fail: ['profile'] });

      const error = await service.ahaMoment('user-1').catch((e) => e as unknown);

      expect(error).toBeInstanceOf(HttpException);
      expect((error as HttpException).getResponse()).toMatchObject({
        code: 'MATCHES_UNAVAILABLE',
        details: { resource: 'profile' },
      });
    });
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// Narrative — the sentence the AHA screen of installed builds prints verbatim.
//
// The score compares a few published criteria with what the student declared;
// it is not an admission probability. So the text never carries a percentage
// (nor any figure: "(96)" would be the same fake precision) and never promises
// "chances", whatever the zone and whether the score is an estimate or not.
// ─────────────────────────────────────────────────────────────────────────────

describe('MatchesService — narrative', () => {
  const ZONES: Array<{ zone: MatchZoneValue; probability: number }> = [
    { zone: 'green', probability: 0.96 },
    { zone: 'yellow', probability: 0.5 },
    { zone: 'blue', probability: 0.1 },
  ];
  const FORBIDDEN: RegExp[] = [
    /%/,
    /\d/,
    /chance/i,
    /garanti/i,
    /guarantee/i,
    /sûr/i,
    /\bsure\b/i,
  ];

  function narrativeOf(
    zone: MatchZoneValue,
    probability: number,
    isEstimate: boolean,
  ): { fr: string; en: string } {
    const { service } = serviceWith({});
    const score: MatchScore = { zone, probability, isEstimate, factors: [] };
    return service['narrative'](fullProgram, score);
  }

  describe.each(ZONES)('zone $zone', ({ zone, probability }) => {
    it.each([false, true])(
      'isEstimate=%s: no figure, no promise, in both languages',
      (isEstimate) => {
        const narrative = narrativeOf(zone, probability, isEstimate);

        expect(Object.keys(narrative).sort()).toEqual(['en', 'fr']);
        for (const text of [narrative.fr, narrative.en]) {
          expect(text.trim()).not.toBe('');
          for (const pattern of FORBIDDEN) {
            expect(text).not.toMatch(pattern);
          }
        }
        expect(narrative.fr).toContain(fullProgram.nameFr);
        expect(narrative.en).toContain(fullProgram.nameEn);
      },
    );

    it('still says when the score is only a partial indication', () => {
      const exact = narrativeOf(zone, probability, false);
      const estimate = narrativeOf(zone, probability, true);

      expect(estimate.fr).not.toBe(exact.fr);
      expect(estimate.en).not.toBe(exact.en);
    });
  });

  it('what ahaMoment and schoolMatch serve carries no percentage either', async () => {
    const { service } = serviceWith({});

    const aha = await service.ahaMoment('user-1');
    const school = await service.schoolMatch('user-1', 'db-inst-1');

    expect(aha.items).not.toHaveLength(0);
    for (const match of [...aha.items, school]) {
      for (const text of [match.narrative.fr, match.narrative.en]) {
        expect(text).not.toMatch(/%/);
        expect(text).not.toMatch(/chance/i);
      }
    }
  });
});
