import { SCHOLARSHIP_CATALOG_V1 } from './scholarship-catalog.v1';
import { eligibilityCoverage } from './scholarship-catalog.validator';
import {
  renderEligibilityCoverage,
  summariseServedEligibility,
  type ServedEligibilityRow,
} from './scholarship-eligibility-coverage';

const NOW = new Date('2026-10-13T12:00:00.000Z');
const CRITERION = {
  key: 'pas-francais',
  type: 'nationality',
  impact: 'hard',
  appliesTo: 'nationality',
  mode: 'exclude',
  countries: ['fra'],
  officialTextFr: 'Texte.',
  officialTextEn: 'Text.',
  sourceUrl: 'https://example.org',
};

function row(overrides: Partial<ServedEligibilityRow>): ServedEligibilityRow {
  return {
    id: 'x',
    eligibleLevels: ['master'],
    eligibilityCriteria: [CRITERION],
    eligibilityStructuredAt: null,
    ...overrides,
  };
}

describe('couverture de l’éligibilité (verify:catalog)', () => {
  it('classe chaque fiche servie selon ce que le moteur peut en faire', () => {
    const coverage = summariseServedEligibility(
      [
        row({ id: 'seed', eligibleLevels: [], eligibilityCriteria: [] }),
        row({ id: 'tags', eligibilityCriteria: [] }),
        row({ id: 'brouillon' }),
        row({ id: 'frais', eligibilityStructuredAt: new Date('2026-09-01T00:00:00.000Z') }),
        row({ id: 'perime', eligibilityStructuredAt: new Date('2025-01-01T00:00:00.000Z') }),
        row({ id: 'illisible', eligibilityCriteria: [{ key: 'x' }] }),
      ],
      NOW,
    );
    expect(coverage).toEqual({
      served: 6,
      notAnalyzed: 1,
      levelsOnly: 2,
      drafts: 1,
      stampedFresh: 1,
      stampedStale: 1,
      withUnreadableCriteria: 1,
    });
  });

  it('avertit tant que le catalogue est en brouillon, et chiffre le rapport', () => {
    const report = renderEligibilityCoverage(
      eligibilityCoverage(SCHOLARSHIP_CATALOG_V1, NOW),
      summariseServedEligibility([], NOW),
      SCHOLARSHIP_CATALOG_V1.catalogVersion,
    );
    expect(report.warn).toBe(true);
    expect(report.lines[0]).toContain('0/36 reviewed and stamped');
    expect(report.lines[0]).toContain('36 draft(s)');
    expect(report.lines.at(-1)).toMatch(/^::warning::/);
  });

  it('se tait quand tout est relu et frais', () => {
    const repo = {
      ...eligibilityCoverage({ ...SCHOLARSHIP_CATALOG_V1, records: [] }, NOW),
      records: 1,
      stamped: 1,
    };
    const report = renderEligibilityCoverage(
      repo,
      summariseServedEligibility(
        [row({ eligibilityStructuredAt: new Date('2026-09-01T00:00:00.000Z') })],
        NOW,
      ),
      '1.5.0',
    );
    expect(report.warn).toBe(false);
    expect(report.lines.some((line) => line.startsWith('::warning::'))).toBe(false);
  });
});
