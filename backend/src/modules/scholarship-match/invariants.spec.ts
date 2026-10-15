import { assess, isStructuredFresh, type MatchScholarship } from './assess';
import { parseEligibilityCriteria } from './eligibility-criteria';
import {
  EXPERIENCE_BANDS,
  GRADE_BANDS,
  LANGUAGE_BANDS,
  TARGET_LEVELS,
  type MatchProfile,
} from './match-inputs';
import { matchScholarships } from './rank';
import { isHonestLabel, renderPoint } from './reasons';
import {
  age,
  date,
  daysBefore,
  eiffel,
  experience,
  financialNeed,
  grade,
  language,
  makeCycle,
  makeScholarship,
  nationality,
  NOW,
  other,
  turkiye,
  uwcBurkina,
  uwcKenya,
} from './testing/match-fixtures';

/**
 * Propriétés vérifiées sur des profils aléatoires (graine fixe) croisés avec
 * un catalogue synthétique qui couvre chaque forme de règle, des règles
 * invalides, des tampons absents ou périmés et des cycles suspendus.
 */

/** mulberry32 : générateur déterministe. */
function rng(seed: number): () => number {
  let state = seed >>> 0;
  return () => {
    state = (state + 0x6d2b79f5) >>> 0;
    let t = state;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

function pick<T>(random: () => number, values: readonly T[]): T {
  return values[Math.floor(random() * values.length)];
}

function maybe<T>(random: () => number, value: T, probability = 0.85): T | null {
  return random() < probability ? value : null;
}

const COUNTRIES = ['ner', 'sen', 'civ', 'bfa', 'cmr', 'ken', 'tza', 'fra', 'tur', 'cod', 'mdg'];
const FIELDS = ['engineering', 'health', 'law', 'business', 'agriculture'];

function randomProfile(random: () => number): MatchProfile {
  const first = maybe(random, pick(random, COUNTRIES));
  const second = random() < 0.2 ? pick(random, COUNTRIES) : null;
  const year = 1985 + Math.floor(random() * 28);
  const month = 1 + Math.floor(random() * 12);
  const day = 1 + Math.floor(random() * 28);
  return {
    nationalities: [first, second].filter(
      (code, index, all): code is string => !!code && all.indexOf(code) === index,
    ),
    residenceCode: maybe(random, pick(random, COUNTRIES)),
    birthDate: maybe(
      random,
      date(`${year}-${String(month).padStart(2, '0')}-${String(day).padStart(2, '0')}`),
    ),
    guardianConsented: random() < 0.5,
    highestDiploma: maybe(random, pick(random, ['none', 'bac', 'licence', 'master'] as const)),
    targetLevel: maybe(random, pick(random, TARGET_LEVELS)),
    fieldIds: random() < 0.3 ? [] : [pick(random, FIELDS)],
    targetCountryIds: random() < 0.5 ? [] : [pick(random, ['fra', 'can', 'tur', 'deu'])],
    gradeBand: maybe(random, pick(random, GRADE_BANDS)),
    englishLevel: maybe(random, pick(random, LANGUAGE_BANDS)),
    frenchLevel: maybe(random, pick(random, LANGUAGE_BANDS), 0.5),
    languageTests: random() < 0.3 ? [{ type: 'ielts', score: 4 + Math.floor(random() * 10) / 2 }] : [],
    workExperienceBand: maybe(random, pick(random, EXPERIENCE_BANDS)),
    confirmed: random() < 0.7,
  };
}

/** Des règles que le moteur ne sait pas lire : jamais excluantes. */
const UNREADABLE = [
  { key: 'religion', type: 'religion', impact: 'hard', countries: ['fra'] },
  { ...nationality('pays-invalides', 'exclude', ['ner']), countries: ['NER', 'xx'] },
  { ...age('age-sans-type', { max: 10 }), type: undefined },
  { ...age('age-sans-asof', { max: 10 }), asOf: { kind: 'someday' } },
  'not a criterion',
];

function catalog(): MatchScholarship[] {
  const rows: MatchScholarship[] = [
    eiffel(),
    turkiye(),
    uwcKenya(),
    uwcBurkina(),
    eiffel({ id: 'eiffel-stale', eligibilityStructuredAt: daysBefore(450) }),
    turkiye({ id: 'turkiye-unstamped', eligibilityStructuredAt: null }),
    makeScholarship({ id: 'no-criteria', eligibilityCriteria: [] }),
    makeScholarship({
      id: 'residents-only',
      eligibleLevels: ['bachelor', 'master'],
      eligibilityCriteria: [
        nationality('residents', 'include', ['sen', 'ner', 'civ'], 'residence'),
        nationality('pas-residents-fr', 'exclude', ['fra'], 'residence'),
      ],
    }),
    makeScholarship({
      id: 'not-residents',
      eligibleLevels: ['bachelor', 'master'],
      eligibilityCriteria: [nationality('pas-residents', 'exclude', ['ner', 'ken'], 'residence')],
    }),
    makeScholarship({ id: 'bad-json', eligibilityCriteria: '{"oops":' }),
    makeScholarship({ id: 'not-analyzed', eligibleLevels: [] }),
    makeScholarship({
      id: 'suspended',
      eligibleLevels: ['bachelor', 'master'],
      cycle: makeCycle({ status: 'suspended' }),
    }),
    makeScholarship({
      id: 'everything-soft',
      eligibleLevels: ['master', 'doctorate'],
      fieldsScope: 'listed',
      relatedFieldIds: ['health'],
      eligibilityCriteria: [
        nationality('afrique', 'include', ['ner', 'sen', 'civ'], 'nationality', 'soft'),
        age('age', { max: 35 }, 'soft'),
        experience('xp', 36, 'soft'),
        language('ielts', { tests: [{ type: 'ielts', min: 6.5 }] }, 'hard'),
        // La citation officielle peut contenir « % » : elle n'est jamais un libellé KPB.
        { ...grade('moyenne', 14, 'hard'), officialTextFr: 'Avoir au minimum 70 %' },
        financialNeed('besoin'),
        other('lettre', 'hard'),
      ],
    }),
    makeScholarship({
      id: 'everything-hard',
      eligibleLevels: ['bachelor', 'master'],
      countryId: 'can',
      eligibilityCriteria: [
        nationality('residents', 'include', ['ner', 'bfa', 'cmr'], 'nationality_and_residence'),
        age('age', { min: 17, max: 24, asOf: { kind: 'cycle_close' } }),
        experience('xp', 12, 'hard', 'master'),
      ],
      cycle: makeCycle({ dateConfidence: 'estimated', closesAt: null, estimatedCloseAt: date('2027-03-01') }),
    }),
  ];
  // Un tiers des fiches de base, dupliquées avec des règles illisibles.
  for (const row of rows.slice(0, 4)) {
    rows.push({
      ...row,
      id: `${row.id}-with-unreadable`,
      eligibilityCriteria: [...(row.eligibilityCriteria as unknown[]), ...UNREADABLE],
    });
  }
  for (let i = 0; i < 12; i += 1) {
    rows.push(
      makeScholarship({
        id: `generic-${String(i).padStart(2, '0')}`,
        eligibleLevels: [TARGET_LEVELS[i % 4], TARGET_LEVELS[(i + 1) % 4]],
        fundingType: pick(rng(i), ['fully_funded', 'partially_funded', 'unknown']),
      }),
    );
  }
  return rows;
}

const PROFILES = (() => {
  const random = rng(20261013);
  return Array.from({ length: 400 }, () => randomProfile(random));
})();
const CATALOG = catalog();

/** Les critères `hard` des types qui peuvent exclure, par fiche. */
function excludingKeys(scholarship: MatchScholarship): Set<string> {
  return new Set(
    parseEligibilityCriteria(scholarship.eligibilityCriteria)
      .criteria.filter(
        (c) => c.impact === 'hard' && ['nationality', 'age', 'work_experience'].includes(c.type),
      )
      .map((c) => c.key),
  );
}

describe('invariants du moteur (profils aléatoires × catalogue synthétique)', () => {
  it('le jeu de données n’est pas vide de sens : chaque statut et chaque motif d’exclusion apparaissent', () => {
    const statuses = new Set<string>();
    const exclusionCodes = new Set<string>();
    for (const profile of PROFILES) {
      for (const scholarship of CATALOG) {
        const result = assess(profile, scholarship, NOW);
        statuses.add(result.status);
        result.exclusions.forEach((exclusion) => exclusionCodes.add(exclusion.code));
      }
    }
    expect([...statuses].sort()).toEqual(
      ['eligible', 'not_analyzed', 'not_eligible', 'suspended', 'to_verify'],
    );
    expect([...exclusionCodes].sort()).toEqual([
      'age_too_old',
      'age_too_young',
      'experience_insufficient',
      'level_other',
      'nationality_excluded',
      'nationality_not_listed',
      'residence_excluded',
      'residence_not_listed',
      'suspended',
    ]);
  });

  it('une bourse non éligible, suspendue ou non analysée n’est JAMAIS dans items', () => {
    for (const profile of PROFILES) {
      const run = matchScholarships(profile, CATALOG, NOW);
      const statusById = new Map(run.entries.map((e) => [e.scholarship.id, e.assessment.status]));
      expect(run.items.length).toBeLessThanOrEqual(10);
      for (const item of run.items) {
        expect(['eligible', 'to_verify']).toContain(statusById.get(item.scholarshipId));
        expect(item.status).toBe(statusById.get(item.scholarshipId));
      }
      // Compatibles d'abord, rangs contigus.
      const sections = run.items.map((item) => item.section);
      expect(sections).toEqual([...sections].sort((a, b) => (a === b ? 0 : a === 'compatible' ? -1 : 1)));
      expect(run.items.map((item) => item.rank)).toEqual(run.items.map((_, i) => i + 1));
    }
  });

  it('une règle inconnue ou invalide n’exclut jamais et ne change aucune exclusion', () => {
    const pairs = CATALOG.filter((row) => row.id.endsWith('-with-unreadable')).map((row) => [
      CATALOG.find((base) => `${base.id}-with-unreadable` === row.id)!,
      row,
    ]);
    expect(pairs).toHaveLength(4);
    for (const profile of PROFILES) {
      for (const [base, withUnreadable] of pairs) {
        const a = assess(profile, base, NOW);
        const b = assess(profile, withUnreadable, NOW);
        expect(b.exclusions).toEqual(a.exclusions);
        expect(b.status === 'eligible').toBe(false);
      }
      // JSON illisible ou vide : seul le niveau tamponné peut encore exclure.
      for (const id of ['bad-json', 'no-criteria']) {
        const result = assess(profile, CATALOG.find((row) => row.id === id)!, NOW);
        expect(result.exclusions.every((exclusion) => exclusion.code === 'level_other')).toBe(true);
        expect(result.status).not.toBe('eligible');
      }
    }
  });

  it('seule une règle dure, tamponnée, fraîche, sur une valeur confirmée peut exclure', () => {
    for (const profile of PROFILES) {
      for (const scholarship of CATALOG) {
        const result = assess(profile, scholarship, NOW);
        if (result.status !== 'not_eligible') continue;
        expect(isStructuredFresh(scholarship.eligibilityStructuredAt, NOW)).toBe(true);
        expect(profile.confirmed).toBe(true);
        const allowed = excludingKeys(scholarship);
        for (const exclusion of result.exclusions) {
          if (exclusion.code === 'level_other') continue;
          expect(allowed.has(exclusion.criterionKey ?? '')).toBe(true);
        }
      }
    }
  });

  it('aucun libellé KPB ne contient « % » ni « chance », citations officielles exclues', () => {
    for (const profile of PROFILES.slice(0, 120)) {
      for (const scholarship of CATALOG) {
        const result = assess(profile, scholarship, NOW);
        for (const point of [...result.reasons, ...result.toVerify, ...result.exclusions]) {
          for (const lang of ['fr', 'en'] as const) {
            const text = renderPoint(point, lang);
            expect([point.code, text, isHonestLabel(text)]).toEqual([point.code, text, true]);
          }
        }
      }
    }
  });

  it('sortie identique pour un `now` fixé, quel que soit l’ordre du catalogue', () => {
    const reversed = [...CATALOG].reverse();
    for (const profile of PROFILES.slice(0, 100)) {
      const first = matchScholarships(profile, CATALOG, NOW);
      const again = matchScholarships(profile, CATALOG, new Date(NOW.getTime()));
      const shuffled = matchScholarships(profile, reversed, NOW);
      expect(again).toEqual(first);
      expect(shuffled.items).toEqual(first.items);
      expect(shuffled.excludedSummary).toEqual(first.excludedSummary);
    }
  });

  it('les comptes s’additionnent', () => {
    for (const profile of PROFILES.slice(0, 50)) {
      const run = matchScholarships(profile, CATALOG, NOW);
      expect(run.eligibleCount + run.toVerifyCount + run.excludedCount + run.notAnalyzedCount).toBe(
        run.candidateCount,
      );
      expect(run.excludedSummary.groups.reduce((sum, group) => sum + group.count, 0)).toBe(
        run.excludedCount,
      );
    }
  });
});
