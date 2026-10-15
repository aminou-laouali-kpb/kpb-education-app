import { assess, type MatchScholarship } from './assess';
import {
  CERTAINTY_PENALTY_PER_POINT,
  closingDate,
  composeRun,
  matchScholarships,
  PROFILE_DEPENDENT_TO_VERIFY,
  relevance,
  RELEVANCE_WEIGHTS,
  type RankedEntry,
} from './rank';
import { TO_VERIFY_CODES } from './reasons';
import {
  date,
  grade,
  language,
  makeCycle,
  makeProfile,
  makeScholarship,
  nationality,
  NOW,
  other,
} from './testing/match-fixtures';

const profile = makeProfile();

function entry(scholarship: MatchScholarship): RankedEntry {
  const assessment = assess(profile, scholarship, NOW);
  return { scholarship, assessment, relevance: relevance(profile, scholarship, assessment, NOW) };
}

/** Mélange déterministe (graine fixe). */
function shuffled<T>(items: readonly T[], seed: number): T[] {
  const out = [...items];
  let state = seed;
  for (let i = out.length - 1; i > 0; i -= 1) {
    state = (state * 1103515245 + 12345) % 2 ** 31;
    const j = state % (i + 1);
    [out[i], out[j]] = [out[j], out[i]];
  }
  return out;
}

const eligibleRow = (id: string, overrides: Partial<MatchScholarship> = {}) =>
  makeScholarship({ id, ...overrides });
const toVerifyRow = (id: string, overrides: Partial<MatchScholarship> = {}) =>
  makeScholarship({ id, eligibilityCriteria: [other('lettre', 'soft')], ...overrides });
const excludedRow = (id: string) =>
  makeScholarship({ id, eligibilityCriteria: [nationality('reserve', 'include', ['sen'])] });

describe('relevance (interne, jamais exposée)', () => {
  it('reste un entier entre 0 et 100, maxima sommant à 100', () => {
    expect(Object.values(RELEVANCE_WEIGHTS).reduce((a, b) => a + b, 0)).toBe(100);
    for (const row of [eligibleRow('a'), toVerifyRow('b'), excludedRow('c')]) {
      const { relevance: value } = entry(row);
      expect(Number.isInteger(value)).toBe(true);
      expect(value).toBeGreaterThanOrEqual(0);
      expect(value).toBeLessThanOrEqual(100);
    }
  });

  it('préfère le domaine listé, le financement complet, la destination visée, la date confirmée', () => {
    const base = entry(eligibleRow('base', { fundingType: 'partially_funded' })).relevance;
    expect(entry(eligibleRow('full', { fundingType: 'fully_funded' })).relevance).toBeGreaterThan(base);
    expect(
      entry(
        eligibleRow('field', {
          fundingType: 'partially_funded',
          fieldsScope: 'listed',
          relatedFieldIds: ['engineering'],
        }),
      ).relevance,
    ).toBeGreaterThan(base);
    const estimated = entry(
      eligibleRow('estimated', {
        fundingType: 'partially_funded',
        cycle: makeCycle({ dateConfidence: 'estimated', closesAt: null, estimatedCloseAt: date('2027-01-15') }),
      }),
    ).relevance;
    expect(estimated).toBeLessThan(base);

    const wanted = makeProfile({ targetCountryIds: ['fra'] });
    const row = eligibleRow('dest');
    expect(relevance(wanted, row, assess(wanted, row, NOW), NOW)).toBeGreaterThan(
      relevance(makeProfile({ targetCountryIds: ['can'] }), row, assess(wanted, row, NOW), NOW),
    );
  });
});

describe('relevance — la certitude ne compte que les incertitudes du profil', () => {
  it('une condition que le test ne pose pas ne fait pas reculer une fiche', () => {
    // Même fiche, transcrite en une ou en quatre conditions « autres » (liste
    // de pays non reproduite, leadership…) : même pertinence.
    const sparse = entry(toVerifyRow('sparse'));
    const detailed = entry(
      toVerifyRow('detailed', {
        eligibilityCriteria: [
          other('pays-eligibles'),
          other('heures'),
          other('leadership'),
          other('exclusions'),
          grade('top-10-pour-cent'),
          language('langue-du-cursus', { lang: 'de', minCefr: 'b2' }),
        ],
      }),
    );
    expect(detailed.assessment.status).toBe('to_verify');
    expect(detailed.assessment.toVerify).toHaveLength(6);
    expect(detailed.relevance).toBe(sparse.relevance);
    // Le statut et la liste affichée, eux, ne bougent pas.
    expect(detailed.assessment.toVerify.map((point) => point.code)).toEqual([
      'condition_other',
      'condition_other',
      'condition_other',
      'condition_other',
      'grade_check',
      'language_other',
    ]);
  });

  it('une incertitude qui tient à l’élève fait toujours reculer', () => {
    const sure = entry(toVerifyRow('sure'));
    const belowGrade = entry(
      toVerifyRow('below', { eligibilityCriteria: [other('lettre'), grade('moyenne', 16)] }),
    );
    const noScore = entry(
      toVerifyRow('no-score', {
        eligibilityCriteria: [other('lettre'), language('ielts', { tests: [{ type: 'ielts', min: 6.5 }] })],
      }),
    );
    expect(belowGrade.assessment.toVerify.map((point) => point.code)).toContain('grade_below');
    expect(noScore.assessment.toVerify.map((point) => point.code)).toContain('language_missing');
    expect(belowGrade.relevance).toBe(sure.relevance - CERTAINTY_PENALTY_PER_POINT);
    expect(noScore.relevance).toBe(sure.relevance - CERTAINTY_PENALTY_PER_POINT);
  });

  it('classe chaque code « à vérifier » : profil ou catalogue', () => {
    const catalogSide = TO_VERIFY_CODES.filter((code) => !PROFILE_DEPENDENT_TO_VERIFY.has(code));
    expect(catalogSide).toEqual([
      'eligibility_not_structured',
      'eligibility_stale',
      'criteria_not_structured',
      'criterion_unreadable',
      'language_other',
      'grade_check',
      'condition_other',
    ]);
    for (const code of PROFILE_DEPENDENT_TO_VERIFY) expect(TO_VERIFY_CODES).toContain(code);
  });
});

describe('composeRun', () => {
  it('les compatibles d’abord, quelle que soit la pertinence', () => {
    const run = composeRun([
      entry(toVerifyRow('verify-full', { fundingType: 'fully_funded' })),
      entry(eligibleRow('eligible-unknown', { fundingType: 'unknown' })),
    ]);
    expect(run.items.map((item) => [item.scholarshipId, item.section, item.rank])).toEqual([
      ['eligible-unknown', 'compatible', 1],
      ['verify-full', 'to_verify', 2],
    ]);
  });

  it('à pertinence égale : clôture la plus proche, puis identifiant', () => {
    const run = composeRun([
      entry(eligibleRow('b-late', { cycle: makeCycle({ closesAt: date('2027-03-01') }) })),
      entry(eligibleRow('c-soon', { cycle: makeCycle({ closesAt: date('2026-11-01') }) })),
      entry(eligibleRow('a-late', { cycle: makeCycle({ closesAt: date('2027-03-01') }) })),
    ]);
    expect(run.items.map((item) => item.scholarshipId)).toEqual(['c-soon', 'a-late', 'b-late']);
  });

  it('tri déterministe : l’ordre d’entrée ne change rien', () => {
    const rows = [
      ...Array.from({ length: 6 }, (_, i) => eligibleRow(`e${i}`, { fundingType: i % 2 ? 'fully_funded' : 'unknown' })),
      ...Array.from({ length: 6 }, (_, i) => toVerifyRow(`v${i}`)),
      excludedRow('x1'),
    ];
    const reference = composeRun(rows.map(entry));
    for (const seed of [1, 7, 42, 2026]) {
      expect(composeRun(shuffled(rows, seed).map(entry))).toEqual(reference);
    }
  });

  it('au plus 10 : 12 compatibles → 10 compatibles, aucune « à vérifier »', () => {
    const rows = [
      ...Array.from({ length: 12 }, (_, i) => eligibleRow(`e${String(i).padStart(2, '0')}`)),
      ...Array.from({ length: 3 }, (_, i) => toVerifyRow(`v${i}`)),
    ];
    const run = composeRun(rows.map(entry));
    expect(run.items).toHaveLength(10);
    expect(run.items.every((item) => item.section === 'compatible')).toBe(true);
    expect(run.eligibleCount).toBe(12);
    expect(run.toVerifyCount).toBe(3);
  });

  it('jamais complétée : 3 compatibles + 2 à vérifier = 5 résultats', () => {
    const rows = [
      ...Array.from({ length: 3 }, (_, i) => eligibleRow(`e${i}`)),
      ...Array.from({ length: 2 }, (_, i) => toVerifyRow(`v${i}`)),
      ...Array.from({ length: 4 }, (_, i) => excludedRow(`x${i}`)),
      makeScholarship({ id: 'na', eligibleLevels: [] }),
      makeScholarship({ id: 'susp', cycle: makeCycle({ status: 'suspended' }) }),
    ];
    const run = composeRun(rows.map(entry));
    expect(run.items.map((item) => item.section)).toEqual([
      'compatible',
      'compatible',
      'compatible',
      'to_verify',
      'to_verify',
    ]);
    expect(run.items.map((item) => item.rank)).toEqual([1, 2, 3, 4, 5]);
    expect(run).toMatchObject({
      eligibleCount: 3,
      toVerifyCount: 2,
      excludedCount: 5,
      notAnalyzedCount: 1,
      candidateCount: 11,
    });
    expect(run.excludedSummary).toEqual({
      groups: [
        { group: 'nationality', count: 4, scholarshipIds: ['x0', 'x1', 'x2', 'x3'] },
        { group: 'suspended', count: 1, scholarshipIds: ['susp'] },
      ],
      notAnalyzedCount: 1,
    });
  });

  it('le résumé des écartées garde au plus 20 noms par groupe, mais le vrai total', () => {
    const rows = Array.from({ length: 25 }, (_, i) => excludedRow(`x${String(i).padStart(2, '0')}`));
    const run = composeRun(rows.map(entry));
    expect(run.items).toEqual([]);
    expect(run.excludedSummary.groups[0].count).toBe(25);
    expect(run.excludedSummary.groups[0].scholarshipIds).toHaveLength(20);
  });

  it('un item porte les codes, la pertinence et le cycle', () => {
    const run = matchScholarships(profile, [eligibleRow('only')], NOW);
    expect(run.items[0]).toEqual({
      scholarshipId: 'only',
      cycleId: 'cycle-1',
      rank: 1,
      section: 'compatible',
      status: 'eligible',
      relevance: expect.any(Number),
      reasonCodes: ['level_accepted', 'fields_all'],
      toVerifyCodes: [],
    });
  });

  it('closingDate : confirmée, sinon estimée, sinon date limite', () => {
    expect(closingDate(eligibleRow('a'))).toEqual(date('2027-01-15'));
    expect(
      closingDate(
        eligibleRow('b', { cycle: makeCycle({ closesAt: null, estimatedCloseAt: date('2027-02-01') }) }),
      ),
    ).toEqual(date('2027-02-01'));
    expect(closingDate(eligibleRow('c', { cycle: null, deadlineAt: date('2027-03-01') }))).toEqual(
      date('2027-03-01'),
    );
  });
});
