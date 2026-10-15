import { BadRequestException } from '@nestjs/common';

import { InternalRole } from '../../common/enums/internal-role.enum';
import type { AdminSessionUser } from '../auth/auth.service';
import {
  COVERAGE_LIST_LIMIT,
  EMPTY_ELIGIBILITY_STATE,
  eligibilityCoverageState,
  hasEligibilityInput,
  LAUNCH_GATE_PERCENT,
  pickEligibilityWrite,
  planEligibilityUpdate,
  summarizeCoverage,
  type CoverageRow,
  type EligibilityState,
} from './scholarship-eligibility-admin';

const NOW = new Date('2026-10-15T12:00:00.000Z');
const DAY_MS = 24 * 60 * 60 * 1000;
const daysAgo = (days: number) => new Date(NOW.getTime() - days * DAY_MS);

const ACTOR: AdminSessionUser = {
  id: 'admin-1',
  fullName: 'Aïcha Relectrice',
  email: 'aicha@kpb.test',
  role: InternalRole.ContentManager,
  languageScope: [],
};

const QUOTE = {
  officialTextFr: 'Ouvert aux ressortissants du Niger.',
  officialTextEn: 'Open to nationals of Niger.',
  sourceUrl: 'https://example.org/eligibility',
};

const NATIONALITY = {
  type: 'nationality',
  key: 'nationalite',
  impact: 'hard',
  appliesTo: 'nationality',
  mode: 'include',
  countries: ['ner', 'sen'],
  ...QUOTE,
};

function errorBody(fn: () => unknown): Record<string, unknown> {
  try {
    fn();
  } catch (error) {
    expect(error).toBeInstanceOf(BadRequestException);
    return (error as BadRequestException).getResponse() as Record<string, unknown>;
  }
  throw new Error('BadRequestException attendue');
}

describe('pickEligibilityWrite — lecture stricte des champs de l’éditeur', () => {
  it('ne voit rien quand le corps ne touche pas à l’éligibilité', () => {
    expect(hasEligibilityInput({ nameFr: 'X', eligibilityFr: ['texte libre'] })).toBe(false);
    expect(hasEligibilityInput({ markStructured: true })).toBe(true);
    expect(pickEligibilityWrite({ nameFr: 'X' })).toEqual({});
  });

  it('range les niveaux dans l’ordre canonique, sans doublon', () => {
    expect(
      pickEligibilityWrite({ eligibleLevels: ['doctorate', 'master', 'master'] }).eligibleLevels,
    ).toEqual(['master', 'doctorate']);
  });

  it('refuse un niveau inconnu par une 400 nommée (jamais un abandon silencieux)', () => {
    const body = errorBody(() => pickEligibilityWrite({ eligibleLevels: ['Licence'] }));
    expect(body.code).toBe('INVALID_ELIGIBLE_LEVELS');
    expect(errorBody(() => pickEligibilityWrite({ eligibleLevels: 'master' })).code).toBe(
      'INVALID_ELIGIBLE_LEVELS',
    );
  });

  it('refuse un fieldsScope inconnu, accepte null comme « unknown »', () => {
    expect(errorBody(() => pickEligibilityWrite({ fieldsScope: 'some' })).code).toBe(
      'INVALID_FIELDS_SCOPE',
    );
    expect(pickEligibilityWrite({ fieldsScope: null }).fieldsScope).toBe('unknown');
    expect(pickEligibilityWrite({ fieldsScope: 'listed' }).fieldsScope).toBe('listed');
  });

  it('valide les critères avec le validateur du moteur et rend la LISTE des erreurs', () => {
    const body = errorBody(() =>
      pickEligibilityWrite({
        eligibilityCriteria: [
          { ...NATIONALITY, countries: ['ner', 'XXX'] },
          { ...NATIONALITY, key: 'sans-citation', officialTextFr: '', sourceUrl: 'ftp://x' },
        ],
      }),
    );
    expect(body.code).toBe('INVALID_ELIGIBILITY_CRITERIA');
    const issues = body.issues as Array<{ path: string; code: string }>;
    expect(issues.map((issue) => issue.code)).toEqual(
      expect.arrayContaining(['unknown_country', 'missing_official_text', 'invalid_source_url']),
    );
    expect(issues.find((issue) => issue.code === 'unknown_country')?.path).toBe('[0].countries[1]');
    // Le message lisible (affiché par l'admin) cite chaque erreur.
    expect(Array.isArray(body.message)).toBe(true);
    expect((body.message as string[]).length).toBe(issues.length);
  });

  it('refuse une clé de critère en double et une valeur qui n’est pas un tableau', () => {
    expect(
      errorBody(() => pickEligibilityWrite({ eligibilityCriteria: [NATIONALITY, NATIONALITY] }))
        .code,
    ).toBe('INVALID_ELIGIBILITY_CRITERIA');
    expect(errorBody(() => pickEligibilityWrite({ eligibilityCriteria: {} })).code).toBe(
      'INVALID_ELIGIBILITY_CRITERIA',
    );
  });

  it('stocke la copie normalisée (sans champ superflu) ; null vide la liste', () => {
    const write = pickEligibilityWrite({
      eligibilityCriteria: [{ ...NATIONALITY, note: 'champ inconnu' }],
    });
    expect(write.eligibilityCriteria).toHaveLength(1);
    expect(write.eligibilityCriteria?.[0]).not.toHaveProperty('note');
    expect(pickEligibilityWrite({ eligibilityCriteria: null }).eligibilityCriteria).toEqual([]);
  });

  it('exige un booléen pour markStructured', () => {
    expect(errorBody(() => pickEligibilityWrite({ markStructured: 'yes' })).code).toBe(
      'INVALID_MARK_STRUCTURED',
    );
  });
});

describe('planEligibilityUpdate — le tampon certifie le contenu enregistré', () => {
  const structured: EligibilityState = {
    eligibleLevels: ['master'],
    fieldsScope: 'all',
    eligibilityCriteria: [NATIONALITY],
    eligibilityStructuredAt: daysAgo(10),
    eligibilityStructuredBy: 'Ancien relecteur',
  };

  it('« Conditions vérifiées » tamponne maintenant, au nom de l’auteur, et s’audite', () => {
    const plan = planEligibilityUpdate(
      structured,
      pickEligibilityWrite({ markStructured: true }),
      ACTOR,
      NOW,
    );
    expect(plan.data.eligibilityStructuredAt).toEqual(NOW);
    expect(plan.data.eligibilityStructuredBy).toBe('Aïcha Relectrice');
    expect(plan.audit?.action).toBe('scholarship.eligibility_structured');
    expect(plan.audit?.changes).toMatchObject({
      stamped: true,
      eligibleLevels: ['master'],
      criteriaKeys: ['nationalite'],
      previousStructuredAt: daysAgo(10).toISOString(),
    });
  });

  it('refuse de tamponner une fiche sans niveau', () => {
    expect(
      errorBody(() =>
        planEligibilityUpdate(EMPTY_ELIGIBILITY_STATE, { markStructured: true }, ACTOR, NOW),
      ).code,
    ).toBe('ELIGIBILITY_LEVELS_REQUIRED');
    expect(
      errorBody(() =>
        planEligibilityUpdate(structured, { eligibleLevels: [], markStructured: true }, ACTOR, NOW),
      ).code,
    ).toBe('ELIGIBILITY_LEVELS_REQUIRED');
  });

  it('refuse de tamponner des critères stockés illisibles', () => {
    const broken = { ...structured, eligibilityCriteria: [{ type: 'age', key: 'x' }] };
    expect(errorBody(() => planEligibilityUpdate(broken, { markStructured: true }, ACTOR, NOW)).code).toBe(
      'INVALID_ELIGIBILITY_CRITERIA',
    );
  });

  it('un contenu modifié SANS nouveau tampon retire l’ancien (retour au brouillon)', () => {
    const plan = planEligibilityUpdate(
      structured,
      pickEligibilityWrite({ eligibleLevels: ['master', 'doctorate'] }),
      ACTOR,
      NOW,
    );
    expect(plan.data).toEqual({
      eligibleLevels: ['master', 'doctorate'],
      eligibilityStructuredAt: null,
      eligibilityStructuredBy: null,
    });
    expect(plan.audit?.action).toBe('scholarship.eligibility_updated');
    expect(plan.audit?.changes).toMatchObject({
      changedFields: ['eligibleLevels'],
      stampCleared: true,
      stamped: false,
    });
  });

  it('rien de changé, rien de demandé : aucune écriture, aucun audit', () => {
    const plan = planEligibilityUpdate(
      structured,
      pickEligibilityWrite({
        eligibleLevels: ['master'],
        fieldsScope: 'all',
        eligibilityCriteria: [NATIONALITY],
      }),
      ACTOR,
      NOW,
    );
    expect(plan).toEqual({ data: {}, audit: null });
  });

  it('markStructured: false retire le tampon et s’audite', () => {
    const plan = planEligibilityUpdate(structured, { markStructured: false }, ACTOR, NOW);
    expect(plan.data).toEqual({ eligibilityStructuredAt: null, eligibilityStructuredBy: null });
    expect(plan.audit?.action).toBe('scholarship.eligibility_unstamped');
  });

  it('l’audit ne porte aucune donnée personnelle ni citation', () => {
    const plan = planEligibilityUpdate(
      structured,
      pickEligibilityWrite({ markStructured: true }),
      ACTOR,
      NOW,
    );
    const text = JSON.stringify(plan.audit);
    expect(text).not.toContain('aicha@kpb.test');
    expect(text).not.toContain(QUOTE.officialTextFr);
  });

  it('nomme l’auteur par son nom, sinon son e-mail, sinon son identifiant', () => {
    const stamp = (actor: AdminSessionUser | undefined) =>
      planEligibilityUpdate(structured, { markStructured: true }, actor, NOW).data
        .eligibilityStructuredBy;
    expect(stamp({ ...ACTOR, fullName: '  ' })).toBe('aicha@kpb.test');
    expect(stamp({ ...ACTOR, fullName: '', email: '' })).toBe('admin-1');
    expect(stamp(undefined)).toBe('unknown-admin');
  });
});

describe('couverture — la porte de lancement', () => {
  let seq = 0;
  function row(overrides: Partial<CoverageRow> = {}): CoverageRow {
    seq += 1;
    return {
      id: `sch-${String(seq).padStart(3, '0')}`,
      nameFr: `Bourse ${String(seq).padStart(3, '0')}`,
      nameEn: `Scholarship ${seq}`,
      eligibleLevels: ['master'],
      eligibilityCriteria: [],
      eligibilityStructuredAt: daysAgo(30),
      eligibilityStructuredBy: 'KPB',
      ...overrides,
    };
  }

  it('classe chaque fiche : fraîche, périmée (400 jours), brouillon, non analysée', () => {
    expect(eligibilityCoverageState(row(), NOW)).toBe('fresh');
    expect(eligibilityCoverageState(row({ eligibilityStructuredAt: daysAgo(399) }), NOW)).toBe(
      'fresh',
    );
    expect(eligibilityCoverageState(row({ eligibilityStructuredAt: daysAgo(400) }), NOW)).toBe(
      'stale',
    );
    expect(eligibilityCoverageState(row({ eligibilityStructuredAt: null }), NOW)).toBe(
      'unstructured',
    );
    // Sans niveau, même tamponnée : non analysée (jamais montrée par le test).
    expect(eligibilityCoverageState(row({ eligibleLevels: [] }), NOW)).toBe('not_analyzed');
  });

  it('compte, liste les fiches à structurer dans l’ordre, et calcule le pourcentage', () => {
    const rows = [
      row(),
      row({ nameFr: 'Zeta', eligibilityStructuredAt: daysAgo(500) }),
      row({ nameFr: 'Alpha', eligibilityStructuredAt: null }),
      row({ nameFr: 'Beta', eligibleLevels: [] }),
    ];
    const coverage = summarizeCoverage(rows, NOW);
    expect(coverage).toMatchObject({
      total: 4,
      structuredFresh: 1,
      stale: 1,
      unstructured: 1,
      notAnalyzed: 1,
      coveragePercent: 25,
      launchReady: false,
      freshnessDays: 400,
      launchGatePercent: LAUNCH_GATE_PERCENT,
      truncated: false,
    });
    expect(coverage.toStructure.map((item) => [item.nameFr, item.state])).toEqual([
      ['Beta', 'not_analyzed'],
      ['Alpha', 'unstructured'],
      ['Zeta', 'stale'],
    ]);
    expect(coverage.toStructureIds).toEqual(coverage.toStructure.map((item) => item.id));
  });

  it('ouvre la porte à 90 % exactement, jamais sur un arrondi', () => {
    const nine = [...Array.from({ length: 9 }, () => row()), row({ eligibilityStructuredAt: null })];
    expect(summarizeCoverage(nine, NOW)).toMatchObject({ coveragePercent: 90, launchReady: true });

    // 8 996 / 10 000 = 89,96 % : affiché 89,9, porte fermée.
    const fresh = Array.from({ length: 8996 }, () => row());
    const rest = Array.from({ length: 1004 }, () => row({ eligibleLevels: [] }));
    const coverage = summarizeCoverage([...fresh, ...rest], NOW);
    expect(coverage.coveragePercent).toBe(89.9);
    expect(coverage.launchReady).toBe(false);
    expect(coverage.toStructure).toHaveLength(COVERAGE_LIST_LIMIT);
    expect(coverage.truncated).toBe(true);
  });

  it('un catalogue public vide n’est pas « prêt »', () => {
    expect(summarizeCoverage([], NOW)).toMatchObject({
      total: 0,
      coveragePercent: 0,
      launchReady: false,
    });
  });

  it('signale les fiches fraîches dont un critère stocké est illisible', () => {
    const coverage = summarizeCoverage(
      [row({ eligibilityCriteria: [{ type: 'nationality', key: 'x' }] }), row()],
      NOW,
    );
    expect(coverage.invalidCriteria).toBe(1);
    expect(coverage.structuredFresh).toBe(2);
  });
});
